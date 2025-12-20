--[[
	PlayerData - Main module for player statistics management.

	Features:
	- Automatic saving at intervals (every 5 minutes)
	- Graceful shutdown with data persistence
	- Cross-server synchronization
	- Statistics caching and debounced saves
]]

local PlayerData = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local modulesFolder = ReplicatedStorage.Modules
local Connections = require(modulesFolder.Wrappers.Connections)
local DataCache = require(script.DataCache)
local DataStore = require(script.DataStore)
local CrossServerMessaging = require(script.CrossServerMessaging)
local StatisticsAPI = require(script.StatisticsAPI)

local AUTO_SAVE_INTERVAL_SECONDS = 300
local ENABLE_AUTO_SAVE = true
local SHUTDOWN_SAVE_WAIT_SECONDS = 1

local connectionsMaid = Connections.new()

local autoSaveThread: thread? = nil
local isShuttingDown = false

local function trackConnection(connection: RBXScriptConnection): RBXScriptConnection
	connectionsMaid:add(connection)
	return connection
end

local function cancelThread(threadHandle: thread?)
	if threadHandle and coroutine.status(threadHandle) ~= "dead" then
		task.cancel(threadHandle)
	end
end

local function performAutoSave()
	if isShuttingDown then
		return
	end

	local saveCount = 0
	local failCount = 0

	for playerUserId, playerStatisticsData in pairs(DataCache.getAllCachedData()) do
		local success = DataStore.savePlayerStatistics(playerUserId, playerStatisticsData)
		if success then
			saveCount += 1
			DataCache.updateSaveTime(playerUserId)
			DataCache.setPendingSaveFlag(playerUserId, false)
		else
			failCount += 1
		end
	end
end

local function startAutoSaveLoop()
	if not ENABLE_AUTO_SAVE or autoSaveThread then
		return
	end

	autoSaveThread = task.spawn(function()
		while not isShuttingDown do
			task.wait(AUTO_SAVE_INTERVAL_SECONDS)
			performAutoSave()
		end
	end)
end

local function stopAutoSaveLoop()
	cancelThread(autoSaveThread)
	autoSaveThread = nil
end

--[[
	Loads or creates player statistics data from the DataStore.
]]
function PlayerData:GetOrCreatePlayerStatisticsData(playerUserId: number): any
	local playerUserIdString = tostring(playerUserId)
	return DataStore.loadPlayerStatistics(playerUserIdString)
end

--[[
	Updates a player statistic and publishes changes across servers.
]]
function PlayerData:UpdatePlayerStatisticAndPublishChanges(playerUserId: string | number, statisticName: string, statisticAmount: number, shouldSetAbsoluteValue: boolean?, isRemoteUpdate: boolean?)
	StatisticsAPI.updatePlayerStatistic(playerUserId, statisticName, statisticAmount, shouldSetAbsoluteValue, isRemoteUpdate)
end

--[[
	Increments a player statistic by the given amount.
]]
function PlayerData:IncrementPlayerStatistic(playerUserId: string | number, statisticName: string, incrementAmount: number, isRemoteUpdate: boolean?)
	StatisticsAPI.incrementPlayerStatistic(playerUserId, statisticName, incrementAmount, isRemoteUpdate)
end

--[[
	Sets a player statistic to an absolute value.
]]
function PlayerData:SetPlayerStatisticAbsoluteValue(playerUserId: string | number, statisticName: string, absoluteValue: number, isRemoteUpdate: boolean?)
	StatisticsAPI.setPlayerStatisticAbsoluteValue(playerUserId, statisticName, absoluteValue, isRemoteUpdate)
end

--[[
	Returns the current value of a player statistic.
]]
function PlayerData:GetPlayerStatisticValue(playerUserId: string | number, statisticName: string): number
	return StatisticsAPI.getPlayerStatisticValue(playerUserId, statisticName)
end

--[[
	Processes a purchase receipt and increments the corresponding statistic.
	Returns (success, newValue, status).
]]
function PlayerData:ProcessReceiptAndIncrementStatistic(playerUserId: string | number, purchaseId: string, statisticName: string, incrementAmount: number): (boolean, number?, string)
	local playerUserIdString = tostring(playerUserId)
	local playerUserIdNumber = tonumber(playerUserId)

	local success, newStatValue, status = DataStore.processReceiptAndIncrementStatistic(
		playerUserIdString,
		purchaseId,
		statisticName,
		incrementAmount
	)

	if success and status == "newly_processed" and newStatValue then
		local cachedData = DataCache.getCachedData(playerUserIdString)
		if cachedData then
			cachedData[statisticName] = newStatValue
			DataCache.setCachedData(playerUserIdString, cachedData)
		end

		if playerUserIdNumber then
			CrossServerMessaging.updatePlayerStats(
				Players:GetPlayerByUserId(playerUserIdNumber),
				statisticName,
				newStatValue
			)
		end
	end

	return success, newStatValue, status
end

--[[
	Loads player statistics from DataStore and caches in memory.
]]
function PlayerData:CachePlayerStatisticsDataInMemory(playerUserId: number)
	local playerUserIdString = tostring(playerUserId)
	local playerStatisticsData = DataStore.loadPlayerStatistics(playerUserIdString)
	DataCache.setCachedData(playerUserIdString, playerStatisticsData)
end

--[[
	Removes player data from cache (triggers save via removal callback).
]]
function PlayerData:RemovePlayerDataFromCacheAndSave(playerUserId: number)
	local playerUserIdString = tostring(playerUserId)
	DataCache.removeCacheEntry(playerUserIdString)
end

--[[
	Saves all cached player data to DataStore.
	Returns (successCount, failCount).
]]
function PlayerData:SaveAllCachedData(): (number, number)
	local successCount = 0
	local failCount = 0

	for playerUserId, playerStatisticsData in pairs(DataCache.getAllCachedData()) do
		local success = DataStore.savePlayerStatistics(playerUserId, playerStatisticsData)
		if success then
			successCount += 1
			DataCache.updateSaveTime(playerUserId)
			DataCache.setPendingSaveFlag(playerUserId, false)
		else
			failCount += 1
		end
	end

	return successCount, failCount
end

local function initialize()
	StatisticsAPI.setDataCacheModule(DataCache)
	StatisticsAPI.setDataStoreModule(DataStore)
	StatisticsAPI.setCrossServerMessagingModule(CrossServerMessaging)
	CrossServerMessaging.subscribe(trackConnection)

	DataCache.setRemovalCallback(function(playerUserId, data)
		DataStore.savePlayerStatistics(playerUserId, data)
	end)

	startAutoSaveLoop()
	DataCache.startCleanupLoop()
end

local function bindToClose()
	isShuttingDown = true

	DataCache.setShutdown(true)
	CrossServerMessaging.setShutdown(true)

	stopAutoSaveLoop()
	DataCache.stopCleanupLoop()

	connectionsMaid:disconnect()
	CrossServerMessaging.cleanup()

	local cacheSize = 0
	for _ in pairs(DataCache.getAllCachedData()) do
		cacheSize += 1
	end

	local successCount, failCount = PlayerData:SaveAllCachedData()

	task.wait(SHUTDOWN_SAVE_WAIT_SECONDS)
end

initialize()
game:BindToClose(bindToClose)

return PlayerData