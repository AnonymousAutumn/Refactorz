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

---------------
-- Constants --
---------------

local DEFAULT_USERNAME = "Unknown"
local MAX_USERNAME_RETRIES = 2
local USERNAME_FETCH_TIMEOUT = 5
local BASE_RETRY_DELAY = 1

---------------
-- Variables --
---------------

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

--[[
	Fetches a username directly from the Roblox API.
	This method always makes a fresh API call for safety and accuracy.

	@param targetUserId number - The user ID to fetch the username for
	@return string - The username, or "Unknown" if the fetch fails
]]
function UsernameCache.getUsername(targetUserId)
	if not validationUtils.isValidUserId(targetUserId) then
		warn(`[{script.Name}] Invalid user ID provided: {tostring(targetUserId)}`)
		return DEFAULT_USERNAME
	end

	local success, username = fetchUsernameFromAPI(targetUserId)
	if success and username then
		return username
	end

	return DEFAULT_USERNAME
end

--[[
	Alias for getUsername. Fetches username directly from API.
	Note: Despite the name, this performs a synchronous API call.

	@param targetUserId number - The user ID to fetch the username for
	@return string - The username, or "Unknown" if the fetch fails
]]
function UsernameCache.getUsernameAsync(targetUserId)
	return UsernameCache.getUsername(targetUserId)
end

--[[
	@deprecated Caching has been removed. This method is a no-op.
	Kept for backwards compatibility with existing code.
]]
function UsernameCache.setCachedUsername(userId, username)
	-- No-op: caching has been removed in favor of direct API fetching
end

--[[
	@deprecated Caching has been removed. This method is a no-op.
	Kept for backwards compatibility with existing code.
]]
function UsernameCache.invalidateCache(userId)
	-- No-op: caching has been removed in favor of direct API fetching
end

--[[
	@deprecated Caching has been removed. This method is a no-op.
	Kept for backwards compatibility with existing code.
]]
function UsernameCache.clearCache()
	-- No-op: caching has been removed in favor of direct API fetching
end

--[[
	@deprecated Caching has been removed. This method is a no-op.
	Kept for backwards compatibility with existing code.
]]
function UsernameCache.cleanup()
	-- No-op: caching has been removed in favor of direct API fetching
	return 0
end

--[[
	Returns statistics about API usage.
	Note: Cache-related statistics (hits, misses, evictions, size) are no longer tracked.

	@return table - Statistics containing apiCalls and failures counts
]]
function UsernameCache.getStatistics()
	return {
		hits = 0, -- Deprecated: always 0 as caching is removed
		misses = 0, -- Deprecated: always 0 as caching is removed
		evictions = 0, -- Deprecated: always 0 as caching is removed
		size = 0, -- Deprecated: always 0 as caching is removed
		apiCalls = apiCalls,
		failures = apiFailures,
	}
end

--[[
	Resets the API call statistics counters.
]]
function UsernameCache.resetStatistics()
	apiCalls = 0
	apiFailures = 0
end

--[[
	@deprecated Caching has been removed. This method is a no-op.
	Kept for backwards compatibility with existing code.
]]
function UsernameCache.configure(settings)
	-- No-op: caching has been removed in favor of direct API fetching
end

--[[
	@deprecated Caching has been removed. This method is a no-op.
	Kept for backwards compatibility with existing code.
]]
function UsernameCache.shutdown()
	-- No-op: caching has been removed in favor of direct API fetching
end

-------------------
-- Return Module --
-------------------

return UsernameCache
