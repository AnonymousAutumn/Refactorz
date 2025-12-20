--[[
	DataCache - In-memory cache for player data with automatic cleanup.

	Features:
	- TTL-based cache entry expiration (15 minutes)
	- Periodic cleanup of stale entries (every 10 minutes)
	- Save delay handles for debounced persistence
	- Callback support for cache eviction events
]]

local DataCache = {}

local Players = game:GetService("Players")

local CACHE_CLEANUP_INTERVAL_SECONDS = 600
local CACHE_ENTRY_MAX_AGE_SECONDS = 900

type CacheMetadata = {
	lastAccessed: number,
	lastSaved: number,
}

type RemovalCallback = (playerUserId: string, cachedData: any) -> ()

local playerDataMemoryCache: { [string]: any } = {}
local cacheMetadata: { [string]: CacheMetadata } = {}
local pendingSaveFlags: { [string]: boolean } = {}
local saveDelayHandles: { [string]: thread } = {}

local cacheCleanupThread: thread? = nil
local isShuttingDown = false

local onCacheEntryRemoved: RemovalCallback? = nil

local function cancelThread(threadHandle: thread?)
	if threadHandle and coroutine.status(threadHandle) ~= "dead" then
		task.cancel(threadHandle)
	end
end

local function isCacheEntryStale(metadata: CacheMetadata, currentTime: number): boolean
	return (currentTime - metadata.lastAccessed) > CACHE_ENTRY_MAX_AGE_SECONDS
end

local function performCacheCleanup()
	if isShuttingDown then
		return
	end

	local currentTime = os.time()
	local removedCount = 0

	for playerUserId, metadata in pairs(cacheMetadata) do
		if isCacheEntryStale(metadata, currentTime) then
			local userId = tonumber(playerUserId)
			local player = if userId then Players:GetPlayerByUserId(userId) else nil

			if not player then
				DataCache.removeCacheEntry(playerUserId)
				removedCount += 1
			end
		end
	end
end

--[[
	Updates the access timestamp for a cache entry.
]]
function DataCache.updateMetadata(playerUserId: string)
	local currentTime = os.time()

	if not cacheMetadata[playerUserId] then
		cacheMetadata[playerUserId] = {
			lastAccessed = currentTime,
			lastSaved = currentTime,
		}
	else
		cacheMetadata[playerUserId].lastAccessed = currentTime
	end
end

--[[
	Updates the last saved timestamp for a cache entry.
]]
function DataCache.updateSaveTime(playerUserId: string)
	local metadata = cacheMetadata[playerUserId]
	if metadata then
		metadata.lastSaved = os.time()
	end
end

--[[
	Removes a player's cache entry and triggers the removal callback if set.
]]
function DataCache.removeCacheEntry(playerUserId: string)
	local cachedData = playerDataMemoryCache[playerUserId]

	if cachedData and onCacheEntryRemoved then
		onCacheEntryRemoved(playerUserId, cachedData)
	end

	playerDataMemoryCache[playerUserId] = nil
	cacheMetadata[playerUserId] = nil
	pendingSaveFlags[playerUserId] = nil

	local handle = saveDelayHandles[playerUserId]
	if handle then
		cancelThread(handle)
		saveDelayHandles[playerUserId] = nil
	end
end

function DataCache.startCleanupLoop()
	if cacheCleanupThread then
		return
	end

	cacheCleanupThread = task.spawn(function()
		while not isShuttingDown do
			task.wait(CACHE_CLEANUP_INTERVAL_SECONDS)
			performCacheCleanup()
		end
	end)
end

function DataCache.stopCleanupLoop()
	cancelThread(cacheCleanupThread)
	cacheCleanupThread = nil
end

--[[
	Returns cached data for a player, or nil if not cached.
]]
function DataCache.getCachedData(playerUserId: string): any?
	return playerDataMemoryCache[playerUserId]
end

--[[
	Stores data in the cache and updates metadata.
]]
function DataCache.setCachedData(playerUserId: string, data: any)
	playerDataMemoryCache[playerUserId] = data
	DataCache.updateMetadata(playerUserId)
end

--[[
	Returns the entire cache table (for iteration).
]]
function DataCache.getAllCachedData(): { [string]: any }
	return playerDataMemoryCache
end

--[[
	Returns whether a player has unsaved changes.
]]
function DataCache.getPendingSaveFlag(playerUserId: string): boolean
	return pendingSaveFlags[playerUserId] == true
end

--[[
	Sets the pending save flag for a player.
]]
function DataCache.setPendingSaveFlag(playerUserId: string, value: boolean)
	pendingSaveFlags[playerUserId] = value
end

--[[
	Returns the save delay thread handle for a player.
]]
function DataCache.getSaveDelayHandle(playerUserId: string): thread?
	return saveDelayHandles[playerUserId]
end

--[[
	Sets or clears the save delay thread handle for a player.
	Passing nil cancels any existing handle.
]]
function DataCache.setSaveDelayHandle(playerUserId: string, handle: thread?)
	if handle == nil then
		local existingHandle = saveDelayHandles[playerUserId]
		if existingHandle then
			cancelThread(existingHandle)
		end
		saveDelayHandles[playerUserId] = nil
	else
		saveDelayHandles[playerUserId] = handle
	end
end

--[[
	Sets the shutdown flag to stop background operations.
]]
function DataCache.setShutdown(shutdown: boolean)
	isShuttingDown = shutdown
end

--[[
	Sets a callback to be invoked when cache entries are removed.
]]
function DataCache.setRemovalCallback(callback: RemovalCallback?)
	onCacheEntryRemoved = callback
end

--[[
	Performs full cleanup: stops the cleanup loop and cancels all pending save handles.
]]
function DataCache.cleanup()
	isShuttingDown = true
	DataCache.stopCleanupLoop()

	for _, handle in pairs(saveDelayHandles) do
		cancelThread(handle)
	end
	table.clear(saveDelayHandles)
end

return DataCache