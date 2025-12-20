--[[
	DataFetcher - Fetches and processes leaderboard data.

	Features:
	- User ID extraction
	- DataStore page retrieval
	- Client update broadcasting
]]

local DataFetcher = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modulesFolder = ReplicatedStorage.Modules
local RetryAsync = require(modulesFolder.Utilities.RetryAsync)
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local Populater = require(script.Parent.Populater)

--[[
	Extracts user ID from a leaderboard entry.
]]
function DataFetcher.extractUserId(leaderboardEntry: any): number?
	if not leaderboardEntry or not leaderboardEntry.key then
		return nil
	end

	local userId = tonumber(leaderboardEntry.key)
	if ValidationUtils.isValidUserId(userId) then
		return userId
	end
	return nil
end

--[[
	Prepares top players data for character display.
]]
function DataFetcher.prepareTopPlayersData(processedLeaderboardEntries: { any }, maxCharacterDisplayCount: number): { number }
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

--[[
	Validates leaderboard data pages.
]]
function DataFetcher.validateLeaderboardDataPages(dataPages: any): boolean
	if not dataPages then
		return false
	end
	if type(dataPages.GetCurrentPage) ~= "function" then
		return false
	end
	return true
end

--[[
	Retrieves leaderboard data from the ordered DataStore.
]]
function DataFetcher.retrieveLeaderboardData(orderedDataStore: OrderedDataStore, maximumEntriesToRetrieve: number, systemConfiguration: any): (boolean, any)
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

--[[
	Extracts leaderboard entries from data pages.
]]
function DataFetcher.extractLeaderboardEntries(leaderboardDataPages: any, displayCount: number): (boolean, { any }?)
	local success, processedLeaderboardEntries = pcall(function()
		return Populater.extractLeaderboardDataFromPages(leaderboardDataPages, displayCount)
	end)
	if not success then
		warn(`[{script.Name}] Failed to extract leaderboard entries: {tostring(processedLeaderboardEntries)}`)
	end
	return success, processedLeaderboardEntries
end

--[[
	Sends top player data to all clients.
]]
function DataFetcher.sendTopPlayerDataToClients(clientUpdateEvent: RemoteEvent, topPlayersData: { number }, statisticName: string)
	local success, errorMessage = pcall(function()
		clientUpdateEvent:FireAllClients(topPlayersData)
	end)
	if not success then
		warn(`[{script.Name}] Failed to fire client update for {statisticName}: {tostring(errorMessage)}`)
	end
end

return DataFetcher