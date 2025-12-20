--[[
	GamePassPurchaseHandler - Handles gamepass purchase flow.

	Features:
	- Purchase validation
	- Error handling
	- Sound effects
]]

local GamePassPurchaseHandler = {}

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)

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

local isPurchaseCurrentlyProcessing = false

local function calculateRetryDelay(attemptNumber: number): number
	return BASE_RETRY_DELAY * attemptNumber
end

local function resetPurchaseProcessingState(cooldownSeconds: number)
	task.delay(cooldownSeconds, function()
		isPurchaseCurrentlyProcessing = false
	end)
end

local function arePromptsDisabled(player: Player): boolean
	return player:GetAttribute("PromptsDisabled") == true
end

local function isValidGamePassAssetId(assetId: number): boolean
	return ValidationUtils.isValidNumber(assetId) and assetId > 0
end

local function isPlayerGamePassCreator(player: Player, assetId: number): (boolean, boolean)
	local success, result = pcall(function()
		local productInfo = MarketplaceService:GetProductInfo(assetId, Enum.InfoType.GamePass)
		
		return productInfo.Creator.Id == player.UserId
	end)

	if success then
		return true, result
	end

	return false, false
end

local function doesPlayerOwnGamePass(player: Player, assetId: number): (boolean, boolean)
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

local function fetchGamepassProductInfo(gamepassAssetId: number): any?
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

local function playSound(sound: Sound?)
	if sound and sound:IsA("Sound") then
		sound:Play()
	end
end

--[[
	Attempts to purchase a gamepass.
]]
function GamePassPurchaseHandler.attemptPurchase(config: any): any
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

--[[
	Checks if prompts are disabled for a player.
]]
function GamePassPurchaseHandler.arePromptsDisabled(player: Player): boolean
	return arePromptsDisabled(player)
end

--[[
	Checks if a purchase is currently processing.
]]
function GamePassPurchaseHandler.isProcessing(): boolean
	return isPurchaseCurrentlyProcessing
end

--[[
	Checks if an asset ID is valid.
]]
function GamePassPurchaseHandler.isValidAssetId(assetId: number): boolean
	return isValidGamePassAssetId(assetId)
end

--[[
	Gets the error message for a given error type.
]]
function GamePassPurchaseHandler.getErrorMessage(errorType: string): string?
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

GamePassPurchaseHandler.doesPlayerOwnPass = doesPlayerOwnGamePass
GamePassPurchaseHandler.isPlayerCreator = isPlayerGamePassCreator
GamePassPurchaseHandler.fetchPassInfo = fetchGamepassProductInfo

return GamePassPurchaseHandler