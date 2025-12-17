-----------------
-- Init Module --
-----------------

local GamePassPurchaseHandler = {}

--------------
-- Services --
--------------

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)

---------------
-- Constants --
---------------

local DEFAULT_PURCHASE_COOLDOWN_SECONDS = 1

local MAX_DATASTORE_RETRIES = 3
local BASE_RETRY_DELAY = 1

local PURCHASE_ERROR_TYPES = {
	ALREADY_PROCESSING = "ALREADY_PROCESSING",
	PROMPTS_DISABLED = "PROMPTS_DISABLED",
	INVALID_ASSET_ID = "INVALID_ASSET_ID",
	IS_CREATOR = "IS_CREATOR",
	ALREADY_OWNED = "ALREADY_OWNED",
	API_ERROR = "API_ERROR",
}

local ERROR_MESSAGES = {
	CANNOT_PURCHASE_CREATED = "Cannot purchase your own passes!",
	CANNOT_PURCHASE_OWNED = "You already own that pass!",
	PROMPTS_DISABLED = "Purchases are currently disabled",
	INVALID_ASSET = "Invalid gamepass",
}

---------------
-- Variables --
---------------

local isPurchaseCurrentlyProcessing = false

---------------
-- Functions --
---------------

local function calculateRetryDelay(attemptNumber)
	return BASE_RETRY_DELAY * attemptNumber
end

local function resetPurchaseProcessingState(cooldownSeconds)
	task.delay(cooldownSeconds, function()
		isPurchaseCurrentlyProcessing = false
	end)
end

local function arePromptsDisabled(player)
	return player:GetAttribute("PromptsDisabled") == true
end

local function isValidGamePassAssetId(assetId)
	return ValidationUtils.isValidNumber(assetId) and assetId > 0
end

local function isPlayerGamePassCreator(player, assetId)
	local success, result = pcall(function()
		local productInfo = MarketplaceService:GetProductInfo(assetId, Enum.InfoType.GamePass)
		
		return productInfo.Creator.Id == player.UserId
	end)

	if success then
		return true, result
	end

	return false, false
end

local function doesPlayerOwnGamePass(player, assetId)
	local success, ownsPass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, assetId)
	end)

	if success then
		if ownsPass then
			return success, true
		end
	end

	if player:GetAttribute(tostring(assetId)) == true then
		return success, true
	end

	return success, false
end

local function fetchGamepassProductInfo(gamepassAssetId)
	for attempt = 1, MAX_DATASTORE_RETRIES do
		local success, result = pcall(function()
			return MarketplaceService:GetProductInfo(gamepassAssetId, Enum.InfoType.GamePass)
		end)

		if success then
			return result
		end

		warn(`GetProductInfo attempt {attempt}/{MAX_DATASTORE_RETRIES} failed: {tostring(result)}`)

		if attempt < MAX_DATASTORE_RETRIES then
			task.wait(calculateRetryDelay(attempt))
		end
	end

	return nil
end

local function playSound(sound)
	if sound and sound:IsA("Sound") then
		sound:Play()
	end
end

function GamePassPurchaseHandler.attemptPurchase(config)
	if isPurchaseCurrentlyProcessing then
		return {
			success = false,
			errorType = PURCHASE_ERROR_TYPES.ALREADY_PROCESSING,
			errorMessage = nil,
		}
	end

	if arePromptsDisabled(config.player) then
		return {
			success = false,
			errorType = PURCHASE_ERROR_TYPES.PROMPTS_DISABLED,
			errorMessage = ERROR_MESSAGES.PROMPTS_DISABLED,
		}
	end

	if not isValidGamePassAssetId(config.assetId) then
		return {
			success = false,
			errorType = PURCHASE_ERROR_TYPES.INVALID_ASSET_ID,
			errorMessage = ERROR_MESSAGES.INVALID_ASSET,
		}
	end

	isPurchaseCurrentlyProcessing = true
	local cooldownSeconds = config.cooldownSeconds or DEFAULT_PURCHASE_COOLDOWN_SECONDS
	resetPurchaseProcessingState(cooldownSeconds)

	if config.sounds then
		playSound(config.sounds.click)
	end

	--[[local creatorCheckSuccess, isCreator = isPlayerGamePassCreator(config.player, config.assetId)
	if isCreator then
		if config.sounds then
			playSound(config.sounds.error)
		end
		if config.onError then
			config.onError(PURCHASE_ERROR_TYPES.IS_CREATOR, ERROR_MESSAGES.CANNOT_PURCHASE_CREATED)
		end
		return {
			success = false,
			errorType = PURCHASE_ERROR_TYPES.IS_CREATOR,
			errorMessage = ERROR_MESSAGES.CANNOT_PURCHASE_CREATED,
		}
	end

	local passCheckSuccess, ownsPass = doesPlayerOwnGamePass(config.player, config.assetId)
	if ownsPass then
		if config.sounds then
			playSound(config.sounds.error)
		end
		if config.onError then
			config.onError(PURCHASE_ERROR_TYPES.ALREADY_OWNED, ERROR_MESSAGES.CANNOT_PURCHASE_OWNED)
		end
		return {
			success = false,
			errorType = PURCHASE_ERROR_TYPES.ALREADY_OWNED,
			errorMessage = ERROR_MESSAGES.CANNOT_PURCHASE_OWNED,
		}
	end]]

	if config.isDevProduct then
		MarketplaceService:PromptProductPurchase(config.player, config.assetId)
	else
		MarketplaceService:PromptGamePassPurchase(config.player, config.assetId)
	end

	if config.onSuccess then
		config.onSuccess()
	end

	return {
		success = true,
		errorType = nil,
		errorMessage = nil,
	}
end

function GamePassPurchaseHandler.arePromptsDisabled(player)
	return arePromptsDisabled(player)
end

function GamePassPurchaseHandler.isProcessing()
	return isPurchaseCurrentlyProcessing
end

function GamePassPurchaseHandler.isValidAssetId(assetId)
	return isValidGamePassAssetId(assetId)
end

function GamePassPurchaseHandler.getErrorMessage(errorType)
	if errorType == PURCHASE_ERROR_TYPES.IS_CREATOR then
		return ERROR_MESSAGES.CANNOT_PURCHASE_CREATED
	elseif errorType == PURCHASE_ERROR_TYPES.ALREADY_OWNED then
		return ERROR_MESSAGES.CANNOT_PURCHASE_OWNED
	elseif errorType == PURCHASE_ERROR_TYPES.PROMPTS_DISABLED then
		return ERROR_MESSAGES.PROMPTS_DISABLED
	elseif errorType == PURCHASE_ERROR_TYPES.INVALID_ASSET_ID then
		return ERROR_MESSAGES.INVALID_ASSET
	end
	return nil
end

---------------------------
-- Expose Module Methods --
---------------------------

GamePassPurchaseHandler.doesPlayerOwnPass = doesPlayerOwnGamePass
GamePassPurchaseHandler.isPlayerCreator = isPlayerGamePassCreator
GamePassPurchaseHandler.fetchPassInfo = fetchGamepassProductInfo

-------------------
-- Return Module --
-------------------

return GamePassPurchaseHandler