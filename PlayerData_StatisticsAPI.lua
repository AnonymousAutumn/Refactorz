-----------------
-- Init Module --
-----------------

local StatisticsAPI = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local DataCache = require(script.Parent.DataCache)
local DataStore = require(script.Parent.DataStore)
local CrossServerMessaging = require(script.Parent.CrossServerMessaging)

---------------
-- Constants --
---------------

local DEFAULT_PLAYER_STATISTICS = {
	Donated = 0,
	Raised = 0,
	Wins = 0,
}

local SAVE_DEBOUNCE_SECONDS = 15

---------------
-- Functions --
---------------

local function isValidStatisticName(statisticName)
	return DEFAULT_PLAYER_STATISTICS[statisticName] ~= nil
end

local function scheduleDebouncedSave(playerUserId)
	if DataCache.getSaveDelayHandle(playerUserId) then
		return
	end

	local handle = task.delay(SAVE_DEBOUNCE_SECONDS, function()
		DataCache.setSaveDelayHandle(playerUserId, nil)
		if DataCache.getPendingSaveFlag(playerUserId) then
			local cachedData = DataCache.getCachedData(playerUserId)
			if cachedData then
				local success = DataStore.savePlayerStatistics(playerUserId, cachedData)
				if success then
					DataCache.updateSaveTime(playerUserId)
					DataCache.setPendingSaveFlag(playerUserId, false)
				end
			end
		end
	end)

	DataCache.setSaveDelayHandle(playerUserId)
end

function StatisticsAPI.updatePlayerStatistic(playerUserId, statisticName, statisticAmount, shouldSetAbsoluteValue, isRemoteUpdate)
	local playerUserIdString = tostring(playerUserId)
	local playerUserIdNumber = tonumber(playerUserId)

	if not ValidationUtils.isValidUserId(playerUserIdNumber) then
		warn(`[{script.Name}] Invalid player user ID: {tostring(playerUserId)}`)
		return
	end

	if not isValidStatisticName(statisticName) then
		warn(`[{script.Name}] Invalid statistic name: {tostring(statisticName)}`)
		return
	end

	if not (ValidationUtils.isValidNumber(statisticAmount) and statisticAmount >= 0) then
		warn(`[{script.Name}] Invalid statistic amount (must be non-negative): {tostring(statisticAmount)}`)
		return
	end

	local playerStatisticsData = DataCache.getCachedData(playerUserIdString)
	if not playerStatisticsData then
		playerStatisticsData = DataStore.loadPlayerStatistics(playerUserIdString)
		DataCache.setCachedData(playerUserIdString, playerStatisticsData)
	end

	if shouldSetAbsoluteValue then
		playerStatisticsData[statisticName] = statisticAmount
	else
		playerStatisticsData[statisticName] = (playerStatisticsData[statisticName] or 0) + statisticAmount
	end

	DataCache.setCachedData(playerUserIdString, playerStatisticsData)
	DataCache.setPendingSaveFlag(playerUserIdString, true)

	if not isRemoteUpdate then
		scheduleDebouncedSave(playerUserIdString)
	end

	local targetPlayerInServer = Players:GetPlayerByUserId(playerUserIdNumber )
	if targetPlayerInServer then
		CrossServerMessaging.updatePlayerStats(
			targetPlayerInServer,
			statisticName,
			playerStatisticsData[statisticName]
		)
	elseif not isRemoteUpdate then
		CrossServerMessaging.publishUpdate({
			UserId = playerUserIdNumber ,
			Stat = statisticName,
			Value = playerStatisticsData[statisticName],
		})
	end
end

function StatisticsAPI.incrementPlayerStatistic(playerUserId, statisticName, incrementAmount, isRemoteUpdate)
	StatisticsAPI.updatePlayerStatistic(playerUserId, statisticName, incrementAmount, false, isRemoteUpdate)
end

function StatisticsAPI.setPlayerStatisticAbsoluteValue(playerUserId, statisticName, absoluteValue, isRemoteUpdate)
	StatisticsAPI.updatePlayerStatistic(playerUserId, statisticName, absoluteValue, true, isRemoteUpdate)
end

function StatisticsAPI.getPlayerStatisticValue(playerUserId, statisticName)
	local playerUserIdString = tostring(playerUserId)

	local playerStatisticsData = DataCache.getCachedData(playerUserIdString)
	if not playerStatisticsData then
		playerStatisticsData = DataStore.loadPlayerStatistics(playerUserIdString)
		DataCache.setCachedData(playerUserIdString, playerStatisticsData)
	end

	return playerStatisticsData[statisticName] or 0
end

-------------------
-- Return Module --
-------------------

return StatisticsAPI