--[[
	UIEventHandler - Handles music player UI events.

	Features:
	- Volume slider drag handling
	- Track navigation buttons
	- Input position normalization
]]

local UIEventHandler = {}
UIEventHandler.updateVolumeCallback = nil
UIEventHandler.playNextTrackCallback = nil
UIEventHandler.playPreviousTrackCallback = nil

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DRAG_DETECTION_RADIUS = 300

local function getRelativeX(sliderFrame: Frame, inputPosX: number): number
	local sliderWidth = math.max(sliderFrame.AbsoluteSize.X, 1)
	local relative = (inputPosX - sliderFrame.AbsolutePosition.X) / sliderWidth
	return math.clamp(relative, 0, 1)
end

--[[
	Sets up all UI event connections.
]]
function UIEventHandler.setupEventConnections(uiElements: any, connections: any, musicTracks: { any })
	local dragging = false
	local pseudoRadius = DRAG_DETECTION_RADIUS

	connections:add(
		uiElements.volumeDragDetector.DragStart:Connect(function(inputPos)
			local knobX = uiElements.volumeDragHandle.AbsolutePosition.X
			local knobSizeX = uiElements.volumeDragHandle.AbsoluteSize.X

			if inputPos.X < (knobX - pseudoRadius) or inputPos.X > (knobX + knobSizeX + pseudoRadius) then
				return
			end

			dragging = true
			if UIEventHandler.updateVolumeCallback then
				UIEventHandler.updateVolumeCallback(getRelativeX(uiElements.sliderFrame, inputPos.X))
			end
		end),
		uiElements.volumeDragDetector.DragContinue:Connect(function(inputPos)
			if not dragging then
				return
			end
			if UIEventHandler.updateVolumeCallback then
				UIEventHandler.updateVolumeCallback(getRelativeX(uiElements.sliderFrame, inputPos.X))
			end
		end),
		uiElements.volumeDragDetector.DragEnd:Connect(function()
			dragging = false
		end),
		uiElements.nextTrackButton.MouseButton1Click:Connect(function()
			if #musicTracks > 0 and UIEventHandler.playNextTrackCallback then
				UIEventHandler.playNextTrackCallback()
			end
		end),
		uiElements.previousTrackButton.MouseButton1Click:Connect(function()
			if #musicTracks > 0 and UIEventHandler.playPreviousTrackCallback then
				UIEventHandler.playPreviousTrackCallback()
			end
		end)
	)
end

return UIEventHandler