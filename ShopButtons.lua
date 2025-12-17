--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

----------------
-- References --
----------------

local localPlayer = Players.LocalPlayer

local networkFolder = ReplicatedStorage.Network
local bindableEvents = networkFolder.Bindables.Events
local sendNotificationEvent = bindableEvents.CreateNotification

local modulesFolder = ReplicatedStorage.Modules
local ButtonWrapper = require(modulesFolder.Wrappers.Buttons)
local PurchaseWrapper = require(modulesFolder.Wrappers.Purchases)
local NotificationHelper = require(modulesFolder.Utilities.NotificationHelper)

local uiSoundGroup = SoundService.UI
local feedbackSoundGroup = SoundService.Feedback

---------------
-- Functions --
---------------

local function handleProductPurchaseButtonInteraction(button)
	local assetId = button:GetAttribute("AssetId")

	PurchaseWrapper.attemptPurchase({
		player = localPlayer,
		assetId = assetId,
		isDevProduct = true,
		sounds = {
			click = uiSoundGroup.Click,
			error = feedbackSoundGroup.Error,
		},
		onError = function(errorType, message)
			NotificationHelper.sendWarning(sendNotificationEvent, message)
		end,
	})
end

local function handleGamePassPurchaseButtonInteraction(button)
	local assetId = button:GetAttribute("AssetId")

	PurchaseWrapper.attemptPurchase({
		player = localPlayer,
		assetId = assetId,
		sounds = {
			click = uiSoundGroup.Click,
			error = feedbackSoundGroup.Error,
		},
		onError = function(errorType, message)
			NotificationHelper.sendWarning(sendNotificationEvent, message)
		end,
	})
end

local function setupProductButtonInteractionHandlers(gamePassButton)
	ButtonWrapper.setupButton({
		button = gamePassButton,
		onClick = handleProductPurchaseButtonInteraction,
		sounds = {
			hover = uiSoundGroup.Hover,
		},
	})
end

local function setupGamePassButtonInteractionHandlers(gamePassButton)
	ButtonWrapper.setupButton({
		button = gamePassButton,
		onClick = handleGamePassPurchaseButtonInteraction,
		sounds = {
			hover = uiSoundGroup.Hover
		},
	})
end

local function initialize()
	local ScrollingFrame = workspace.World.Structures.Store.ProductsHolder.SurfaceGui.MainFrame.ItemScrollingFrame

	for _, instance in pairs(ScrollingFrame:GetChildren()) do
		local getTypeAttribute = instance:GetAttribute("Type")

		if not getTypeAttribute then
			continue
		end

		if getTypeAttribute == "Pass" then
			setupGamePassButtonInteractionHandlers(instance.ButtonPrefab)
		else
			setupProductButtonInteractionHandlers(instance.ButtonPrefab)
		end
	end
end

--------------------
-- Initialization --
--------------------

initialize()