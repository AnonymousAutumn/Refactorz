-----------------
-- Init Module --
-----------------

local Stands = {}
Stands.MapPlayerToStand = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local networkFolder = ReplicatedStorage.Network
local remoteEvents = networkFolder.Remotes.Events
local refreshStandRemoteEvent = remoteEvents.RefreshStand

local modulesFolder = ReplicatedStorage.Modules
local PassCache = require(modulesFolder.Caches.PassCache)

---------------
-- Functions --
---------------

local function getPlayerGamepasses(player)
	local playerPasses = PassCache.GetPlayerCachedGamepassData(player)
	return playerPasses and playerPasses.gamepasses or {}
end

function Stands.MapPlayerToStandTable(tbl)
	Stands.MapPlayerToStand = tbl
end

function Stands.RefreshStandForPlayer(player)
	local standObject = Stands.MapPlayerToStand[player.Name]
	if not standObject then
		return
	end

	local playerGamepasses = getPlayerGamepasses(player)
	refreshStandRemoteEvent:FireClient(player, standObject.Stand, playerGamepasses, false)
end

function Stands.RefreshAllStandsForPlayer(player, StandObjects, ClaimedStands)
	for standModel, standObject in pairs(StandObjects) do
		local claimedData = ClaimedStands[standModel]
		local gamepasses = claimedData and claimedData.gamepasses or {}
		local isUnclaimed = not claimedData
		
		refreshStandRemoteEvent:FireClient(player, standModel, gamepasses, isUnclaimed)
	end
end

function Stands.BroadcastStandRefresh(player)
	local standObject = Stands.MapPlayerToStand[player.Name]
	if not standObject then
		return
	end

	local playerGamepasses = getPlayerGamepasses(player)
	refreshStandRemoteEvent:FireAllClients(standObject.Stand, playerGamepasses, false)
end

-------------------
-- Return Module --
-------------------

return Stands