--[[
	DataCrawler - Fetches player data with retry logic.

	Features:
	- Safe data fetching with retries
	- Dependency injection for testability
	- Cache clear waiting with timeout
]]

local DataCrawler = {}

export type Dependencies = {
	passesLoader: any,
	createEmptyEntry: (userId: number) -> any,
}

local deps: Dependencies? = nil

--[[
	Initializes the data crawler with dependencies.
]]
function DataCrawler.initialize(dependencies: Dependencies)
	deps = dependencies
end

--[[
	Fetches player data safely with retry logic.
	Returns (success, dataEntry) tuple.
]]
function DataCrawler.fetchPlayerDataSafely(userId: number, retryAttempts: number, retryDelay: number): (boolean, any?)
	local lastError = nil

	for attempt = 1, retryAttempts do
		local gamepassFetchSuccess, gamepassError, playerOwnedGamepasses = deps.passesLoader:FetchAllPlayerGamepasses(userId)
		local gamesFetchSuccess, gamesError, playerOwnedGames = deps.passesLoader:FetchPlayerOwnedGames(userId)

		if gamepassFetchSuccess and gamesFetchSuccess then
			local dataEntry = deps.createEmptyEntry(userId)
			dataEntry.gamepasses = playerOwnedGamepasses or {}
			dataEntry.games = playerOwnedGames or {}

			return true, dataEntry
		end

		lastError = gamepassError or gamesError

		if attempt < retryAttempts then
			warn(`[{script.Name}] API fetch failed for {userId}`)
			task.wait(retryDelay * attempt)
		end
	end

	warn(`[{script.Name}] Failed to fetch data for {userId} after {retryAttempts} attempts`)

	return false, nil
end

--[[
	Waits for a player's cache to be cleared with timeout.
	Returns true if cleared, false if timeout.
]]
function DataCrawler.waitForCacheClear(playerCache: { [Player]: any }, targetPlayer: Player, timeoutSeconds: number, checkInterval: number): boolean
	local cacheWaitStartTime = os.clock()

	while playerCache[targetPlayer] do
		if os.clock() - cacheWaitStartTime > timeoutSeconds then
			warn(`[{script.Name}] Cache clear timeout for player {targetPlayer.Name} (UserId: {targetPlayer.UserId})`)

			return false
		end
		task.wait(checkInterval)
	end

	return true
end

return DataCrawler