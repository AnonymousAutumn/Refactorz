--[[
	PlayerNotifications - Sends game UI notifications to players.

	Features:
	- Single player notifications
	- Multi-player broadcasts
	- UI clear commands
]]

local PlayerNotifications = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local networkFolder = ReplicatedStorage.Network
local remoteEvents = networkFolder.Remotes.Events
local updateGameUIRemoteEvent = remoteEvents.UpdateGameUI

--[[
	Sends a notification to a single player.
]]
function PlayerNotifications.sendToPlayer(player: Player, message: string?, timeout: number?, exitButtonVisible: boolean?)
	local hideExitButton = not (exitButtonVisible or false)
	updateGameUIRemoteEvent:FireClient(player, message, timeout, hideExitButton)
end

--[[
	Sends a notification to multiple players.
]]
function PlayerNotifications.sendToPlayers(players: { Player }, message: string?, timeout: number?, exitButtonVisible: boolean?)
	for _, player in pairs(players) do
		PlayerNotifications.sendToPlayer(player, message, timeout, exitButtonVisible)
	end
end

--[[
	Sends a notification to all players except one.
]]
function PlayerNotifications.sendToPlayersExcept(players: { Player }, message: string?, excludePlayer: Player)
	for _, player in pairs(players) do
		if player ~= excludePlayer then
			PlayerNotifications.sendToPlayer(player, message, nil, false)
		end
	end
end

--[[
	Clears the game UI for a player.
]]
function PlayerNotifications.clearUI(player: Player)
	PlayerNotifications.sendToPlayer(player, "", nil, false)
end

--[[
	Clears the game UI for all players.
]]
function PlayerNotifications.clearAllUI(players: { Player })
	for _, player in pairs(players) do
		PlayerNotifications.clearUI(player)
	end
end

return PlayerNotifications