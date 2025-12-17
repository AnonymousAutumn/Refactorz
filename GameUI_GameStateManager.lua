-----------------
-- Init Module --
-----------------

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

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local Connections = require(modulesFolder.Wrappers.Connections)

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

function GameStateManager.trackConnection(connection)
	GameStateManager.state.connections:add(connection)
	return connection
end

function GameStateManager.trackTween(tween)
	table.insert(GameStateManager.state.tweens, tween)
	return tween
end

function GameStateManager.trackTask(threadHandle)
	table.insert(GameStateManager.state.threads, threadHandle)
	return threadHandle
end

function GameStateManager.cancelAllTweens()
	for _, tween in ipairs(GameStateManager.state.tweens) do
		pcall(function()
			if tween then
				tween:Cancel()
			end
		end)
	end
	table.clear(GameStateManager.state.tweens)
end

function GameStateManager.cancelAllTasks()
	for _, thread in ipairs(GameStateManager.state.threads) do
		pcall(function()
			if thread and coroutine.status(thread) == "suspended" then
				task.cancel(thread)
			end
		end)
	end
	table.clear(GameStateManager.state.threads)
end

function GameStateManager.disconnectAllConnections()
	GameStateManager.state.connections:disconnect()
end

function GameStateManager.resetState()
	GameStateManager.state.isStatusVisible = false
	GameStateManager.state.previousStatusText = ""
end

function GameStateManager.incrementTimeoutSequence()
	GameStateManager.state.timeoutSequenceId += 1
end

function GameStateManager.incrementStatusSequence()
	GameStateManager.state.statusSequenceId += 1
end

function GameStateManager.getTimeoutSequenceId()
	return GameStateManager.state.timeoutSequenceId
end

function GameStateManager.getStatusSequenceId()
	return GameStateManager.state.statusSequenceId
end

--------------------
-- Initialization --
--------------------

GameStateManager.state.connections = Connections.new()

-------------------
-- Return Module --
-------------------

return GameStateManager