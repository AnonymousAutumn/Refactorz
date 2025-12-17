-----------------
-- Init Module --
-----------------

local CacheStatistics = {}

---------------
-- Functions --
---------------

local function countTableEntries(tbl)
	local count = 0
	for _ in tbl do
		count += 1
	end
	
	return count
end

function CacheStatistics.gather(playerCache, temporaryCache)
	local totalEntries = 0
	local oldestEntry = nil
	local newestEntry = nil
	local currentTime = os.time()

	for _, cacheEntry in playerCache do
		totalEntries += 1

		local age = currentTime - cacheEntry.metadata.loadedAt

		if not oldestEntry or age > oldestEntry then
			oldestEntry = age
		end

		if not newestEntry or age < newestEntry then
			newestEntry = age
		end
	end

	local temporaryEntries = countTableEntries(temporaryCache)

	return {
		totalEntries = totalEntries,
		oldestEntry = oldestEntry,
		newestEntry = newestEntry,
		temporaryEntries = temporaryEntries,
	}
end

-------------------
-- Return Module --
-------------------

return CacheStatistics