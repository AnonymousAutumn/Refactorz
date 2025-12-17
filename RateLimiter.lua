-----------------
-- Init Module --
-----------------

local RateLimiter = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local Connections = require(modulesFolder.Wrappers.Connections)
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)

---------------
-- Constants --
---------------

local DEFAULT_COOLDOWN_SECONDS = 1
local CLEANUP_INTERVAL_SECONDS = 300
local ENTRY_EXPIRY_SECONDS = 600
local VIOLATION_THRESHOLD = 10
local SUSPICIOUS_THRESHOLD = 50

---------------
-- Variables --
---------------

local connectionsMaid = Connections.new()

local rateLimitData = {}
local globalCooldowns = {}
local cleanupThread = nil

---------------
-- Functions --
---------------

local function getOrCreatePlayerData(userId)
	if not rateLimitData[userId] then
		rateLimitData[userId] = {}
	end
	return rateLimitData[userId]
end

local function getOrCreateEntry(playerData, actionName)
	if not playerData[actionName] then
		playerData[actionName] = {
			lastCallTime = 0,
			violationCount = 0,
		}
	end
	return playerData[actionName]
end

local function getCooldownDuration(actionName)
	return globalCooldowns[actionName] or DEFAULT_COOLDOWN_SECONDS
end

local function isEntryExpired(entry, currentTime)
	return (currentTime - entry.lastCallTime) > ENTRY_EXPIRY_SECONDS
end

local function cleanupPlayerData(userId, currentTime)
	local playerData = rateLimitData[userId]
	if not playerData then
		return
	end

	local entriesRemoved = 0
	for actionName, entry in playerData do
		if isEntryExpired(entry, currentTime) then
			playerData[actionName] = nil
			entriesRemoved += 1
		end
	end

	if next(playerData) == nil then
		rateLimitData[userId] = nil
	end
end

local function performCleanup()
	local currentTime = tick()
	local playersProcessed = 0
	local entriesRemoved = 0

	for userId in rateLimitData do
		cleanupPlayerData(userId, currentTime)
		playersProcessed += 1
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

local function onPlayerRemoving(player)
	local userId = player.UserId
	if rateLimitData[userId] then
		rateLimitData[userId] = nil
	end
end

function RateLimiter.checkRateLimit(player, actionName, cooldownSeconds)
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

	if entry.violationCount > 0 then
		entry.violationCount = 0
	end

	return true
end

function RateLimiter.setGlobalCooldown(actionName, cooldownSeconds)
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

function RateLimiter.getCooldown(actionName)
	return getCooldownDuration(actionName)
end

function RateLimiter.resetPlayerRateLimit(player, actionName)
	if not ValidationUtils.isValidPlayer(player) then
		warn(`[{script.Name}] Invalid player for rate limit reset`)
		return
	end

	local userId = player.UserId
	local playerData = rateLimitData[userId]

	if playerData and playerData[actionName] then
		playerData[actionName] = nil
	end
end

function RateLimiter.getPlayerViolations(player)
	if not ValidationUtils.isValidPlayer(player) then
		return {}
	end

	local userId = player.UserId
	local playerData = rateLimitData[userId]
	local violations = {}

	if playerData then
		for actionName, entry in playerData do
			if entry.violationCount > 0 then
				violations[actionName] = entry.violationCount
			end
		end
	end

	return violations
end

function RateLimiter.clearAllData()
	rateLimitData = {}
end

function RateLimiter.getTrackedPlayerCount()
	local count = 0
	for _ in rateLimitData do
		count += 1
	end
	return count
end

--------------------
-- Initialization --
--------------------

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

-------------------
-- Return Module --
-------------------

return RateLimiter