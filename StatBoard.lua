--[[
	StatBoard - Server-side leaderboard management system.

	Features:
	- Multiple leaderboard tracking
	- DataStore data fetching
	- Display frame management
	- Client update broadcasting
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local networkFolder = ReplicatedStorage.Network
local leaderboardRemoteEvents = networkFolder.Remotes.Leaderboards

local modulesFolder = ReplicatedStorage.Modules
local configurationFolder = ReplicatedStorage.Configuration
local Connections = require(modulesFolder.Wrappers.Connections)
local EnhancedValidation = require(modulesFolder.Utilities.EnhancedValidation)
local GameConfig = require(configurationFolder.GameConfig)
local DataFetcher = require(script.DataFetcher)
local DisplayManager = require(script.DisplayManager)
local UpdateScheduler = require(script.UpdateScheduler)
local UIElementFinder = require(script.UIElementFinder)

local instancesFolder = ReplicatedStorage.Instances
local guiPrefabs = instancesFolder.GuiPrefabs
local leaderboardEntryPrefab = guiPrefabs.LeaderboardEntryPrefab

local leaderboardsContainer = workspace.Leaderboards
UIElementFinder.leaderboardsContainer = leaderboardsContainer

local TRACKED_LEADERBOARD_CONFIGURATIONS = {
	{
		statisticName = "Donated",
		dataStoreKey = GameConfig.DATASTORE.DONATED_ORDERED_KEY,
		clientUpdateEvent = leaderboardRemoteEvents.UpdateDonated,
		displayType = "currency",
	},
	{
		statisticName = "Raised",
		dataStoreKey = GameConfig.DATASTORE.RAISED_ORDERED_KEY,
		clientUpdateEvent = leaderboardRemoteEvents.UpdateRaised,
		displayType = "currency",
	},
	{
		statisticName = "Wins",
		dataStoreKey = GameConfig.DATASTORE.WINS_ORDERED_KEY,
		clientUpdateEvent = leaderboardRemoteEvents.UpdateWins,
		displayType = "number",
	},
}

local LEADERBOARD_ENTRY_FADE_IN_DURATION = 0.5
local DATASTORE_MAXIMUM_PAGE_SIZE = 100
local UPDATE_STAGGER_DELAY = 2

local connectionsMaid = Connections.new()

local activeLeaderboards = {}
local activeThreads = {}

local isShuttingDown = false

local function trackThread(thr: thread): thread
	activeThreads[#activeThreads + 1] = thr
	return thr
end

local function cancelAllThreads()
	for i = 1, #activeThreads do
		local thr = activeThreads[i]
		if thr and coroutine.status(thr) ~= "dead" then
			task.cancel(thr)
		end
	end
	table.clear(activeThreads)
end

local function cleanupAllResources()
	connectionsMaid:disconnect()
	cancelAllThreads()
end

local function createSystemConfiguration(leaderboardConfig: any): any
	return {
		AVATAR_HEADSHOT_URL = GameConfig.AVATAR_HEADSHOT_URL,
		ROBUX_ICON_UTF = GameConfig.ROBUX_ICON_UTF,
		LEADERBOARD_CONFIG = GameConfig.LEADERBOARD_CONFIG,
		FormatHandler = require(modulesFolder.Utilities.FormatString),
		displayType = leaderboardConfig.displayType,
	}
end

local function refreshLeaderboardDataAsync(leaderboardState: any): boolean
	if isShuttingDown then
		return false
	end

	local leaderboardConfig = leaderboardState.config
	local orderedDataStore = leaderboardState.dataStore
	local displayFrameCollection = leaderboardState.displayFrames
	local systemConfiguration = leaderboardState.systemConfig

	local maximumEntriesToRetrieve =
		math.min(systemConfiguration.LEADERBOARD_CONFIG.DISPLAY_COUNT, DATASTORE_MAXIMUM_PAGE_SIZE)

	local dataRetrievalSuccess, retrievedDataResult = DataFetcher.retrieveLeaderboardData(
		orderedDataStore,
		maximumEntriesToRetrieve,
		systemConfiguration
	)

	if not dataRetrievalSuccess then
		UpdateScheduler.updateLeaderboardState(leaderboardState, false)
		return false
	end

	if not DataFetcher.validateLeaderboardDataPages(retrievedDataResult) then
		UpdateScheduler.updateLeaderboardState(leaderboardState, false)
		return false
	end

	local leaderboardDataPages = retrievedDataResult

	local extractSuccess, processedLeaderboardEntries = DataFetcher.extractLeaderboardEntries(
		leaderboardDataPages,
		systemConfiguration.LEADERBOARD_CONFIG.DISPLAY_COUNT
	)

	if not extractSuccess or not processedLeaderboardEntries then
		UpdateScheduler.updateLeaderboardState(leaderboardState, false)
		return false
	end

	local maximumCharacterDisplayCount =
		math.min(systemConfiguration.LEADERBOARD_CONFIG.TOP_DISPLAY_AMOUNT, #processedLeaderboardEntries)

	local topPlayersForCharacterDisplay =
		DataFetcher.prepareTopPlayersData(processedLeaderboardEntries, maximumCharacterDisplayCount)
	DataFetcher.sendTopPlayerDataToClients(
		leaderboardConfig.clientUpdateEvent,
		topPlayersForCharacterDisplay,
		leaderboardConfig.statisticName
	)

	local displaySuccess = DisplayManager.updateDisplayFrames(
		displayFrameCollection,
		processedLeaderboardEntries,
		systemConfiguration,
		leaderboardConfig.statisticName
	)

	if not displaySuccess then
		UpdateScheduler.updateLeaderboardState(leaderboardState, false)
		return false
	end

	UpdateScheduler.updateLeaderboardState(leaderboardState, true)
	return true
end

local function connectClientReadyEvent(leaderboardState: any)

	local connection = leaderboardState.config.clientUpdateEvent.OnServerEvent:Connect(function(
		requestingPlayer,
		clientMessage
	)
		if not EnhancedValidation.validateRemoteArgs(requestingPlayer, {
			{clientMessage, "string", {minLength = 1, maxLength = 100}},
			}) then
			return
		end

		UpdateScheduler.handleClientReadyEvent(requestingPlayer, clientMessage, leaderboardState)
	end)
	connectionsMaid:add(connection)
end

local function initializeLeaderboard(leaderboardConfig: any, index: number): any?
	local success, orderedDataStore = pcall(function()
		return DataStoreService:GetOrderedDataStore(leaderboardConfig.dataStoreKey)
	end)

	if not success then
		warn(`[{script.Name}] Failed to get OrderedDataStore for {leaderboardConfig.statisticName}: {tostring(orderedDataStore)}`)
		return nil
	end

	local leaderboardScrollingFrame = UIElementFinder.getLeaderboardUIElements(leaderboardConfig)
	if not leaderboardScrollingFrame then
		warn(`[{script.Name}] Missing leaderboard UI for {leaderboardConfig.statisticName}`)
		return nil
	end

	local systemConfiguration = createSystemConfiguration(leaderboardConfig)

	local displayFrames = DisplayManager.createLeaderboardDisplayFrames(
		leaderboardScrollingFrame,
		systemConfiguration.LEADERBOARD_CONFIG.DISPLAY_COUNT,
		systemConfiguration.LEADERBOARD_CONFIG.COLORS,
		LEADERBOARD_ENTRY_FADE_IN_DURATION,
		leaderboardEntryPrefab
	)

	if #displayFrames == 0 then
		warn(`[{script.Name}] Failed to create display frames for leaderboard: {leaderboardConfig.statisticName}`)
		return nil
	end

	local leaderboardState = {
		config = leaderboardConfig,
		dataStore = orderedDataStore,
		displayFrames = displayFrames,
		systemConfig = systemConfiguration,
		updateThread = nil,
		consecutiveFailures = 0,
		lastUpdateTime = 0,
		lastUpdateSuccess = false,
	}

	connectClientReadyEvent(leaderboardState)

	task.delay(index * UPDATE_STAGGER_DELAY, function()
		if not isShuttingDown then
			UpdateScheduler.setupLeaderboardUpdateLoop(leaderboardState)
		end
	end)

	return leaderboardState
end

local function initializeAllLeaderboards()
	UpdateScheduler.refreshLeaderboardDataAsync = refreshLeaderboardDataAsync
	UpdateScheduler.trackThread = trackThread
	UpdateScheduler.isShuttingDown = isShuttingDown

	for index = 1, #TRACKED_LEADERBOARD_CONFIGURATIONS do
		local leaderboardConfig = TRACKED_LEADERBOARD_CONFIGURATIONS[index]
		local leaderboardState = initializeLeaderboard(leaderboardConfig, index)
		if leaderboardState then
			activeLeaderboards[#activeLeaderboards + 1] = leaderboardState
		else
			warn(`[{script.Name}] Failed to initialize leaderboard: {leaderboardConfig.statisticName}`)
		end
	end
end

local function cleanup()
	isShuttingDown = true
	UpdateScheduler.isShuttingDown = true
	cleanupAllResources()
	table.clear(activeLeaderboards)
end

local function initialize()
	initializeAllLeaderboards()

	game:BindToClose(cleanup)
end

initialize()