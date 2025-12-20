--[[
	DataPersistence - Records player wins to persistent storage.

	Features:
	- DataStore win recording
	- PlayerData statistics updates
]]

local DataPersistence = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modulesFolder = ReplicatedStorage.Modules
local PlayerData = require(modulesFolder.Managers.PlayerData)
local DataStores = require(modulesFolder.Wrappers.DataStores)

local WINS_STAT_KEY = "Wins"

local function updateWinsDataStore(playerId: number, increment: number): number
	local success, result = DataStores.Wins:incrementAsync(tostring(playerId), increment)

	if not success then
		warn(`[{script.Name}] Failed to update wins datastore for player {playerId}: {tostring(result)}`)
		return 0
	end

	return result or 0
end

--[[
	Records a player win to DataStore and PlayerData.
]]
function DataPersistence.recordPlayerWin(playerUserId: number, wins: number)
	updateWinsDataStore(playerUserId, wins)

	local success, errorMessage = pcall(function()
		PlayerData:IncrementPlayerStatistic(playerUserId, WINS_STAT_KEY, wins)
	end)

	if not success then
		warn(`[{script.Name}] Failed to update player statistics for {playerUserId}: {tostring(errorMessage)}`)
	end
end

return DataPersistence