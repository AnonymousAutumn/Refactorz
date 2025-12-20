--[[
	StateManager - Manages leaderboard state per instance.

	Features:
	- State initialization and cleanup
	- Connection tracking per leaderboard
	- Update count tracking
]]

local StateManager = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modulesFolder = ReplicatedStorage.Modules
local Connections = require(modulesFolder.Wrappers.Connections)

local leaderboardStates = {}

local function safeExecute(func: () -> ()): boolean
	local success, errorMessage = pcall(func)
	if not success then
		warn("Error in StateManager.safeExecute:", errorMessage)
	end
	return success
end

--[[
	Initializes or returns existing state for a leaderboard.
]]
function StateManager.initializeState(leaderboardName: string): any
	if not leaderboardStates[leaderboardName] then
		leaderboardStates[leaderboardName] = {
			handler = nil,
			connections = Connections.new(),
			isInitialized = false,
			lastUpdateTime = nil,
			updateCount = 0,
		}
	end
	return leaderboardStates[leaderboardName]
end

--[[
	Returns the state for a leaderboard.
]]
function StateManager.getState(leaderboardName: string): any?
	return leaderboardStates[leaderboardName]
end

--[[
	Cleans up a specific leaderboard state.
]]
function StateManager.cleanup(leaderboardName: string)
	local state = leaderboardStates[leaderboardName]
	if not state then
		return
	end

	if state.handler and state.handler.cleanup then
		safeExecute(function()
			state.handler:cleanup()
		end)
	end

	state.connections:disconnect()

	leaderboardStates[leaderboardName] = nil
end

--[[
	Cleans up all leaderboard states.
]]
function StateManager.cleanupAll()
	for leaderboardName, _ in pairs(leaderboardStates) do
		StateManager.cleanup(leaderboardName)
	end
end

--[[
	Updates a leaderboard state with new update info.
]]
function StateManager.updateState(state: any)
	state.updateCount = state.updateCount + 1
	state.lastUpdateTime = os.time()
end

return StateManager