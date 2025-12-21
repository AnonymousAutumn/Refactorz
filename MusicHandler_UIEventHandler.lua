-----------------
-- Init Module --
-----------------

local UIEventHandler = {}
UIEventHandler.updateVolumeCallback = nil
UIEventHandler.playNextTrackCallback = nil
UIEventHandler.playPreviousTrackCallback = nil

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

---------------
-- Constants --
---------------

local DRAG_DETECTION_RADIUS = 300

---------------
-- Functions --
---------------

local function getRelativeX(sliderFrame, inputPosX)
	local sliderWidth = math.max(sliderFrame.AbsoluteSize.X, 1)
	local relative = (inputPosX - sliderFrame.AbsolutePosition.X) / sliderWidth
	return math.clamp(relative, 0, 1)
end

function UIEventHandler.setupEventConnections(uiElements, connections, musicTracks)
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
		-- Use Activated for cross-platform support (PC, Mobile, Console)
		uiElements.nextTrackButton.Activated:Connect(function()
			if #musicTracks > 0 and UIEventHandler.playNextTrackCallback then
				UIEventHandler.playNextTrackCallback()
			end
		end),
		uiElements.previousTrackButton.Activated:Connect(function()
			if #musicTracks > 0 and UIEventHandler.playPreviousTrackCallback then
				UIEventHandler.playPreviousTrackCallback()
			end
		end)
	)
end

-------------------
-- Return Module --
-------------------

return UIEventHandler