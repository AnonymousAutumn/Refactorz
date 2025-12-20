--[[
	StatusAnimator - Animates game status UI elements.

	Features:
	- Status text updates
	- Show/hide animations
	- Mobile/desktop positioning
]]

local StatusAnimator = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local GameStateManager = require(script.Parent.GameStateManager)

local STATUS_ANIMATION_TWEEN_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local STATUS_VISIBLE_DESKTOP = UDim2.new(0.5, 0, 1, -80)
local STATUS_VISIBLE_MOBILE = UDim2.new(0.5, 0, 1, -20)
local STATUS_HIDDEN = UDim2.new(0.5, 0, 1, 40)
local EMPTY_TEXT_PLACEHOLDER = ""

StatusAnimator.statusLabel = nil
StatusAnimator.statusHolder = nil
StatusAnimator.exitButton = nil
StatusAnimator.isMobileDevice = false

local function safeExecute(func: () -> (), errorMessage: string): boolean
	local success, errorDetails = pcall(func)
	if not success then
		warn(errorMessage, errorDetails)
	end
	return success
end

--[[
	Updates the status label text.
]]
function StatusAnimator.updateStatusText(newText: string?)
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

--[[
	Sets the exit button visibility.
]]
function StatusAnimator.setExitButtonVisibility(isVisible: boolean)
	safeExecute(function()
		if StatusAnimator.exitButton then
			StatusAnimator.exitButton.Visible = isVisible
		end
	end, "Error setting exit button visibility")
end

--[[
	Returns the visible position based on device type.
]]
function StatusAnimator.getVisiblePosition(): UDim2
	return StatusAnimator.isMobileDevice and STATUS_VISIBLE_MOBILE or STATUS_VISIBLE_DESKTOP
end

--[[
	Toggles core GUI visibility for mobile devices.
]]
function StatusAnimator.toggleCoreGui(enabled: boolean)
	if not StatusAnimator.isMobileDevice then
		return
	end

	safeExecute(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, enabled)
	end, "Error toggling core GUI")
end

--[[
	Creates and plays a tween on the target.
]]
function StatusAnimator.createAndPlayTween(target: Instance, properties: { [string]: any })
	local tween = TweenService:Create(target, STATUS_ANIMATION_TWEEN_INFO, properties)
	GameStateManager.trackTween(tween)
	tween:Play()
end

--[[
	Shows the status interface with animation.
]]
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

--[[
	Hides the status interface with animation.
]]
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

--[[
	Returns whether the status is currently visible.
]]
function StatusAnimator.isStatusVisible(): boolean
	return GameStateManager.state.isStatusVisible
end

--[[
	Returns the previous status text.
]]
function StatusAnimator.getPreviousStatusText(): string
	return GameStateManager.state.previousStatusText
end

return StatusAnimator