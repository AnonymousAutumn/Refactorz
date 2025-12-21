--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

----------------
-- References --
----------------

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local modulesFolder = ReplicatedStorage.Modules
local Connections = require(modulesFolder.Wrappers.Connections)
local leaderboardDisplayHandler = require(script.RigCreator)
local StateManager = require(script.StateManager)
local ComponentFinder = require(script.ComponentFinder)
local UIController = require(script.UIController)
local UpdateHandler = require(script.UpdateHandler)

---------------
-- Constants --
---------------

local MAX_INIT_RETRIES = 1
local INIT_RETRY_DELAY = 2

---------------
-- Variables --
---------------

local connectionsMaid = Connections.new()

---------------
-- Functions --
---------------

local function safeExecute(func)
	local success, errorMessage = pcall(func)
	if not success then
		warn(`[{script.Name}] Error:", errorMessage`)
	end

	return success
end

local function performLeaderboardInitialization(leaderboardSurfaceGui, state)
	local leaderboardName = leaderboardSurfaceGui.Name

	local clientLeaderboardHandler = leaderboardDisplayHandler.new(leaderboardSurfaceGui)
	if not clientLeaderboardHandler then
		warn(`[{script.Name}] Failed to create handler for`, leaderboardName)

		return false
	end
	state.handler = clientLeaderboardHandler

	local workspaceComponents = ComponentFinder.getWorkspaceComponents(leaderboardName)
	if not workspaceComponents then
		warn(`[{script.Name}] Failed to get workspace components for`, leaderboardName)

		return false
	end

	local leaderboardUpdateRemoteEvent = ComponentFinder.getUpdateRemoteEvent(leaderboardName)
	if not leaderboardUpdateRemoteEvent then
		warn(`[{script.Name}] Failed to get update remote event for`, leaderboardName)

		return false
	end

	if not UIController.setupToggle(workspaceComponents.toggleButton, workspaceComponents.scrollingFrame, clientLeaderboardHandler, state) then
		warn(`[{script.Name}] Failed to setup toggle for`, leaderboardName)

		return false
	end

	if not UpdateHandler.setupUpdates(leaderboardUpdateRemoteEvent, clientLeaderboardHandler, state, StateManager.updateState) then
		warn(`[{script.Name}] Failed to setup updates for`, leaderboardName)
		return false
	end

	return true
end

local function initializeLeaderboardInterface(leaderboardSurfaceGui)
	if not leaderboardSurfaceGui then
		return false
	end

	local leaderboardName = leaderboardSurfaceGui.Name
	local state = StateManager.initializeState(leaderboardName)

	if state.isInitialized then
		return true
	end

	for attempt = 1, MAX_INIT_RETRIES do
		local success = pcall(function()
			performLeaderboardInitialization(leaderboardSurfaceGui, state)
		end)

		if success then
			state.isInitialized = true
			return true
		end

		if attempt < MAX_INIT_RETRIES then
			task.wait(INIT_RETRY_DELAY * attempt)
		end
	end

	StateManager.cleanup(leaderboardName)
	return false
end

local function initializeAllLeaderboards(screenGui)
	for i, leaderboardInstance in screenGui:GetChildren() do
		if leaderboardInstance:IsA("SurfaceGui") then
			safeExecute(function()
				initializeLeaderboardInterface(leaderboardInstance)
			end)
		end
	end
end

local function cleanup()
	StateManager.cleanupAll()
	connectionsMaid:disconnect()
end

local function initialize()
	local screenGui = playerGui:WaitForChild("LeaderboardUI", 10)
	if not screenGui then
		warn("LeaderboardUI not found in PlayerGui")
		return
	end

	initializeAllLeaderboards(screenGui)

	connectionsMaid:add(
		localPlayer.AncestryChanged:Connect(function()
			if not localPlayer:IsDescendantOf(game) then
				cleanup()
			end
		end)
	)

	connectionsMaid:add(
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