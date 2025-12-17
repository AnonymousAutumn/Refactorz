-----------------
-- Init Module --
-----------------

local CameraController = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local networkFolder = ReplicatedStorage.Network
local connect4Remotes = networkFolder.Remotes.Connect4

---------------
-- Functions --
---------------

function CameraController.updatePlayerCamera(player, isPlayerTurn, cameraCFrame)
	if cameraCFrame then
		connect4Remotes.UpdateCamera:FireClient(player, isPlayerTurn, cameraCFrame)
	end
end

function CameraController.resetPlayerCamera(player)
	connect4Remotes.UpdateCamera:FireClient(player, false)
end

function CameraController.resetAllCameras(players)
	for _, player in players do
		CameraController.resetPlayerCamera(player)
	end
end

-------------------
-- Return Module --
-------------------

return CameraController