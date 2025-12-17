-----------------
-- Init Module --
-----------------

local VolumeControl = {}

---------------
-- Functions --
---------------

function VolumeControl.updateVolume(volumeState, currentAudioTrack, volumeFill, volumeDragHandle, newVolumeNormalized)
	volumeState.currentVolumeNormalized = math.clamp(newVolumeNormalized, 0, 1)

	local scaledVolume = volumeState.currentVolumeNormalized * volumeState.maxVolume

	if currentAudioTrack then
		currentAudioTrack.Volume = scaledVolume
	end

	volumeFill.Size = UDim2.new(volumeState.currentVolumeNormalized, 0, 1, 0)
	volumeDragHandle.Position = UDim2.new(volumeState.currentVolumeNormalized, 0, 0.5, 0)
end

function VolumeControl.initializeDefaults(volumeFill, volumeDragHandle, currentVolumeNormalized)
	local sliderPosition = math.clamp(currentVolumeNormalized, 0, 1)
	volumeDragHandle.Position = UDim2.new(sliderPosition, 0, 0.5, 0)
	volumeFill.Size = UDim2.new(sliderPosition, 0, 1, 0)
end

-------------------
-- Return Module --
-------------------

return VolumeControl