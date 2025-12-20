--[[
	Stands - Manages stand refresh and player mapping.

	Features:
	- Player-to-stand mapping
	- Stand refresh broadcasting
]]

local Stands = {}
Stands.MapPlayerToStand = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local networkFolder = ReplicatedStorage.Network
local remoteEvents = networkFolder.Remotes.Events
local refreshStandRemoteEvent = remoteEvents.RefreshStand

local modulesFolder = ReplicatedStorage.Modules
local PassCache = require(modulesFolder.Caches.PassCache)

local function getPlayerGamepasses(player: Player): { any }
	local playerPasses = PassCache.GetPlayerCachedGamepassData(player)
	return playerPasses and playerPasses.gamepasses or {}
end

--[[
	Sets the player-to-stand mapping table.
]]
function Stands.MapPlayerToStandTable(tbl: { [string]: any })
	Stands.MapPlayerToStand = tbl
end

--[[
	Refreshes the stand for a specific player.
]]
function Stands.RefreshStandForPlayer(player: Player)
	local standObject = Stands.MapPlayerToStand[player.Name]
	if not standObject then
		return
	end

	local playerGamepasses = getPlayerGamepasses(player)
	refreshStandRemoteEvent:FireClient(player, standObject.Stand, playerGamepasses, false)
end

--[[
	Refreshes all stands for a specific player.
]]
function Stands.RefreshAllStandsForPlayer(player: Player, StandObjects: { [Model]: any }, ClaimedStands: { [Model]: any })
	for standModel, standObject in pairs(StandObjects) do
		local claimedData = ClaimedStands[standModel]
		local gamepasses = claimedData and claimedData.gamepasses or {}
		local isUnclaimed = not claimedData
		
		refreshStandRemoteEvent:FireClient(player, standModel, gamepasses, isUnclaimed)
	end
end

--[[
	Broadcasts a stand refresh to all clients.
]]
function Stands.BroadcastStandRefresh(player: Player)
	local standObject = Stands.MapPlayerToStand[player.Name]
	if not standObject then
		return
	end

	local playerGamepasses = getPlayerGamepasses(player)
	refreshStandRemoteEvent:FireAllClients(standObject.Stand, playerGamepasses, false)
end

return Stands