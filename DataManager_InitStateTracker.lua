-----------------
-- Init Module --
-----------------

local InitStateTracker = {}
InitStateTracker.__index = InitStateTracker

---------------
-- Constants --
---------------

local DEFAULT_TIMEOUT = 30
local DEFAULT_CLEANUP_DELAY = 60

---------------
-- Functions --
---------------

function InitStateTracker.new()
	local self = setmetatable({}, InitStateTracker) 
	self.states = {}
	return self 
end

function InitStateTracker:create(player)
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

function InitStateTracker:scheduleTimeout(state, timeoutSeconds, onTimeout)
	local thread = task.delay(timeoutSeconds, function()
		if not state.completed then
			onTimeout(state)
		end
	end)

	state.timeoutThread = thread
end

function InitStateTracker:cancelTimeout(state)
	if state.timeoutThread then
		pcall(function()
			task.cancel(state.timeoutThread)
		end)
		state.timeoutThread = nil
	end
end

function InitStateTracker:complete(state, success, error)
	state.completed = true
	state.success = success
	state.error = error

	self:cancelTimeout(state)
end

function InitStateTracker:scheduleCleanup(userId, delaySeconds)
	task.delay(delaySeconds, function()
		self.states[userId] = nil
	end)
end

function InitStateTracker:getState(userId)
	return self.states[userId]
end

function InitStateTracker:getActiveCount()
	local count = 0
	for _ in self.states do
		count += 1
	end
	return count
end

function InitStateTracker:createWithTimeout(player, timeoutSeconds, onTimeout)
	local state = self:create(player)

	if onTimeout then
		self:scheduleTimeout(state, timeoutSeconds or DEFAULT_TIMEOUT, onTimeout)
	end

	return state
end

-------------------
-- Return Module --
-------------------

return InitStateTracker