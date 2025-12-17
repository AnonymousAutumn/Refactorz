-----------------
-- Init Module --
-----------------

local DataLoader = {}

---------------
-- Variables --
---------------

local deps = nil 

---------------
-- Functions --
---------------

function DataLoader.initialize(dependencies)
	deps = dependencies
end

function DataLoader.fetchPlayerDataSafely(userId, retryAttempts, retryDelay)
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

function DataLoader.waitForCacheClear(playerCache, targetPlayer, timeoutSeconds, checkInterval)
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

-------------------
-- Return Module --
-------------------

return DataLoader