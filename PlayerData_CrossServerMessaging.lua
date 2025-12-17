-----------------
-- Init Module --
-----------------

local CrossServerMessaging = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")

----------------
-- References --
----------------

local networkFolder = ReplicatedStorage.Network
local bindableEvents = networkFolder.Bindables.Events
local updateUIBindableEvent = bindableEvents.UpdateUI

local modulesFolder = ReplicatedStorage.Modules
local configurationFolder = ReplicatedStorage.Configuration

local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local GameConfig = require(configurationFolder.GameConfig)

---------------
-- Constants --
---------------

local CROSS_SERVER_LEADERSTATS_UPDATE_TOPIC = GameConfig.MESSAGING_SERVICE_CONFIG.LEADERBOARD_UPDATE
local UI_UPDATE_STATISTIC_NAME = "Raised"

---------------
-- Variables --
---------------

local isShuttingDown = false
local messageConnection = nil

---------------
-- Functions --
---------------

local function isValidCrossServerMessage(message)
	return type(message) == "table"
		and ValidationUtils.isValidUserId(message.UserId)
		and type(message.Stat) == "string"
		and type(message.Value) == "number"
end

local function updatePlayerLeaderboardStatistics(targetPlayer, statisticName, newStatisticValue)
	if not ValidationUtils.isValidPlayer(targetPlayer) then
		return
	end

	local playerLeaderboardStats = targetPlayer:WaitForChild("leaderstats")
	if not playerLeaderboardStats then
		return
	end

	local leaderboardStatisticObject = playerLeaderboardStats:FindFirstChild(statisticName)
	if leaderboardStatisticObject and leaderboardStatisticObject:IsA("IntValue") then
		leaderboardStatisticObject.Value = newStatisticValue
	end

	if statisticName == UI_UPDATE_STATISTIC_NAME then
		updateUIBindableEvent:Fire(false, { Viewer = targetPlayer }, true)
	end
end

local function handleCrossServerLeaderstatUpdate(message)
	if not isValidCrossServerMessage(message) then
		warn(`[{script.Name}] Invalid cross-server leaderstat update message received`)
		return
	end

	local targetPlayer = Players:GetPlayerByUserId(message.UserId)
	if targetPlayer then
		updatePlayerLeaderboardStatistics(targetPlayer, message.Stat, message.Value)
	end
end

function CrossServerMessaging.publishUpdate(updateMessage)
	if isShuttingDown then
		return
	end

	local publishSuccess, publishErrorMessage = pcall(function()
		MessagingService:PublishAsync(CROSS_SERVER_LEADERSTATS_UPDATE_TOPIC, updateMessage)
	end)

	if not publishSuccess then
		warn(`[{script.Name}] Failed to publish to messaging topic '{CROSS_SERVER_LEADERSTATS_UPDATE_TOPIC}': {tostring(publishErrorMessage)}`)
	end
end

function CrossServerMessaging.subscribe(connectionTracker)
	local subscribeSuccess, subscribeError = pcall(function()
		messageConnection = connectionTracker(
			MessagingService:SubscribeAsync(
				CROSS_SERVER_LEADERSTATS_UPDATE_TOPIC,
				function(envelope)
					local data = envelope and envelope.Data
					handleCrossServerLeaderstatUpdate(data)
				end
			)
		)
	end)

	if not subscribeSuccess then
		warn(`[{script.Name}] Failed to subscribe to cross-server updates: {tostring(subscribeError)}`)
	end
end

function CrossServerMessaging.updatePlayerStats(targetPlayer, statisticName, newStatisticValue)
	updatePlayerLeaderboardStatistics(targetPlayer, statisticName, newStatisticValue)
end

function CrossServerMessaging.setShutdown(shutdown)
	isShuttingDown = shutdown
end

function CrossServerMessaging.cleanup()
	isShuttingDown = true
	
	if messageConnection then
		messageConnection:Disconnect()
		messageConnection = nil
	end
end

-------------------
-- Return Module --
-------------------

return CrossServerMessaging