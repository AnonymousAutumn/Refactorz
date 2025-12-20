--[[
	InitStateTracker - Tracks player initialization state with timeout protection.

	Features:
	- Creates and tracks initialization states per player
	- Configurable timeouts with callback on timeout
	- Automatic cleanup of completed states
]]

local InitStateTracker = {}
InitStateTracker.__index = InitStateTracker

local DEFAULT_TIMEOUT = 30
local DEFAULT_CLEANUP_DELAY = 60

export type InitState = {
	player: Player,
	startTime: number,
	completed: boolean,
	success: boolean,
	error: string?,
	timeoutThread: thread?,
}

type TimeoutCallback = (state: InitState) -> ()

--[[
	Creates a new InitStateTracker instance.
]]
function InitStateTracker.new()
	local self = setmetatable({}, InitStateTracker) 
	self.states = {}
	return self 
end

--[[
	Creates a new initialization state for a player.
]]
function InitStateTracker:create(player: Player): InitState
	local state = {
		player = player,
		startTime = os.time(),
		completed = false,
		success = false,
		error = nil,
		timeoutThread = nil,
	}

	self.states[player.UserId] = state
	return state
end

--[[
	Schedules a timeout callback for an initialization state.
]]
function InitStateTracker:scheduleTimeout(state: InitState, timeoutSeconds: number, onTimeout: TimeoutCallback)
	local thread = task.delay(timeoutSeconds, function()
		if not state.completed then
			onTimeout(state)
		end
	end)

	state.timeoutThread = thread
end

--[[
	Cancels an active timeout for an initialization state.
]]
function InitStateTracker:cancelTimeout(state: InitState)
	if state.timeoutThread then
		pcall(function()
			task.cancel(state.timeoutThread)
		end)
		state.timeoutThread = nil
	end
end

--[[
	Marks an initialization state as complete.
]]
function InitStateTracker:complete(state: InitState, success: boolean, error: string?)
	state.completed = true
	state.success = success
	state.error = error

	self:cancelTimeout(state)
end

--[[
	Schedules cleanup of a player's initialization state.
]]
function InitStateTracker:scheduleCleanup(userId: number, delaySeconds: number)
	task.delay(delaySeconds, function()
		self.states[userId] = nil
	end)
end

--[[
	Returns the initialization state for a player, if it exists.
]]
function InitStateTracker:getState(userId: number): InitState?
	return self.states[userId]
end

--[[
	Returns the number of active initialization states.
]]
function InitStateTracker:getActiveCount(): number
	local count = 0
	for _ in pairs(self.states) do
		count += 1
	end
	return count
end

--[[
	Creates an initialization state with an automatic timeout.
]]
function InitStateTracker:createWithTimeout(player: Player, timeoutSeconds: number?, onTimeout: TimeoutCallback?): InitState
	local state = self:create(player)

	if onTimeout then
		self:scheduleTimeout(state, timeoutSeconds or DEFAULT_TIMEOUT, onTimeout)
	end

	return state
end

return InitStateTracker