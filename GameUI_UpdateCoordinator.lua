-----------------
-- Init Module --
-----------------

local UpdateCoordinator = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local GameStateManager = require(script.Parent.GameStateManager)
local StatusAnimator = require(script.Parent.StatusAnimator)
local TimeoutManager = require(script.Parent.TimeoutManager)

---------------
-- Constants --
---------------

local STATUS_MESSAGE_DISPLAY_DURATION = 3
local IGNORE_UPDATES_BUFFER = 0.1

local GAME_ENDING_PATTERNS = {
	"timed out",
	"stopped playing",
	"won!",
	"draw",
}

---------------
-- Functions --
---------------

local function getCurrentTime()
	return os.clock()
end

local function safeExecute(func, errorMessage)
	local success, errorDetails = pcall(func)
	if not success then
		warn(errorMessage, errorDetails)
	end
	return success
end

function UpdateCoordinator.validateTurnUpdateParams(statusText, timeoutSeconds)
	if not ValidationUtils.isValidString(statusText) then
		return false
	end
	if timeoutSeconds ~= nil and not (ValidationUtils.isValidNumber(timeoutSeconds) and timeoutSeconds >= 0) then
		return false
	end
	return true
end

function UpdateCoordinator.displayStatusIfChanged(message)
	if not ValidationUtils.isValidString(message) then
		return
	end

	if message ~= StatusAnimator.getPreviousStatusText() or not StatusAnimator.isStatusVisible() then
		StatusAnimator.updateStatusText(message)
		StatusAnimator.showStatusInterface()
	end
end

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

function UpdateCoordinator.isGameEndingMessage(message)
	if not ValidationUtils.isValidString(message) then
		return false
	end

	for _, pattern in GAME_ENDING_PATTERNS do
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

function UpdateCoordinator.handleGameUIUpdate(statusText, timeoutSeconds, hideExitButton)
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

-------------------
-- Return Module --
-------------------

return UpdateCoordinator