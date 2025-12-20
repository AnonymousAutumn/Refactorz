--[[
	TimeoutManager - Manages game timeout countdowns.

	Features:
	- Countdown display updates
	- Cancellation support
	- Status text integration
]]

local TimeoutManager = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local GameStateManager = require(script.Parent.GameStateManager)
local StatusAnimator = require(script.Parent.StatusAnimator)

local MESSAGE_FORMAT_TIMEOUT = "Time Left: %d"

local function safeExecute(func: () -> (), errorMessage: string): boolean
	local success, errorDetails = pcall(func)
	if not success then
		warn(errorMessage, errorDetails)
	end
	return success
end

local function updateTimeoutDisplay(secondsLeft: number)
	safeExecute(function()
		StatusAnimator.updateStatusText(`Time Left: {secondsLeft}`)
	end, "Error updating timeout text")
end

local function isTimeoutActive(handlerId: number, isCancelled: boolean): boolean
	return not isCancelled and GameStateManager.getTimeoutSequenceId() == handlerId
end

local function runTimeoutCountdown(timeRemaining: number, handlerId: number, isCancelledRef: { value: boolean })
	local secondsLeft = timeRemaining
	while secondsLeft > 0 and isTimeoutActive(handlerId, isCancelledRef.value) do
		updateTimeoutDisplay(secondsLeft)
		task.wait(1)
		secondsLeft -= 1
	end
end

local function finalizeTimeout(finalMessage: string, handlerId: number, isCancelledRef: { value: boolean })
	if isTimeoutActive(handlerId, isCancelledRef.value) then
		StatusAnimator.updateStatusText(finalMessage)
		StatusAnimator.hideStatusInterface()
	end
end

--[[
	Creates a timeout handler with countdown and cancellation support.
]]
function TimeoutManager.createTimeoutHandler(timeRemaining: number?, finalMessage: string?): { cancel: () -> (), isActive: () -> boolean }
	if not (ValidationUtils.isValidNumber(timeRemaining) and timeRemaining >= 0) or not ValidationUtils.isValidString(finalMessage) then
		return {
			cancel = function() end,
			isActive = function()
				return false
			end,
		}
	end

	local handlerId = GameStateManager.getTimeoutSequenceId()
	local isCancelledRef = { value = false }

	local function cancel()
		isCancelledRef.value = true
	end

	local function isActive()
		return isTimeoutActive(handlerId, isCancelledRef.value)
	end

	local timeoutTask = task.spawn(function()
		runTimeoutCountdown(timeRemaining, handlerId, isCancelledRef)
		finalizeTimeout(finalMessage, handlerId, isCancelledRef)
	end)

	GameStateManager.trackTask(timeoutTask)

	return {
		cancel = cancel,
		isActive = isActive,
	}
end

--[[
	Cancels the active timeout handler.
]]
function TimeoutManager.cancelTimeoutHandler()
	if not GameStateManager.state.activeTimeoutHandler then
		return
	end

	safeExecute(function()
		if GameStateManager.state.activeTimeoutHandler and GameStateManager.state.activeTimeoutHandler.isActive() then
			GameStateManager.state.activeTimeoutHandler.cancel()
		end
	end, "Error cancelling timeout handler")

	GameStateManager.state.activeTimeoutHandler = nil
end

return TimeoutManager