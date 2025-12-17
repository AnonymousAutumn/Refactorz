-----------------
-- Init Module --
-----------------

local DisplayManager = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local Populater = require(script.Parent.Populater)

---------------
-- Functions --
---------------

function DisplayManager.isValidDisplayCount(count)
	return type(count) == "number" and count > 0
end

function DisplayManager.isValidUIElement(element)
	return element ~= nil and element.Parent ~= nil
end

function DisplayManager.createSingleDisplayFrame(frameIndex, parentScrollingFrame, colorConfiguration, fadeInDuration, leaderboardPrefab)
	local success, frameOrError = pcall(function()
		return Populater.createLeaderboardEntryFrame(
			frameIndex,
			leaderboardPrefab,
			parentScrollingFrame,
			colorConfiguration,
			fadeInDuration
		)
	end)
	if success and frameOrError then
		return frameOrError
	end
	if not success then
		warn(`{TAG} Failed to create leaderboard frame for index {frameIndex}: {tostring(frameOrError)}`)
	end
	return nil
end

function DisplayManager.createLeaderboardDisplayFrames(parentScrollingFrame, totalDisplayCount, colorConfiguration, fadeInDuration, leaderboardPrefab)
	if not DisplayManager.isValidUIElement(parentScrollingFrame) then
		return {}
	end
	if not DisplayManager.isValidDisplayCount(totalDisplayCount) then
		return {}
	end

	local createdDisplayFrames = {}
	for frameIndex = 1, totalDisplayCount do
		local frame = DisplayManager.createSingleDisplayFrame(
			frameIndex,
			parentScrollingFrame,
			colorConfiguration,
			fadeInDuration,
			leaderboardPrefab
		)
		if frame then
			createdDisplayFrames[frameIndex] = frame
		end
	end

	return createdDisplayFrames
end

function DisplayManager.updateDisplayFrames(displayFrameCollection, processedLeaderboardEntries, systemConfiguration, statisticName)
	local success, errorMessage = pcall(function()
		Populater.refreshAllLeaderboardDisplayFrames(displayFrameCollection, processedLeaderboardEntries, systemConfiguration)
	end)
	if not success then
		warn(`[{script.Name}] Failed to update display frames for {statisticName}: {tostring(errorMessage)}`)
		return false
	end
	return true
end

-------------------
-- Return Module --
-------------------

return DisplayManager