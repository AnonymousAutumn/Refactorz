--[[
	CrossServerMessaging - Handles cross-server leaderboard updates via MessagingService.

	Features:
	- Publishes statistic updates to other servers
	- Subscribes to incoming updates and syncs leaderboards
	- Triggers UI refresh when "Raised" statistic changes
]]

local CrossServerMessaging = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")

local networkFolder = ReplicatedStorage.Network
local bindableEvents = networkFolder.Bindables.Events
local updateUIBindableEvent = bindableEvents.UpdateUI

local modulesFolder = ReplicatedStorage.Modules
local configurationFolder = ReplicatedStorage.Configuration

local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local GameConfig = require(configurationFolder.GameConfig)

local CROSS_SERVER_LEADERSTATS_UPDATE_TOPIC = GameConfig.MESSAGING_SERVICE_CONFIG.LEADERBOARD_UPDATE
local UI_UPDATE_STATISTIC_NAME = "Raised"

export type CrossServerMessage = {
	UserId: number,
	Stat: string,
	Value: number,
}

local isShuttingDown = false
local messageConnection: RBXScriptConnection? = nil

local function isValidCrossServerMessage(message: any): boolean
	return type(message) == "table"
		and ValidationUtils.isValidUserId(message.UserId)
		and type(message.Stat) == "string"
		and type(message.Value) == "number"
end

local function updatePlayerLeaderboardStatistics(targetPlayer: Player?, statisticName: string, newStatisticValue: number)
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

local function handleCrossServerLeaderstatUpdate(message: CrossServerMessage?)
	if not isValidCrossServerMessage(message) then
		warn(`[{script.Name}] Invalid cross-server leaderstat update message received`)
		return
	end

	local targetPlayer = Players:GetPlayerByUserId(message.UserId)
	if targetPlayer then
		updatePlayerLeaderboardStatistics(targetPlayer, message.Stat, message.Value)
	end
end

--[[
	Publishes a statistic update to all other servers.
]]
function CrossServerMessaging.publishUpdate(updateMessage: CrossServerMessage)
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

--[[
	Subscribes to cross-server updates and registers the connection.
]]
function CrossServerMessaging.subscribe(connectionTracker: (RBXScriptConnection) -> RBXScriptConnection)
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

--[[
	Updates a player's leaderboard statistics locally.
]]
function CrossServerMessaging.updatePlayerStats(targetPlayer: Player?, statisticName: string, newStatisticValue: number)
	updatePlayerLeaderboardStatistics(targetPlayer, statisticName, newStatisticValue)
end

--[[
	Sets the shutdown flag to stop publishing updates.
]]
function CrossServerMessaging.setShutdown(shutdown: boolean)
	isShuttingDown = shutdown
end

--[[
	Cleans up the module by disconnecting message subscriptions.
]]
function CrossServerMessaging.cleanup()
	isShuttingDown = true

	if messageConnection then
		messageConnection:Disconnect()
		messageConnection = nil
	end
end

return CrossServerMessaging