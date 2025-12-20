--[[
	CacheManager - Generic TTL cache with automatic cleanup and statistics.

	Features:
	- Time-to-live (TTL) based expiration
	- Automatic background cleanup (optional)
	- Hit/miss/eviction statistics
	- Thread-safe for single-threaded Luau environment

	Usage:
		local cache = CacheManager.new(3600, 600, true) -- 1hr TTL, 10min cleanup
		cache:set("key", value)
		local value = cache:get("key")
]]

local CacheManager = {}

local DEFAULT_MAX_AGE = 3600 -- 1 hour
local DEFAULT_CLEANUP_INTERVAL = 600 -- 10 minutes

export type CacheEntry = {
	data: any,
	timestamp: number,
	lastAccessed: number,
}

export type CacheStatistics = {
	hits: number,
	misses: number,
	evictions: number,
	size: number,
}

function CacheManager.new(maxAge: number?, cleanupInterval: number?, autoCleanup: boolean?)
	local cache: { [any]: CacheEntry } = {}
	local effectiveMaxAge = maxAge or DEFAULT_MAX_AGE
	local effectiveCleanupInterval = cleanupInterval or DEFAULT_CLEANUP_INTERVAL
	local cleanupThread: thread? = nil

	local statistics: CacheStatistics = {
		hits = 0,
		misses = 0,
		evictions = 0,
		size = 0,
	}

	local function isExpired(entry: CacheEntry): boolean
		return (os.time() - entry.timestamp) >= effectiveMaxAge
	end

	local self = {} 

	--[[
		Retrieves a value from the cache. Returns nil if not found or expired.
		Updates lastAccessed time on hit.
	]]
	function self:get(key: any): any?
		local entry = cache[key]
		if not entry then
			statistics.misses += 1
			return nil
		end

		if isExpired(entry) then
			cache[key] = nil
			statistics.size -= 1
			statistics.evictions += 1
			statistics.misses += 1
			return nil
		end

		entry.lastAccessed = os.time()
		statistics.hits += 1
		return entry.data
	end

	--[[
		Stores a value in the cache with current timestamp.
	]]
	function self:set(key: any, value: any)
		local isNew = cache[key] == nil
		local now = os.time()

		cache[key] = {
			data = value,
			timestamp = now,
			lastAccessed = now,
		}

		if isNew then
			statistics.size += 1
		end
	end

	--[[
		Returns true if key exists and is not expired.
	]]
	function self:has(key: any): boolean
		return self:get(key) ~= nil
	end

	--[[
		Removes a specific key from the cache.
		Returns true if the key was present.
	]]
	function self:invalidate(key: any): boolean
		if cache[key] then
			cache[key] = nil
			statistics.size -= 1
			return true
		end
		return false
	end

	--[[
		Removes all entries from the cache.
	]]
	function self:clear()
		table.clear(cache)
		statistics.size = 0
	end

	--[[
		Removes all expired entries from the cache.
		Returns the number of entries removed.
	]]
	function self:cleanup(): number
		local removed = 0
		local now = os.time()

		for key, entry in cache do
			if (now - entry.timestamp) >= effectiveMaxAge then
				cache[key] = nil
				removed += 1
			end
		end

		statistics.size -= removed
		statistics.evictions += removed
		return removed
	end

	--[[
		Returns a copy of the current cache statistics.
	]]
	function self:getStatistics(): CacheStatistics
		return {
			hits = statistics.hits,
			misses = statistics.misses,
			evictions = statistics.evictions,
			size = statistics.size,
		}
	end

	--[[
		Resets hit/miss/eviction counters (preserves size).
	]]
	function self:resetStatistics()
		statistics.hits = 0
		statistics.misses = 0
		statistics.evictions = 0
	end

	--[[
		Stops the automatic cleanup background thread.
	]]
	function self:stopAutoCleanup()
		if cleanupThread then
			task.cancel(cleanupThread)
			cleanupThread = nil
		end
	end

	--[[
		Returns the current number of entries in the cache.
	]]
	function self:getSize(): number
		return statistics.size
	end

	-- Start auto-cleanup thread if enabled (default: true)
	if autoCleanup ~= false then
		cleanupThread = task.spawn(function()
			while true do
				task.wait(effectiveCleanupInterval)
				self:cleanup()
			end
		end)
	end

	return self
end

return CacheManager