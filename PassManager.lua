--[[
	PassManager - Manages player gamepass data loading and unloading.

	Features:
	- Loads gamepass data when players join
	- Unloads data when players leave
	- Fires DataLoaded event to clients
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local networkFolder = ReplicatedStorage.Network
local signalsFolder = networkFolder.Signals
local dataLoadedRemoteEvent = signalsFolder.DataLoaded

local modulesFolder = ReplicatedStorage.Modules
local Connections = require(modulesFolder.Wrappers.Connections)
local GamepassCacheManager = require(modulesFolder.Caches.PassCache)
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)

local isShuttingDown = false
local connections = Connections.new()

local function loadPlayerGamepassData(player: Player)
	if not ValidationUtils.isValidPlayer(player) then
		return
	end

	local success, errorMessage = pcall(function()
		GamepassCacheManager.LoadPlayerGamepassDataIntoCache(player)
	end)

	if success then
		dataLoadedRemoteEvent:FireClient(player)
	else
		warn(`[{script.Name}] Failed to load gamepass data for {player.Name} (UserId: {player.UserId}): {tostring(errorMessage)}`)
	end
end

local function unloadPlayerGamepassData(player: Player)
	local success, errorMessage = pcall(function()
		GamepassCacheManager.UnloadPlayerDataFromCache(player)
	end)

	if not success then
		warn(`[{script.Name}] Failed to unload gamepass data for {player.Name} (UserId: {player.UserId}): {tostring(errorMessage)}`)
	end
end

local function handlePlayerConnection(connectingPlayer: Player)
	if isShuttingDown then
		return
	end

	task.spawn(function()
		loadPlayerGamepassData(connectingPlayer)
	end)
end

local function handlePlayerDisconnection(disconnectingPlayer: Player)
	unloadPlayerGamepassData(disconnectingPlayer)
end

local function initializeExistingPlayers()
	for _, existingPlayer in pairs(Players:GetPlayers()) do
		task.spawn(handlePlayerConnection, existingPlayer)
	end
end

local function unloadAllPlayerGamepassData()
	for _, player in pairs(Players:GetPlayers()) do
		pcall(function()
			GamepassCacheManager.UnloadPlayerDataFromCache(player)
		end)
	end
end

local function cleanupAllResources()
	connections:disconnect()
end

local function initialize()
	connections:add(Players.PlayerAdded:Connect(handlePlayerConnection))
	connections:add(Players.PlayerRemoving:Connect(handlePlayerDisconnection))

	initializeExistingPlayers()

	game:BindToClose(function()
		isShuttingDown = true
		cleanupAllResources()
		unloadAllPlayerGamepassData()
	end)
end

initialize()