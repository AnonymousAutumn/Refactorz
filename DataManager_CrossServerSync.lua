--[[
	CrossServerSync - Manages cross-server messaging with retry logic.

	Features:
	- MessagingService subscription with automatic retry
	- Update message validation
	- Configurable retry attempts and backoff delay
]]

local CrossServerSync = {}
CrossServerSync.__index = CrossServerSync

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessagingService = game:GetService("MessagingService")

local modulesFolder = ReplicatedStorage.Modules
local configurationFolder = ReplicatedStorage.Configuration
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local GameConfig = require(configurationFolder.GameConfig)

local RETRY_DELAY = 5
local MAX_RETRY_ATTEMPTS = 3

local VALID_STATISTICS = { "Donated", "Raised", "Wins" }

export type UpdateData = {
	UserId: number,
	Stat: string,
	Value: number,
}

type MessageHandler = (message: any) -> ()

--[[
	Creates a new CrossServerSync instance.
]]
function CrossServerSync.new()
	local self = setmetatable({}, CrossServerSync) 
	self.connection = nil
	return self 
end

local function isValidStatistic(statisticName: string): boolean
	for _, name in pairs(VALID_STATISTICS) do
		if name == statisticName then
			return true
		end
	end
	return false
end

local function isValidValue(value: any): boolean
	return type(value) == "number"
end

local function extractUpdateData(message: any): UpdateData?
	if type(message) ~= "table" then
		return nil
	end

	local payload = message.Data or message
	if type(payload) ~= "table" then
		return nil
	end

	return payload
end

--[[
	Validates a cross-server update message structure.
]]
function CrossServerSync.validateUpdateMessage(message: any): boolean
	local updateData = extractUpdateData(message)
	if not updateData then
		return false
	end

	if not ValidationUtils.isValidUserId(updateData.UserId) then
		return false
	end

	if type(updateData.Stat) ~= "string" or not isValidStatistic(updateData.Stat) then
		return false
	end

	if not isValidValue(updateData.Value) then
		return false
	end

	return true
end

--[[
	Extracts and validates update data from a message.
	Returns nil if validation fails.
]]
function CrossServerSync.extractUpdate(message: any): UpdateData?
	if not CrossServerSync.validateUpdateMessage(message) then
		return nil
	end

	return extractUpdateData(message)
end

local function calculateRetryDelay(attemptNumber: number): number
	return RETRY_DELAY * attemptNumber
end

local function establishConnection(topic: string, handler: MessageHandler, attemptNumber: number, maxRetries: number): RBXScriptConnection?
	if attemptNumber > maxRetries then
		warn(`[{script.Name}] Failed to connect after {maxRetries} attempts`)
		return nil
	end

	local success, result = pcall(function()
		return MessagingService:SubscribeAsync(topic, handler)
	end)

	if success then
		return result
	else
		warn(`[{script.Name}] Connection failed (attempt {attemptNumber}/{maxRetries}): {tostring(result)}`)
		task.wait(calculateRetryDelay(attemptNumber))

		if attemptNumber < maxRetries then
			warn(`[{script.Name}] Retrying connection (attempt {attemptNumber + 1})...`)
			return establishConnection(topic, handler, attemptNumber + 1, maxRetries)
		end

		return nil
	end
end

--[[
	Subscribes to a MessagingService topic with automatic retry.
	Returns true if subscription succeeded.
]]
function CrossServerSync:subscribe(topic: string, handler: MessageHandler, maxRetries: number?): boolean
	local retries = maxRetries or MAX_RETRY_ATTEMPTS

	self.connection = establishConnection(topic, handler, 1, retries)

	return self.connection ~= nil
end

--[[
	Disconnects from the current subscription.
]]
function CrossServerSync:disconnect()
	if self.connection then
		pcall(function()
			self.connection:Disconnect()
		end)
		self.connection = nil
	end
end

--[[
	Returns whether the sync is currently connected.
]]
function CrossServerSync:isConnected(): boolean
	return self.connection ~= nil
end

--[[
	Factory function to create a sync instance for leaderboard updates.
]]
function CrossServerSync.createLeaderboardSync(handler: MessageHandler)
	local sync = CrossServerSync.new()
	local topic = GameConfig.MESSAGING_SERVICE_CONFIG.LEADERBOARD_UPDATE

	sync:subscribe(topic, handler)

	return sync
end

return CrossServerSync