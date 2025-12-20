--[[
	UsernameCache - Caches player usernames with API fallback and retry logic.

	Features:
	- TTL-based caching (1 hour expiration)
	- Automatic retry with linear backoff
	- Statistics tracking (hits, misses, API calls)
	- Timeout protection for API calls
]]

local UsernameCache = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local CacheManager = require(modulesFolder.Wrappers.Cache)

local DEFAULT_USERNAME = "Unknown"
local USERNAME_CACHE_EXPIRATION = 60 * 60 -- 1 hour
local USERNAME_CACHE_CLEANUP_INTERVAL = 60 * 10 -- 10 minutes
local MAX_USERNAME_RETRIES = 2
local USERNAME_FETCH_TIMEOUT = 5
local BASE_RETRY_DELAY = 1

export type UsernameCacheStatistics = {
	hits: number,
	misses: number,
	evictions: number,
	size: number,
	apiCalls: number,
	failures: number,
}

local usernameCacheMaid = CacheManager.new(
	USERNAME_CACHE_EXPIRATION,
	USERNAME_CACHE_CLEANUP_INTERVAL,
	true
)

local apiCalls = 0
local apiFailures = 0

local function calculateRetryDelay(attemptNumber: number): number
	return BASE_RETRY_DELAY * attemptNumber
end

local function hasExceededTimeout(startTime: number, timeoutSeconds: number): boolean
	return os.clock() - startTime > timeoutSeconds
end

local function fetchUsernameFromAPI(targetUserId: number): (boolean, string?)
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

--[[
	Returns the username for a user ID, using cache or API.
	Returns "Unknown" if the username cannot be fetched.
]]
function UsernameCache.getUsername(targetUserId: number): string
	if not ValidationUtils.isValidUserId(targetUserId) then
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

--[[
	Alias for getUsername (kept for backwards compatibility).
]]
function UsernameCache.getUsernameAsync(targetUserId: number): string
	return UsernameCache.getUsername(targetUserId)
end

--[[
	Manually sets a cached username (useful for pre-caching online players).
]]
function UsernameCache.setCachedUsername(userId: number, username: string)
	if not ValidationUtils.isValidUserId(userId) or not ValidationUtils.isValidString(username) then
		warn(`[{script.Name}] Invalid userId or username provided to setCachedUsername`)
		return
	end

	usernameCacheMaid:set(userId, username)
end

--[[
	Removes a specific user ID from the cache.
]]
function UsernameCache.invalidateCache(userId: number)
	usernameCacheMaid:invalidate(userId)
end

--[[
	Clears all cached usernames.
]]
function UsernameCache.clearCache()
	usernameCacheMaid:clear()
end

--[[
	Manually triggers cache cleanup of expired entries.
	Returns the number of entries removed.
]]
function UsernameCache.cleanup(): number
	return usernameCacheMaid:cleanup()
end

--[[
	Returns cache and API statistics.
]]
function UsernameCache.getStatistics(): UsernameCacheStatistics
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

--[[
	Resets all statistics counters.
]]
function UsernameCache.resetStatistics()
	usernameCacheMaid:resetStatistics()
	apiCalls = 0
	apiFailures = 0
end

--[[
	Configuration placeholder (not yet implemented).
]]
function UsernameCache.configure(_settings: any)
	warn(`[{script.Name}] Note: configure() is not yet implemented. Using defaults.`)
end

--[[
	Stops the automatic cleanup thread.
]]
function UsernameCache.shutdown()
	usernameCacheMaid:stopAutoCleanup()
end

return UsernameCache