-----------------
-- Init Module --
-----------------

local SoundManager = {}

--------------
-- Services --
--------------

local SoundService = game:GetService("SoundService")

----------------
-- References --
----------------

local feedbackGroup = SoundService.Feedback

---------------
-- Constants --
---------------

local SOUND_NAMES = {
	Success = "Success",
	Warning = "Error",
	Error = "Error",
}

---------------
-- Functions --
---------------

local function getSound(soundName)
	local sound = feedbackGroup:FindFirstChild(soundName)
	if sound and sound:IsA("Sound") then
		return sound 
	end
	return nil
end

local function playSound(soundName)
	local success, errorMsg = pcall(function()
		local sound = getSound(soundName)
		if sound then
			sound:Play()
		end
	end)

	if not success then
		warn(`[SoundManager] Failed to play sound {soundName}: {tostring(errorMsg)}`)
	end
end

function SoundManager.playForType(notificationType)
	local soundName = SOUND_NAMES[notificationType]
	if soundName then
		playSound(soundName)
	end
end

function SoundManager.playSuccess()
	playSound(SOUND_NAMES.Success)
end

function SoundManager.playError()
	playSound(SOUND_NAMES.Error)
end

-------------------
-- Return Module --
-------------------

return SoundManager