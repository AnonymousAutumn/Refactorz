--[[
	ErrorDisplay - Handles error message display in the gift UI.

	Features:
	- Temporary error message display
	- Input field visibility management
]]

local ErrorDisplay = {}
ErrorDisplay.safeExecute = nil

local ERROR_MESSAGE_DISPLAY_DURATION = 3

--[[
	Shows an error message and disables input elements.
]]
function ErrorDisplay.showErrorMessage(elements: any, errorMessageText: string)
	if not ErrorDisplay.safeExecute then
		return
	end

	ErrorDisplay.safeExecute(function()
		elements.errorMessageDisplayFrame.Visible = true
		elements.errorMessageLabel.Text = errorMessageText
		elements.usernameInputTextBox.Visible = false
		elements.giftSendConfirmationButton.Active = false
	end)
end

--[[
	Hides the error message and re-enables input elements.
]]
function ErrorDisplay.hideErrorMessage(elements: any)
	if not ErrorDisplay.safeExecute then
		return
	end

	ErrorDisplay.safeExecute(function()
		elements.errorMessageDisplayFrame.Visible = false
		elements.errorMessageLabel.Text = ""
		elements.usernameInputTextBox.Visible = true
		elements.giftSendConfirmationButton.Active = true
	end)
end

--[[
	Displays a temporary error message that auto-hides after a duration.
]]
function ErrorDisplay.displayTemporaryErrorMessage(elements: any, errorMessageText: string)
	ErrorDisplay.showErrorMessage(elements, errorMessageText)
	task.delay(ERROR_MESSAGE_DISPLAY_DURATION, function()
		ErrorDisplay.hideErrorMessage(elements)
	end)
end

return ErrorDisplay