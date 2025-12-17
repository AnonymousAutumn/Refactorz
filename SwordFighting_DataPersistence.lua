-----------------
-- Init Module --
-----------------

local DataPersistence = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local PlayerData = require(modulesFolder.Managers.PlayerData)
local DataStores = require(modulesFolder.Wrappers.DataStores)

---------------
-- Constants --
---------------

local WINS_STAT_KEY = "Wins"

---------------
-- Functions --
---------------

local function updateWinsDataStore(playerId, increment)
	local success, result = DataStores.Wins:incrementAsync(tostring(playerId), increment)

	if not success then
		warn(`[{script.Name}] Failed to update wins datastore for player {playerId}: {tostring(result)}`)
		return 0
	end

	return result or 0
end

function DataPersistence.recordPlayerWin(playerUserId, wins)
	updateWinsDataStore(playerUserId, wins)

	local success, errorMessage = pcall(function()
		PlayerData:IncrementPlayerStatistic(playerUserId, WINS_STAT_KEY, wins)
	end)

	if not success then
		warn(`[{script.Name}] Failed to update player statistics for {playerUserId}: {tostring(errorMessage)}`)
	end
end

-------------------
-- Return Module --
-------------------

return DataPersistence