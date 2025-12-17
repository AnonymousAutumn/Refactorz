-----------------
-- Init Module --
-----------------

local CrossServerSync = {}
CrossServerSync.__index = CrossServerSync

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessagingService = game:GetService("MessagingService")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local configurationFolder = ReplicatedStorage.Configuration
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local GameConfig = require(configurationFolder.GameConfig)

---------------
-- Constants --
---------------

local RETRY_DELAY = 5
local MAX_RETRY_ATTEMPTS = 3

local VALID_STATISTICS = { "Donated", "Raised", "Wins" }

---------------
-- Functions --
---------------

function CrossServerSync.new()
	local self = setmetatable({}, CrossServerSync) 
	self.connection = nil
	return self 
end

local function isValidStatistic(statisticName)
	for _, name in VALID_STATISTICS do
		if name == statisticName then
			return true
		end
	end
	return false
end

local function isValidValue(value)
	return type(value) == "number"
end

local function extractUpdateData(message)
	if type(message) ~= "table" then
		return nil
	end

	local payload = message.Data or message
	if type(payload) ~= "table" then
		return nil
	end

	return payload
end

function CrossServerSync.validateUpdateMessage(message)
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

function CrossServerSync.extractUpdate(message)
	if not CrossServerSync.validateUpdateMessage(message) then
		return nil
	end

	return extractUpdateData(message)
end

local function calculateRetryDelay(attemptNumber)
	return RETRY_DELAY * attemptNumber
end

local function establishConnection(topic, handler, attemptNumber, maxRetries)
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

function CrossServerSync:subscribe(topic, handler, maxRetries)
	local retries = maxRetries or MAX_RETRY_ATTEMPTS

	self.connection = establishConnection(topic, handler, 1, retries)

	return self.connection ~= nil
end

function CrossServerSync:disconnect()
	if self.connection then
		pcall(function()
			self.connection:Disconnect()
		end)
		self.connection = nil
	end
end

function CrossServerSync:isConnected()
	return self.connection ~= nil
end

function CrossServerSync.createLeaderboardSync(handler)
	local sync = CrossServerSync.new()
	local topic = GameConfig.MESSAGING_SERVICE_CONFIG.LEADERBOARD_UPDATE

	sync:subscribe(topic, handler)

	return sync
end

-------------------
-- Return Module --
-------------------

return CrossServerSync