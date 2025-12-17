-----------------
-- Init Module --
-----------------

local UIController = {}

---------------
-- Constants --
---------------

local LEADERBOARD_TRANSPARENCY = {
	VISIBLE = 0.85,
	HIDDEN = 0,
}

---------------
-- Functions --
---------------

local function safeExecute(func)
	local success, errorMessage = pcall(func)
	if not success then
		warn("Error in UIController.safeExecute:", errorMessage)
	end
	return success
end

local function toggleLeaderboardVisibility(scrollingFrame, mainFrameLike)
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

function UIController.setupToggle(toggleButton, scrollingFrame, clientHandler, state)
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

-------------------
-- Return Module --
-------------------

return UIController