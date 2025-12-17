--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

----------------
-- References --
----------------

local localPlayer = Players.LocalPlayer
local currentCamera = workspace.CurrentCamera

local networkFolder = ReplicatedStorage.Network
local remoteEvents = networkFolder.Remotes
local connect4RemoteEvents = remoteEvents.Connect4
local updateCameraEvent = connect4RemoteEvents.UpdateCamera

local modulesFolder = ReplicatedStorage.Modules
local Connections = require(modulesFolder.Wrappers.Connections)
local TweenHelper = require(modulesFolder.Utilities.TweenHelper)

---------------
-- Constants --
---------------

local CAMERA_TWEEN_INFO = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

---------------
-- Variables --
---------------

local connectionsMaid = Connections.new()

local savedCameraType = nil
local savedCameraFrame = nil
local currentTween = nil

---------------
-- Functions --
---------------

local function cancelCurrentTween()
	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end
end

local function restoreCamera()
	cancelCurrentTween()

	if savedCameraType and savedCameraFrame then
		currentCamera.CameraType = savedCameraType
		currentCamera.CFrame = savedCameraFrame
		savedCameraType = nil
		savedCameraFrame = nil
	end
end

local function focusOnBoard(targetCFrame)
	if not savedCameraType then
		savedCameraType = currentCamera.CameraType
		savedCameraFrame = currentCamera.CFrame
	end

	cancelCurrentTween()
	currentCamera.CameraType = Enum.CameraType.Scriptable
	currentTween = TweenHelper.play(currentCamera, CAMERA_TWEEN_INFO, { CFrame = targetCFrame })
end

local function onCameraUpdate(isPlayerTurn, boardCFrame)
	if isPlayerTurn and boardCFrame then
		focusOnBoard(boardCFrame)
	else
		restoreCamera()
	end
end

local function cleanup()
	restoreCamera()
	connectionsMaid:disconnect()
end

local function initialize()
	connectionsMaid:add(updateCameraEvent.OnClientEvent:Connect(onCameraUpdate))
	connectionsMaid:add(localPlayer.CharacterAdded:Connect(restoreCamera))

	connectionsMaid:add(localPlayer.AncestryChanged:Connect(function()
		if not localPlayer:IsDescendantOf(game) then
			cleanup()
		end
	end))
end

--------------------
-- Initialization --
--------------------

initialize()