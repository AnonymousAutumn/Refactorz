-----------------
-- Init Module --
-----------------

local ErrorDisplay = {}
ErrorDisplay.safeExecute = nil

---------------
-- Constants --
---------------

local ERROR_MESSAGE_DISPLAY_DURATION = 3

---------------
-- Functions --
---------------

function ErrorDisplay.showErrorMessage(elements, errorMessageText)
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

function ErrorDisplay.hideErrorMessage(elements)
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

function ErrorDisplay.displayTemporaryErrorMessage(elements, errorMessageText)
	ErrorDisplay.showErrorMessage(elements, errorMessageText)
	task.delay(ERROR_MESSAGE_DISPLAY_DURATION, function()
		ErrorDisplay.hideErrorMessage(elements)
	end)
end

-------------------
-- Return Module --
-------------------

return ErrorDisplay