-----------------
-- Init Module --
-----------------

local UsernameCache = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local validationUtils = require(modulesFolder.Utilities.ValidationUtils)
local CacheManager = require(modulesFolder.Wrappers.Cache)

---------------
-- Constants --
---------------

local DEFAULT_USERNAME = "Unknown"
local USERNAME_CACHE_EXPIRATION = 60 * 60
local USERNAME_CACHE_CLEANUP_INTERVAL = 60 * 10
local MAX_USERNAME_RETRIES = 2
local USERNAME_FETCH_TIMEOUT = 5
local BASE_RETRY_DELAY = 1

---------------
-- Variables --
---------------

local usernameCacheMaid = CacheManager.new(
	USERNAME_CACHE_EXPIRATION,
	USERNAME_CACHE_CLEANUP_INTERVAL,
	true
)

local apiCalls = 0
local apiFailures = 0

---------------
-- Functions --
---------------

local function calculateRetryDelay(attemptNumber)
	return BASE_RETRY_DELAY * attemptNumber
end

local function hasExceededTimeout(startTime, timeoutSeconds)
	return os.clock() - startTime > timeoutSeconds
end

local function fetchUsernameFromAPI(targetUserId)
	for attemptNumber = 1, MAX_USERNAME_RETRIES do
		apiCalls += 1
		local requestStartTime = os.clock()

		local success, result = pcall(function()
			local username = Players:GetNameFromUserIdAsync(targetUserId)
			if hasExceededTimeout(requestStartTime, USERNAME_FETCH_TIMEOUT) then
				error("Username fetch timeout")
			end
			return username
		end)

		if success and typeof(result) == "string" and #result > 0 then
			return true, result
		end

		if attemptNumber < MAX_USERNAME_RETRIES then
			task.wait(calculateRetryDelay(attemptNumber))
		end
	end

	apiFailures += 1
	return false, nil
end

function UsernameCache.getUsername(targetUserId)

	if not validationUtils.isValidUserId(targetUserId) then
		warn(`[{script.Name}] Invalid user ID provided: {tostring(targetUserId)}`)
		return DEFAULT_USERNAME
	end

	local cachedName = usernameCacheMaid:get(targetUserId)
	if cachedName then
		return cachedName
	end

	local success, username = fetchUsernameFromAPI(targetUserId)
	if success and username then
		usernameCacheMaid:set(targetUserId, username)
		
		return username
	end

	return DEFAULT_USERNAME
end

function UsernameCache.getUsernameAsync(targetUserId)
	return UsernameCache.getUsername(targetUserId)
end

function UsernameCache.setCachedUsername(userId, username)
	if not validationUtils.isValidUserId(userId) or not validationUtils.isValidString(username) then
		warn(`[{script.Name}] Invalid userId or username provided to setCachedUsername`)
		return
	end

	usernameCacheMaid:set(userId, username)
end

function UsernameCache.invalidateCache(userId)
	usernameCacheMaid:invalidate(userId)
end

function UsernameCache.clearCache()
	usernameCacheMaid:clear()
end

function UsernameCache.cleanup()
	return usernameCacheMaid:cleanup()
end

function UsernameCache.getStatistics()
	local baseStats = usernameCacheMaid:getStatistics()

	return {
		hits = baseStats.hits,
		misses = baseStats.misses,
		evictions = baseStats.evictions,
		size = baseStats.size,
		apiCalls = apiCalls,
		failures = apiFailures,
	}
end

function UsernameCache.resetStatistics()
	usernameCacheMaid:resetStatistics()
	apiCalls = 0
	apiFailures = 0
end

function UsernameCache.configure(settings)
	warn(`[{script.Name}] Note: configure() is not yet implemented. Using defaults.`)
end

function UsernameCache.shutdown()
	usernameCacheMaid:stopAutoCleanup()
end

-------------------
-- Return Module --
-------------------

return UsernameCache