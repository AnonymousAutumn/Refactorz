-----------------
-- Init Module --
-----------------

local DonationStatistics = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

----------------
-- References --
----------------

local networkFolder = ReplicatedStorage.Network
local remoteEvents = networkFolder.Remotes.Events
local notificationRemoteEvent = remoteEvents.CreateNotification
local messageRemoteEvent = remoteEvents.SendMessage

local modulesFolder = ReplicatedStorage.Modules
local configurationFolder = ReplicatedStorage.Configuration
local PlayerData = require(modulesFolder.Managers.PlayerData)
local DataStores = require(modulesFolder.Wrappers.DataStores)
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local GameConfig = require(configurationFolder.GameConfig)
local DonationMessaging = require(script.Parent.DonationMessaging)

local LARGE_DONATION_BROADCAST_TOPIC = GameConfig.MESSAGING_SERVICE_CONFIG.LARGE_DONATION_TOPIC
local LARGE_DONATION_THRESHOLD_AMOUNT = GameConfig.MESSAGING_SERVICE_CONFIG.DONATION_THRESHOLD

---------------
-- Constants --
---------------

local CLIENT_NOTIFICATION_TYPES = {
	SUCCESS = "Success",
	WARNING = "Warning",
	ERROR = "Error",
}

local DONATION_CONFIRMATION_FORMAT = "Your %s has been sent to %s!"
local PURCHASE_CANCELLED_MESSAGE = "Your purchase was cancelled."
local DONATION_FAILED_MESSAGE = "Failed to process donation. Please try again."
local DEVELOPER_PRODUCT_CONFIRMATION_MESSAGE = "Thank you for your contribution to development!"

local TRANSACTION_TYPE_DONATION = "donation"
local TRANSACTION_TYPE_GIFT = "gift"

local ACTION_VERB_DONATED = "donated"
local ACTION_VERB_GIFTED = "gifted"

local STAT_KEY_DONATED = "Donated"
local STAT_KEY_RAISED = "Raised"

local MIN_GIFT_AMOUNT = 1

---------------
-- Functions --
---------------

local function isValidGiftAmount(amount)
	return ValidationUtils.isValidNumber(amount) and amount >= MIN_GIFT_AMOUNT
end

local function incrementDonatedDataStore(playerId, incrementAmount)
	if not ValidationUtils.isValidUserId(playerId) or not isValidGiftAmount(incrementAmount) then
		warn(`[{script.Name}] Invalid parameters for Donated DataStore increment: userId={tostring(playerId)}, amount={tostring(incrementAmount)}`)
		return 0
	end

	local success, result = DataStores.Donated:incrementAsync(tostring(playerId), incrementAmount)

	if success then
		return result or 0
	else
		warn(`[{script.Name}] Failed to increment Donated DataStore for player {playerId}: {tostring(result)}`)
		return 0
	end
end

local function incrementRaisedDataStore(playerId, incrementAmount)
	if not ValidationUtils.isValidUserId(playerId) or not isValidGiftAmount(incrementAmount) then
		warn(`[{script.Name}] Invalid parameters for Raised DataStore increment: userId={tostring(playerId)}, amount={tostring(incrementAmount)}`)
		return 0
	end

	local success, result = DataStores.Raised:incrementAsync(tostring(playerId), incrementAmount)

	if success then
		return result or 0
	else
		warn(`[{script.Name}] Failed to increment Raised DataStore for player {playerId}: {tostring(result)}`)
		return 0
	end
end

local function sendClientNotification(player, message, notificationType)
	if not ValidationUtils.isValidPlayer(player) then
		warn(`[{script.Name}] Invalid player for notification`)
		return
	end

	local success = pcall(function()
		notificationRemoteEvent:FireClient(player, message, notificationType)
	end)

	if not success then
		warn(`[{script.Name}] Failed to send notification to player {player.Name}`)
	end
end

local function formatDonationConfirmation(recipientDisplayName, recipientIsOnline)
	local transactionType = if recipientIsOnline then TRANSACTION_TYPE_DONATION else TRANSACTION_TYPE_GIFT
	return `Your {transactionType} has been sent to {recipientDisplayName}!`
end

function DonationStatistics.sendDonationConfirmationToPlayer(donorPlayer, recipientDisplayName, recipientIsOnline)
	if not ValidationUtils.isValidPlayer(donorPlayer) then
		warn(`[{script.Name}] Invalid donor player for confirmation`)
		return
	end

	local confirmationMessage = formatDonationConfirmation(recipientDisplayName, recipientIsOnline)
	sendClientNotification(donorPlayer, confirmationMessage, CLIENT_NOTIFICATION_TYPES.SUCCESS)
end

function DonationStatistics.sendPurchaseCancellationNotification(player)
	sendClientNotification(player, PURCHASE_CANCELLED_MESSAGE, CLIENT_NOTIFICATION_TYPES.WARNING)
end

function DonationStatistics.sendDonationFailureNotification(player)
	sendClientNotification(player, DONATION_FAILED_MESSAGE, CLIENT_NOTIFICATION_TYPES.ERROR)
end

function DonationStatistics.sendDeveloperProductConfirmation(player)
	if not ValidationUtils.isValidPlayer(player) then
		warn(`[{script.Name}] Invalid player for developer product confirmation`)
		return
	end

	sendClientNotification(player, DEVELOPER_PRODUCT_CONFIRMATION_MESSAGE, CLIENT_NOTIFICATION_TYPES.SUCCESS)
end

local function getDonationActionVerb(recipientIsOnline)
	return if recipientIsOnline then ACTION_VERB_DONATED else ACTION_VERB_GIFTED
end

local function announceToAllClients(donorName, recipientName, actionVerb, amount)
	local success = pcall(function()
		messageRemoteEvent:FireAllClients(donorName, recipientName, actionVerb, amount)
	end)
	if not success then
		warn(`[{script.Name}] Failed to announce donation to all clients`)
	end
end

local function broadcastLargeDonation(donorName, recipientName, actionVerb, amount)
	DonationMessaging.broadcastToMessagingService(LARGE_DONATION_BROADCAST_TOPIC, {
		Donor = donorName,
		Receiver = recipientName,
		Amount = amount,
		Filler = actionVerb,
	})
end

function DonationStatistics.announceDonationToAllPlayers(donorPlayer, recipientDisplayName, donationAmount, recipientIsCurrentlyOnline)
	if not ValidationUtils.isValidPlayer(donorPlayer) then
		warn(`[{script.Name}] Invalid donor player for announcement`)
		return
	end
	if not isValidGiftAmount(donationAmount) then
		warn(`[{script.Name}] Invalid donation amount for announcement: {tostring(donationAmount)}`)
		return
	end

	local donationActionVerb = getDonationActionVerb(recipientIsCurrentlyOnline)

	if donationAmount >= LARGE_DONATION_THRESHOLD_AMOUNT then

		broadcastLargeDonation(donorPlayer.Name, recipientDisplayName, donationActionVerb, donationAmount)
	else

		announceToAllClients(donorPlayer.Name, recipientDisplayName, donationActionVerb, donationAmount)
	end
end

local function updatePlayerStatistics(userId, statKey, amount)
	local success, errorMessage = pcall(function()
		PlayerData:IncrementPlayerStatistic(userId, statKey, amount)
	end)
	if not success then
		warn(`[{script.Name}] Failed to update player statistics for {userId}: {tostring(errorMessage)}`)
		return false
	end
	return true
end

function DonationStatistics.updateDonationStatistics(donorUserId, recipientUserId, transactionAmount)
	if not ValidationUtils.isValidUserId(donorUserId) or not ValidationUtils.isValidUserId(recipientUserId) or not isValidGiftAmount(transactionAmount) then
		warn(`[{script.Name}] Invalid statistics update parameters: donor={tostring(donorUserId)}, recipient={tostring(recipientUserId)}, amount={tostring(transactionAmount)}`)
		return false
	end

	local donatedSuccess = incrementDonatedDataStore(donorUserId, transactionAmount)
	local raisedSuccess = incrementRaisedDataStore(recipientUserId, transactionAmount)

	local localDonatedSuccess = updatePlayerStatistics(donorUserId, STAT_KEY_DONATED, transactionAmount)
	local localRaisedSuccess = updatePlayerStatistics(recipientUserId, STAT_KEY_RAISED, transactionAmount)

	return (donatedSuccess > 0 or raisedSuccess > 0 or localDonatedSuccess or localRaisedSuccess)
end

function DonationStatistics.updateDonorStatisticsOnly(donorUserId, transactionAmount)
	if not ValidationUtils.isValidUserId(donorUserId) or not isValidGiftAmount(transactionAmount) then
		warn(`[{script.Name}] Invalid donor statistics update parameters: donor={tostring(donorUserId)}, amount={tostring(transactionAmount)}`)
		return false
	end

	local donatedSuccess = incrementDonatedDataStore(donorUserId, transactionAmount)
	local localDonatedSuccess = updatePlayerStatistics(donorUserId, STAT_KEY_DONATED, transactionAmount)

	return (donatedSuccess > 0 or localDonatedSuccess)
end

function DonationStatistics.updateDonorStatisticsWithReceipt(donorUserId, purchaseId, transactionAmount)
	if not ValidationUtils.isValidUserId(donorUserId) or not isValidGiftAmount(transactionAmount) then
		warn(`[{script.Name}] Invalid donor statistics update parameters: donor={tostring(donorUserId)}, amount={tostring(transactionAmount)}`)
		return false, "invalid_params"
	end

	if type(purchaseId) ~= "string" or purchaseId == "" then
		warn(`[{script.Name}] Invalid purchase ID: {tostring(purchaseId)}`)
		return false, "invalid_params"
	end

	local success, newStatValue, status = PlayerData:ProcessReceiptAndIncrementStatistic(
		donorUserId,
		purchaseId,
		STAT_KEY_DONATED,
		transactionAmount
	)

	if not success then
		return false, status
	end

	if status == "newly_processed" then
		incrementDonatedDataStore(donorUserId, transactionAmount)
	end

	return true, status
end

-------------------
-- Return Module --
-------------------

return DonationStatistics