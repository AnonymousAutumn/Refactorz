--[[
	VolumeControl - Controls volume slider and audio levels.

	Features:
	- Volume normalization
	- Slider UI updates
	- Audio track volume sync
]]

local VolumeControl = {}

--[[
	Updates volume and UI elements.
]]
function VolumeControl.updateVolume(volumeState: any, currentAudioTrack: Sound?, volumeFill: Frame, volumeDragHandle: GuiButton, newVolumeNormalized: number)
	volumeState.currentVolumeNormalized = math.clamp(newVolumeNormalized, 0, 1)

	local scaledVolume = volumeState.currentVolumeNormalized * volumeState.maxVolume

	if currentAudioTrack then
		currentAudioTrack.Volume = scaledVolume
	end

	volumeFill.Size = UDim2.new(volumeState.currentVolumeNormalized, 0, 1, 0)
	volumeDragHandle.Position = UDim2.new(volumeState.currentVolumeNormalized, 0, 0.5, 0)
end

--[[
	Initializes default volume slider positions.
]]
function VolumeControl.initializeDefaults(volumeFill: Frame, volumeDragHandle: GuiButton, currentVolumeNormalized: number)
	local sliderPosition = math.clamp(currentVolumeNormalized, 0, 1)
	volumeDragHandle.Position = UDim2.new(sliderPosition, 0, 0.5, 0)
	volumeFill.Size = UDim2.new(sliderPosition, 0, 1, 0)
end

return VolumeControl