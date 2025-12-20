--[[
	PurchaseFlow - Handles purchase completion and processing.

	Features:
	- Gamepass purchase handling
	- Developer product processing
	- Gift saving for offline recipients
]]

local PurchaseFlow = {}

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local networkFolder = ReplicatedStorage.Network
local remoteEvents = networkFolder.Remotes.Events
local SendNotificationEvent = remoteEvents.CreateNotification

local modulesFolder = ReplicatedStorage.Modules
local configurationFolder = ReplicatedStorage.Configuration
local UsernameCache = require(modulesFolder.Caches.UsernameCache)
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local Coins = require(modulesFolder.Utilities.Coins)
local GameConfig = require(configurationFolder.GameConfig)

local MAX_DATASTORE_RETRIES = 3
local BASE_RETRY_DELAY = 1

local GiftPersistence = nil
local DonationStatistics = nil
local DonationMessaging = nil

local function isValidGiftAmount(amount: number): boolean
	return ValidationUtils.isValidNumber(amount) and amount >= 1
end

local function isValidGamepassInfo(info: any): boolean
	if typeof(info) ~= "table" then
		return false
	end
	return info.Creator ~= nil
		and typeof(info.Creator) == "table"
		and ValidationUtils.isValidUserId(info.Creator.Id)
end

local function isValidDeveloperProductInfo(info: any): boolean
	if typeof(info) ~= "table" then
		return false
	end
	return info.PriceInRobux ~= nil and typeof(info.PriceInRobux) == "number"
end

local function calculateRetryDelay(attemptNumber: number): number
	return BASE_RETRY_DELAY * attemptNumber
end

local function fetchGamepassProductInfo(gamepassAssetId: number): any?
	for attempt = 1, MAX_DATASTORE_RETRIES do
		local success, result = pcall(function()
			return MarketplaceService:GetProductInfo(gamepassAssetId, Enum.InfoType.GamePass)
		end)

		if success and isValidGamepassInfo(result) then
			return result
		end

		warn(`[{script.Name}] GetProductInfo attempt {attempt}/{MAX_DATASTORE_RETRIES} failed: {tostring(result)}`)

		if attempt < MAX_DATASTORE_RETRIES then
			task.wait(calculateRetryDelay(attempt))
		end
	end

	return nil
end

local function fetchDeveloperProductInfo(productId: number): any?
	for attempt = 1, MAX_DATASTORE_RETRIES do
		local success, result = pcall(function()
			return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
		end)

		if success and isValidDeveloperProductInfo(result) then
			return result
		end

		warn(`[{script.Name}] GetProductInfo (DevProduct) attempt {attempt}/{MAX_DATASTORE_RETRIES} failed: {tostring(result)}`)

		if attempt < MAX_DATASTORE_RETRIES then
			task.wait(calculateRetryDelay(attempt))
		end
	end

	return nil
end

local function extractCreatorInfo(gamepassProductInfo: any): (number?, number?)
	local creatorUserId = gamepassProductInfo.Creator and gamepassProductInfo.Creator.Id
	local priceInRobux = gamepassProductInfo.PriceInRobux or 0

	if not ValidationUtils.isValidUserId(creatorUserId) then
		warn(`[{script.Name}] Invalid creator user ID from gamepass info`)
		return nil, nil
	end
	if not isValidGiftAmount(priceInRobux) then
		warn(`[{script.Name}] Invalid gamepass price: {tostring(priceInRobux)}`)
		return nil, nil
	end

	return creatorUserId, priceInRobux
end

local function processSuccessfulPurchase(purchasingPlayer: Player, gamepassAssetId: number)
	local gamepassProductInfo = fetchGamepassProductInfo(gamepassAssetId)
	if not gamepassProductInfo then
		warn(`[{script.Name}] Failed to retrieve product information for gamepass {gamepassAssetId}`)
		if DonationStatistics then
			DonationStatistics.sendDonationFailureNotification(purchasingPlayer)
		end
		return
	end

	local creatorUserId, priceInRobux = extractCreatorInfo(gamepassProductInfo)
	if not creatorUserId or not priceInRobux then
		return
	end

	local creatorPlayerInstance = Players:GetPlayerByUserId(creatorUserId)
	local creatorDisplayName = UsernameCache.getUsername(creatorUserId)
	local creatorIsOnline = creatorPlayerInstance ~= nil

	if DonationStatistics then
		local statsUpdated = DonationStatistics.updateDonationStatistics(
			purchasingPlayer.UserId,
			creatorUserId,
			priceInRobux
		)
		if not statsUpdated then
			warn("[Transaction.PurchaseFlow] Failed to update donation statistics")
		end
	end

	if creatorIsOnline then
		Coins.SpawnCoins(purchasingPlayer, creatorPlayerInstance, 5)
	end

	if not creatorIsOnline and GiftPersistence then
		local giftSaved = GiftPersistence.saveGiftToDataStore(purchasingPlayer.UserId, creatorUserId, priceInRobux)
		if not giftSaved then
			warn(`[{script.Name}] Failed to save gift to DataStore`)
		end
	end

	if DonationStatistics then
		DonationStatistics.sendDonationConfirmationToPlayer(purchasingPlayer, creatorDisplayName, creatorIsOnline)
	end

	purchasingPlayer:SetAttribute(tostring(gamepassAssetId), true)

	if DonationMessaging then
		local messagingConfiguration = GameConfig.MESSAGING_SERVICE_CONFIG
		local LIVE_DONATION_BROADCAST_TOPIC = messagingConfiguration.LIVE_DONATION_TOPIC

		DonationMessaging.broadcastToMessagingService(LIVE_DONATION_BROADCAST_TOPIC, {
			Donor = purchasingPlayer.UserId,
			Receiver = creatorUserId,
			Amount = priceInRobux,
		})
	end

	if DonationStatistics then
		DonationStatistics.announceDonationToAllPlayers(
			purchasingPlayer,
			creatorDisplayName,
			priceInRobux,
			creatorIsOnline
		)
	end
end

--[[
	Handles gamepass purchase completion.
]]
function PurchaseFlow.handleGamepassPurchaseCompletion(purchasingPlayer: Player, gamepassAssetId: number, purchaseWasSuccessful: boolean)
	if not ValidationUtils.isValidPlayer(purchasingPlayer) then
		warn(`[{script.Name}] Invalid player for purchase completion`)
		return
	end

	if not purchaseWasSuccessful then
		if DonationStatistics then
			DonationStatistics.sendPurchaseCancellationNotification(purchasingPlayer)
		end
		return
	end

	for _, pass in pairs(GameConfig.MONETIZATION) do
		if gamepassAssetId == pass then
			local gamepassProductInfo = fetchGamepassProductInfo(gamepassAssetId)

			if gamepassProductInfo then
				SendNotificationEvent:FireClient(purchasingPlayer, `You purchased the {gamepassProductInfo.Name} pass!`, "Success")
				purchasingPlayer:SetAttribute(tostring(gamepassAssetId), true)
			end
			return
		end
	end

	task.spawn(processSuccessfulPurchase, purchasingPlayer, gamepassAssetId)
end

--[[
	Handles developer product purchase receipt.
]]
function PurchaseFlow.handleDeveloperProductPurchase(receiptInfo: any): Enum.ProductPurchaseDecision
	local playerId = receiptInfo.PlayerId
	local productId = receiptInfo.ProductId
	local purchaseId = receiptInfo.PurchaseId

	local productInfo = fetchDeveloperProductInfo(productId)
	if not productInfo then
		warn(`[{script.Name}] Failed to retrieve product information for developer product {productId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local priceInRobux = productInfo.PriceInRobux or 0
	if not isValidGiftAmount(priceInRobux) then
		warn(`[{script.Name}] Invalid developer product price: {tostring(priceInRobux)}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if not DonationStatistics then
		warn(`[{script.Name}] DonationStatistics module not set`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local success, status = DonationStatistics.updateDonorStatisticsWithReceipt(
		playerId,
		purchaseId,
		priceInRobux
	)

	if not success then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if status == "newly_processed" then
		local purchasingPlayer = Players:GetPlayerByUserId(playerId)
		if purchasingPlayer then
			DonationStatistics.sendDeveloperProductConfirmation(purchasingPlayer)
		end
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

--[[
	Sets the GiftPersistence module reference.
]]
function PurchaseFlow.setGiftPersistenceModule(module: any)
	GiftPersistence = module
end

--[[
	Sets the DonationStatistics module reference.
]]
function PurchaseFlow.setDonationStatisticsModule(module: any)
	DonationStatistics = module
end

--[[
	Sets the DonationMessaging module reference.
]]
function PurchaseFlow.setDonationMessagingModule(module: any)
	DonationMessaging = module
end

return PurchaseFlow