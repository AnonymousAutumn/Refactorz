--[[
	CacheStatistics - Gathers and reports cache statistics.

	Features:
	- Entry counting
	- Age tracking (oldest/newest)
	- Temporary cache statistics
]]

local CacheStatistics = {}

export type Statistics = {
	totalEntries: number,
	oldestEntry: number?,
	newestEntry: number?,
	temporaryEntries: number,
}

local function countTableEntries(tbl: { [any]: any }): number
	local count = 0
	for _ in pairs(tbl) do
		count += 1
	end

	return count
end

--[[
	Gathers statistics about the current cache state.
]]
function CacheStatistics.gather(playerCache: { [Player]: any }, temporaryCache: { [number]: any }): Statistics
	local totalEntries = 0
	local oldestEntry = nil
	local newestEntry = nil
	local currentTime = os.time()

	for _, cacheEntry in pairs(playerCache) do
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

return CacheStatistics