-----------------
-- Init Module --
-----------------

local StateManager = {}
StateManager.safeExecute = nil

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local TextToSpeech = require(modulesFolder.Utilities.TextToSpeech)

---------------
-- Functions --
---------------

function StateManager.updateGiftNotificationBadgeDisplay(badgeElements, unreadGiftCount)
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

function StateManager.resetGiftState(state)
	state.currentUnreadGiftCount = 0
	table.clear(state.cachedGiftDataFromServer)
	table.clear(state.activeGiftTimeDisplayEntries)
end

-------------------
-- Return Module --
-------------------

return StateManager