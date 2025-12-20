--[[
	UIController - Manages leaderboard UI toggle interactions.

	Features:
	- Toggle button setup
	- Visibility state management
	- Transparency animations
]]

local UIController = {}

local LEADERBOARD_TRANSPARENCY = {
	VISIBLE = 0.85,
	HIDDEN = 0,
}

local function safeExecute(func: () -> ()): boolean
	local success, errorMessage = pcall(func)
	if not success then
		warn("Error in UIController.safeExecute:", errorMessage)
	end
	return success
end

local function toggleLeaderboardVisibility(scrollingFrame: ScrollingFrame, mainFrameLike: any)
	local shouldShowEntries = not scrollingFrame.Visible
	scrollingFrame.Visible = shouldShowEntries

	safeExecute(function()
		if mainFrameLike.ImageTransparency ~= nil then
			mainFrameLike.ImageTransparency = shouldShowEntries
				and LEADERBOARD_TRANSPARENCY.VISIBLE
				or LEADERBOARD_TRANSPARENCY.HIDDEN
		end
	end)
end

--[[
	Sets up toggle button interaction for leaderboard visibility.
]]
function UIController.setupToggle(toggleButton: GuiButton?, scrollingFrame: ScrollingFrame?, clientHandler: any?, state: any?): boolean
	if not toggleButton or not scrollingFrame or not clientHandler or not state then
		return false
	end

	return safeExecute(function()
		local toggleConnection = toggleButton.MouseButton1Click:Connect(function()
			safeExecute(function()
				toggleLeaderboardVisibility(scrollingFrame, clientHandler.MainFrame)
			end)
		end)
		table.insert(state.connections, toggleConnection)
	end)
end

return UIController