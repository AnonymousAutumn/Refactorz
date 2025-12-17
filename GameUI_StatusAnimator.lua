-----------------
-- Init Module --
-----------------

local StatusAnimator = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local GameStateManager = require(script.Parent.GameStateManager)

---------------
-- Constants --
---------------

local STATUS_ANIMATION_TWEEN_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local STATUS_VISIBLE_DESKTOP = UDim2.new(0.5, 0, 1, -80)
local STATUS_VISIBLE_MOBILE = UDim2.new(0.5, 0, 1, -20)
local STATUS_HIDDEN = UDim2.new(0.5, 0, 1, 40)
local EMPTY_TEXT_PLACEHOLDER = ""

---------------
-- Variables --
---------------

StatusAnimator.statusLabel = nil
StatusAnimator.statusHolder = nil
StatusAnimator.exitButton = nil
StatusAnimator.isMobileDevice = false

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

function StatusAnimator.updateStatusText(newText)
	safeExecute(function()
		local displayText = newText or EMPTY_TEXT_PLACEHOLDER
		if not ValidationUtils.isValidString(displayText) then
			return
		end
		if StatusAnimator.statusLabel then
			StatusAnimator.statusLabel.Text = displayText
			GameStateManager.state.previousStatusText = displayText
		end
	end, "Error updating status text")
end

function StatusAnimator.setExitButtonVisibility(isVisible)
	safeExecute(function()
		if StatusAnimator.exitButton then
			StatusAnimator.exitButton.Visible = isVisible
		end
	end, "Error setting exit button visibility")
end

function StatusAnimator.getVisiblePosition()
	return StatusAnimator.isMobileDevice and STATUS_VISIBLE_MOBILE or STATUS_VISIBLE_DESKTOP
end

function StatusAnimator.toggleCoreGui(enabled)
	if not StatusAnimator.isMobileDevice then
		return
	end

	safeExecute(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, enabled)
	end, "Error toggling core GUI")
end

function StatusAnimator.createAndPlayTween(target, properties)
	local tween = TweenService:Create(target, STATUS_ANIMATION_TWEEN_INFO, properties)
	GameStateManager.trackTween(tween)
	tween:Play()
end

function StatusAnimator.showStatusInterface()
	if GameStateManager.state.isStatusVisible then
		return
	end

	safeExecute(function()
		if not StatusAnimator.statusHolder then
			return
		end

		local targetPosition = StatusAnimator.getVisiblePosition()
		StatusAnimator.createAndPlayTween(StatusAnimator.statusHolder, { Position = targetPosition })

		GameStateManager.state.isStatusVisible = true
		StatusAnimator.toggleCoreGui(false)
	end, "Error showing status interface")
end

function StatusAnimator.hideStatusInterface()
	if not GameStateManager.state.isStatusVisible then
		return
	end

	safeExecute(function()
		if not StatusAnimator.statusHolder then
			return
		end

		StatusAnimator.createAndPlayTween(StatusAnimator.statusHolder, { Position = STATUS_HIDDEN })

		GameStateManager.state.isStatusVisible = false
		GameStateManager.state.previousStatusText = ""

		StatusAnimator.toggleCoreGui(true)
	end, "Error hiding status interface")
end

function StatusAnimator.isStatusVisible()
	return GameStateManager.state.isStatusVisible
end

function StatusAnimator.getPreviousStatusText()
	return GameStateManager.state.previousStatusText
end

-------------------
-- Return Module --
-------------------

return StatusAnimator