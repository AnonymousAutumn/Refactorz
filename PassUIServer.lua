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
local bindableEvents = networkFolder.Bindables.Events
local highlightRemoteEvent = remoteEvents.CreateHighlight
local giftUIRemoteEvent = remoteEvents.ToggleGiftUI
local updateUIBindableEvent = bindableEvents.UpdateUI
local toggleUIBindableEvent = bindableEvents.ToggleUI

local modulesFolder = ReplicatedStorage.Modules
local Configuration = ReplicatedStorage.Configuration
local Connections = require(modulesFolder.Wrappers.Connections)
local GamepassCacheManager = require(modulesFolder.Caches.PassCache)
local PassUIUtilities = require(modulesFolder.Utilities.PassUIUtilities)
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local EnhancedValidation = require(modulesFolder.Utilities.EnhancedValidation)
local GameConfig = require(Configuration.GameConfig)
local ComponentBuilder = require(script.ComponentBuilder)
local DisplayRenderer = require(script.DisplayRenderer)
local CooldownManager = require(script.CooldownManager)
local GiftInterface = require(script.GiftInterface)
local StateManager = require(script.StateManager)
local DataLabelManager = require(script.DataLabelManager)

---------------
-- Constants --
---------------

local PLAYER_ATTRIBUTES_REFERENCE = {
	Viewing = "Viewing",
	ViewingOwnPasses = "ViewingOwnPasses",
	Gifting = "Gifting",
	CooldownTime = "CooldownTime",
	PromptsDisabled = "PromptsDisabled",
}

---------------
-- Variables --
---------------

local connectionsMaid = Connections.new()

local playerCooldownRegistry = {}
local playerUIStates = {}

StateManager.playerUIStates = playerUIStates
StateManager.playerCooldownRegistry = playerCooldownRegistry
CooldownManager.playerUIStates = playerUIStates
CooldownManager.playerCooldownRegistry = playerCooldownRegistry

---------------
-- Functions --
---------------

local function trackGlobalConnection(connection)
	connectionsMaid:add(connection)
	return connection
end

local function retrievePlayerDonationInterface(targetPlayer, isInGiftingMode)
	if not ValidationUtils.isValidPlayer(targetPlayer) then
		warn(`[{script.Name}] Invalid player for UI retrieval`)
		return nil
	end

	local playerGuiContainer = targetPlayer:FindFirstChild("PlayerGui")
	if not playerGuiContainer then
		return nil
	end

	local donationInterface = playerGuiContainer:FindFirstChild("PassUI")
	if not donationInterface then
		return nil
	end

	local interfaceComponents = ComponentBuilder.buildUIComponents(donationInterface)
	if not interfaceComponents then
		return nil
	end

	-- CloseButton event handler
	local closeConnection = interfaceComponents.CloseButton.MouseButton1Click:Once(function()
		pcall(function()
			if isInGiftingMode then
				targetPlayer:SetAttribute(PLAYER_ATTRIBUTES_REFERENCE.Gifting, nil)
				local state = StateManager.getPlayerUIState(targetPlayer)
				if state then
					state.isGifting = false
				end
			end

			interfaceComponents.MainFrame.Visible = false
			highlightRemoteEvent:FireClient(targetPlayer, nil)
			StateManager.cleanupPlayerResources(targetPlayer, false)
		end)
	end)
	StateManager.trackPlayerConnection(targetPlayer, closeConnection)

	return interfaceComponents
end

local function refreshDataDisplayLabel(isInGiftingMode, viewingContext, shouldPlayAnimation)
	if not ValidationUtils.isValidPlayer(viewingContext.Viewer) then
		warn(`[{script.Name}] Invalid viewer for data label refresh`)
		return
	end

	local userInterface = retrievePlayerDonationInterface(viewingContext.Viewer, isInGiftingMode)
	if not userInterface then
		return
	end

	local success = pcall(function()
		DataLabelManager.updateDataDisplayLabel(
			userInterface.DataLabel,
			userInterface.TimerLabel,
			userInterface.RefreshButton,
			viewingContext.Viewer,
			viewingContext.Viewing,
			isInGiftingMode,
			shouldPlayAnimation or false,
			StateManager.trackPlayerTween
		)
	end)
	if not success then
		warn(`[{script.Name}] Error refreshing data label for {viewingContext.Viewer.Name}`)
	end
end

local function handleGiftRecipientDisplay(userInterface, currentViewer, giftRecipientRef)
	local recipientUserId = nil
	if typeof(giftRecipientRef) == "number" then
		if ValidationUtils.isValidUserId(giftRecipientRef) then
			recipientUserId = giftRecipientRef
		end
	elseif typeof(giftRecipientRef) == "Instance" and giftRecipientRef:IsA("Player") then
		recipientUserId = giftRecipientRef.UserId
	end

	if not recipientUserId then
		return
	end

	currentViewer:SetAttribute(PLAYER_ATTRIBUTES_REFERENCE.Viewing, recipientUserId)

	local recipientGamepassData = GamepassCacheManager.LoadGiftRecipientGamepassDataTemporarily(recipientUserId)
	local recipientGamepasses = recipientGamepassData and recipientGamepassData.gamepasses or {}

	recipientGamepasses = DisplayRenderer.truncateGamepassList(recipientGamepasses)

	DisplayRenderer.configureEmptyStateVisibility(userInterface, recipientGamepasses, false)
	userInterface.LoadingLabel.Visible = (#recipientGamepasses == 0)

	DisplayRenderer.displayGamepasses(userInterface.ItemFrame, recipientGamepasses, currentViewer, recipientUserId)
end

local function handleStandardPlayerDisplay(userInterface, currentViewer, targetPlayerToView, viewingContext, shouldReloadData)
	if not ValidationUtils.isValidPlayer(targetPlayerToView) then
		warn(`[{script.Name}] Invalid target player for viewing`)
		return
	end

	local isViewingOwnPasses = (viewingContext.Viewing == nil)
	currentViewer:SetAttribute(PLAYER_ATTRIBUTES_REFERENCE.Viewing, targetPlayerToView.UserId)

	if shouldReloadData then
		GamepassCacheManager.ReloadPlayerGamepassDataCache(currentViewer)
	end

	local targetPlayerData = GamepassCacheManager.GetPlayerCachedGamepassData(targetPlayerToView)
	local targetPlayerGamepasses = targetPlayerData and targetPlayerData.gamepasses or {}

	targetPlayerGamepasses = DisplayRenderer.truncateGamepassList(targetPlayerGamepasses)

	DisplayRenderer.configureEmptyStateVisibility(userInterface, targetPlayerGamepasses, isViewingOwnPasses)
	userInterface.LoadingLabel.Visible = DisplayRenderer.shouldShowLoadingLabel(
		userInterface,
		targetPlayerGamepasses,
		isViewingOwnPasses,
		viewingContext
	)
	DisplayRenderer.configureEmptyStateMessages(userInterface, targetPlayerData, #targetPlayerGamepasses)
	DisplayRenderer.displayGamepasses(userInterface.ItemFrame, targetPlayerGamepasses, currentViewer, targetPlayerToView.UserId)
end

local function populateGamepassDisplayFrame(viewingContext, shouldReloadData, isInGiftingMode)
	if not ValidationUtils.isValidPlayer(viewingContext.Viewer) then
		warn(`[{script.Name}] Invalid viewer for gamepass display`)
		return
	end

	local userInterface = retrievePlayerDonationInterface(viewingContext.Viewer, isInGiftingMode)
	if not userInterface then
		return
	end

	local success, errorMessage = pcall(function()
		PassUIUtilities.resetGamepassScrollFrame(userInterface.ItemFrame)
		userInterface.LoadingLabel.Visible = true
		userInterface.InfoLabel.Visible = false
		userInterface.LinkTextBox.Visible = false

		local currentViewer = viewingContext.Viewer

		if isInGiftingMode then
			handleGiftRecipientDisplay(userInterface, currentViewer, viewingContext.Viewing)
			return
		end

		local targetPlayerToView = viewingContext.Viewing or currentViewer
		handleStandardPlayerDisplay(
			userInterface,
			currentViewer,
			targetPlayerToView,
			viewingContext,
			shouldReloadData or false
		)
	end)

	if not success then
		warn(`[{script.Name}] Error populating gamepass display for {viewingContext.Viewer.Name}: {errorMessage}`)
	end
end

----------------------
-- Export Functions --
----------------------

CooldownManager.populateGamepassDisplayFrame = populateGamepassDisplayFrame
GiftInterface.retrievePlayerDonationInterface = retrievePlayerDonationInterface
GiftInterface.refreshDataDisplayLabel = refreshDataDisplayLabel
GiftInterface.populateGamepassDisplayFrame = populateGamepassDisplayFrame
GiftInterface.getOrCreatePlayerUIState = StateManager.getOrCreatePlayerUIState

---------------------

local function configureUIVisibility(userInterface, currentViewer, isViewingOwnPasses, hasCloseButton)
	userInterface.MainFrame.Visible = true
	userInterface.CloseButton.Visible = hasCloseButton

	currentViewer:SetAttribute(PLAYER_ATTRIBUTES_REFERENCE.ViewingOwnPasses, isViewingOwnPasses)

	local playerOnCooldown = StateManager.isPlayerOnCooldown(currentViewer)
	userInterface.RefreshButton.Visible = (isViewingOwnPasses and not playerOnCooldown)
	userInterface.TimerLabel.Visible = (isViewingOwnPasses and playerOnCooldown)

	if playerOnCooldown then
		local remainingCooldownTime = currentViewer:GetAttribute(PLAYER_ATTRIBUTES_REFERENCE.CooldownTime)
			or GameConfig.GAMEPASS_CONFIG.REFRESH_COOLDOWN
		userInterface.TimerLabel.Text = tostring(remainingCooldownTime)
	end
end

local function handleDonationInterfaceToggle(viewingData)
	if not ValidationUtils.isValidPlayer(viewingData.Viewer) then
		warn(`[{script.Name}] Invalid viewer for interface toggle`)
		return
	end

	local currentViewer = viewingData.Viewer
	local userInterface = retrievePlayerDonationInterface(currentViewer, false)
	if not userInterface then
		return
	end

	local success = pcall(function()
		if not viewingData.Visible then
			userInterface.MainFrame.Visible = false
			currentViewer:SetAttribute(PLAYER_ATTRIBUTES_REFERENCE.ViewingOwnPasses, nil)
			StateManager.cleanupPlayerResources(currentViewer, true)
			return
		end

		local isViewingOwnPasses = (viewingData.Viewing == nil)
		configureUIVisibility(userInterface, currentViewer, isViewingOwnPasses, viewingData.Viewing ~= nil)

		if isViewingOwnPasses then
			local connection = CooldownManager.initializeRefreshButtonBehavior(currentViewer, userInterface, viewingData)
			if connection then
				StateManager.trackPlayerConnection(currentViewer, connection)
			end
		end

		highlightRemoteEvent:FireClient(currentViewer, viewingData.Viewing or nil)

		local displayContext = { Viewer = currentViewer, Viewing = viewingData.Viewing }
		refreshDataDisplayLabel(false, displayContext, false)
		populateGamepassDisplayFrame(displayContext, false, false)

		local activeCooldownTime = currentViewer:GetAttribute(PLAYER_ATTRIBUTES_REFERENCE.CooldownTime)
		if activeCooldownTime and activeCooldownTime > 0 then
			CooldownManager.activateRefreshCooldownTimer(currentViewer, userInterface, isViewingOwnPasses)
		end
	end)

	if not success then
		warn(`[{script.Name}] Error toggling interface for {currentViewer.Name}`)
	end
end

local function cleanup()
	StateManager.cleanupAllStates()

	for userId, thread in pairs(CooldownManager.backgroundCooldownThreads) do
		pcall(task.cancel, thread)
	end
	table.clear(CooldownManager.backgroundCooldownThreads)

	connectionsMaid:disconnect()
end

local function initialize()
	trackGlobalConnection(
		Players.PlayerRemoving:Connect(function(departingPlayer)
			StateManager.cleanupPlayerResources(departingPlayer, true)
			CooldownManager.cleanupBackgroundThread(departingPlayer)

			pcall(function()
				GamepassCacheManager.UnloadPlayerDataFromCache(departingPlayer)
			end)
		end)
	)

	trackGlobalConnection(giftUIRemoteEvent.OnServerEvent:Connect(function(player, recipient: Player | number)
		if not EnhancedValidation.validatePlayer(player) then
			warn(`[{script.Name}] Invalid player in gift UI toggle`)
			return
		end
		GiftInterface.handleGiftInterfaceToggle(player, recipient)
	end))

	trackGlobalConnection(toggleUIBindableEvent.Event:Connect(handleDonationInterfaceToggle))
	trackGlobalConnection(updateUIBindableEvent.Event:Connect(refreshDataDisplayLabel))

	game:BindToClose(cleanup)
end

--------------------
-- Initialization --
--------------------

initialize()