--[[
	UpdateCoordinator - Coordinates game UI updates.

	Features:
	- Status display management
	- Game ending pattern detection
	- Auto-hide scheduling
]]

local UpdateCoordinator = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local GameStateManager = require(script.Parent.GameStateManager)
local StatusAnimator = require(script.Parent.StatusAnimator)
local TimeoutManager = require(script.Parent.TimeoutManager)

local STATUS_MESSAGE_DISPLAY_DURATION = 3
local IGNORE_UPDATES_BUFFER = 0.1

local GAME_ENDING_PATTERNS = {
	"timed out",
	"stopped playing",
	"won!",
	"draw",
}

local function getCurrentTime(): number
	return os.clock()
end

local function safeExecute(func: () -> (), errorMessage: string): boolean
	local success, errorDetails = pcall(func)
	if not success then
		warn(errorMessage, errorDetails)
	end
	return success
end

--[[
	Validates turn update parameters.
]]
function UpdateCoordinator.validateTurnUpdateParams(statusText: string?, timeoutSeconds: number?): boolean
	if not ValidationUtils.isValidString(statusText) then
		return false
	end
	if timeoutSeconds ~= nil and not (ValidationUtils.isValidNumber(timeoutSeconds) and timeoutSeconds >= 0) then
		return false
	end
	return true
end

--[[
	Displays status if changed from previous.
]]
function UpdateCoordinator.displayStatusIfChanged(message: string?)
	if not ValidationUtils.isValidString(message) then
		return
	end

	if message ~= StatusAnimator.getPreviousStatusText() or not StatusAnimator.isStatusVisible() then
		StatusAnimator.updateStatusText(message)
		StatusAnimator.showStatusInterface()
	end
end

--[[
	Cancels the auto-hide task if active.
]]
function UpdateCoordinator.cancelAutoHideTask()
	if not GameStateManager.state.autoHideTask then
		return
	end

	GameStateManager.incrementStatusSequence()

	safeExecute(function()
		task.cancel(GameStateManager.state.autoHideTask)
	end, "Error cancelling auto-hide task")

	GameStateManager.state.autoHideTask = nil
end

function UpdateCoordinator.scheduleAutoHide()
	UpdateCoordinator.cancelAutoHideTask()
	GameStateManager.incrementStatusSequence()
	local currentSequenceId = GameStateManager.getStatusSequenceId()

	GameStateManager.state.autoHideTask = task.delay(STATUS_MESSAGE_DISPLAY_DURATION, function()
		if GameStateManager.getStatusSequenceId() == currentSequenceId then
			StatusAnimator.hideStatusInterface()
			StatusAnimator.updateStatusText(nil)
			GameStateManager.state.autoHideTask = nil
		end
	end)

	GameStateManager.trackTask(GameStateManager.state.autoHideTask)
end

--[[
	Checks if the message indicates game ending.
]]
function UpdateCoordinator.isGameEndingMessage(message: string?): boolean
	if not ValidationUtils.isValidString(message) then
		return false
	end

	for _, pattern in pairs(GAME_ENDING_PATTERNS) do
		if string.find(message, pattern) then
			return true
		end
	end
	return false
end

function UpdateCoordinator.setIgnoreUpdatesPeriod()
	GameStateManager.state.ignoreUpdatesUntil = getCurrentTime() + STATUS_MESSAGE_DISPLAY_DURATION + IGNORE_UPDATES_BUFFER
end

function UpdateCoordinator.shouldIgnoreUpdates()
	return getCurrentTime() < GameStateManager.state.ignoreUpdatesUntil
end

function UpdateCoordinator.handleEmptyStatus(hideExitButton, statusText)
	if hideExitButton and statusText == "" then
		StatusAnimator.updateStatusText(nil)
		StatusAnimator.hideStatusInterface()
		return true
	end
	return false
end

function UpdateCoordinator.prepareForTurnUpdate(hideExitButton)
	GameStateManager.incrementTimeoutSequence()
	TimeoutManager.cancelTimeoutHandler()
	UpdateCoordinator.cancelAutoHideTask()
	StatusAnimator.setExitButtonVisibility(not hideExitButton)
end

--[[
	Handles game UI update events from server.
]]
function UpdateCoordinator.handleGameUIUpdate(statusText: string?, timeoutSeconds: number?, hideExitButton: boolean?)
	if not UpdateCoordinator.validateTurnUpdateParams(statusText, timeoutSeconds) then
		return
	end

	safeExecute(function()
		if UpdateCoordinator.shouldIgnoreUpdates() then
			return
		end

		UpdateCoordinator.prepareForTurnUpdate(hideExitButton)

		if UpdateCoordinator.handleEmptyStatus(hideExitButton, statusText) then
			return
		end

		UpdateCoordinator.displayStatusIfChanged(statusText)

		if timeoutSeconds then
			GameStateManager.state.activeTimeoutHandler = TimeoutManager.createTimeoutHandler(timeoutSeconds, statusText)
		else
			if UpdateCoordinator.isGameEndingMessage(statusText) then
				UpdateCoordinator.setIgnoreUpdatesPeriod()
			end
			UpdateCoordinator.scheduleAutoHide()
		end
	end, "Error handling game UI update")
end

return UpdateCoordinator