--[[
	TextToSpeech - Text-to-speech audio playback.

	Features:
	- TTS instance creation
	- Audio playback with cleanup
]]

local TextToSpeech = {}
TextToSpeech.DefaultVoiceId = "1"
TextToSpeech.DefaultPitch = 1.0
TextToSpeech.DefaultVolume = 1.0

local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

function TextToSpeech._createTTSInstance(text: string, voiceId: string, pitch: number, volume: number): (any, AudioDeviceOutput, Wire)
	local ats = Instance.new("AudioTextToSpeech")
	ats.Text = text
	ats.VoiceId = voiceId
	ats.Pitch = pitch
	ats.Volume = volume

	local deviceOutput = Instance.new("AudioDeviceOutput")
	deviceOutput.Parent = SoundService

	local wire = Instance.new("Wire")
	wire.Parent = SoundService
	wire.SourceInstance = ats
	wire.TargetInstance = deviceOutput

	return ats, deviceOutput, wire
end

--[[
	Speaks the given text using TTS.
]]
function TextToSpeech.Speak(text: string, opts: any?): RBXScriptConnection?
	opts = opts or {}
	local voiceId = opts.VoiceId or TextToSpeech.DefaultVoiceId
	local pitch = opts.Pitch or TextToSpeech.DefaultPitch
	local volume = opts.Volume or TextToSpeech.DefaultVolume

	if typeof(text) ~= "string" then
		warn(`[{script.Name}] Speak called with non-string text:", text`)
		return
	end

	local ats, devOut, wire = TextToSpeech._createTTSInstance(text, voiceId, pitch, volume)
	ats.Parent = SoundService
	devOut.Parent = SoundService

	local ok, err = pcall(function()
		ats:Play()
	end)
	if not ok then
		warn(`[{script.Name}] Failed to Play(): `, err)
		wire:Destroy()
		devOut:Destroy()
		ats:Destroy()
		return
	end

	local connection
	connection = ats.Ended:Connect(function()
		connection:Disconnect()
		wire:Destroy()
		devOut:Destroy()
		ats:Destroy()
	end)

	return connection
end

return TextToSpeech