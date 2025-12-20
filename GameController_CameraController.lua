--[[
	CameraController - Controls player camera for game views.

	Features:
	- Camera position updates
	- Turn-based camera control
	- Camera reset functionality
]]

local CameraController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local networkFolder = ReplicatedStorage.Network
local connect4Remotes = networkFolder.Remotes.Connect4

--[[
	Updates a player's camera position.
]]
function CameraController.updatePlayerCamera(player: Player, isPlayerTurn: boolean, cameraCFrame: CFrame?)
	if cameraCFrame then
		connect4Remotes.UpdateCamera:FireClient(player, isPlayerTurn, cameraCFrame)
	end
end

--[[
	Resets a player's camera to default.
]]
function CameraController.resetPlayerCamera(player: Player)
	connect4Remotes.UpdateCamera:FireClient(player, false)
end

--[[
	Resets cameras for all players.
]]
function CameraController.resetAllCameras(players: { Player })
	for _, player in pairs(players) do
		CameraController.resetPlayerCamera(player)
	end
end

return CameraController