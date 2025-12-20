--[[
	TrackManager - Manages audio track lifecycle.

	Features:
	- Sound creation and playback
	- Track index navigation
	- Sound approval validation
]]

local TrackManager = {}
TrackManager.setBufferingCallback = nil
TrackManager.updateTrackNameCallback = nil
TrackManager.animateScrollCallback = nil

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SOUND_LOAD_TIMEOUT = 5
local SOUND_LOAD_POLL_INTERVAL = 0.1

--[[
	Stops and cleans up the current track.
]]
function TrackManager.stopCurrentTrack(state: any)
	state.soundConnections:disconnect()
	if state.currentAudioTrack then
		state.currentAudioTrack:Stop()
		state.currentAudioTrack:Destroy()
		state.currentAudioTrack = nil
	end
end

--[[
	Checks if a track index is valid.
]]
function TrackManager.isValidTrackIndex(index: number, musicTracks: { any }): boolean
	return #musicTracks > 0 and index >= 1 and index <= #musicTracks
end

--[[
	Gets the next track index with wraparound.
]]
function TrackManager.getNextTrackIndex(currentIndex: number, musicTracks: { any }): number
	if #musicTracks == 0 then
		return 1
	end
	return (currentIndex % #musicTracks) + 1
end

--[[
	Gets the previous track index with wraparound.
]]
function TrackManager.getPreviousTrackIndex(currentIndex: number, musicTracks: { any }): number
	if #musicTracks == 0 then
		return 1
	end
	return ((currentIndex - 2) % #musicTracks) + 1
end

--[[
	Creates a new sound instance for a track.
]]
function TrackManager.createSound(trackData: any, parentInstance: Instance, currentVolumeNormalized: number, maxVolume: number): Sound
	local newSound = Instance.new("Sound")
	newSound.SoundId = `rbxassetid://{trackData.Id}`
	newSound.Name = trackData.Name

	newSound.Volume = currentVolumeNormalized * maxVolume
	newSound.Parent = parentInstance
	return newSound
end

--[[
	Sets the UI to buffering state.
]]
function TrackManager.setBufferingState(bufferingText: string)
	if TrackManager.setBufferingCallback then
		TrackManager.setBufferingCallback(false)
	end
	if TrackManager.updateTrackNameCallback then
		TrackManager.updateTrackNameCallback(bufferingText)
	end
	if TrackManager.animateScrollCallback then
		TrackManager.animateScrollCallback()
	end
end

--[[
	Handles sound loaded event.
]]
function TrackManager.onSoundLoaded(sound: Sound, trackData: any)
	sound:Play()
	if TrackManager.setBufferingCallback then
		TrackManager.setBufferingCallback(true)
	end
	if TrackManager.updateTrackNameCallback then
		TrackManager.updateTrackNameCallback(trackData.Name)
	end
	if TrackManager.animateScrollCallback then
		TrackManager.animateScrollCallback()
	end
end

--[[
	Sets up sound event handlers.
]]
function TrackManager.setupSoundEvents(sound: Sound, trackData: any, state: any, playTrackAtIndexFn: (number) -> ())
	local loadedConnection = sound.Loaded:Connect(function()
		TrackManager.onSoundLoaded(sound, trackData)
	end)

	local endedConnection
	endedConnection = sound.Ended:Connect(function()

		if loadedConnection.Connected then
			loadedConnection:Disconnect()
		end
		if endedConnection and endedConnection.Connected then
			endedConnection:Disconnect()
		end

		TrackManager.stopCurrentTrack(state)
		local nextIndex = TrackManager.getNextTrackIndex(state.currentTrackIndex, state.musicTracks)
		playTrackAtIndexFn(nextIndex)
	end)

	state.soundConnections:add(loadedConnection, endedConnection)
end

--[[
	Validates that a sound can be loaded.
]]
function TrackManager.isApprovedSound(trackData: any, testParent: Instance): boolean
	local testSound = Instance.new("Sound")
	testSound.SoundId = `rbxassetid://{trackData.Id}`
	testSound.Parent = testParent

	local soundLoaded = false
	local loadConnection

	loadConnection = testSound.Loaded:Connect(function()
		soundLoaded = true
		loadConnection:Disconnect()
	end)

	local timeout = SOUND_LOAD_TIMEOUT
	local startTime = tick()
	while not soundLoaded and tick() - startTime < timeout do
		task.wait(SOUND_LOAD_POLL_INTERVAL)
	end

	testSound:Destroy()

	return soundLoaded
end

return TrackManager