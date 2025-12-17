-----------------
-- Init Module --
-----------------

local DataProcessor = {}

---------------
-- Constants --
---------------

local GAMEPASS_THUMBNAIL_FORMAT = "rbxthumb://type=GamePass&id=%d&w=150&h=150"

---------------
-- Functions --
---------------

local function createGamepassData(gamepassInfo)
	local gamepassId = gamepassInfo.id

	return {
		Id = gamepassId,
		Name = gamepassInfo.name ,
		Icon = `rbxthumb://type=GamePass&id={gamepassId}&w=150&h=150`,
		Price = gamepassInfo.price ,
	}
end

local function extractGameId(gameInfo)
	return gameInfo.id
end

local function isValidGameId(gameId)
	return type(gameId) == "number" and gameId > 0
end

function DataProcessor.isValidGamepassData(gamepassInfo)
	if type(gamepassInfo) ~= "table" then
		return false
	end

	local gamepassId = gamepassInfo.id
	if not gamepassId or type(gamepassId) ~= "number" then
		return false
	end

	local gamepassName = gamepassInfo.name
	if not gamepassName or type(gamepassName) ~= "string" then
		return false
	end

	if not gamepassInfo.price or type(gamepassInfo.price) ~= "number" or gamepassInfo.price <= 0 then
		return false
	end

	return true
end

function DataProcessor.processGamepasses(rawGamepassData)
	local processedGamepasses = {}
	local skippedCount = 0

	for _, gamepassInfo in rawGamepassData do
		if DataProcessor.isValidGamepassData(gamepassInfo) then
			table.insert(processedGamepasses, createGamepassData(gamepassInfo))
		else
			skippedCount += 1
		end
	end

	return {
		gamepasses = processedGamepasses,
		skippedCount = skippedCount,
	}
end

function DataProcessor.validateGamepassResponse(decodedData, universeId)
	if not decodedData.gamePasses or type(decodedData.gamePasses) ~= "table" then
		warn(`[DataProcessor] Invalid gamepass data structure for universe {universeId}`)
		return false
	end
	return true
end

function DataProcessor.processGames(rawGameData)
	local gameIds = {}

	for _, gameInfo in rawGameData do
		local gameId = extractGameId(gameInfo)

		if isValidGameId(gameId) then
			table.insert(gameIds, gameId )
		end
	end

	return gameIds
end

function DataProcessor.validateGamesResponse(decodedData, playerId)
	if not decodedData.data or type(decodedData.data) ~= "table" then
		warn(`[DataProcessor] Invalid games data structure for player {playerId}`)
		return false
	end
	return true
end

-------------------
-- Return Module --
-------------------

return DataProcessor