--[[
	SoundManager - Plays notification sounds by type.

	Features:
	- Type-based sound selection
	- Safe sound playback with error handling
]]

local SoundManager = {}

local SoundService = game:GetService("SoundService")

local feedbackGroup = SoundService.Feedback

local SOUND_NAMES = {
	Success = "Success",
	Warning = "Error",
	Error = "Error",
}

local function getSound(soundName: string): Sound?
	local sound = feedbackGroup:FindFirstChild(soundName)
	if sound and sound:IsA("Sound") then
		return sound 
	end
	return nil
end

local function playSound(soundName: string)
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

--[[
	Plays the sound associated with a notification type.
]]
function SoundManager.playForType(notificationType: string)
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

return SoundManager