-----------------
-- Init Module --
-----------------

local CacheOperations = {}

---------------
-- Functions --
---------------

function CacheOperations.createEmpty(userId)
	local currentTime = os.time()
	
	return {
		gamepasses = {},
		games = {},
		
		metadata = {
			loadedAt = currentTime,
			lastAccessed = currentTime,
			userId = userId or 0,
		},
	}
end

function CacheOperations.createCopy(cacheEntry)
	return {
		gamepasses = table.clone(cacheEntry.gamepasses),
		games = table.clone(cacheEntry.games),
		
		metadata = {
			loadedAt = cacheEntry.metadata.loadedAt,
			lastAccessed = cacheEntry.metadata.lastAccessed,
			userId = cacheEntry.metadata.userId,
		},
	}
end

function CacheOperations.updateAccessTime(cacheEntry)
	if cacheEntry and cacheEntry.metadata then
		cacheEntry.metadata.lastAccessed = os.time()
	end
end

function CacheOperations.isStale(cacheEntry, currentTime, maxAge)
	local age = currentTime - cacheEntry.metadata.loadedAt
	return age > maxAge
end

function CacheOperations.countEntries(tbl)
	local count = 0
	for _ in tbl do
		count += 1
	end
	
	return count
end

-------------------
-- Return Module --
-------------------

return CacheOperations