--[[
	CacheLifecycle - Manages cache cleanup and lifecycle.

	Features:
	- Automatic stale entry removal
	- Configurable cleanup intervals
	- Graceful shutdown handling
]]

local CacheLifecycle = {}

export type LifecycleConfig = {
	checkStaleFunc: (cacheEntry: any, currentTime: number, maxAge: number) -> boolean,
	isValidPlayerFunc: (player: Player) -> boolean,
}

export type CleanupConfig = {
	enabled: boolean,
	intervalSeconds: number,
	maxAgeSeconds: number,
}

local state: {
	cleanupThread: thread?,
	isShuttingDown: boolean,
	checkStaleFunc: ((any, number, number) -> boolean)?,
	isValidPlayerFunc: ((Player) -> boolean)?,
}? = nil

--[[
	Initializes the lifecycle manager with configuration.
]]
function CacheLifecycle.initialize(config: LifecycleConfig)
	state = {
		cleanupThread = nil,
		isShuttingDown = false,
		checkStaleFunc = config.checkStaleFunc,
		isValidPlayerFunc = config.isValidPlayerFunc,
	}
end

--[[
	Cancels any active cleanup thread.
]]
function CacheLifecycle.cancelCleanupThread()
	if state and state.cleanupThread then
		task.cancel(state.cleanupThread)
		state.cleanupThread = nil
	end
end

--[[
	Removes stale player entries from the cache.
	Returns the number of entries removed.
]]
function CacheLifecycle.removeStalePlayerEntries(playerCache: { [Player]: any }, currentTime: number, maxAge: number): number
	local playersToRemove: { Player } = {}

	for player, cacheEntry in pairs(playerCache) do
		if state.checkStaleFunc(cacheEntry, currentTime, maxAge) or not state.isValidPlayerFunc(player) then
			table.insert(playersToRemove, player)
		end
	end

	for _, player in pairs(playersToRemove) do
		playerCache[player] = nil
	end

	return #playersToRemove
end

--[[
	Removes stale temporary entries from the cache.
	Returns the number of entries removed.
]]
function CacheLifecycle.removeStaleTempEntries(temporaryCache: { [number]: any }, currentTime: number, maxAge: number): number
	local userIdsToRemove: { number } = {}

	for userId, cacheEntry in pairs(temporaryCache) do
		if state.checkStaleFunc(cacheEntry, currentTime, maxAge) then
			table.insert(userIdsToRemove, userId)
		end
	end

	for _, userId in pairs(userIdsToRemove) do
		temporaryCache[userId] = nil
	end

	return #userIdsToRemove
end

--[[
	Performs a cleanup pass on both caches.
]]
function CacheLifecycle.performCleanup(playerCache: { [Player]: any }, temporaryCache: { [number]: any }, maxAge: number)
	if state.isShuttingDown then
		return
	end

	local currentTime = os.time()

	CacheLifecycle.removeStalePlayerEntries(playerCache, currentTime, maxAge)
	CacheLifecycle.removeStaleTempEntries(temporaryCache, currentTime, maxAge)
end

--[[
	Starts the background cleanup loop.
]]
function CacheLifecycle.startCleanupLoop(playerCache: { [Player]: any }, temporaryCache: { [number]: any }, config: CleanupConfig)
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

--[[
	Stops the background cleanup loop.
]]
function CacheLifecycle.stopCleanupLoop()
	CacheLifecycle.cancelCleanupThread()
end

--[[
	Sets the shutdown flag to stop cleanup operations.
]]
function CacheLifecycle.setShuttingDown(value: boolean)
	if state then
		state.isShuttingDown = value
	end
end

return CacheLifecycle