-----------------
-- Init Module --
-----------------

local PlayerNotifications = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local networkFolder = ReplicatedStorage.Network
local remoteEvents = networkFolder.Remotes.Events
local updateGameUIRemoteEvent = remoteEvents.UpdateGameUI

---------------
-- Functions --
---------------

function PlayerNotifications.sendToPlayer(player, message, timeout, exitButtonVisible)
	local hideExitButton = not (exitButtonVisible or false)
	updateGameUIRemoteEvent:FireClient(player, message, timeout, hideExitButton)
end

function PlayerNotifications.sendToPlayers(players, message, timeout, exitButtonVisible)
	for _, player in players do
		PlayerNotifications.sendToPlayer(player, message, timeout, exitButtonVisible)
	end
end

function PlayerNotifications.sendToPlayersExcept(players, message, excludePlayer)
	for _, player in players do
		if player ~= excludePlayer then
			PlayerNotifications.sendToPlayer(player, message, nil, false)
		end
	end
end

function PlayerNotifications.clearUI(player)
	PlayerNotifications.sendToPlayer(player, "", nil, false)
end

function PlayerNotifications.clearAllUI(players)
	for _, player in players do
		PlayerNotifications.clearUI(player)
	end
end

-------------------
-- Return Module --
-------------------

return PlayerNotifications