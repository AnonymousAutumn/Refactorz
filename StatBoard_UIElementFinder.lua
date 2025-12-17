-----------------
-- Init Module --
-----------------

local UIElementFinder = {}
UIElementFinder.leaderboardsContainer = nil

---------------
-- Functions --
---------------

function UIElementFinder.getLeaderboardUIElement(parent, elementName)
	return parent:FindFirstChild(elementName)
end

function UIElementFinder.getLeaderboardUIElements(leaderboardConfig)
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

-------------------
-- Return Module --
-------------------

return UIElementFinder