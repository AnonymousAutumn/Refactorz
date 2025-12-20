--[[
	Booths - Manages booth claiming and purchasing.

	Features:
	- Booth claiming system
	- Gamepass verification
	- Stand replication
]]

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local networkFolder = ReplicatedStorage.Network
local remoteEvents = networkFolder.Remotes.Events
local unclaimStandRemoteEvent = remoteEvents.UnclaimStand
local toggleStandClaimRemoteEvent = remoteEvents.ToggleStandClaim
local refreshStandRemoteEvent = remoteEvents.RefreshStand
local sendNotificationRemoteEvent = remoteEvents.SendMessage

local modulesFolder = ReplicatedStorage.Modules
local configurationFolder = ReplicatedStorage.Configuration
local Connections = require(modulesFolder.Wrappers.Connections)
local PurchasesWrapper = require(modulesFolder.Wrappers.Purchases)
local PassCache = require(modulesFolder.Caches.PassCache)
local StandManager = require(modulesFolder.Managers.Stands)
local EnhancedValidation = require(modulesFolder.Utilities.EnhancedValidation)
local RateLimiter = require(modulesFolder.Utilities.RateLimiter)
local GameConfig = require(configurationFolder.GameConfig)
local Claimer = require(script.Claimer)

local connectionsMaid = Connections.new()
local isShuttingDown = false

local standObjects = {}
local MapPlayerToStand = {}
local claimedStands = {}

local function replicateStandToClient(player: Player, standModel: Model, gamepasses: {}, remove: boolean)
	refreshStandRemoteEvent:FireClient(player, standModel, gamepasses, remove)
end

local function notify(player: Player, message: string, messageType: string)
	sendNotificationRemoteEvent:FireClient(player, message, messageType)
end

local function finalizeClaim(player: Player, standObj: any, gamepasses: {})
	standObj:Claim(player)
	MapPlayerToStand[player.Name] = standObj

	claimedStands[standObj.Stand] = {
		Owner = player,
		gamepasses = gamepasses,
	}

	refreshStandRemoteEvent:FireAllClients(standObj.Stand, gamepasses, false)
end

local function promptGamepassPurchase(player: Player, passId: number): boolean
	local ok, err = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, passId)
	end)

	if not ok then
		warn(`[{script.Name}] Failed to prompt purchase for {player.Name}: {err}`)
		notify(player, "Purchase failed. Please try again.", "Error")
		return false
	end

	local bindable = Instance.new("BindableEvent")
	local success = false

	local connection
	connection = MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(p, purchasedId, wasSuccessful)
		if p == player and purchasedId == passId then
			success = wasSuccessful
			bindable:Fire()
			connection:Disconnect()
		end
	end)

	bindable.Event:Wait()
	bindable:Destroy()
	return success
end

function TryClaimStand(player: Player, standObj: any)
	if MapPlayerToStand[player.Name] then
		return
	end

	local cached = PassCache.GetPlayerCachedGamepassData(player)
	local gamepasses = cached and cached.gamepasses or {}

	local passId = GameConfig.MONETIZATION.STAND_ACCESS

	local _, ownsPass = PurchasesWrapper.doesPlayerOwnPass(player, passId)
	if ownsPass then
		finalizeClaim(player, standObj, gamepasses)
		return
	end

	local purchaseSuccess = promptGamepassPurchase(player, passId)
	if purchaseSuccess then
		finalizeClaim(player, standObj, gamepasses)
	end
end

local function unclaimStand(player: Player)
	local standObj = MapPlayerToStand[player.Name]
	if not standObj then
		return
	end

	standObj:Reset()
	MapPlayerToStand[player.Name] = nil
	claimedStands[standObj.Stand] = nil

	refreshStandRemoteEvent:FireAllClients(standObj.Stand, nil, true)
	notify(player, "You've unclaimed your booth.", "Error")
end

local function replicateAllStandsToPlayer(player: Player)
	if isShuttingDown then
		return
	end

	for standModel, _standObj in pairs(standObjects) do
		local data = claimedStands[standModel]
		local gamepasses = data and data.gamepasses or {}

		replicateStandToClient(player, standModel, gamepasses, false)
	end
end

local function cleanup()
	isShuttingDown = true
	connectionsMaid:disconnect()

	for _, standObj in pairs(MapPlayerToStand) do
		standObj:Reset()
	end

	table.clear(MapPlayerToStand)
	table.clear(claimedStands)
	table.clear(standObjects)
end

local function findAvailableStand(): any?
	for standModel, standObj in pairs(standObjects) do
		if not claimedStands[standModel] then
			return standObj
		end
	end
	return nil
end

local function toggleStandClaim(player: Player)
	-- Scenario 2: User has stand claimed = unclaim stand
	if MapPlayerToStand[player.Name] then
		unclaimStand(player)
		return
	end

	-- Try to find an available stand
	local availableStand = findAvailableStand()

	-- Scenario 3: User has no stand + no stands available
	if not availableStand then
		notify(player, "All booths are currently occupied.", "Error")
		return
	end

	-- Scenario 1: User has no stand + stand is available = claim stand
	TryClaimStand(player, availableStand)
end

local function initialize()
	StandManager.MapPlayerToStandTable(MapPlayerToStand)

	for _, stand in ipairs(Workspace:WaitForChild("Stands"):GetChildren()) do
		if stand:IsA("Model") and stand:FindFirstChild("PromptHolder") then
			stand.Positioner.Transparency = 1

			standObjects[stand] = Claimer.new(stand, TryClaimStand, refreshStandRemoteEvent, claimedStands)
		end
	end

	connectionsMaid:add(
		toggleStandClaimRemoteEvent.OnServerEvent:Connect(function(player)
			if not EnhancedValidation.validatePlayer(player) then
				warn(`[{script.Name}] Invalid player for toggle stand claim event.`)
				return
			end

			if not RateLimiter.checkRateLimit(player, "ToggleStandClaim", 1) then
				return
			end

			toggleStandClaim(player)
		end)
	)

	connectionsMaid:add(
		unclaimStandRemoteEvent.OnServerEvent:Connect(function(player)
			if not EnhancedValidation.validatePlayer(player) then
				warn(`[{script.Name}] Invalid player for unclaim event.`)
				return
			end

			if not RateLimiter.checkRateLimit(player, "UnclaimStand", 1) then
				return
			end

			unclaimStand(player)
		end)
	)

	connectionsMaid:add(Players.PlayerAdded:Connect(replicateAllStandsToPlayer))
	connectionsMaid:add(Players.PlayerRemoving:Connect(unclaimStand))

	game:BindToClose(cleanup)
end

initialize()