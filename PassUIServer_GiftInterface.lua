-----------------
-- Init Module --
-----------------

local GiftInterface = {}
GiftInterface.retrievePlayerDonationInterface = nil
GiftInterface.refreshDataDisplayLabel = nil
GiftInterface.populateGamepassDisplayFrame = nil
GiftInterface.getOrCreatePlayerUIState = nil

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
local highlightRemoteEvent = remoteEvents.CreateHighlight

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local EnhancedValidation = require(modulesFolder.Utilities.EnhancedValidation)
local RateLimiter = require(modulesFolder.Utilities.RateLimiter)

---------------
-- Constants --
---------------

local GIFTING_ATTRIBUTE_NAME = "Gifting"

---------------
-- Functions --
---------------

local function unequipHeldTool(player)
	local character = player.Character
	if not character then
		return
	end

	local equippedTool = character:FindFirstChildOfClass("Tool")
	if equippedTool then
		local backpack = player:FindFirstChild("Backpack")
		if backpack then
			equippedTool.Parent = backpack
		end
	end
end

function GiftInterface.handleGiftInterfaceToggle(giftGiver, giftRecipient: Player | number)

	if not EnhancedValidation.validatePlayer(giftGiver) then
		warn(`[{script.Name}] Invalid gift giver`)
		return
	end

	local isValidRecipient = false
	if typeof(giftRecipient) == "Instance" and giftRecipient:IsA("Player") then
		isValidRecipient = ValidationUtils.isValidPlayer(giftRecipient)
	elseif typeof(giftRecipient) == "number" then
		isValidRecipient = EnhancedValidation.validateUserId(giftRecipient)
	end

	if not isValidRecipient then
		warn(`[{script.Name}] Invalid gift recipient`)
		return
	end

	if not RateLimiter.checkRateLimit(giftGiver, "ToggleGiftUI", 1) then
		return
	end

	local success = pcall(function()
		highlightRemoteEvent:FireClient(giftGiver, nil)
		unequipHeldTool(giftGiver)

		giftGiver:SetAttribute(GIFTING_ATTRIBUTE_NAME, true)

		if GiftInterface.getOrCreatePlayerUIState then
			local state = GiftInterface.getOrCreatePlayerUIState(giftGiver)
			state.isGifting = true
		end

		local giftingContext = { Viewer = giftGiver, Viewing = giftRecipient }

		local giftInterface = nil
		if GiftInterface.retrievePlayerDonationInterface then
			giftInterface = GiftInterface.retrievePlayerDonationInterface(giftGiver, true)
		end

		if not giftInterface then
			warn(`[{script.Name}] Failed to retrieve gift interface`)
			return
		end

		giftInterface.MainFrame.Visible = true
		giftInterface.CloseButton.Visible = true

		if GiftInterface.refreshDataDisplayLabel then
			GiftInterface.refreshDataDisplayLabel(true, giftingContext, false)
		end

		if GiftInterface.populateGamepassDisplayFrame then
			GiftInterface.populateGamepassDisplayFrame(giftingContext, false, true)
		end
	end)

	if not success then
		warn(`[{script.Name}] Error toggling gift interface for {giftGiver.Name}`)
	end
end

-------------------
-- Return Module --
-------------------

return GiftInterface