-----------------
-- Init Module --
-----------------

local ComponentFinder = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

----------------
-- References --
----------------

local networkFolder = ReplicatedStorage.Network
local leaderboardRemoteEvents = networkFolder.Remotes.Leaderboards
local workspaceLeaderboardsContainer = Workspace:WaitForChild("Leaderboards")

---------------
-- Constants --
---------------

local COMPONENT_WAIT_TIMEOUT = 10
local REMOTE_EVENT_NAME_FORMAT = "Update%s"

---------------
-- Functions --
---------------

local function waitForChildSafe(parent, childName, timeout)
	local success, child = pcall(function()
		return parent:WaitForChild(childName, timeout)
	end)
	return success and child or nil
end

function ComponentFinder.getWorkspaceComponents(leaderboardName)
	if typeof(leaderboardName) ~= "string" or leaderboardName == "" then
		return nil
	end

	local workspaceLeaderboard = workspaceLeaderboardsContainer:FindFirstChild(leaderboardName)
	if not workspaceLeaderboard then
		return nil
	end

	local surfaceGui = waitForChildSafe(workspaceLeaderboard, "SurfaceGui", COMPONENT_WAIT_TIMEOUT)
	if not surfaceGui then
		return nil
	end

	local mainFrame = waitForChildSafe(surfaceGui, "MainFrame", COMPONENT_WAIT_TIMEOUT)
	if not mainFrame then
		return nil
	end

	local scrollingFrame = waitForChildSafe(mainFrame, "ScrollingFrame", COMPONENT_WAIT_TIMEOUT)
	local toggleButton = waitForChildSafe(mainFrame, "ToggleButton", COMPONENT_WAIT_TIMEOUT)

	if not scrollingFrame or not scrollingFrame:IsA("ScrollingFrame") then
		return nil
	end
	if not toggleButton or not toggleButton:IsA("GuiButton") then
		return nil
	end

	return {
		scrollingFrame = scrollingFrame ,
		toggleButton = toggleButton ,
	}
end

function ComponentFinder.getUpdateRemoteEvent(leaderboardName)
	local updateEventName = `Update{leaderboardName}`
	local remoteEvent = leaderboardRemoteEvents:FindFirstChild(updateEventName)
	
	return remoteEvent
end

-------------------
-- Return Module --
-------------------

return ComponentFinder