-----------------
-- Init Module --
-----------------

local GiftPersistence = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local UsernameCache = require(modulesFolder.Caches.UsernameCache)
local DataStores = require(modulesFolder.Wrappers.DataStores)
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)

---------------
-- Constants --
---------------

local MIN_GIFT_AMOUNT = 1
local MAX_GIFTS_PER_PLAYER = 100

---------------
-- Functions --
---------------

local function isValidGiftAmount(amount)
	return ValidationUtils.isValidNumber(amount) and amount >= MIN_GIFT_AMOUNT
end

local function isValidGiftRecord(record)
	if typeof(record) ~= "table" then
		return false
	end
	return ValidationUtils.isValidUserId(record.from)
		and isValidGiftAmount(record.amount)
		and typeof(record.timestamp) == "number"
		and typeof(record.id) == "string"
end

local function constructGiftRecord(donorUserId, giftAmount)
	if not ValidationUtils.isValidUserId(donorUserId) or not isValidGiftAmount(giftAmount) then
		warn(`[{script.Name}] Invalid gift record parameters: donor={tostring(donorUserId)}, amount={tostring(giftAmount)}`)
		return nil
	end

	return {
		from = donorUserId,
		amount = giftAmount,
		timestamp = os.time(),
		id = HttpService:GenerateGUID(false),
	}
end

local function validateGiftRecords(records)
	local validRecords = {}

	if type(records) ~= "table" then
		return validRecords
	end

	for _, record in records do
		if isValidGiftRecord(record) then
			table.insert(validRecords, record)
		end
	end

	return validRecords
end

local function enforceGiftLimit(giftHistory, recipientUserId)
	if #giftHistory >= MAX_GIFTS_PER_PLAYER then
		warn(`[{script.Name}] Player {recipientUserId} has reached maximum gift limit ({MAX_GIFTS_PER_PLAYER})`)
		table.remove(giftHistory, 1)
	end
end

function GiftPersistence.saveGiftToDataStore(donorUserId, recipientUserId, giftAmount)
	if not ValidationUtils.isValidUserId(donorUserId)
		or not ValidationUtils.isValidUserId(recipientUserId)
		or not isValidGiftAmount(giftAmount) then
		warn(`[{script.Name}] Invalid gift save parameters: donor={tostring(donorUserId)}, recipient={tostring(recipientUserId)}, amount={tostring(giftAmount)}`)
		return false
	end

	local recipientDataKey = tostring(recipientUserId)

	local success, result = DataStores.Gifts:updateAsync(
		recipientDataKey,
		function(existingGiftRecords)
			local recipientGiftHistory = validateGiftRecords(existingGiftRecords)
			enforceGiftLimit(recipientGiftHistory, recipientUserId)

			local newGift = constructGiftRecord(donorUserId, giftAmount)
			if newGift then
				table.insert(recipientGiftHistory, newGift)
			end

			return recipientGiftHistory
		end
	)

	if success then
		return true
	else
		warn(`[{script.Name}] Failed to save gift: {tostring(result)}`)
		return false
	end
end

local function formatGiftRecord(giftRecord)
	local giftSenderName = UsernameCache.getUsername(giftRecord.from)
	return {
		Id = giftRecord.id,
		Gifter = giftSenderName,
		Amount = giftRecord.amount,
		Timestamp = giftRecord.timestamp,
	}
end

function GiftPersistence.retrievePlayerGiftHistory(requestingPlayer)
	if not ValidationUtils.isValidPlayer(requestingPlayer) then
		warn(`[{script.Name}] Invalid player for gift retrieval`)
		return {}
	end

	local playerDataKey = tostring(requestingPlayer.UserId)

	local success, result = DataStores.Gifts:getAsync(playerDataKey)

	if not success then
		warn(`[{script.Name}] Failed to retrieve gifts for player {requestingPlayer.UserId}: {tostring(result)}`)
		return {}
	end

	local formattedGiftList = {}
	if type(result) == "table" then
		for _, giftRecord in result do
			if not isValidGiftRecord(giftRecord) then
				warn(`[{script.Name}] Invalid gift record found for player {requestingPlayer.UserId}`)
				continue
			end
			table.insert(formattedGiftList, formatGiftRecord(giftRecord))
		end
	end

	return formattedGiftList
end

function GiftPersistence.removeAllPlayerGifts(targetPlayer)
	if not ValidationUtils.isValidPlayer(targetPlayer) then
		warn("[Transaction.GiftPersistence] Invalid player for gift clearance")
		return false
	end

	local playerDataKey = tostring(targetPlayer.UserId)

	local success, result = DataStores.Gifts:removeAsync(playerDataKey)

	if success then
		return true
	else
		warn(`[{script.Name}] Failed to clear gifts for player {targetPlayer.UserId}: {tostring(result)}`)
		return false
	end
end

-------------------
-- Return Module --
-------------------

return GiftPersistence