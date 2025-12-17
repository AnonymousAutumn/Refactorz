-----------------
-- Init Module --
-----------------

local CacheLifecycle = {}

---------------
-- Variables --
---------------

local state = nil

---------------
-- Functions --
---------------

function CacheLifecycle.initialize(config)
	state = {
		cleanupThread = nil,
		isShuttingDown = false,
		checkStaleFunc = config.checkStaleFunc,
		isValidPlayerFunc = config.isValidPlayerFunc,
	}
end

function CacheLifecycle.cancelCleanupThread()
	if state.cleanupThread then
		task.cancel(state.cleanupThread)
		state.cleanupThread = nil
	end
end

function CacheLifecycle.removeStalePlayerEntries(playerCache, currentTime, maxAge)
	local playersToRemove = {}

	for player, cacheEntry in playerCache do
		if state.checkStaleFunc(cacheEntry, currentTime, maxAge) or not state.isValidPlayerFunc(player) then
			table.insert(playersToRemove, player)
		end
	end

	for _, player in playersToRemove do
		playerCache[player] = nil
	end

	return #playersToRemove
end

function CacheLifecycle.removeStaleTempEntries(temporaryCache, currentTime, maxAge)
	local userIdsToRemove = {}

	for userId, cacheEntry in temporaryCache do
		if state.checkStaleFunc(cacheEntry, currentTime, maxAge) then
			table.insert(userIdsToRemove, userId)
		end
	end

	for _, userId in userIdsToRemove do
		temporaryCache[userId] = nil
	end

	return #userIdsToRemove
end

function CacheLifecycle.performCleanup(playerCache, temporaryCache, maxAge)
	if state.isShuttingDown then
		return
	end

	local currentTime = os.time()

	CacheLifecycle.removeStalePlayerEntries(playerCache, currentTime, maxAge)
	CacheLifecycle.removeStaleTempEntries(temporaryCache, currentTime, maxAge)
end

function CacheLifecycle.startCleanupLoop(playerCache, temporaryCache, config)
	if not config.enabled or state.cleanupThread then
		return
	end

	state.cleanupThread = task.spawn(function()
		while not state.isShuttingDown do
			task.wait(config.intervalSeconds)
			CacheLifecycle.performCleanup(playerCache, temporaryCache, config.maxAgeSeconds)
		end
	end)
end

function CacheLifecycle.stopCleanupLoop()
	CacheLifecycle.cancelCleanupThread()
end

function CacheLifecycle.setShuttingDown(value)
	state.isShuttingDown = value
end

-------------------
-- Return Module --
-------------------

return CacheLifecycle