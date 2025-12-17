local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modules = ReplicatedStorage:WaitForChild("Modules")
local configuration = ReplicatedStorage:WaitForChild("Configuration")

local ValidationUtils = require(modules.Utilities.ValidationUtils)
local GameConfig = require(configuration.GameConfig)

local TAG = "[CrossServerBridge]"
local CROSS_SERVER_DONATION_MESSAGING_TOPIC = GameConfig.MESSAGING_SERVICE_CONFIG.LIVE_DONATION_TOPIC

local CrossServerBridge = {}
CrossServerBridge.__index = CrossServerBridge

function CrossServerBridge.new()
	local self = setmetatable({}, CrossServerBridge) 

	self.messagingSubscription = nil 
	self.isShuttingDown = false

	return self
end

function CrossServerBridge.validateDonationData(donationData)
	if type(donationData) ~= "table" then
		warn(`{TAG} Donation data is not a table`)
		return false
	end
	if not (ValidationUtils.isValidNumber(donationData.Amount) and donationData.Amount > 0) then
		warn(`{TAG} Invalid donation amount: {tostring(donationData.Amount)}`)
		return false
	end
	if not ValidationUtils.isValidUserId(donationData.Donor) then
		warn(`{TAG} Invalid donor user ID: {tostring(donationData.Donor)}`)
		return false
	end
	if not ValidationUtils.isValidUserId(donationData.Receiver) then
		warn(`{TAG} Invalid receiver user ID: {tostring(donationData.Receiver)}`)
		return false
	end
	return true
end

function CrossServerBridge:handleMessage(messagingServicePacket, processDonation)
	if self.isShuttingDown then
		return
	end

	local success, errorMessage = pcall(processDonation, messagingServicePacket.Data)
	if not success then
		warn(`{TAG} Error processing cross-server donation message: {tostring(errorMessage)}`)
	end
end

function CrossServerBridge:subscribe(processDonation)
	if self.messagingSubscription then
		warn(`{TAG} Already subscribed to messaging service`)
		return false
	end

	local success, subscription = pcall(function()
		return MessagingService:SubscribeAsync(CROSS_SERVER_DONATION_MESSAGING_TOPIC, function(packet)
			self:handleMessage(packet, processDonation)
		end)
	end)

	if success then
		self.messagingSubscription = subscription
		return true
	else
		warn(`{TAG} Failed to establish cross-server messaging connection: {tostring(subscription)}`)
		return false
	end
end

function CrossServerBridge:disconnect()
	if self.messagingSubscription then
		pcall(function()
			self.messagingSubscription:Disconnect()
		end)
		self.messagingSubscription = nil
	end
end

function CrossServerBridge:shutdown()
	self.isShuttingDown = true
	self:disconnect()
end

function CrossServerBridge.getTopic()
	return CROSS_SERVER_DONATION_MESSAGING_TOPIC
end

return CrossServerBridge