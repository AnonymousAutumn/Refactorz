--[[
	UIElementFinder - Locates leaderboard UI elements in workspace.

	Features:
	- Surface GUI detection
	- Frame hierarchy traversal
	- UI element validation
]]

local UIElementFinder = {}
UIElementFinder.leaderboardsContainer = nil

--[[
	Finds a child UI element by name.
]]
function UIElementFinder.getLeaderboardUIElement(parent: Instance, elementName: string): Instance?
	return parent:FindFirstChild(elementName)
end

--[[
	Finds leaderboard scrolling frame from configuration.
]]
function UIElementFinder.getLeaderboardUIElements(leaderboardConfig: any): ScrollingFrame?
	if not UIElementFinder.leaderboardsContainer then
		warn(`[{script.Name}] Leaderboards container not set`)
		return nil
	end

	local leaderboardPhysicalModel = UIElementFinder.leaderboardsContainer:FindFirstChild(leaderboardConfig.statisticName)
	if not leaderboardPhysicalModel then
		return nil
	end

	local leaderboardSurfaceGui = UIElementFinder.getLeaderboardUIElement(leaderboardPhysicalModel, "SurfaceGui")
	if not leaderboardSurfaceGui or not leaderboardSurfaceGui:IsA("SurfaceGui") then
		return nil
	end

	local leaderboardMainFrame = UIElementFinder.getLeaderboardUIElement(leaderboardSurfaceGui, "MainFrame")
	if not leaderboardMainFrame or not leaderboardMainFrame:IsA("Frame") then
		return nil
	end

	local leaderboardScrollingFrame = UIElementFinder.getLeaderboardUIElement(leaderboardMainFrame, "ScrollingFrame")
	if not leaderboardScrollingFrame or not leaderboardScrollingFrame:IsA("ScrollingFrame") then
		return nil
	end

	return leaderboardScrollingFrame
end

return UIElementFinder