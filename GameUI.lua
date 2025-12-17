--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

----------------
-- References --
----------------

local networkFolder = ReplicatedStorage.Network
local remoteEvents = networkFolder.Remotes.Events
local connect4Bindables = networkFolder.Bindables.Connect4
local connect4Remotes = networkFolder.Remotes.Connect4
local updateGameUIRemoteEvent = remoteEvents.UpdateGameUI

local modulesFolder = ReplicatedStorage.Modules
local InputCategorizer = require(modulesFolder.Utilities.InputCategorizer)

local Modules = ReplicatedStorage.Modules
local InputCategorizer = require(Modules.Utilities.InputCategorizer)
local GameStateManager = require(script.GameStateManager)
local StatusAnimator = require(script.StatusAnimator)
local TimeoutManager = require(script.TimeoutManager)
local UpdateCoordinator = require(script.UpdateCoordinator)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

---------------
-- Constants --
---------------

local STATUS_MESSAGE_DISPLAY_DURATION = 3
local MESSAGE_PLAYER_LEFT = "left the game"

---------------
-- Functions --
---------------

local function safeExecute(func, errorMessage)
	local success, errorDetails = pcall(func)
	if not success then
		warn(errorMessage, errorDetails)
	end
	return success
end

local function firePlayerExitedEvent()
	safeExecute(function()
		connect4Remotes.PlayerExited:FireServer()
	end, "Error firing player exited event")
end

local function prepareForPlayerExit()
	TimeoutManager.cancelTimeoutHandler()
	UpdateCoordinator.cancelAutoHideTask()
	StatusAnimator.setExitButtonVisibility(false)
end

local function scheduleExitCleanup()
	local exitTask = task.delay(STATUS_MESSAGE_DISPLAY_DURATION, function()
		StatusAnimator.hideStatusInterface()
		StatusAnimator.updateStatusText(nil)
	end)

	GameStateManager.trackTask(exitTask)
end

local function handlePlayerExit()
	safeExecute(function()
		firePlayerExitedEvent()
		prepareForPlayerExit()
		UpdateCoordinator.displayStatusIfChanged(MESSAGE_PLAYER_LEFT)
		UpdateCoordinator.setIgnoreUpdatesPeriod()
		scheduleExitCleanup()
	end, "Error handling player exit")
end

local function resetCamera()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	camera.CameraType = Enum.CameraType.Custom

	local character = localPlayer.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
			return
		end
		if character.PrimaryPart then
			camera.CameraSubject = character.PrimaryPart
			return
		end
	end

	camera.CameraSubject = character
end

local function handleGameCleanup()
	safeExecute(function()
		resetCamera()
		StatusAnimator.setExitButtonVisibility(false)
	end, "Error handling game cleanup")
end

local function cleanup()
	TimeoutManager.cancelTimeoutHandler()
	UpdateCoordinator.cancelAutoHideTask()
	GameStateManager.cancelAllTweens()
	GameStateManager.cancelAllTasks()
	GameStateManager.disconnectAllConnections()
	GameStateManager.resetState()
end

local function initialize()
	local screenGui = playerGui:WaitForChild("GameUI")
	if not screenGui then
		warn("GameUI not found in PlayerGui")
		return
	end

	local gameStatusInterface = screenGui.MainFrame
	local statusHolder = gameStatusInterface.BarFrame
	local exitButton = gameStatusInterface.ExitButton
	local statusLabel = statusHolder.TextLabel

	local isMobileDevice = InputCategorizer.getLastInputCategory() == "Touch"

	StatusAnimator.statusLabel = statusLabel
	StatusAnimator.statusHolder = statusHolder
	StatusAnimator.exitButton = exitButton
	StatusAnimator.isMobileDevice = isMobileDevice

	GameStateManager.trackConnection(exitButton.MouseButton1Click:Connect(handlePlayerExit))
	GameStateManager.trackConnection(remoteEvents.UpdateGameUI.OnClientEvent:Connect(UpdateCoordinator.handleGameUIUpdate))
	GameStateManager.trackConnection(connect4Remotes.Cleanup.OnClientEvent:Connect(handleGameCleanup))

	GameStateManager.trackConnection(
		localPlayer.AncestryChanged:Connect(function()
			if not localPlayer:IsDescendantOf(game) then
				cleanup()
			end
		end)
	)

	GameStateManager.trackConnection(
		screenGui.AncestryChanged:Connect(function()
			if not screenGui:IsDescendantOf(game) then
				cleanup()
			end
		end)
	)
end

--------------------
-- Initialization --
--------------------

initialize()