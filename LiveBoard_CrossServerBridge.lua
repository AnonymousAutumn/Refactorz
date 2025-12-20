--[[
	CrossServerBridge - Cross-server messaging for donation notifications.

	Features:
	- MessagingService subscription
	- Donation data validation
	- Cross-server event handling
]]

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

--[[
	Creates a new CrossServerBridge instance.
]]
function CrossServerBridge.new(): any
	local self = setmetatable({}, CrossServerBridge) 

	self.messagingSubscription = nil 
	self.isShuttingDown = false

	return self
end

--[[
	Validates donation data structure.
]]
function CrossServerBridge.validateDonationData(donationData: any): boolean
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

--[[
	Handles incoming messaging service packets.
]]
function CrossServerBridge:handleMessage(messagingServicePacket: any, processDonation: (any) -> ())
	if self.isShuttingDown then
		return
	end

	local success, errorMessage = pcall(processDonation, messagingServicePacket.Data)
	if not success then
		warn(`{TAG} Error processing cross-server donation message: {tostring(errorMessage)}`)
	end
end

--[[
	Subscribes to cross-server donation notifications.
]]
function CrossServerBridge:subscribe(processDonation: (any) -> ()): boolean
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

--[[
	Disconnects from messaging service.
]]
function CrossServerBridge:disconnect()
	if self.messagingSubscription then
		pcall(function()
			self.messagingSubscription:Disconnect()
		end)
		self.messagingSubscription = nil
	end
end

--[[
	Shuts down the bridge and cleans up resources.
]]
function CrossServerBridge:shutdown()
	self.isShuttingDown = true
	self:disconnect()
end

--[[
	Gets the messaging topic name.
]]
function CrossServerBridge.getTopic(): string
	return CROSS_SERVER_DONATION_MESSAGING_TOPIC
end

return CrossServerBridge