-----------------
-- Init Module --
-----------------

local DataCache = {}

--------------
-- Services --
--------------

local Players = game:GetService("Players")

---------------
-- Constants --
---------------

local CACHE_CLEANUP_INTERVAL_SECONDS = 600
local CACHE_ENTRY_MAX_AGE_SECONDS = 900

---------------
-- Variables --
---------------

local playerDataMemoryCache = {}
local cacheMetadata = {}
local pendingSaveFlags = {}
local saveDelayHandles = {}

local cacheCleanupThread = nil
local isShuttingDown = false

local onCacheEntryRemoved = nil

---------------
-- Functions --
---------------

local function cancelThread(threadHandle)
	if threadHandle and coroutine.status(threadHandle) ~= "dead" then
		task.cancel(threadHandle)
	end
end

local function isCacheEntryStale(metadata, currentTime)
	return (currentTime - metadata.lastAccessed) > CACHE_ENTRY_MAX_AGE_SECONDS
end

local function performCacheCleanup()
	if isShuttingDown then
		return
	end

	local currentTime = os.time()
	local removedCount = 0

	for playerUserId, metadata in cacheMetadata do
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

function DataCache.updateMetadata(playerUserId)
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

function DataCache.updateSaveTime(playerUserId)
	local metadata = cacheMetadata[playerUserId]
	if metadata then
		metadata.lastSaved = os.time()
	end
end

function DataCache.removeCacheEntry(playerUserId)
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

function DataCache.getCachedData(playerUserId)
	return playerDataMemoryCache[playerUserId]
end

function DataCache.setCachedData(playerUserId, data)
	playerDataMemoryCache[playerUserId] = data
	DataCache.updateMetadata(playerUserId)
end

function DataCache.getAllCachedData()
	return playerDataMemoryCache
end

function DataCache.getPendingSaveFlag(playerUserId)
	return pendingSaveFlags[playerUserId] == true
end

function DataCache.setPendingSaveFlag(playerUserId, value)
	pendingSaveFlags[playerUserId] = value
end

function DataCache.getSaveDelayHandle(playerUserId)
	return saveDelayHandles[playerUserId]
end

function DataCache.setSaveDelayHandle(playerUserId, handle)
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

function DataCache.setShutdown(shutdown)
	isShuttingDown = shutdown
end

function DataCache.setRemovalCallback(callback)
	onCacheEntryRemoved = callback
end

function DataCache.cleanup()
	isShuttingDown = true
	DataCache.stopCleanupLoop()

	for _, handle in saveDelayHandles do
		cancelThread(handle)
	end
	table.clear(saveDelayHandles)
end

-------------------
-- Return Module --
-------------------

return DataCache