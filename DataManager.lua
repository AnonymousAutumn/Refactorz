--[[
	DataManager - Orchestrates player data loading, leaderboard creation, and cross-server sync.

	Features:
	- Player initialization with timeout protection
	- Leaderboard creation on player join
	- Cross-server leaderboard updates
	- Graceful shutdown with data persistence
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local networkFolder = ReplicatedStorage.Network
local bindableEvents = networkFolder.Bindables.Events
local signalsFolder = networkFolder.Signals
local updateUIBindableEvent = bindableEvents.UpdateUI
local dataLoadedRemoteEvent = signalsFolder.DataLoaded

local modulesFolder = ReplicatedStorage.Modules
local configurationFolder = ReplicatedStorage.Configuration
local Connections = require(modulesFolder.Wrappers.Connections)
local PlayerData = require(modulesFolder.Managers.PlayerData)
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local Coins = require(modulesFolder.Utilities.Coins)
local GameConfig = require(configurationFolder.GameConfig)
local LeaderboardBuilder = require(script.LeaderboardBuilder)
local InitStateTracker = require(script.InitStateTracker)
local CrossServerSync = require(script.CrossServerSync)

local PLAYER_INIT_TIMEOUT = 30
local INIT_STATE_CLEANUP_DELAY = 60
local UI_UPDATE_STATISTIC = "Raised"

local KICK_MESSAGES = {
	DATA_FETCH_ERROR = "Error fetching data: %s",
	DATA_LOAD_FAILED = "Data loading failed. Please rejoin.",
	INIT_TIMEOUT = "Data initialization timed out. Please rejoin.",
}

local initTracker = InitStateTracker.new()
local crossServerSync = CrossServerSync.new()
local connectionsMaid = Connections.new()

local orderedDataStoreRegistry: { [string]: OrderedDataStore } = {}
local isShuttingDown = false

local function safeKick(player: Player, message: string)
	if ValidationUtils.isValidPlayer(player) then
		player:Kick(message)
	end
end

local function initializeDataStoreRegistry(): boolean
	local success, errorMessage = pcall(function()
		orderedDataStoreRegistry = {
			Wins = DataStoreService:GetOrderedDataStore(GameConfig.DATASTORE.WINS_ORDERED_KEY),
			Donated = DataStoreService:GetOrderedDataStore(GameConfig.DATASTORE.DONATED_ORDERED_KEY),
			Raised = DataStoreService:GetOrderedDataStore(GameConfig.DATASTORE.RAISED_ORDERED_KEY),
		}
	end)

	if not success then
		warn(`[{script.Name}] Failed to initialize DataStore registry: {tostring(errorMessage)}`)
	end

	return success
end

local function triggerUIRefresh(player: Player)
	if not ValidationUtils.isValidPlayer(player) then
		return
	end

	local success, errorMessage = pcall(function()
		updateUIBindableEvent:Fire(false, { Viewer = player }, true)
	end)

	if not success then
		warn(`[{script.Name}] Failed to refresh UI for player {player.Name} (UserId: {player.UserId}): {tostring(errorMessage)}`)
	end
end

local function updatePlayerStatisticDisplay(targetPlayer: Player, statisticName: string, updatedValue: number)
	local leaderboardFolder = LeaderboardBuilder.getLeaderstatsFolder(targetPlayer)
	if not leaderboardFolder then
		warn(`[{script.Name}] No leaderboard display found for player {targetPlayer.Name} (UserId: {targetPlayer.UserId})`)
		return
	end

	local statisticObject = LeaderboardBuilder.getStatisticObject(leaderboardFolder, statisticName)
	if not statisticObject then
		warn(`[{script.Name}] Statistic {statisticName} not found for player {targetPlayer.Name} (UserId: {targetPlayer.UserId})`)
		return
	end

	if statisticObject.Value == updatedValue then
		return
	end

	statisticObject.Value = updatedValue

	if statisticName == UI_UPDATE_STATISTIC then
		triggerUIRefresh(targetPlayer)
	end
end

local function processLeaderboardUpdate(crossServerMessage: any)
	if isShuttingDown then
		return
	end

	local updateData = CrossServerSync.extractUpdate(crossServerMessage)
	if not updateData then
		warn(`[{script.Name}] Invalid leaderboard update message received`)
		return
	end

	PlayerData:UpdatePlayerStatisticAndPublishChanges(updateData.UserId, updateData.Stat, updateData.Value, true, true)

	local targetPlayer = Players:GetPlayerByUserId(updateData.UserId)
	if targetPlayer and ValidationUtils.isValidPlayer(targetPlayer) then
		updatePlayerStatisticDisplay(targetPlayer, updateData.Stat, updateData.Value)
		Coins.SpawnCoinsFromPart(workspace.World.Environment.CoinSpawner, targetPlayer, 5)
	end
end

local function loadPlayerStatisticsData(playerUserId: number)
	PlayerData:GetOrCreatePlayerStatisticsData(playerUserId)
end

local function createPlayerLeaderboard(player: Player)
	local leaderboardCreated = LeaderboardBuilder.createLeaderboard(player)

	if not leaderboardCreated then
		error("Player leaderboard display creation failed")
	end
end

local function handleFailedInit(player: Player, errorMessage: string)
	warn(`[PlayerStatisticsManager] Error initializing player statistics for {player.Name} (UserId: {player.UserId}): {tostring(errorMessage)}`)

	if ValidationUtils.isValidPlayer(player) then
		safeKick(player, KICK_MESSAGES.DATA_LOAD_FAILED)
	end
end

local function handleInitTimeout(initState: InitStateTracker.InitState)
	if isShuttingDown or not ValidationUtils.isValidPlayer(initState.player) then
		return
	end

	warn(`[PlayerStatisticsManager] Player initialization timed out for {initState.player.Name} (UserId: {initState.player.UserId})`)
	safeKick(initState.player, KICK_MESSAGES.INIT_TIMEOUT)
end

local function initializePlayerStatistics(connectingPlayer: Player)
	if not ValidationUtils.isValidPlayer(connectingPlayer) or isShuttingDown then
		return
	end

	local initState = initTracker:createWithTimeout(connectingPlayer, PLAYER_INIT_TIMEOUT, handleInitTimeout)

	local success, errorMessage = pcall(function()
		loadPlayerStatisticsData(connectingPlayer.UserId)
		createPlayerLeaderboard(connectingPlayer)
	end)

	initTracker:complete(initState, success, errorMessage)

	if not success then
		handleFailedInit(connectingPlayer, tostring(errorMessage))
	end

	initTracker:scheduleCleanup(connectingPlayer.UserId, INIT_STATE_CLEANUP_DELAY)
end

local function handlePlayerConnection(connectingPlayer: Player)
	if isShuttingDown then
		return
	end
	task.spawn(function()
		initializePlayerStatistics(connectingPlayer)
	end)
end

local function cleanupPlayerStatistics(player: Player)
	local success, errorMessage = pcall(function()
		PlayerData:RemovePlayerDataFromCacheAndSave(player.UserId)
	end)
	if not success then
		warn(`[{script.Name}] Error cleaning up player statistics for {player.Name} (UserId: {player.UserId}): {tostring(errorMessage)}`)
	end
end

local function handlePlayerDisconnection(disconnectingPlayer: Player)
	cleanupPlayerStatistics(disconnectingPlayer)
end

local function initializeExistingPlayers()
	for _, existingPlayer in pairs(Players:GetPlayers()) do
		task.spawn(handlePlayerConnection, existingPlayer)
	end
end

local function saveAllPlayerStatistics()
	for _, player in pairs(Players:GetPlayers()) do
		pcall(function()
			PlayerData:RemovePlayerDataFromCacheAndSave(player.UserId)
		end)
	end
end

local function cleanupAllResources()
	connectionsMaid:disconnect()
	crossServerSync:disconnect()
end

local function bindToClose()
	isShuttingDown = true
	cleanupAllResources()
	saveAllPlayerStatistics()
end

local function initialize()
	if not initializeDataStoreRegistry() then
		error("Failed to initialize DataStore registry - cannot continue")
	end

	connectionsMaid:add(Players.PlayerAdded:Connect(handlePlayerConnection))
	connectionsMaid:add(Players.PlayerRemoving:Connect(handlePlayerDisconnection))

	initializeExistingPlayers()

	crossServerSync:subscribe(
		GameConfig.MESSAGING_SERVICE_CONFIG.LEADERBOARD_UPDATE,
		processLeaderboardUpdate
	)

	game:BindToClose(bindToClose)
end

initialize()