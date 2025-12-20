--[[
	CacheOperations - Provides cache entry creation and utility operations.

	Features:
	- Empty cache entry creation
	- Cache entry copying
	- Staleness checking
	- Access time tracking
]]

local CacheOperations = {}

export type CacheMetadata = {
	loadedAt: number,
	lastAccessed: number,
	userId: number,
}

export type CacheEntry = {
	gamepasses: { any },
	games: { any },
	metadata: CacheMetadata,
}

--[[
	Creates an empty cache entry for a user.
]]
function CacheOperations.createEmpty(userId: number?): CacheEntry
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

--[[
	Creates a shallow copy of a cache entry.
]]
function CacheOperations.createCopy(cacheEntry: CacheEntry): CacheEntry
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

--[[
	Updates the last accessed time on a cache entry.
]]
function CacheOperations.updateAccessTime(cacheEntry: CacheEntry?)
	if cacheEntry and cacheEntry.metadata then
		cacheEntry.metadata.lastAccessed = os.time()
	end
end

--[[
	Checks if a cache entry is stale based on max age.
]]
function CacheOperations.isStale(cacheEntry: CacheEntry, currentTime: number, maxAge: number): boolean
	local age = currentTime - cacheEntry.metadata.loadedAt
	return age > maxAge
end

--[[
	Counts the number of entries in a table.
]]
function CacheOperations.countEntries(tbl: { [any]: any }): number
	local count = 0
	for _ in pairs(tbl) do
		count += 1
	end

	return count
end

return CacheOperations