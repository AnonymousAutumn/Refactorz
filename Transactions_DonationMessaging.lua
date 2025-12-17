-----------------
-- Init Module --
-----------------

local DonationMessaging = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessagingService = game:GetService("MessagingService")

----------------
-- References --
----------------

local networkFolder = ReplicatedStorage.Network
local remoteEvents = networkFolder.Remotes.Events
local sendMessageRemoteEvent = remoteEvents.SendMessage

local configurationFolder = ReplicatedStorage.Configuration
local GameConfig = require(configurationFolder.GameConfig)

local LARGE_DONATION_BROADCAST_TOPIC = GameConfig.MESSAGING_SERVICE_CONFIG.LARGE_DONATION_TOPIC

---------------
-- Constants --
---------------

local MAX_MESSAGING_RETRIES = 3
local BASE_RETRY_DELAY = 1
local MESSAGING_TIMEOUT = 5

---------------
-- Variables --
---------------

local messagingSubscription = nil

---------------
-- Functions --
---------------

local function isValidBroadcastData(data)
	if typeof(data) ~= "table" then
		return false
	end
	return data.Donor ~= nil and data.Receiver ~= nil and data.Amount ~= nil
end

local function hasTimedOut(startTime, timeout)
	return os.clock() - startTime > timeout
end

local function calculateRetryDelay(attemptNumber)
	return BASE_RETRY_DELAY * attemptNumber
end

local function disconnectMessagingSubscription()
	if messagingSubscription then
		pcall(function()
			messagingSubscription:Disconnect()
		end)
		messagingSubscription = nil
	end
end

local function publishToMessagingService(topic, messageData)
	for attempt = 1, MAX_MESSAGING_RETRIES do
		local startTime = os.clock()
		local success, result = pcall(function()
			MessagingService:PublishAsync(topic, messageData)
			if hasTimedOut(startTime, MESSAGING_TIMEOUT) then
				error("MessagingService timeout")
			end
		end)

		if success then
			return true
		end

		warn(`[{script.Name}] MessagingService publish attempt {attempt}/{MAX_MESSAGING_RETRIES} failed: {tostring(result)}`)

		if attempt < MAX_MESSAGING_RETRIES then
			task.wait(calculateRetryDelay(attempt))
		end
	end

	warn(`[{script.Name}] Failed to publish message after {MAX_MESSAGING_RETRIES} attempts`)
	return false
end

function DonationMessaging.broadcastToMessagingService(broadcastTopic, messageData)
	if not isValidBroadcastData(messageData) then
		warn(`[{script.Name}] Invalid message data for broadcast`)
		return false
	end

	return publishToMessagingService(broadcastTopic, messageData)
end

local function processLargeDonationBroadcast(messagingPacket)
	local broadcastData = messagingPacket.Data
	if not isValidBroadcastData(broadcastData) then
		warn(`[{script.Name}] Invalid or incomplete broadcast data received`)
		return
	end

	local success = pcall(function()
		sendMessageRemoteEvent:FireAllClients(
			broadcastData.Donor,
			broadcastData.Receiver,
			broadcastData.Filler,
			broadcastData.Amount,
			true
		)
	end)

	if not success then
		warn(`[{script.Name}] Failed to fire large donation broadcast to clients`)
	end
end

function DonationMessaging.subscribeToMessagingService()
	local success, subscription = pcall(function()
		return MessagingService:SubscribeAsync(LARGE_DONATION_BROADCAST_TOPIC, processLargeDonationBroadcast)
	end)

	if success then
		messagingSubscription = subscription
	else
		warn(`[{script.Name}] Failed to subscribe to MessagingService: {tostring(subscription)}`)
	end
end

function DonationMessaging.cleanup()
	disconnectMessagingSubscription()
end

-------------------
-- Return Module --
-------------------

return DonationMessaging