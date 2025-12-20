--[[
	PassCache - Caches player gamepass data with automatic lifecycle management.

	Features:
	- Player-specific gamepass data caching
	- Temporary gift recipient caching
	- Automatic stale cache cleanup
	- Cache reload with timeout protection
]]

local PassCache = {}
PassCache.playerPassCaches = {}
PassCache.temporaryGiftCaches = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local modulesFolder = ReplicatedStorage.Modules
local configurationFolder = ReplicatedStorage.Configuration
local PassesLoader = require(modulesFolder.Managers.PassesLoader)
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local GameConfig = require(configurationFolder.GameConfig)
local CacheOperations = require(script.CacheOperations)
local CacheLifecycle = require(script.CacheLifecycle)
local CacheStatistics = require(script.CacheStatistics)
local DataCrawler = require(script.DataCrawler)

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

--[[
	Loads player gamepass data into the cache.
	Returns true if successful, false if failed (player is kicked).
]]
function PassCache.LoadPlayerGamepassDataIntoCache(targetPlayer: Player): boolean
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

--[[
	Loads gift recipient data into temporary cache.
	Returns the cache entry if successful, nil if failed.
]]
function PassCache.LoadGiftRecipientGamepassDataTemporarily(recipientUserId: number): any?
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

--[[
	Reloads a player's gamepass data cache.
	Returns true if successful, false if failed (player is kicked).
]]
function PassCache.ReloadPlayerGamepassDataCache(targetPlayer: Player): boolean
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

--[[
	Removes a player's data from the cache.
]]
function PassCache.UnloadPlayerDataFromCache(targetPlayer: Player)
	if PassCache.playerPassCaches[targetPlayer] then
		PassCache.playerPassCaches[targetPlayer] = nil
	end
end

--[[
	Returns a copy of the player's cached gamepass data.
]]
function PassCache.GetPlayerCachedGamepassData(targetPlayer: Player): any?
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

--[[
	Clears all cached data from both player and temporary caches.
]]
function PassCache.ClearAllCachedData()
	table.clear(PassCache.playerPassCaches)
	table.clear(PassCache.temporaryGiftCaches)
end

--[[
	Returns statistics about the current cache state.
]]
function PassCache.GetCacheStatistics(): any
	return CacheStatistics.gather(PassCache.playerPassCaches, PassCache.temporaryGiftCaches)
end

--[[
	Returns the list of gamepasses for a player.
]]
function PassCache.GetPlayerGamepassesAsList(targetPlayer: Player): { any }?
	local data = PassCache.GetPlayerCachedGamepassData(targetPlayer)
	if not data then
		return nil
	end

	return data.gamepasses
end

--[[
	Returns the list of gamepasses for a gift recipient.
]]
function PassCache.GetGiftRecipientGamepassesAsList(recipientUserId: number): { any }?
	local data = PassCache.LoadGiftRecipientGamepassDataTemporarily(recipientUserId)
	if not data then
		return nil
	end

	return data.gamepasses
end

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

return PassCache