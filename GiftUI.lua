--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

----------------
-- References --
----------------

local localPlayer = Players.LocalPlayer
local localPlayerGui = localPlayer:WaitForChild("PlayerGui")

local modulesFolder = ReplicatedStorage.Modules
local Connections = require(modulesFolder.Wrappers.Connections)
local TimeFormatter = require(script.TimeFormatter)
local UIRenderer = require(script.UIRenderer)
local ValidationHandler = require(script.ValidationHandler)
local ServerComms = require(script.ServerComms)
local StateManager = require(script.StateManager)
local ErrorDisplay = require(script.ErrorDisplay)
local BackgroundTasks = require(script.BackgroundTasks)

local networkFolder = ReplicatedStorage:WaitForChild("Network") 
local remoteEvents = networkFolder.Remotes.Events
local remoteFunctions = networkFolder.Remotes.Functions
local toggleGiftUIEvent = remoteEvents.ToggleGiftUI
local clearGiftDataEvent = remoteEvents.ClearGifts
local requestGiftDataFunction = remoteFunctions.RequestGifts

local instancesFolder = ReplicatedStorage.Instances
local giftReceivedPrefab = instancesFolder.GuiPrefabs.GiftReceivedPrefab

---------------
-- Variables --
---------------

local GiftUIState = {
	activeGiftTimeDisplayEntries = {},
	cachedGiftDataFromServer = {},
	currentUnreadGiftCount = 0,
	connections = Connections.new(),
	threads = {},
	isInitialized = false,
}

local giftDisplayFrame
local giftEntriesScrollingFrame
local giftInterfaceCloseButton
local sendGiftInterfaceFrame
local usernameInputFrame
local errorMessageDisplayFrame
local errorMessageLabel
local usernameInputTextBox
local giftSendConfirmationButton
local giftNotificationButton
local giftCountNotificationLabel

---------------
-- Functions --
---------------

local function safeExecute(func)
	local success, errorMessage = pcall(func)
	if not success then
		warn(`[GiftUI] Error: {errorMessage}`)
	end
	return success
end

-- ouuuuuuuuuuuuuuggggh I love helldivers 2
ServerComms.safeExecute = safeExecute
StateManager.safeExecute = safeExecute
ErrorDisplay.safeExecute = safeExecute

local function updateGiftNotificationBadgeDisplay(unreadGiftCount)
	StateManager.updateGiftNotificationBadgeDisplay(
		{ giftCountNotificationLabel = giftCountNotificationLabel },
		unreadGiftCount
	)
end

local function displayTemporaryErrorMessage(errorMessageText)
	local errorDisplayElements = {
		errorMessageDisplayFrame = errorMessageDisplayFrame,
		errorMessageLabel = errorMessageLabel,
		usernameInputTextBox = usernameInputTextBox,
		giftSendConfirmationButton = giftSendConfirmationButton,
	}
	ErrorDisplay.displayTemporaryErrorMessage(errorDisplayElements, errorMessageText)
end

local function requestLatestGiftDataFromServer()
	local retrievedGiftData = ServerComms.requestLatestGiftDataFromServer(requestGiftDataFunction)

	if not retrievedGiftData then
		return
	end

	GiftUIState.cachedGiftDataFromServer = retrievedGiftData

	if giftDisplayFrame.Visible then
		UIRenderer.populateGiftDisplayWithServerData(
			retrievedGiftData,
			{
				giftReceivedPrefab = giftReceivedPrefab,
				giftEntriesScrollingFrame = giftEntriesScrollingFrame,
			},
			GiftUIState.activeGiftTimeDisplayEntries,
			safeExecute
		)
	else
		GiftUIState.currentUnreadGiftCount = #retrievedGiftData
		updateGiftNotificationBadgeDisplay(GiftUIState.currentUnreadGiftCount)
	end
end

local function clearAllGiftDisplayElements()
	local children = giftEntriesScrollingFrame:GetChildren()
	for i, childElement in children do
		if not childElement:IsA("UIListLayout") then
			safeExecute(function()
				childElement:Destroy()
			end)
		end
	end
end

local function clearAllGiftDataAndInterface()
	clearAllGiftDisplayElements()

	giftDisplayFrame.Visible = false
	updateGiftNotificationBadgeDisplay(0)

	StateManager.resetGiftState(GiftUIState)
	ServerComms.notifyServerOfGiftClearance(clearGiftDataEvent)
end

local function showGiftDisplayFrame()
	safeExecute(function()
		giftDisplayFrame.Visible = true
		sendGiftInterfaceFrame.Visible = false
		UIRenderer.populateGiftDisplayWithServerData(
			GiftUIState.cachedGiftDataFromServer,
			{
				giftReceivedPrefab = giftReceivedPrefab,
				giftEntriesScrollingFrame = giftEntriesScrollingFrame,
			},
			GiftUIState.activeGiftTimeDisplayEntries,
			safeExecute
		)
		GiftUIState.currentUnreadGiftCount = 0
		updateGiftNotificationBadgeDisplay(0)
		ServerComms.notifyServerOfGiftClearance(clearGiftDataEvent)
	end)
end

local function toggleGiftDisplayFrameVisibility()
	if GiftUIState.currentUnreadGiftCount <= 0 then
		return
	end

	if giftDisplayFrame.Visible then
		clearAllGiftDataAndInterface()
	else
		showGiftDisplayFrame()
	end
end

local function validateUsernameAndInitiateGiftProcess()
	if errorMessageDisplayFrame.Visible then
		return
	end

	local enteredUsername = usernameInputTextBox.Text
	if not ValidationHandler.validateUsernameInput(enteredUsername, displayTemporaryErrorMessage) then
		return
	end

	task.spawn(function()
		local targetPlayerUserId = ValidationHandler.retrieveUserIdFromUsername(enteredUsername)
		if not ValidationHandler.validateTargetUserId(targetPlayerUserId, displayTemporaryErrorMessage) then
			return
		end

		local verifiedPlayerName = ValidationHandler.retrieveUsernameFromUserId(targetPlayerUserId )
		if not ValidationHandler.validateTargetUsername(verifiedPlayerName, displayTemporaryErrorMessage) then
			return
		end

		if ValidationHandler.isGiftingToSelf(verifiedPlayerName , localPlayer.Name, displayTemporaryErrorMessage) then
			return
		end

		ServerComms.initiateGiftProcess(toggleGiftUIEvent, targetPlayerUserId )
		sendGiftInterfaceFrame.Visible = false
	end)
end

local function handleGiftNotificationButtonClick()
	if giftDisplayFrame.Visible then
		clearAllGiftDataAndInterface()
	elseif sendGiftInterfaceFrame.Visible then
		sendGiftInterfaceFrame.Visible = false
		if GiftUIState.currentUnreadGiftCount > 0 then
			toggleGiftDisplayFrameVisibility()
		end
	else
		if GiftUIState.currentUnreadGiftCount > 0 then
			toggleGiftDisplayFrameVisibility()
		else
			sendGiftInterfaceFrame.Visible = true
		end
	end
end

local function initializeGiftSystemOnStartup()
	if GiftUIState.isInitialized then
		return
	end

	requestLatestGiftDataFromServer()

	if GiftUIState.currentUnreadGiftCount > 0 then
		safeExecute(function()
			giftDisplayFrame.Visible = true
			UIRenderer.populateGiftDisplayWithServerData(
				GiftUIState.cachedGiftDataFromServer,
				{
					giftReceivedPrefab = giftReceivedPrefab,
					giftEntriesScrollingFrame = giftEntriesScrollingFrame,
				},
				GiftUIState.activeGiftTimeDisplayEntries,
				safeExecute
			)
			updateGiftNotificationBadgeDisplay(0)
			GiftUIState.currentUnreadGiftCount = 0
			ServerComms.notifyServerOfGiftClearance(clearGiftDataEvent)
		end)
	end

	GiftUIState.isInitialized = true
end

local function cleanup()
	GiftUIState.connections:disconnect()

	for _, thread in ipairs(GiftUIState.threads) do
		pcall(function()
			if thread then
				task.cancel(thread)
			end
		end)
	end
	table.clear(GiftUIState.threads)

	StateManager.resetGiftState(GiftUIState)
	GiftUIState.isInitialized = false
end

local function initialize()
	local screenGui = localPlayerGui:WaitForChild("GiftUI")
	if not screenGui then
		warn("GiftUI ScreenGui not found in PlayerGui")
		return
	end

	local topbarUserInterface = localPlayerGui:WaitForChild("TopbarUI")
	local topbarMainFrame = topbarUserInterface:WaitForChild("MainFrame")
	local topbarContentHolder = topbarMainFrame:WaitForChild("Holder")
	giftNotificationButton = topbarContentHolder:WaitForChild("GiftButton") 
	giftCountNotificationLabel = giftNotificationButton:WaitForChild("CountLabel") 

	giftDisplayFrame = screenGui:WaitForChild("GiftFrame") 
	giftEntriesScrollingFrame = giftDisplayFrame:WaitForChild("ScrollingFrame") 
	giftInterfaceCloseButton = giftDisplayFrame:WaitForChild("CloseButton") 

	sendGiftInterfaceFrame = screenGui:WaitForChild("SendGiftFrame") 
	usernameInputFrame = sendGiftInterfaceFrame:WaitForChild("InputFrame") 
	errorMessageDisplayFrame = usernameInputFrame:WaitForChild("InvalidFrame") 
	errorMessageLabel = errorMessageDisplayFrame:WaitForChild("TextLabel") 
	usernameInputTextBox = usernameInputFrame:WaitForChild("TextBox")
	giftSendConfirmationButton = sendGiftInterfaceFrame:WaitForChild("ConfirmButton")

	-- Use Activated for cross-platform support (PC, Mobile, Console)
	GiftUIState.connections:add(
		giftNotificationButton.Activated:Connect(handleGiftNotificationButtonClick),
		giftSendConfirmationButton.Activated:Connect(validateUsernameAndInitiateGiftProcess),
		giftInterfaceCloseButton.Activated:Connect(clearAllGiftDataAndInterface),
		screenGui.AncestryChanged:Connect(function()
			if not screenGui:IsDescendantOf(game) then
				cleanup()
			end
		end),
		localPlayer.AncestryChanged:Connect(function()
			if not localPlayer:IsDescendantOf(game) then
				cleanup()
			end
		end)
	)

	BackgroundTasks.requestLatestGiftDataCallback = requestLatestGiftDataFromServer
	BackgroundTasks.updateTimeDisplayCallback = function()
		TimeFormatter.updateAllGiftTimeDisplayLabels(GiftUIState.activeGiftTimeDisplayEntries, safeExecute)
	end

	task.spawn(initializeGiftSystemOnStartup)
	BackgroundTasks.startContinuousGiftDataRefreshLoop(GiftUIState.threads)
	BackgroundTasks.startContinuousTimeDisplayUpdateLoop(GiftUIState.threads, giftDisplayFrame)
end

--------------------
-- Initialization --
--------------------

initialize()