--[[
	PassUI - Client-side gamepass shop interface controller.

	Features:
	- Shop open/close animations
	- Gamepass button interaction handling
	- Session management with cleanup
]]

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local networkFolder = ReplicatedStorage.Network
local bindableEvents = networkFolder.Bindables.Events
local sendNotificationBindableEvent = bindableEvents.CreateNotification

local modulesFolder = ReplicatedStorage.Modules
local Connections = require(modulesFolder.Wrappers.Connections)
local PurchaseWrapper = require(modulesFolder.Wrappers.Purchases)
local ButtonWrapper = require(modulesFolder.Wrappers.Buttons)
local InputCategorizer = require(modulesFolder.Utilities.InputCategorizer)
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local NotificationHelper = require(modulesFolder.Utilities.NotificationHelper)

local uiSoundGroup = SoundService.UI
local feedbackSoundGroup = SoundService.Feedback

local SHOP_ANIMATION_DURATION = 0.2
local SHOP_CLOSED_VERTICAL_OFFSET = -95
local SHOP_OPENED_VERTICAL_OFFSET = -80

local SHOP_ANIMATION_TWEEN_INFO = TweenInfo.new(
	SHOP_ANIMATION_DURATION,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out
)

local connectionsMaid = Connections.new()
local sessionTweens: { Tween } = {}

local gamePassShopMainFrame: Frame? = nil
local gamePassItemsDisplayFrame: ScrollingFrame? = nil
local gamePassItemsLayoutManager: UIListLayout? = nil

local buttonWrapperInitialized = false

local function isValidProductInfo(info: any): boolean
	return typeof(info) == "table"
		and info.Creator ~= nil
		and typeof(info.Creator) == "table"
		and ValidationUtils.isValidNumber(info.Creator.Id) and info.Creator.Id > 0
end

local function safeExecute(func: () -> (), _errorMessage: string?): boolean
	local success = pcall(func)
	return success
end

local function trackConnection(connection: RBXScriptConnection): RBXScriptConnection
	connectionsMaid:add(connection)
	return connection
end

local function trackTween(tween: Tween): Tween
	table.insert(sessionTweens, tween)
	return tween
end

local function updateGamePassItemsScrollingCanvasSize()
	if not gamePassItemsDisplayFrame or not gamePassItemsLayoutManager then
		return
	end

	safeExecute(function()
		gamePassItemsDisplayFrame.CanvasSize = UDim2.new(
			0, gamePassItemsLayoutManager.AbsoluteContentSize.X,
			0, gamePassItemsLayoutManager.AbsoluteContentSize.Y
		)
	end, "Error updating canvas size")
end

local function createShopOpeningAnimation(): Tween?
	if not gamePassShopMainFrame then
		return nil
	end

	local openingAnimation = TweenService:Create(
		gamePassShopMainFrame,
		SHOP_ANIMATION_TWEEN_INFO,
		{ Position = UDim2.new(0.5, 0, 1, SHOP_OPENED_VERTICAL_OFFSET) }
	)
	trackTween(openingAnimation)
	return openingAnimation
end

local function animateGamePassShopInterfaceOpen()
	if not gamePassShopMainFrame then
		return
	end

	safeExecute(function()
		gamePassShopMainFrame.Position = UDim2.new(0.5, 0, 1, SHOP_CLOSED_VERTICAL_OFFSET)
		local shopOpeningAnimation = createShopOpeningAnimation()
		if shopOpeningAnimation then
			shopOpeningAnimation:Play()
		end
		uiSoundGroup.Open:Play()
	end, "Error animating shop open")
end

local function isGamePassButton(element: Instance): boolean
	return element:IsA("TextButton")
end

local function clearAllGamePassItemsFromDisplay()
	if not gamePassItemsDisplayFrame then
		return
	end

	safeExecute(function()
		local children = gamePassItemsDisplayFrame:GetChildren()
		for _, childElement in pairs(children) do
			if isGamePassButton(childElement) then
				childElement:Destroy()
			end
		end
		gamePassItemsDisplayFrame.CanvasPosition = Vector2.zero
	end, "Error clearing GamePass items")
end

local function handleGamePassPurchaseButtonInteraction(button: TextButton)
	local assetId = button:GetAttribute("AssetId")

	PurchaseWrapper.attemptPurchase({
		player = localPlayer,
		assetId = assetId,
		isDevProduct = false,
		sounds = {
			click = uiSoundGroup.Click,
			error = feedbackSoundGroup.Error,
		},
		onError = function(errorType, message)
			NotificationHelper.sendWarning(sendNotificationBindableEvent, message)
		end,
	})
end

local function setupGamePassButtonInteractionHandlers(gamePassButton: TextButton)
	ButtonWrapper.setupButton({
		button = gamePassButton,
		onClick = handleGamePassPurchaseButtonInteraction,
		sounds = {
			hover = uiSoundGroup.Hover,
		},
		connectionTracker = nil,
	})
end

local function handleShopOpening()
	animateGamePassShopInterfaceOpen()
end

local function handleShopClosing()
	uiSoundGroup.Close:Play()
	clearAllGamePassItemsFromDisplay()
end

local function handleGamePassShopVisibilityStateChange()
	if not gamePassShopMainFrame then
		return
	end

	if gamePassShopMainFrame.Visible then
		handleShopOpening()
	else
		handleShopClosing()
	end
end

local function setupExistingButtons()
	if not gamePassItemsDisplayFrame then
		return
	end

	local descendants = gamePassItemsDisplayFrame:GetChildren()
	for i = 1, #descendants do
		local inst = descendants[i]
		if inst:IsA("TextButton") then
			setupGamePassButtonInteractionHandlers(inst)
		end
	end
end

local function cleanupSession()
	connectionsMaid:disconnect()

	for _, tween in pairs(sessionTweens) do
		pcall(function()
			if tween then
				tween:Cancel()
			end
		end)
	end
	table.clear(sessionTweens)

	gamePassShopMainFrame = nil
	gamePassItemsDisplayFrame = nil
	gamePassItemsLayoutManager = nil
end

local function setupSession(): boolean
	cleanupSession()

	local screenGui = playerGui:WaitForChild("PassUI")
	if not screenGui then
		warn(`[{script.Name}] PassUI ScreenGui not found in PlayerGui`)
		return false
	end

	gamePassShopMainFrame = screenGui:WaitForChild("MainFrame") 
	gamePassItemsDisplayFrame = gamePassShopMainFrame:WaitForChild("ItemFrame") 
	gamePassItemsLayoutManager = gamePassItemsDisplayFrame:WaitForChild("UIListLayout") 

	if not buttonWrapperInitialized then
		ButtonWrapper.initialize(InputCategorizer)
		buttonWrapperInitialized = true
	end

	updateGamePassItemsScrollingCanvasSize()
	setupExistingButtons()

	trackConnection(gamePassShopMainFrame:GetPropertyChangedSignal("Visible"):Connect(handleGamePassShopVisibilityStateChange))
	trackConnection(gamePassItemsLayoutManager:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateGamePassItemsScrollingCanvasSize))
	trackConnection(gamePassItemsDisplayFrame.DescendantAdded:Connect(function(instance)
		if instance:IsA("TextButton") then
			setupGamePassButtonInteractionHandlers(instance)
		end
	end))

	trackConnection(
		screenGui.AncestryChanged:Connect(function()
			if not screenGui:IsDescendantOf(game) then
				cleanupSession()
			end
		end)
	)

	return true
end

local function initialize()
	setupSession()

	localPlayer.CharacterAdded:Connect(function()
		setupSession()
	end)

	localPlayer.AncestryChanged:Connect(function()
		if not localPlayer:IsDescendantOf(game) then
			cleanupSession()
		end
	end)
end

initialize()