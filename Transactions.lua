--------------
-- Services --
--------------

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local networkFolder = ReplicatedStorage.Network
local remoteEvents = networkFolder.Remotes.Events
local remoteFunctions = networkFolder.Remotes.Functions
local giftClearanceRemoteEvent = remoteEvents.ClearGifts
local giftRequestRemoteFunction = remoteFunctions.RequestGifts

local modulesFolder = ReplicatedStorage.Modules
local Connections = require(modulesFolder.Wrappers.Connections)
local EnhancedValidation = require(modulesFolder.Utilities.EnhancedValidation)
local RateLimiter = require(modulesFolder.Utilities.RateLimiter)
local GiftPersistence = require(script.GiftPersistence)
local DonationMessaging = require(script.DonationMessaging)
local PurchaseFlow = require(script.PurchaseFlow)

---------------
-- Variables --
---------------

local connectionsMaid = Connections.new()

---------------
-- Functions --
---------------

local function cleanup()
	connectionsMaid:disconnect()
	DonationMessaging.cleanup()
end

local function initialize()
	giftRequestRemoteFunction.OnServerInvoke = function(player)
		if not EnhancedValidation.validatePlayer(player) then
			warn(`[{script.Name}] Invalid player in gift request`)
			return {}
		end

		if not RateLimiter.checkRateLimit(player, "RequestGifts", 2) then
			return {}
		end

		return GiftPersistence.retrievePlayerGiftHistory(player)
	end

	connectionsMaid:add(giftClearanceRemoteEvent.OnServerEvent:Connect(function(player)
		if not EnhancedValidation.validatePlayer(player) then
			warn(`[{script.Name}] Invalid player in gift clearance`)
			return
		end

		if not RateLimiter.checkRateLimit(player, "ClearGifts", 5) then
			return
		end

		GiftPersistence.removeAllPlayerGifts(player)
	end))

	connectionsMaid:add(MarketplaceService.PromptGamePassPurchaseFinished:Connect(PurchaseFlow.handleGamepassPurchaseCompletion))

	MarketplaceService.ProcessReceipt = PurchaseFlow.handleDeveloperProductPurchase

	DonationMessaging.subscribeToMessagingService()

	game:BindToClose(cleanup)
end

--------------------
-- Initialization --
--------------------

initialize()