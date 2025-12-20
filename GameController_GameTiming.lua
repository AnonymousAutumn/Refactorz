--[[
	GameTiming - Manages game timing and timeouts.

	Features:
	- Turn timeout tracking
	- Drop cooldown scheduling
	- Reset delay handling
]]

local GameTiming = {}
GameTiming.__index = GameTiming

local TURN_TIMEOUT = 30
local TOKEN_DROP_COOLDOWN = 0.65
local RESET_DELAY = 3

--[[
	Creates a new GameTiming instance.
]]
function GameTiming.new(): any
	local self = setmetatable({}, GameTiming) 
	self.currentTimeoutId = 0
	
	return self 
end

--[[
	Starts a turn timeout timer.
]]
function GameTiming:startTurnTimeout(onTimeout: () -> ())
	self.currentTimeoutId += 1
	local timeoutId = self.currentTimeoutId

	task.delay(TURN_TIMEOUT, function()
		if timeoutId == self.currentTimeoutId then
			onTimeout()
		end
	end)
end

--[[
	Cancels the current timeout.
]]
function GameTiming:cancelCurrentTimeout()
	self.currentTimeoutId += 1
end

--[[
	Schedules a game reset after delay.
]]
function GameTiming.scheduleReset(callback: () -> ())
	task.delay(RESET_DELAY, callback)
end

--[[
	Schedules callback after drop cooldown.
]]
function GameTiming.scheduleDropCooldown(callback: () -> ())
	task.delay(TOKEN_DROP_COOLDOWN, callback)
end

--[[
	Gets the turn timeout value.
]]
function GameTiming.getTurnTimeout(): number
	return TURN_TIMEOUT
end

return GameTiming