-----------------
-- Init Module --
-----------------

local PassCache = {}
PassCache.playerPassCaches = {}
PassCache.temporaryGiftCaches = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local configurationFolder = ReplicatedStorage.Configuration
local PassesLoader = require(modulesFolder.Managers.PassesLoader)
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local GameConfig = require(configurationFolder.GameConfig)
local CacheOperations = require(script.CacheOperations)
local CacheLifecycle = require(script.CacheLifecycle)
local CacheStatistics = require(script.CacheStatistics)
local DataCrawler = require(script.DataCrawler)

---------------
-- Constants --
---------------

local CACHE_OPERATION_TIMEOUT_SECONDS = 15
local CACHE_CLEAR_CHECK_INTERVAL_SECONDS = 0.1

local CACHE_ENTRY_MAX_AGE_SECONDS = 60 * 60
local CACHE_CLEANUP_INTERVAL_SECONDS = 60 * 10
local ENABLE_CACHE_CLEANUP = true

local API_FETCH_RETRY_ATTEMPTS = 3
local API_FETCH_RETRY_DELAY_SECONDS = 1

local KICK_MESSAGES = {
	LOAD_FAILED = "\nGamepass data failed to load. Please rejoin.",
	CACHE_TIMEOUT = "Cache reload timeout occurred. Please rejoin.",
	RELOAD_FAILED = "Cache reload failed. Please rejoin.",
}

---------------
-- Functions --
---------------

function PassCache.LoadPlayerGamepassDataIntoCache(targetPlayer)
	if not ValidationUtils.isValidPlayer(targetPlayer) then
		warn(`Attempt to load cache for {tostring(targetPlayer)} failed`)
		return false
	end

	if PassCache.playerPassCaches[targetPlayer] then
		warn(`Cache already exists for {targetPlayer.Name}`)
		CacheOperations.updateAccessTime(PassCache.playerPassCaches[targetPlayer])

		return true
	end

	local fetchSuccess, playerDataCacheEntry = DataCrawler.fetchPlayerDataSafely(
		targetPlayer.UserId,
		API_FETCH_RETRY_ATTEMPTS,
		API_FETCH_RETRY_DELAY_SECONDS
	)

	if not fetchSuccess or not playerDataCacheEntry then
		warn(`Failed to load passes for {targetPlayer.Name}`)
		targetPlayer:Kick(KICK_MESSAGES.LOAD_FAILED)

		return false
	end

	PassCache.playerPassCaches[targetPlayer] = playerDataCacheEntry

	return true
end

function PassCache.LoadGiftRecipientGamepassDataTemporarily(recipientUserId)
	local cachedEntry = PassCache.temporaryGiftCaches[recipientUserId]
	if cachedEntry then
		local currentTime = os.time()
		if not CacheOperations.isStale(cachedEntry, currentTime, CACHE_ENTRY_MAX_AGE_SECONDS) then
			CacheOperations.updateAccessTime(cachedEntry)
			return cachedEntry
		end
	end

	local fetchSuccess, temporaryDataCacheEntry = DataCrawler.fetchPlayerDataSafely(
		recipientUserId,
		API_FETCH_RETRY_ATTEMPTS,
		API_FETCH_RETRY_DELAY_SECONDS
	)

	if not fetchSuccess or not temporaryDataCacheEntry then
		warn(`Failed to fetch data for {recipientUserId}`)
		return nil
	end

	PassCache.temporaryGiftCaches[recipientUserId] = temporaryDataCacheEntry

	return temporaryDataCacheEntry
end

function PassCache.ReloadPlayerGamepassDataCache(targetPlayer)
	if not ValidationUtils.isValidPlayer(targetPlayer) then
		warn("Invalid argument: player expected")
		return false
	end

	PassCache.UnloadPlayerDataFromCache(targetPlayer)

	local cacheClearSuccess = DataCrawler.waitForCacheClear(
		PassCache.playerPassCaches,
		targetPlayer,
		CACHE_OPERATION_TIMEOUT_SECONDS,
		CACHE_CLEAR_CHECK_INTERVAL_SECONDS
	)

	if not cacheClearSuccess then
		warn(`Cache could not be cleared for {targetPlayer.Name}`)
		targetPlayer:Kick(KICK_MESSAGES.CACHE_TIMEOUT)

		return false
	end

	local success, loadResult = pcall(PassCache.LoadPlayerGamepassDataIntoCache, targetPlayer)
	if not success then
		warn(
			"Cache reload error for player %s (UserId: %d): %s",
			targetPlayer.Name,
			targetPlayer.UserId,
			tostring(loadResult)
		)

		targetPlayer:Kick(KICK_MESSAGES.RELOAD_FAILED)

		return false
	end

	if not loadResult then
		warn(`Cache failed to reload for {targetPlayer.Name}`)
		targetPlayer:Kick(KICK_MESSAGES.RELOAD_FAILED)

		return false
	end

	return true
end

function PassCache.UnloadPlayerDataFromCache(targetPlayer)
	if PassCache.playerPassCaches[targetPlayer] then
		PassCache.playerPassCaches[targetPlayer] = nil
	end
end

function PassCache.GetPlayerCachedGamepassData(targetPlayer)
	if not ValidationUtils.isValidPlayer(targetPlayer) then
		warn(`Failed to get cache for {targetPlayer.Name}`)

		return nil
	end

	local playerCachedData = PassCache.playerPassCaches[targetPlayer]
	if not playerCachedData then
		return nil
	end

	CacheOperations.updateAccessTime(playerCachedData)

	return CacheOperations.createCopy(playerCachedData)
end

function PassCache.ClearAllCachedData()
	local playerCount = CacheOperations.countEntries(PassCache.playerPassCaches)
	local tempCount = CacheOperations.countEntries(PassCache.temporaryGiftCaches)

	table.clear(PassCache.playerPassCaches)
	table.clear(PassCache.temporaryGiftCaches)
end

function PassCache.GetCacheStatistics()
	return CacheStatistics.gather(PassCache.playerPassCaches, PassCache.temporaryGiftCaches)
end

function PassCache.GetPlayerGamepassesAsList(targetPlayer)
	local data = PassCache.GetPlayerCachedGamepassData(targetPlayer)
	if not data then
		return nil
	end

	return data.gamepasses
end

function PassCache.GetGiftRecipientGamepassesAsList(recipientUserId)
	local data = PassCache.LoadGiftRecipientGamepassDataTemporarily(recipientUserId)
	if not data then
		return nil
	end

	return data.gamepasses
end

--------------------
-- Initialization --
--------------------

CacheLifecycle.initialize({
	checkStaleFunc = CacheOperations.isStale,
	isValidPlayerFunc = ValidationUtils.isValidPlayer,
})

DataCrawler.initialize({
	passesLoader = PassesLoader,
	createEmptyEntry = CacheOperations.createEmpty
})

if RunService:IsServer() then

	CacheLifecycle.startCleanupLoop(PassCache.playerPassCaches, PassCache.temporaryGiftCaches,
		{
			enabled = ENABLE_CACHE_CLEANUP,
			intervalSeconds = CACHE_CLEANUP_INTERVAL_SECONDS,
			maxAgeSeconds = CACHE_ENTRY_MAX_AGE_SECONDS,
		}
	)

	Players.PlayerRemoving:Connect(function(player)
		PassCache.UnloadPlayerDataFromCache(player)
	end)

	game:BindToClose(function()
		CacheLifecycle.setShuttingDown(true)

		CacheLifecycle.stopCleanupLoop()
		PassCache.ClearAllCachedData()
	end)

end

-------------------
-- Return Module --
-------------------

return PassCache