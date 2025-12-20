--[[
	DataProcessor - Validates and transforms API response data.

	Features:
	- Gamepass data validation and transformation
	- Game data extraction and validation
	- Response structure validation
]]

local DataProcessor = {}

local GAMEPASS_THUMBNAIL_FORMAT = "rbxthumb://type=GamePass&id=%d&w=150&h=150"

export type GamepassInfo = {
	id: number,
	name: string,
	price: number,
}

export type ProcessedGamepass = {
	Id: number,
	Name: string,
	Icon: string,
	Price: number,
}

export type ProcessResult = {
	gamepasses: { ProcessedGamepass },
	skippedCount: number,
}

local function createGamepassData(gamepassInfo: GamepassInfo): ProcessedGamepass
	local gamepassId = gamepassInfo.id

	return {
		Id = gamepassId,
		Name = gamepassInfo.name ,
		Icon = `rbxthumb://type=GamePass&id={gamepassId}&w=150&h=150`,
		Price = gamepassInfo.price ,
	}
end

local function extractGameId(gameInfo: any): number?
	return gameInfo.id
end

local function isValidGameId(gameId: any): boolean
	return type(gameId) == "number" and gameId > 0
end

--[[
	Validates that gamepass info contains required fields.
]]
function DataProcessor.isValidGamepassData(gamepassInfo: any): boolean
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

--[[
	Processes raw gamepass data from API response.
	Returns processed gamepasses and count of skipped invalid entries.
]]
function DataProcessor.processGamepasses(rawGamepassData: { any }): ProcessResult
	local processedGamepasses: { ProcessedGamepass } = {}
	local skippedCount = 0

	for _, gamepassInfo in pairs(rawGamepassData) do
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

--[[
	Validates that the API response contains valid gamepass data structure.
]]
function DataProcessor.validateGamepassResponse(decodedData: any, universeId: number): boolean
	if not decodedData.gamePasses or type(decodedData.gamePasses) ~= "table" then
		warn(`[DataProcessor] Invalid gamepass data structure for universe {universeId}`)
		return false
	end
	return true
end

--[[
	Extracts valid game IDs from raw game data.
]]
function DataProcessor.processGames(rawGameData: { any }): { number }
	local gameIds: { number } = {}

	for _, gameInfo in pairs(rawGameData) do
		local gameId = extractGameId(gameInfo)

		if isValidGameId(gameId) then
			table.insert(gameIds, gameId )
		end
	end

	return gameIds
end

--[[
	Validates that the API response contains valid games data structure.
]]
function DataProcessor.validateGamesResponse(decodedData: any, playerId: number): boolean
	if not decodedData.data or type(decodedData.data) ~= "table" then
		warn(`[DataProcessor] Invalid games data structure for player {playerId}`)
		return false
	end
	return true
end

return DataProcessor