-----------------
-- Init Module --
-----------------

local TrackManager = {}
TrackManager.setBufferingCallback = nil
TrackManager.updateTrackNameCallback = nil
TrackManager.animateScrollCallback = nil

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

---------------
-- Constants --
---------------

local SOUND_LOAD_TIMEOUT = 5
local SOUND_LOAD_POLL_INTERVAL = 0.1

---------------
-- Functions --
---------------

function TrackManager.stopCurrentTrack(state)
	state.soundConnections:disconnect()
	if state.currentAudioTrack then
		state.currentAudioTrack:Stop()
		state.currentAudioTrack:Destroy()
		state.currentAudioTrack = nil
	end
end

function TrackManager.isValidTrackIndex(index, musicTracks)
	return #musicTracks > 0 and index >= 1 and index <= #musicTracks
end

function TrackManager.getNextTrackIndex(currentIndex, musicTracks)
	if #musicTracks == 0 then
		return 1
	end
	return (currentIndex % #musicTracks) + 1
end

function TrackManager.getPreviousTrackIndex(currentIndex, musicTracks)
	if #musicTracks == 0 then
		return 1
	end
	return ((currentIndex - 2) % #musicTracks) + 1
end

function TrackManager.createSound(trackData, parentInstance, currentVolumeNormalized, maxVolume)
	local newSound = Instance.new("Sound")
	newSound.SoundId = `rbxassetid://{trackData.Id}`
	newSound.Name = trackData.Name

	newSound.Volume = currentVolumeNormalized * maxVolume
	newSound.Parent = parentInstance
	return newSound
end

function TrackManager.setBufferingState(bufferingText)
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

function TrackManager.onSoundLoaded(sound, trackData)
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

function TrackManager.setupSoundEvents(sound, trackData, state, playTrackAtIndexFn: (number) -> ())
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

function TrackManager.isApprovedSound(trackData, testParent)
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

	if soundLoaded then
		return true
	else
		return false
	end
end

-------------------
-- Return Module --
-------------------

return TrackManager