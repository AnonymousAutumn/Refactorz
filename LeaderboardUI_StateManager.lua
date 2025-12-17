-----------------
-- Init Module --
-----------------

local StateManager = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local Connections = require(modulesFolder.Wrappers.Connections)

---------------
-- Variables --
---------------

local leaderboardStates = {}

---------------
-- Functions --
---------------

local function safeExecute(func)
	local success, errorMessage = pcall(func)
	if not success then
		warn("Error in StateManager.safeExecute:", errorMessage)
	end
	return success
end

function StateManager.initializeState(leaderboardName)
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

function StateManager.getState(leaderboardName)
	return leaderboardStates[leaderboardName]
end

function StateManager.cleanup(leaderboardName)
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

function StateManager.cleanupAll()
	for leaderboardName, _ in leaderboardStates do
		StateManager.cleanup(leaderboardName)
	end
end

function StateManager.updateState(state)
	state.updateCount = state.updateCount + 1
	state.lastUpdateTime = os.time()
end

-------------------
-- Return Module --
-------------------

return StateManager