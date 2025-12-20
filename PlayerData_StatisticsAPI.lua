--[[
	StatisticsAPI - High-level API for player statistics management.

	Features:
	- Caching layer with debounced saves
	- Cross-server synchronization
	- Dependency injection for testability
]]

local StatisticsAPI = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)

local DEFAULT_PLAYER_STATISTICS = {
	Donated = 0,
	Raised = 0,
	Wins = 0,
}

local SAVE_DEBOUNCE_SECONDS = 15

export type StatisticName = "Donated" | "Raised" | "Wins"

local DataCache: any = nil
local DataStore: any = nil
local CrossServerMessaging: any = nil

local function isValidStatisticName(statisticName: string): boolean
	return DEFAULT_PLAYER_STATISTICS[statisticName] ~= nil
end

local function scheduleDebouncedSave(playerUserId: string)
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

	DataCache.setSaveDelayHandle(playerUserId, handle)
end

--[[
	Updates a player's statistic value.
	Can either increment or set an absolute value.
	Broadcasts changes via cross-server messaging if needed.
]]
function StatisticsAPI.updatePlayerStatistic(playerUserId: string | number, statisticName: StatisticName, statisticAmount: number, shouldSetAbsoluteValue: boolean?, isRemoteUpdate: boolean?)
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

	local targetPlayerInServer = Players:GetPlayerByUserId(playerUserIdNumber)
	if targetPlayerInServer then
		CrossServerMessaging.updatePlayerStats(
			targetPlayerInServer,
			statisticName,
			playerStatisticsData[statisticName]
		)
	elseif not isRemoteUpdate then
		CrossServerMessaging.publishUpdate({
			UserId = playerUserIdNumber,
			Stat = statisticName,
			Value = playerStatisticsData[statisticName],
		})
	end
end

--[[
	Increments a player's statistic by the given amount.
]]
function StatisticsAPI.incrementPlayerStatistic(playerUserId: string | number, statisticName: StatisticName, incrementAmount: number, isRemoteUpdate: boolean?)
	StatisticsAPI.updatePlayerStatistic(playerUserId, statisticName, incrementAmount, false, isRemoteUpdate)
end

--[[
	Sets a player's statistic to an absolute value.
]]
function StatisticsAPI.setPlayerStatisticAbsoluteValue(playerUserId: string | number, statisticName: StatisticName, absoluteValue: number, isRemoteUpdate: boolean?)
	StatisticsAPI.updatePlayerStatistic(playerUserId, statisticName, absoluteValue, true, isRemoteUpdate)
end

--[[
	Returns the current value of a player's statistic.
	Loads from DataStore if not cached.
]]
function StatisticsAPI.getPlayerStatisticValue(playerUserId: string | number, statisticName: StatisticName): number
	local playerUserIdString = tostring(playerUserId)

	local playerStatisticsData = DataCache.getCachedData(playerUserIdString)
	if not playerStatisticsData then
		playerStatisticsData = DataStore.loadPlayerStatistics(playerUserIdString)
		DataCache.setCachedData(playerUserIdString, playerStatisticsData)
	end

	return playerStatisticsData[statisticName] or 0
end

--[[
	Injects the DataCache module dependency.
]]
function StatisticsAPI.setDataCacheModule(module: any)
	DataCache = module
end

--[[
	Injects the DataStore module dependency.
]]
function StatisticsAPI.setDataStoreModule(module: any)
	DataStore = module
end

--[[
	Injects the CrossServerMessaging module dependency.
]]
function StatisticsAPI.setCrossServerMessagingModule(module: any)
	CrossServerMessaging = module
end

return StatisticsAPI