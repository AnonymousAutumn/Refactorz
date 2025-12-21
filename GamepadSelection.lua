-----------------
-- Init Module --
-----------------

local GamepadSelection = {}

--------------
-- Services --
--------------

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

---------------
-- Variables --
---------------

local lastSelectedObjects = {}

---------------
-- Functions --
---------------

local function isGamepadEnabled()
	return UserInputService.GamepadEnabled
end

local function isUsingGamepad()
	local lastInputType = UserInputService:GetLastInputType()
	return lastInputType == Enum.UserInputType.Gamepad1
		or lastInputType == Enum.UserInputType.Gamepad2
		or lastInputType == Enum.UserInputType.Gamepad3
		or lastInputType == Enum.UserInputType.Gamepad4
end

--[[
	Sets the currently selected GUI object for gamepad navigation.
	Only sets selection if gamepad is available or being used.

	@param guiObject GuiObject - The button/element to select
	@param contextKey string? - Optional key to remember selection per context
]]
function GamepadSelection.setSelection(guiObject, contextKey)
	if not guiObject or not guiObject:IsA("GuiObject") then
		return
	end

	if not isGamepadEnabled() and not isUsingGamepad() then
		return
	end

	GuiService.SelectedObject = guiObject

	if contextKey then
		lastSelectedObjects[contextKey] = guiObject
	end
end

--[[
	Clears the current gamepad selection.

	@param contextKey string? - Optional key to clear remembered selection
]]
function GamepadSelection.clearSelection(contextKey)
	GuiService.SelectedObject = nil

	if contextKey then
		lastSelectedObjects[contextKey] = nil
	end
end

--[[
	Restores the last remembered selection for a context.

	@param contextKey string - The context key to restore
	@return boolean - Whether selection was restored
]]
function GamepadSelection.restoreSelection(contextKey)
	local lastSelected = lastSelectedObjects[contextKey]
	if lastSelected and lastSelected:IsDescendantOf(game) then
		GuiService.SelectedObject = lastSelected
		return true
	end
	return false
end

--[[
	Sets up automatic selection when a frame becomes visible.
	Call this once during initialization.

	@param frame GuiObject - The frame to watch
	@param defaultButton GuiButton - The button to select when frame becomes visible
	@param contextKey string? - Optional context key for remembering selection
	@return RBXScriptConnection - The connection (for cleanup)
]]
function GamepadSelection.setupAutoSelection(frame, defaultButton, contextKey)
	return frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if frame.Visible then
			if contextKey and GamepadSelection.restoreSelection(contextKey) then
				return
			end
			GamepadSelection.setSelection(defaultButton, contextKey)
		else
			if contextKey then
				-- Remember current selection before clearing
				local current = GuiService.SelectedObject
				if current and current:IsDescendantOf(frame) then
					lastSelectedObjects[contextKey] = current
				end
			end
		end
	end)
end

--[[
	Finds the first selectable button in a container.

	@param container GuiObject - The container to search
	@return GuiButton? - The first button found, or nil
]]
function GamepadSelection.findFirstButton(container)
	for _, child in container:GetDescendants() do
		if (child:IsA("TextButton") or child:IsA("ImageButton")) and child.Visible then
			return child
		end
	end
	return nil
end

--[[
	Configures navigation order for a list of buttons (vertical or horizontal).

	@param buttons table - Array of buttons in order
	@param direction string - "vertical" or "horizontal"
]]
function GamepadSelection.setupNavigationOrder(buttons, direction)
	for i, button in buttons do
		local prevButton = buttons[i - 1]
		local nextButton = buttons[i + 1]

		if direction == "vertical" then
			if prevButton then
				button.NextSelectionUp = prevButton
			end
			if nextButton then
				button.NextSelectionDown = nextButton
			end
		else
			if prevButton then
				button.NextSelectionLeft = prevButton
			end
			if nextButton then
				button.NextSelectionRight = nextButton
			end
		end
	end
end

--[[
	Checks if gamepad is currently being used.

	@return boolean
]]
function GamepadSelection.isUsingGamepad()
	return isUsingGamepad()
end

--[[
	Checks if any gamepad is connected.

	@return boolean
]]
function GamepadSelection.isGamepadEnabled()
	return isGamepadEnabled()
end

-------------------
-- Return Module --
-------------------

return GamepadSelection
