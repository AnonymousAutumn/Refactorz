-----------------
-- Init Module --
-----------------

local PassesLoader = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local configurationFolder = ReplicatedStorage.Configuration

local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local GameConfig = require(configurationFolder.GameConfig)
local HttpClient = require(script.HttpClient)
local ResponseParser = require(script.ResponseParser)
local DataProcessor = require(script.DataProcessor)

---------------
-- Constants --
---------------

local API_RATE_LIMIT_DELAY = 0.2

local ERROR_MESSAGES = {
	DEFAULT = "There was an error. Try again!",
	HTTP_FAILED = "HTTP request failed",
	INVALID_DATA = "Invalid data received from API",
	INVALID_UNIVERSE_ID = "Invalid universe ID",
	INVALID_PLAYER_ID = "Invalid player ID",
}

local requestStats = {
	totalRequests = 0,
	successfulRequests = 0,
	failedRequests = 0,
	rateLimitHits = 0,
}

---------------
-- Functions --
---------------

local function updateRequestStats(success, wasRateLimited)
	requestStats.totalRequests += 1

	if success then
		requestStats.successfulRequests += 1
	else
		requestStats.failedRequests += 1
	end
	if wasRateLimited then
		requestStats.rateLimitHits += 1
	end
end

local function validateGamepassResponse(decodedData, universeId)
	if not decodedData.gamePasses or type(decodedData.gamePasses) ~= "table" then
		warn(`[{script.Name}] Invalid gamepass data structure for universe {universeId}`)
		return false
	end
	return true
end

local function validateGamesResponse(decodedData, playerId)
	if not decodedData.data or type(decodedData.data) ~= "table" then
		warn(`[{script.Name}] Invalid games data structure for player {playerId}`)
		return false
	end
	return true
end

function PassesLoader:FetchGamepassesFromUniverseId(universeId)
	if not ValidationUtils.isValidUniverseId(universeId) then
		warn(`[{script.Name}] Invalid universe ID: {tostring(universeId)}`)

		return false, ERROR_MESSAGES.INVALID_UNIVERSE_ID, nil
	end

	-- First, check if universe has any gamepasses (optimization)
	local checkUrl = string.format(
		GameConfig.GAMEPASS_CONFIG.GAMEPASS_FETCH_ROOT_URL,
		universeId,
		GameConfig.GAMEPASS_CONFIG.GAMEPASSES_CHECK_LIMIT,
		""
	)

	local httpResult = HttpClient.makeRequest(checkUrl)
	updateRequestStats(httpResult.success, httpResult.wasRateLimited)

	if not httpResult.success then
		warn(`[{script.Name}] Failed to check gamepasses for universe {universeId}`)
		return false, ERROR_MESSAGES.HTTP_FAILED, nil
	end

	local parseResult = ResponseParser.parseResponse(httpResult.responseData)
	if not parseResult.success then
		return false, parseResult.errorMessage, nil
	end

	if not validateGamepassResponse(parseResult.data, universeId) then
		return false, ERROR_MESSAGES.INVALID_DATA, nil
	end

	-- If no gamepasses, return empty list
	if not parseResult.data.gamePasses or #parseResult.data.gamePasses == 0 then
		return true, "", {}
	end

	-- Universe has gamepasses, fetch all pages
	local allGamepasses = {}
	local nextPageToken = ""
	local pageCount = 0

	repeat
		pageCount += 1

		local gamepassApiUrl = string.format(
			GameConfig.GAMEPASS_CONFIG.GAMEPASS_FETCH_ROOT_URL,
			universeId,
			GameConfig.GAMEPASS_CONFIG.GAMEPASSES_PAGE_LIMIT,
			nextPageToken
		)

		local pageHttpResult = HttpClient.makeRequest(gamepassApiUrl)
		updateRequestStats(pageHttpResult.success, pageHttpResult.wasRateLimited)

		if not pageHttpResult.success then
			warn(`[{script.Name}] Gamepass fetch failed for universe {universeId} (page {pageCount})`)
			break
		end

		local pageParseResult = ResponseParser.parseResponse(pageHttpResult.responseData)
		if not pageParseResult.success then
			warn(`[{script.Name}] Parse error for universe {universeId} (page {pageCount}): {pageParseResult.errorMessage}`)
			break
		end

		if not validateGamepassResponse(pageParseResult.data, universeId) then
			break
		end

		-- Process this page's gamepasses
		local processResult = DataProcessor.processGamepasses(pageParseResult.data.gamePasses)
		for _, gamepassData in processResult.gamepasses do
			table.insert(allGamepasses, gamepassData)
		end

		-- Check for next page
		nextPageToken = pageParseResult.data.nextPageCursor or ""
	until nextPageToken == ""

	return true, "", allGamepasses
end

function PassesLoader:FetchPlayerOwnedGames(playerId)
	if not ValidationUtils.isValidUserId(playerId) then
		warn(`[{script.Name}] Invalid player ID: {tostring(playerId)}`)

		return false, ERROR_MESSAGES.INVALID_PLAYER_ID, nil
	end

	local allUniverseIds: {number} = {}
	local nextCursor = ""
	local pageCount = 0

	repeat
		pageCount += 1

		-- Build API URL with cursor
		local playerGamesApiUrl = string.format(
			GameConfig.GAMEPASS_CONFIG.GAMES_FETCH_ROOT_URL,
			playerId,
			GameConfig.GAMEPASS_CONFIG.UNIVERSES_PAGE_LIMIT,
			nextCursor
		)

		-- Make HTTP request
		local httpResult = HttpClient.makeRequest(playerGamesApiUrl)
		updateRequestStats(httpResult.success, httpResult.wasRateLimited)

		if not httpResult.success then
			warn(`[{script.Name}] Player games fetch failed for player {playerId} (page {pageCount}): HTTP request unsuccessful`)
			-- Return what we have so far rather than failing completely
			break
		end

		-- Process response
		local parseResult = ResponseParser.parseResponse(httpResult.responseData)
		if not parseResult.success then
			warn(`[{script.Name}] Failed to process page {pageCount} for player {playerId}: {parseResult.errorMessage}`)
			break
		end

		-- Validate response structure
		if not validateGamesResponse(parseResult.data, playerId) then
			break
		end

		-- Extract game IDs from this page
		local pageGameIds = DataProcessor.processGames(parseResult.data.data)

		-- Add to collection
		for _, universeId in pageGameIds do
			table.insert(allUniverseIds, universeId)
		end

		-- Get next cursor
		nextCursor = parseResult.data.nextPageCursor or ""

		-- Rate limit between pages
		if nextCursor ~= "" then
			task.wait(API_RATE_LIMIT_DELAY)
		end

	until nextCursor == ""

	return true, "", allUniverseIds
end

function PassesLoader:FetchAllPlayerGamepasses(playerId)
	-- First, fetch all games the player owns
	local gamesSuccess, gamesError, playerOwnedGames = self:FetchPlayerOwnedGames(playerId)

	if not gamesSuccess or not playerOwnedGames then
		warn(`[{script.Name}] Failed to fetch games for player {playerId}: {gamesError}`)
		return false, gamesError, nil
	end

	if #playerOwnedGames == 0 then
		return true, "", {}
	end

	-- Fetch gamepasses from each game
	local aggregatedGamepasses = {}
	local successfulFetches = 0
	local failedFetches = 0
	local skippedUniverses = 0

	for index, gameUniverseId in playerOwnedGames do
		local gamepassSuccess, gamepassError, gameGamepasses = self:FetchGamepassesFromUniverseId(gameUniverseId)

		if gamepassSuccess and gameGamepasses then
			successfulFetches += 1

			if #gameGamepasses == 0 then
				skippedUniverses += 1
			else
				for _, gamepassData in gameGamepasses do
					table.insert(aggregatedGamepasses, gamepassData)
				end
			end
		else
			failedFetches += 1
			warn(`[{script.Name}] Skipping game {gameUniverseId} due to error: {gamepassError}`)
		end

		-- Rate limiting between requests
		if index < #playerOwnedGames then
			task.wait(API_RATE_LIMIT_DELAY)
		end
	end

	return true, "", aggregatedGamepasses
end

return PassesLoader