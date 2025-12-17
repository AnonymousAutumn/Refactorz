-----------------
-- Init Module --
-----------------

local GameTiming = {}
GameTiming.__index = GameTiming

---------------
-- Constants --
---------------

local TURN_TIMEOUT = 30
local TOKEN_DROP_COOLDOWN = 0.65
local RESET_DELAY = 3

---------------
-- Functions --
---------------

function GameTiming.new()
	local self = setmetatable({}, GameTiming) 
	self.currentTimeoutId = 0
	
	return self 
end

function GameTiming:startTurnTimeout(onTimeout)
	self.currentTimeoutId += 1
	local timeoutId = self.currentTimeoutId

	task.delay(TURN_TIMEOUT, function()
		if timeoutId == self.currentTimeoutId then
			onTimeout()
		end
	end)
end

function GameTiming:cancelCurrentTimeout()
	self.currentTimeoutId += 1
end

function GameTiming.scheduleReset(callback)
	task.delay(RESET_DELAY, callback)
end

function GameTiming.scheduleDropCooldown(callback)
	task.delay(TOKEN_DROP_COOLDOWN, callback)
end

function GameTiming.getTurnTimeout()
	return TURN_TIMEOUT
end

-------------------
-- Return Module --
-------------------

return GameTiming