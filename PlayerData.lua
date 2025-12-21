-----------------
-- Init Module --
-----------------

local PlayerData = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local Connections = require(modulesFolder.Wrappers.Connections)
local DataCache = require(script.DataCache)
local DataStore = require(script.DataStore)
local CrossServerMessaging = require(script.CrossServerMessaging)
local StatisticsAPI = require(script.StatisticsAPI)

---------------
-- Constants --
---------------

local AUTO_SAVE_INTERVAL_SECONDS = 300
local ENABLE_AUTO_SAVE = true
local SHUTDOWN_SAVE_WAIT_SECONDS = 1

---------------
-- Variables --
---------------

local connectionsMaid = Connections.new()

local autoSaveThread = nil
local isShuttingDown = false

---------------
-- Functions --
---------------

local function trackConnection(connection)
	connectionsMaid:add(connection)
	
	return connection
end

local function cancelThread(threadHandle)
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

	for playerUserId, playerStatisticsData in DataCache.getAllCachedData() do
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

function PlayerData:GetOrCreatePlayerStatisticsData(playerUserId)
	local playerUserIdString = tostring(playerUserId)
	
	return DataStore.loadPlayerStatistics(playerUserIdString)
end

function PlayerData:UpdatePlayerStatisticAndPublishChanges(playerUserId, statisticName, statisticAmount, shouldSetAbsoluteValue, isRemoteUpdate)
	StatisticsAPI.updatePlayerStatistic(playerUserId, statisticName, statisticAmount, shouldSetAbsoluteValue, isRemoteUpdate)
end

function PlayerData:IncrementPlayerStatistic(playerUserId, statisticName, incrementAmount, isRemoteUpdate)
	StatisticsAPI.incrementPlayerStatistic(playerUserId, statisticName, incrementAmount, isRemoteUpdate)
end

function PlayerData:SetPlayerStatisticAbsoluteValue(playerUserId, statisticName, absoluteValue, isRemoteUpdate)
	StatisticsAPI.setPlayerStatisticAbsoluteValue(playerUserId, statisticName, absoluteValue, isRemoteUpdate)
end

function PlayerData:GetPlayerStatisticValue(playerUserId, statisticName)
	return StatisticsAPI.getPlayerStatisticValue(playerUserId, statisticName)
end

function PlayerData:ProcessReceiptAndIncrementStatistic(playerUserId, purchaseId, statisticName, incrementAmount)
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

function PlayerData:CachePlayerStatisticsDataInMemory(playerUserId)
	local playerUserIdString = tostring(playerUserId)
	local playerStatisticsData = DataStore.loadPlayerStatistics(playerUserIdString)
	
	DataCache.setCachedData(playerUserIdString, playerStatisticsData)
end

function PlayerData:RemovePlayerDataFromCacheAndSave(playerUserId)
	local playerUserIdString = tostring(playerUserId)
	DataCache.removeCacheEntry(playerUserIdString)
end

function PlayerData:SaveAllCachedData()
	local successCount = 0
	local failCount = 0

	for playerUserId, playerStatisticsData in DataCache.getAllCachedData() do
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

--------------------
-- Initialization --
--------------------

local function initialize()
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
	for _ in DataCache.getAllCachedData() do
		cacheSize += 1
	end

	local successCount, failCount = PlayerData:SaveAllCachedData()

	task.wait(SHUTDOWN_SAVE_WAIT_SECONDS)
end

initialize()
game:BindToClose(bindToClose)

-------------------
-- Return Module --
-------------------

return PlayerData