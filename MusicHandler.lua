--[[
	MusicHandler - Client-side music player controller.

	Features:
	- Track playback management
	- Volume control
	- Scrolling track name animation
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local modulesFolder = ReplicatedStorage.Modules
local configurationFolder = ReplicatedStorage.Configuration

local MusicLibrary = require(configurationFolder.MusicLibrary)
local Connections = require(modulesFolder.Wrappers.Connections)
local ScrollAnimator = require(script.ScrollAnimator)
local VolumeControl = require(script.VolumeControl)
local TrackManager = require(script.TrackManager)
local UIEventHandler = require(script.UIEventHandler)

local MAX_VOLUME = 0.5

local MUSIC_PLAYER_CONFIG = {
	DEFAULT_VOLUME = 0.25,
	SCROLL_SPEED = 35,
	SCROLL_RESET_DELAY = 1,
	SCROLL_INITIAL_DELAY = 2,
	BUFFERING_TEXT = "Buffering...",
}

local connectionsMaid = Connections.new()

local scrollState = {
	tween = nil,
	thread = nil,
}

local volumeState = {
	currentVolumeNormalized = MUSIC_PLAYER_CONFIG.DEFAULT_VOLUME / MAX_VOLUME,
	maxVolume = MAX_VOLUME,
}

local playbackState = {
	currentAudioTrack = nil,
	currentTrackIndex = 0,
	musicTracks = MusicLibrary,
	soundConnections = Connections.new(),
	volumeState = volumeState,
}

local musicPlayerInterface
local nextTrackButton
local previousTrackButton
local trackFrame
local trackNameLabel
local sliderFrame
local volumeFill
local volumeDragHandle
local volumeDragDetector

local function animateTrackNameScroll()
	ScrollAnimator.animateTrackNameScroll(trackNameLabel, trackFrame, scrollState, MUSIC_PLAYER_CONFIG)
end

local function updateVolume(newVolumeNormalized: number)
	VolumeControl.updateVolume(volumeState, playbackState.currentAudioTrack, volumeFill, volumeDragHandle, newVolumeNormalized)
end

local function playTrackAtIndex(targetIndex: number)
	if #MusicLibrary == 0 then
		warn("No music tracks available")
		return
	end

	targetIndex = math.clamp(targetIndex, 1, #MusicLibrary)
	playbackState.currentTrackIndex = targetIndex
	local trackData = MusicLibrary[targetIndex]

	TrackManager.stopCurrentTrack(playbackState)
	TrackManager.setBufferingState(MUSIC_PLAYER_CONFIG.BUFFERING_TEXT)
	ScrollAnimator.cleanupScrollAnimations(scrollState)

	if not TrackManager.isApprovedSound(trackData, script) then
		warn(`Skipping invalid sound: {trackData.Name} ({trackData.Id})`)
		local nextIndex = TrackManager.getNextTrackIndex(playbackState.currentTrackIndex, MusicLibrary)
		playTrackAtIndex(nextIndex)
		return
	end

	local newSound = TrackManager.createSound(trackData, musicPlayerInterface, volumeState.currentVolumeNormalized, volumeState.maxVolume)
	TrackManager.setupSoundEvents(newSound, trackData, playbackState, playTrackAtIndex)
	playbackState.currentAudioTrack = newSound
end

local function playRandomTrack()
	if #MusicLibrary == 0 then
		warn("No music tracks available")
		return
	end

	local randomIndex = math.random(1, #MusicLibrary)
	playTrackAtIndex(randomIndex)
end

local function playNextTrack()
	local nextIndex = TrackManager.getNextTrackIndex(playbackState.currentTrackIndex, MusicLibrary)
	playTrackAtIndex(nextIndex)
end

local function playPreviousTrack()
	local prevIndex = TrackManager.getPreviousTrackIndex(playbackState.currentTrackIndex, MusicLibrary)
	playTrackAtIndex(prevIndex)
end

local function setupEventConnections()

	TrackManager.setBufferingCallback = function(enabled)
		volumeDragDetector.Enabled = enabled
	end

	TrackManager.updateTrackNameCallback = function(text)
		trackNameLabel.Text = text
	end

	TrackManager.animateScrollCallback = animateTrackNameScroll

	UIEventHandler.updateVolumeCallback = updateVolume
	UIEventHandler.playNextTrackCallback = playNextTrack
	UIEventHandler.playPreviousTrackCallback = playPreviousTrack

	local uiElements = {
		sliderFrame = sliderFrame,
		volumeDragHandle = volumeDragHandle,
		volumeDragDetector = volumeDragDetector,
		nextTrackButton = nextTrackButton,
		previousTrackButton = previousTrackButton,
	}

	UIEventHandler.setupEventConnections(uiElements, connectionsMaid, MusicLibrary)
end

local function cleanup()
	connectionsMaid:disconnect()

	playbackState.soundConnections:disconnect()
	ScrollAnimator.cleanupScrollAnimations(scrollState)
	TrackManager.stopCurrentTrack(playbackState)
end

local function waitForPlayerLoaded()
	while not localPlayer:GetAttribute("Loaded") do
		task.wait()
	end
	localPlayer:SetAttribute("Loaded", nil)
end

local function initialize()
	local topbarUI = playerGui:WaitForChild("TopbarUI")
	if not topbarUI then
		warn(`[{script.Name}] TopbarUI not found in PlayerGui`)
		return
	end

	local mainFrame = topbarUI:WaitForChild("MainFrame")
	local holder = mainFrame:WaitForChild("Holder")

	musicPlayerInterface = holder:WaitForChild("MusicFrame") 
	nextTrackButton = musicPlayerInterface:WaitForChild("NextButton") 
	previousTrackButton = musicPlayerInterface:WaitForChild("PreviousButton") 
	trackFrame = musicPlayerInterface:WaitForChild("TrackFrame") 
	trackNameLabel = trackFrame:WaitForChild("TextLabel") 
	sliderFrame = musicPlayerInterface:WaitForChild("SliderFrame") 
	volumeFill = sliderFrame:WaitForChild("Fill") 
	volumeDragHandle = sliderFrame:WaitForChild("DragButton") 
	volumeDragDetector = sliderFrame:WaitForChild("UIDragDetector")

	waitForPlayerLoaded()
	VolumeControl.initializeDefaults(volumeFill, volumeDragHandle, volumeState.currentVolumeNormalized)
	setupEventConnections()
	playRandomTrack()

	connectionsMaid:add(
		musicPlayerInterface.AncestryChanged:Connect(function()
			if not musicPlayerInterface.Parent then
				cleanup()
			end
		end),
		localPlayer.AncestryChanged:Connect(function()
			if not localPlayer:IsDescendantOf(game) then
				cleanup()
			end
		end)
	)
end

initialize()