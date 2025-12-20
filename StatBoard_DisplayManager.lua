--[[
	DisplayManager - Manages leaderboard display frames.

	Features:
	- Display frame creation
	- Frame update coordination
	- UI validation
]]

local DisplayManager = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Populater = require(script.Parent.Populater)

--[[
	Validates that count is a positive number.
]]
function DisplayManager.isValidDisplayCount(count: number?): boolean
	return type(count) == "number" and count > 0
end

--[[
	Validates that UI element exists and has a parent.
]]
function DisplayManager.isValidUIElement(element: Instance?): boolean
	return element ~= nil and element.Parent ~= nil
end

--[[
	Creates a single leaderboard display frame.
]]
function DisplayManager.createSingleDisplayFrame(frameIndex: number, parentScrollingFrame: ScrollingFrame, colorConfiguration: any, fadeInDuration: number, leaderboardPrefab: Frame): Frame?
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

--[[
	Creates all leaderboard display frames.
]]
function DisplayManager.createLeaderboardDisplayFrames(parentScrollingFrame: ScrollingFrame, totalDisplayCount: number, colorConfiguration: any, fadeInDuration: number, leaderboardPrefab: Frame): { Frame }
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

--[[
	Updates display frames with new leaderboard data.
]]
function DisplayManager.updateDisplayFrames(displayFrameCollection: { Frame }, processedLeaderboardEntries: { any }, systemConfiguration: any, statisticName: string): boolean
	local success, errorMessage = pcall(function()
		Populater.refreshAllLeaderboardDisplayFrames(displayFrameCollection, processedLeaderboardEntries, systemConfiguration)
	end)
	if not success then
		warn(`[{script.Name}] Failed to update display frames for {statisticName}: {tostring(errorMessage)}`)
		return false
	end
	return true
end

return DisplayManager