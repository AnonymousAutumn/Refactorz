-----------------
-- Module Init --
-----------------

local CacheManager = {}

---------------
-- Constants --
---------------

local DEFAULT_MAX_AGE = 3600
local DEFAULT_CLEANUP_INTERVAL = 600

---------------
-- Functions --
---------------

function CacheManager.new(maxAge, cleanupInterval, autoCleanup)
	local cache = {}
	local effectiveMaxAge = maxAge or DEFAULT_MAX_AGE
	local effectiveCleanupInterval = cleanupInterval or DEFAULT_CLEANUP_INTERVAL
	local cleanupThread = nil

	local statistics = {
		hits = 0,
		misses = 0,
		evictions = 0,
		size = 0,
	}

	local function isExpired(entry)
		return (os.time() - entry.timestamp) >= effectiveMaxAge
	end

	local self = {} 

	function self:get(key)
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

	function self:set(key, value)
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

	function self:has(key)
		return self:get(key) ~= nil
	end

	function self:invalidate(key)
		if cache[key] then
			cache[key] = nil
			statistics.size -= 1
			return true
		end
		return false
	end

	function self:clear()
		table.clear(cache)
		statistics.size = 0
	end

	function self:cleanup()
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

	function self:getStatistics()
		return {
			hits = statistics.hits,
			misses = statistics.misses,
			evictions = statistics.evictions,
			size = statistics.size,
		}
	end

	function self:resetStatistics()
		statistics.hits = 0
		statistics.misses = 0
		statistics.evictions = 0
	end

	function self:stopAutoCleanup()
		if cleanupThread and coroutine.status(cleanupThread) ~= "dead" then
			task.cancel(cleanupThread)
			cleanupThread = nil
		end
	end

	function self:getSize()
		return statistics.size
	end

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

-------------------
-- Return Module --
-------------------

return CacheManager