-----------------
-- Init Module --
-----------------

local DataFetcher = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local RetryAsync = require(modulesFolder.Utilities.RetryAsync)
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local Populater = require(script.Parent.Populater)

---------------
-- Functions --
---------------

function DataFetcher.extractUserId(leaderboardEntry)
	if not leaderboardEntry or not leaderboardEntry.key then
		return nil
	end

	local userId = tonumber(leaderboardEntry.key)
	if ValidationUtils.isValidUserId(userId) then
		return userId
	end
	return nil
end

function DataFetcher.prepareTopPlayersData(processedLeaderboardEntries, maxCharacterDisplayCount)
	local topPlayersForCharacterDisplay = {}
	for entryIndex = 1, maxCharacterDisplayCount do
		local leaderboardEntry = processedLeaderboardEntries[entryIndex]
		local userId = DataFetcher.extractUserId(leaderboardEntry)
		if userId then
			topPlayersForCharacterDisplay[entryIndex] = userId
		end
	end
	return topPlayersForCharacterDisplay
end

function DataFetcher.validateLeaderboardDataPages(dataPages)
	if not dataPages then
		return false
	end
	if type(dataPages.GetCurrentPage) ~= "function" then
		return false
	end
	return true
end

function DataFetcher.retrieveLeaderboardData(orderedDataStore, maximumEntriesToRetrieve, systemConfiguration)
	local dataRetrievalSuccess, retrievedDataResult = RetryAsync(
		function()
			return orderedDataStore:GetSortedAsync(false, maximumEntriesToRetrieve)
		end,
		systemConfiguration.LEADERBOARD_CONFIG.UPDATE_MAX_ATTEMPTS,
		systemConfiguration.LEADERBOARD_CONFIG.UPDATE_RETRY_PAUSE_CONSTANT,
		systemConfiguration.LEADERBOARD_CONFIG.UPDATE_RETRY_PAUSE_EXPONENT_BASE
	)
	return dataRetrievalSuccess, retrievedDataResult
end

function DataFetcher.extractLeaderboardEntries(leaderboardDataPages, displayCount)
	local success, processedLeaderboardEntries = pcall(function()
		return Populater.extractLeaderboardDataFromPages(leaderboardDataPages, displayCount)
	end)
	if not success then
		warn(`[{script.Name}] Failed to extract leaderboard entries: {tostring(processedLeaderboardEntries)}`)
	end
	return success, processedLeaderboardEntries
end

function DataFetcher.sendTopPlayerDataToClients(clientUpdateEvent, topPlayersData, statisticName)
	local success, errorMessage = pcall(function()
		clientUpdateEvent:FireAllClients(topPlayersData)
	end)
	if not success then
		warn(`[{script.Name}] Failed to fire client update for {statisticName}: {tostring(errorMessage)}`)
	end
end

-------------------
-- Return Module --
-------------------

return DataFetcher