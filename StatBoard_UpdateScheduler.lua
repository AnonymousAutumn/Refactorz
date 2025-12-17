-----------------
-- Init Module --
-----------------

local UpdateScheduler = {}
UpdateScheduler.refreshLeaderboardDataAsync = nil
UpdateScheduler.trackThread = nil
UpdateScheduler.isShuttingDown = false

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)

---------------
-- Constants --
---------------

local INITIAL_UPDATE_DELAY = 5
local FAILURE_BACKOFF_MULTIPLIER = 2
local MAX_BACKOFF_MULTIPLIER = 8
local MAX_CONSECUTIVE_FAILURES = 5

local CLIENT_READY_MESSAGE = "Ready"

---------------
-- Functions --
---------------

function UpdateScheduler.updateLeaderboardState(leaderboardState, success)
	if success then
		leaderboardState.consecutiveFailures = 0
		leaderboardState.lastUpdateTime = os.time()
		leaderboardState.lastUpdateSuccess = true
	else
		leaderboardState.consecutiveFailures = leaderboardState.consecutiveFailures + 1
		leaderboardState.lastUpdateSuccess = false
	end
end

function UpdateScheduler.calculateBackoffMultiplier(consecutiveFailures)
	return math.min(FAILURE_BACKOFF_MULTIPLIER ^ consecutiveFailures, MAX_BACKOFF_MULTIPLIER)
end

function UpdateScheduler.calculateUpdateInterval(leaderboardState)
	local baseInterval = leaderboardState.systemConfig.LEADERBOARD_CONFIG.UPDATE_INTERVAL
	if leaderboardState.consecutiveFailures > 0 then
		local backoffMultiplier = UpdateScheduler.calculateBackoffMultiplier(leaderboardState.consecutiveFailures)
		return baseInterval * backoffMultiplier
	end
	return baseInterval
end

function UpdateScheduler.logBackoffWarning(leaderboardState, updateInterval)
	if leaderboardState.consecutiveFailures > 0 then
		warn(`[{script.Name}] {leaderboardState.config.statisticName} failed {leaderboardState.consecutiveFailures} times in a row; next update in {updateInterval}s`)
	end
end

function UpdateScheduler.setupLeaderboardUpdateLoop(leaderboardState)
	if not UpdateScheduler.refreshLeaderboardDataAsync or not UpdateScheduler.trackThread then
		warn(`[{script.Name}] Dependencies not set`)
		return
	end

	local updateThread = task.spawn(function()
		task.wait(INITIAL_UPDATE_DELAY)
		
		while not UpdateScheduler.isShuttingDown do
			UpdateScheduler.refreshLeaderboardDataAsync(leaderboardState)
			
			local updateInterval = UpdateScheduler.calculateUpdateInterval(leaderboardState)
			UpdateScheduler.logBackoffWarning(leaderboardState, updateInterval)
			
			task.wait(updateInterval)
		end
	end)

	leaderboardState.updateThread = updateThread
	UpdateScheduler.trackThread(updateThread)
end

function UpdateScheduler.isValidClientReadyMessage(message)
	return type(message) == "string" and message == CLIENT_READY_MESSAGE
end

function UpdateScheduler.handleClientReadyEvent(requestingPlayer, clientMessage, leaderboardState)
	if UpdateScheduler.isShuttingDown then
		return
	end
	if not ValidationUtils.isValidPlayer(requestingPlayer) then
		return
	end
	if not UpdateScheduler.isValidClientReadyMessage(clientMessage) then
		return
	end

	if not UpdateScheduler.refreshLeaderboardDataAsync then
		return
	end

	task.spawn(function()
		UpdateScheduler.refreshLeaderboardDataAsync(leaderboardState)
	end)
end

-------------------
-- Return Module --
-------------------

return UpdateScheduler