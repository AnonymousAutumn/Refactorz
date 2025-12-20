--[[
	UpdateScheduler - Schedules leaderboard data refresh cycles.

	Features:
	- Periodic update scheduling
	- Exponential backoff on failures
	- Client ready event handling
]]

local UpdateScheduler = {}
UpdateScheduler.refreshLeaderboardDataAsync = nil
UpdateScheduler.trackThread = nil
UpdateScheduler.isShuttingDown = false

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)

local INITIAL_UPDATE_DELAY = 5
local FAILURE_BACKOFF_MULTIPLIER = 2
local MAX_BACKOFF_MULTIPLIER = 8
local MAX_CONSECUTIVE_FAILURES = 5

local CLIENT_READY_MESSAGE = "Ready"

--[[
	Updates leaderboard state after refresh attempt.
]]
function UpdateScheduler.updateLeaderboardState(leaderboardState: any, success: boolean)
	if success then
		leaderboardState.consecutiveFailures = 0
		leaderboardState.lastUpdateTime = os.time()
		leaderboardState.lastUpdateSuccess = true
	else
		leaderboardState.consecutiveFailures = leaderboardState.consecutiveFailures + 1
		leaderboardState.lastUpdateSuccess = false
	end
end

--[[
	Calculates exponential backoff multiplier based on failures.
]]
function UpdateScheduler.calculateBackoffMultiplier(consecutiveFailures: number): number
	return math.min(FAILURE_BACKOFF_MULTIPLIER ^ consecutiveFailures, MAX_BACKOFF_MULTIPLIER)
end

--[[
	Calculates next update interval with backoff.
]]
function UpdateScheduler.calculateUpdateInterval(leaderboardState: any): number
	local baseInterval = leaderboardState.systemConfig.LEADERBOARD_CONFIG.UPDATE_INTERVAL
	if leaderboardState.consecutiveFailures > 0 then
		local backoffMultiplier = UpdateScheduler.calculateBackoffMultiplier(leaderboardState.consecutiveFailures)
		return baseInterval * backoffMultiplier
	end
	return baseInterval
end

--[[
	Logs warning when in backoff state.
]]
function UpdateScheduler.logBackoffWarning(leaderboardState: any, updateInterval: number)
	if leaderboardState.consecutiveFailures > 0 then
		warn(`[{script.Name}] {leaderboardState.config.statisticName} failed {leaderboardState.consecutiveFailures} times in a row; next update in {updateInterval}s`)
	end
end

--[[
	Sets up periodic update loop for a leaderboard.
]]
function UpdateScheduler.setupLeaderboardUpdateLoop(leaderboardState: any)
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

--[[
	Validates client ready message format.
]]
function UpdateScheduler.isValidClientReadyMessage(message: any): boolean
	return type(message) == "string" and message == CLIENT_READY_MESSAGE
end

--[[
	Handles client ready events to trigger immediate refresh.
]]
function UpdateScheduler.handleClientReadyEvent(requestingPlayer: Player, clientMessage: any, leaderboardState: any)
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

return UpdateScheduler