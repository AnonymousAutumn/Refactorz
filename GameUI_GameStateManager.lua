--[[
	GameStateManager - Manages game UI state and resources.

	Features:
	- Connection and tween tracking
	- Task lifecycle management
	- State reset and cleanup
]]

local GameStateManager = {}
GameStateManager.state = {
	timeoutSequenceId = 0,
	activeTimeoutHandler = nil,
	autoHideTask = nil,
	statusSequenceId = 0,
	ignoreUpdatesUntil = 0,

	isStatusVisible = false,
	previousStatusText = "",

	connections = nil,
	tweens = {},
	threads = {},
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modulesFolder = ReplicatedStorage.Modules
local Connections = require(modulesFolder.Wrappers.Connections)

local function safeExecute(func: () -> (), errorMessage: string): boolean
	local success, errorDetails = pcall(func)
	if not success then
		warn(errorMessage, errorDetails)
	end
	return success
end

--[[
	Tracks a connection for later cleanup.
]]
function GameStateManager.trackConnection(connection: RBXScriptConnection): RBXScriptConnection
	GameStateManager.state.connections:add(connection)
	return connection
end

--[[
	Tracks a tween for later cleanup.
]]
function GameStateManager.trackTween(tween: Tween): Tween
	table.insert(GameStateManager.state.tweens, tween)
	return tween
end

--[[
	Tracks a task thread for later cleanup.
]]
function GameStateManager.trackTask(threadHandle: thread): thread
	table.insert(GameStateManager.state.threads, threadHandle)
	return threadHandle
end

--[[
	Cancels all tracked tweens.
]]
function GameStateManager.cancelAllTweens()
	for _, tween in pairs(GameStateManager.state.tweens) do
		pcall(function()
			if tween then
				tween:Cancel()
			end
		end)
	end
	table.clear(GameStateManager.state.tweens)
end

--[[
	Cancels all tracked tasks.
]]
function GameStateManager.cancelAllTasks()
	for _, thread in pairs(GameStateManager.state.threads) do
		pcall(function()
			if thread and coroutine.status(thread) == "suspended" then
				task.cancel(thread)
			end
		end)
	end
	table.clear(GameStateManager.state.threads)
end

--[[
	Disconnects all tracked connections.
]]
function GameStateManager.disconnectAllConnections()
	GameStateManager.state.connections:disconnect()
end

--[[
	Resets the status visibility state.
]]
function GameStateManager.resetState()
	GameStateManager.state.isStatusVisible = false
	GameStateManager.state.previousStatusText = ""
end

--[[
	Increments the timeout sequence ID.
]]
function GameStateManager.incrementTimeoutSequence()
	GameStateManager.state.timeoutSequenceId += 1
end

--[[
	Increments the status sequence ID.
]]
function GameStateManager.incrementStatusSequence()
	GameStateManager.state.statusSequenceId += 1
end

--[[
	Returns the current timeout sequence ID.
]]
function GameStateManager.getTimeoutSequenceId(): number
	return GameStateManager.state.timeoutSequenceId
end

--[[
	Returns the current status sequence ID.
]]
function GameStateManager.getStatusSequenceId(): number
	return GameStateManager.state.statusSequenceId
end

GameStateManager.state.connections = Connections.new()

return GameStateManager