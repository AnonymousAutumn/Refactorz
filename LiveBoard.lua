--[[
	LiveBoard - Displays live donation notifications.

	Features:
	- Cross-server donation subscription
	- Tiered donation display
	- Frame lifecycle management
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local modulesFolder = ReplicatedStorage:WaitForChild("Modules")
local configurationFolder = ReplicatedStorage:WaitForChild("Configuration")
local Connections = require(modulesFolder.Wrappers.Connections)
local GameConfig = require(configurationFolder.GameConfig)
local DonationTierCalculator = require(script.DonationTierCalculator)
local DonationFrameManager = require(script.DonationFrameManager)
local DonationFrameFactory = require(script.DonationFrameFactory)
local CrossServerBridge = require(script.CrossServerBridge)

local instancesFolder = ReplicatedStorage.Instances
local guiPrefabs = instancesFolder.GuiPrefabs
local liveDonationPrefab = guiPrefabs.LiveDonationPrefab

local leaderboardsFolder = workspace.Leaderboards
local liveDonationLeaderboard = leaderboardsFolder.Live
local leaderboardSurfaceGui = liveDonationLeaderboard.SurfaceGui
local leaderboardMainFrame = leaderboardSurfaceGui.MainFrame
local donationScrollingFrame = leaderboardMainFrame.ScrollingFrame
local largeDonationDisplayFrame = donationScrollingFrame.PriorityEntriesFrame
local standardDonationDisplayFrame = donationScrollingFrame.NormalEntriesFrame

local DEFAULT_DONATION_DISPLAY_DURATION = GameConfig.LIVE_DONATION_CONFIG.DEFAULT_LIFETIME

local connectionsMaids = Connections.new()

local frameManager = nil
local crossServerBridge = nil
local isShuttingDown = false
local activeTweens = {}

local function trackConnection(connection: RBXScriptConnection): RBXScriptConnection
	connectionsMaids:add(connection)
	return connection
end

local function trackTween(tween: Tween): Tween
	table.insert(activeTweens, tween)
	return tween
end

local function cleanupAllResources()
	connectionsMaids:disconnect()

	for _, tween in pairs(activeTweens) do
		pcall(function()
			if tween then
				tween:Cancel()
			end
		end)
	end
	table.clear(activeTweens)
end

local function handleCountdownCompletion(donationFrame: Frame)
	frameManager:removeFromTracking(donationFrame, "large")

	frameManager:adjustLayoutOrdering("Normal")
	donationFrame.LayoutOrder = 1

	local _, maxStandardFrames = DonationFrameManager.getMaxLimits()
	frameManager:enforceLimit("standard", maxStandardFrames)

	donationFrame.Parent = frameManager:getStandardContainer()
	frameManager:addStandardFrame(donationFrame)

	frameManager:scheduleCleanup(donationFrame, "standard", DEFAULT_DONATION_DISPLAY_DURATION)
end

local function setupLargeDonationDisplay(donationFrame: Frame, tierInfo: any)
	local setupSuccess = DonationFrameFactory.setupLargeDonationCountdown(donationFrame, tierInfo, handleCountdownCompletion, trackTween, trackConnection)

	if not setupSuccess then
		warn(`[{script.Name}] Failed to setup large donation countdown`)
		return
	end

	local maxLargeFrames, _ = DonationFrameManager.getMaxLimits()
	frameManager:enforceLimit("large", maxLargeFrames)

	donationFrame.Parent = frameManager:getLargeContainer()
	frameManager:addLargeFrame(donationFrame)
end

local function setupStandardDonationDisplay(donationFrame: Frame)
	local _, maxStandardFrames = DonationFrameManager.getMaxLimits()
	frameManager:enforceLimit("standard", maxStandardFrames)

	donationFrame.Parent = frameManager:getStandardContainer()
	frameManager:addStandardFrame(donationFrame)

	frameManager:scheduleCleanup(donationFrame, "standard", DEFAULT_DONATION_DISPLAY_DURATION)
end

local function createAndDisplayDonationFrame(donorUserId: number, recipientUserId: number, donationAmount: number, tierInfo: any, isLargeDonation: boolean)
	local newDonationFrame = DonationFrameFactory.createFrame(liveDonationPrefab, donorUserId, recipientUserId, donationAmount, tierInfo, isLargeDonation, trackTween)

	if isLargeDonation then
		setupLargeDonationDisplay(newDonationFrame, tierInfo)
	else
		setupStandardDonationDisplay(newDonationFrame)
	end
end

local function processDonationNotification(donationNotificationData: any)
	if isShuttingDown then
		return
	end
	if not CrossServerBridge.validateDonationData(donationNotificationData) then
		return
	end

	local tierInfo = DonationTierCalculator.determineTierInfo(donationNotificationData.Amount)
	local isHighTier = DonationTierCalculator.isHighTier(tierInfo)

	if isHighTier then
		createAndDisplayDonationFrame(
			donationNotificationData.Donor,
			donationNotificationData.Receiver,
			donationNotificationData.Amount,
			tierInfo,
			true
		)
	else
		frameManager:adjustLayoutOrdering("Normal")
		createAndDisplayDonationFrame(
			donationNotificationData.Donor,
			donationNotificationData.Receiver,
			donationNotificationData.Amount,
			tierInfo,
			false
		)
	end
end

local function cleanup()
	isShuttingDown = true

	if frameManager then
		frameManager:shutdown()
		frameManager:destroyAll()
	end

	if crossServerBridge then
		crossServerBridge:shutdown()
	end

	cleanupAllResources()
end

local function initialize()
	frameManager = DonationFrameManager.new(largeDonationDisplayFrame, standardDonationDisplayFrame)

	crossServerBridge = CrossServerBridge.new()

	local subscribed = crossServerBridge:subscribe(processDonationNotification)
	if not subscribed then
		warn(`[{script.Name}] Failed to subscribe to cross-server donations`)
	end

	frameManager:startCleanupLoop()

	game:BindToClose(cleanup)
end

initialize()