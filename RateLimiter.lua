--[[
	RateLimiter - Per-player, per-action rate limiting with violation tracking.

	Features:
	- Configurable cooldowns per action
	- Automatic cleanup of stale entries
	- Violation counting with threshold warnings
	- Global cooldown configuration
]]

local RateLimiter = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local modulesFolder = ReplicatedStorage.Modules
local Connections = require(modulesFolder.Wrappers.Connections)
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)

local DEFAULT_COOLDOWN_SECONDS = 1
local CLEANUP_INTERVAL_SECONDS = 300 -- 5 minutes
local ENTRY_EXPIRY_SECONDS = 600 -- 10 minutes
local VIOLATION_THRESHOLD = 10
local SUSPICIOUS_THRESHOLD = 50

export type RateLimitEntry = {
	lastCallTime: number,
	violationCount: number,
}

local connectionsMaid = Connections.new()
local rateLimitData: { [number]: { [string]: RateLimitEntry } } = {}
local globalCooldowns: { [string]: number } = {}
local cleanupThread: thread? = nil

local function getOrCreatePlayerData(userId: number): { [string]: RateLimitEntry }
	if not rateLimitData[userId] then
		rateLimitData[userId] = {}
	end
	return rateLimitData[userId]
end

local function getOrCreateEntry(playerData: { [string]: RateLimitEntry }, actionName: string): RateLimitEntry
	if not playerData[actionName] then
		playerData[actionName] = {
			lastCallTime = 0,
			violationCount = 0,
		}
	end
	return playerData[actionName]
end

local function getCooldownDuration(actionName: string): number
	return globalCooldowns[actionName] or DEFAULT_COOLDOWN_SECONDS
end

local function isEntryExpired(entry: RateLimitEntry, currentTime: number): boolean
	return (currentTime - entry.lastCallTime) > ENTRY_EXPIRY_SECONDS
end

local function cleanupPlayerData(userId: number, currentTime: number)
	local playerData = rateLimitData[userId]
	if not playerData then
		return
	end

	for actionName, entry in playerData do
		if isEntryExpired(entry, currentTime) then
			playerData[actionName] = nil
		end
	end

	if next(playerData) == nil then
		rateLimitData[userId] = nil
	end
end

local function performCleanup()
	local currentTime = tick()

	for userId in rateLimitData do
		cleanupPlayerData(userId, currentTime)
	end
end

local function startCleanupLoop()
	if cleanupThread then
		return
	end

	cleanupThread = task.spawn(function()
		while true do
			task.wait(CLEANUP_INTERVAL_SECONDS)
			performCleanup()
		end
	end)
end

local function stopCleanupLoop()
	if cleanupThread then
		task.cancel(cleanupThread)
		cleanupThread = nil
	end
end

local function onPlayerRemoving(player: Player)
	rateLimitData[player.UserId] = nil
end

--[[
	Checks if an action is allowed for a player based on cooldown.
	Returns true if allowed, false if rate limited.
	Tracks violations and warns at thresholds.
]]
function RateLimiter.checkRateLimit(player: Player, actionName: string, cooldownSeconds: number?): boolean
	if not ValidationUtils.isValidPlayer(player) then
		warn(`[{script.Name}] Invalid player for rate limit check`)
		return false
	end

	if not ValidationUtils.isValidString(actionName) then
		warn(`[{script.Name}] Invalid action name for rate limit check`)
		return false
	end

	local userId = player.UserId
	local currentTime = tick()
	local cooldown = cooldownSeconds or getCooldownDuration(actionName)

	local playerData = getOrCreatePlayerData(userId)
	local entry = getOrCreateEntry(playerData, actionName)

	local timeSinceLastCall = currentTime - entry.lastCallTime

	if timeSinceLastCall < cooldown then
		entry.violationCount += 1

		if entry.violationCount == VIOLATION_THRESHOLD then
			warn(`[{script.Name}] Player {player.Name} ({userId}) has {entry.violationCount} rate limit violations for action '{actionName}'`)
		elseif entry.violationCount >= SUSPICIOUS_THRESHOLD then
			warn(`[{script.Name}] SUSPICIOUS: Player {player.Name} ({userId}) has {entry.violationCount} rate limit violations for action '{actionName}' (possible exploit)`)
		end

		return false
	end

	entry.lastCallTime = currentTime
	entry.violationCount = 0

	return true
end

--[[
	Sets a global cooldown duration for an action.
]]
function RateLimiter.setGlobalCooldown(actionName: string, cooldownSeconds: number)
	if not ValidationUtils.isValidString(actionName) then
		warn(`[{script.Name}] Invalid action name for global cooldown`)
		return
	end

	if not ValidationUtils.isValidNumber(cooldownSeconds) or cooldownSeconds < 0 then
		warn(`[{script.Name}] Invalid cooldown duration: {tostring(cooldownSeconds)}`)
		return
	end

	globalCooldowns[actionName] = cooldownSeconds
end

--[[
	Returns the cooldown duration for an action.
]]
function RateLimiter.getCooldown(actionName: string): number
	return getCooldownDuration(actionName)
end

--[[
	Resets a specific action's rate limit for a player.
]]
function RateLimiter.resetPlayerRateLimit(player: Player, actionName: string)
	if not ValidationUtils.isValidPlayer(player) then
		warn(`[{script.Name}] Invalid player for rate limit reset`)
		return
	end

	local userId = player.UserId
	local playerData = rateLimitData[userId]

	if playerData then
		playerData[actionName] = nil
	end
end

--[[
	Returns a table of action names to violation counts for a player.
]]
function RateLimiter.getPlayerViolations(player: Player): { [string]: number }
	if not ValidationUtils.isValidPlayer(player) then
		return {}
	end

	local userId = player.UserId
	local playerData = rateLimitData[userId]
	local violations: { [string]: number } = {}

	if playerData then
		for actionName, entry in playerData do
			if entry.violationCount > 0 then
				violations[actionName] = entry.violationCount
			end
		end
	end

	return violations
end

--[[
	Clears all rate limit data (useful for testing).
]]
function RateLimiter.clearAllData()
	table.clear(rateLimitData)
end

--[[
	Returns the number of players currently being tracked.
]]
function RateLimiter.getTrackedPlayerCount(): number
	local count = 0
	for _ in rateLimitData do
		count += 1
	end
	return count
end

-- Initialization
local function initialize()
	connectionsMaid:add(Players.PlayerRemoving:Connect(onPlayerRemoving))
	startCleanupLoop()
end

local function bindToClose()
	stopCleanupLoop()
	connectionsMaid:disconnect()
end

initialize()
game:BindToClose(bindToClose)

return RateLimiter