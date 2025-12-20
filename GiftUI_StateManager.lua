--[[
	StateManager - Manages gift UI state and notifications.

	Features:
	- Gift notification badge updates
	- Text-to-speech announcements
	- State reset functionality
]]

local StateManager = {}
StateManager.safeExecute = nil

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modulesFolder = ReplicatedStorage.Modules
local TextToSpeech = require(modulesFolder.Utilities.TextToSpeech)

--[[
	Updates the gift notification badge display and announces pending gifts.
]]
function StateManager.updateGiftNotificationBadgeDisplay(badgeElements: any, unreadGiftCount: number)
	if not StateManager.safeExecute then
		return
	end

	StateManager.safeExecute(function()
		if unreadGiftCount > 0 then
			badgeElements.giftCountNotificationLabel.Text = tostring(unreadGiftCount)
			badgeElements.giftCountNotificationLabel.Visible = true

			local suffix = (unreadGiftCount == 1) and "" or "s"
			local formattedSpeech = `You have {unreadGiftCount} pending gift{suffix}.`
			TextToSpeech.Speak(formattedSpeech)
		else
			badgeElements.giftCountNotificationLabel.Visible = false
		end
	end)
end

--[[
	Resets the gift state to default values.
]]
function StateManager.resetGiftState(state: any)
	state.currentUnreadGiftCount = 0
	table.clear(state.cachedGiftDataFromServer)
	table.clear(state.activeGiftTimeDisplayEntries)
end

return StateManager