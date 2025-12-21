-----------------
-- Init Module --
-----------------

local CooldownManager = {}
CooldownManager.playerUIStates = nil
CooldownManager.playerCooldownRegistry = nil
CooldownManager.populateGamepassDisplayFrame = nil

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
local notificationEvent = remoteEvents.CreateNotification

local modulesFolder = ReplicatedStorage.Modules
local configurationFolder = ReplicatedStorage.Configuration

local GamepassCacheManager = require(modulesFolder.Caches.PassCache)
local StandManager = require(modulesFolder.Managers.Stands)
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local GameConfig = require(configurationFolder.GameConfig)

---------------
-- Constants --
---------------

local PLAYER_ATTRIBUTES_REFERENCE = {
	ViewingOwnPasses = "ViewingOwnPasses",
	CooldownTime = "CooldownTime",
	PromptsDisabled = "PromptsDisabled",
}

---------------
-- Variables --
---------------

CooldownManager.backgroundCooldownThreads = {}

---------------
-- Functions --
---------------

local function validateUIComponents(components)
	return typeof(components) == "table"
		and components.RefreshButton
		and components.TimerLabel
		and components.DataLabel
end

function CooldownManager.activateRefreshCooldownTimer(targetPlayer, userInterface, isViewingOwnPasses)
	if not ValidationUtils.isValidPlayer(targetPlayer) or not validateUIComponents(userInterface) then
		warn(`[{script.Name}] Invalid parameters for cooldown timer`)
		return
	end

	if not CooldownManager.playerUIStates then
		warn(`[{script.Name}] playerUIStates not initialized`)
		return
	end

	local state = CooldownManager.playerUIStates[targetPlayer.UserId]
	if not state then
		return
	end

	if state.cooldownThread then
		task.cancel(state.cooldownThread)
	end

	local cooldownDurationSeconds = targetPlayer:GetAttribute(PLAYER_ATTRIBUTES_REFERENCE.CooldownTime)
		or GameConfig.GAMEPASS_CONFIG.REFRESH_COOLDOWN
	userInterface.RefreshButton.Visible = false
	userInterface.TimerLabel.Visible = isViewingOwnPasses

	state.cooldownThread = task.spawn(function()
		local remainingSeconds = cooldownDurationSeconds

		while remainingSeconds > 0 do
			if isViewingOwnPasses then
				userInterface.TimerLabel.Text = tostring(remainingSeconds)
			end

			targetPlayer:SetAttribute(PLAYER_ATTRIBUTES_REFERENCE.CooldownTime, remainingSeconds)
			task.wait(1)
			remainingSeconds = remainingSeconds - 1

			if not targetPlayer:GetAttribute(PLAYER_ATTRIBUTES_REFERENCE.ViewingOwnPasses) then
				userInterface.TimerLabel.Visible = false
				userInterface.RefreshButton.Visible = false
			end
		end

		userInterface.TimerLabel.Text = ""
		userInterface.TimerLabel.Visible = false
		targetPlayer:SetAttribute(PLAYER_ATTRIBUTES_REFERENCE.CooldownTime, nil)

		if CooldownManager.playerCooldownRegistry then
			CooldownManager.playerCooldownRegistry[targetPlayer.UserId] = nil
		end

		if state then
			state.cooldownThread = nil
		end

		if targetPlayer:GetAttribute(PLAYER_ATTRIBUTES_REFERENCE.ViewingOwnPasses) and userInterface.DataLabel.RichText then
			userInterface.RefreshButton.Visible = true
		end
	end)
end

function CooldownManager.handleRefreshButtonClick(currentViewer, userInterface, viewingData)
	if not CooldownManager.playerCooldownRegistry or not CooldownManager.playerUIStates then
		warn(`[{script.Name}] Registries not initialized`)
		return
	end

	if CooldownManager.playerCooldownRegistry[currentViewer.UserId] then
		return
	end

	local success = pcall(function()
		CooldownManager.playerCooldownRegistry[currentViewer.UserId] = true
		currentViewer:SetAttribute(PLAYER_ATTRIBUTES_REFERENCE.PromptsDisabled, true)

		local state = CooldownManager.playerUIStates[currentViewer.UserId]
		if state then
			state.lastRefreshTime = os.time()
		end

		local refreshContext = { Viewer = currentViewer, Viewing = viewingData.Viewing }

		if CooldownManager.populateGamepassDisplayFrame then
			CooldownManager.populateGamepassDisplayFrame(refreshContext, true, false)
		end

		currentViewer:SetAttribute(PLAYER_ATTRIBUTES_REFERENCE.PromptsDisabled, false)

		-- Always notify and broadcast, regardless of UI state
		notificationEvent:FireClient(currentViewer, "Your passes have been refreshed!", "Success")
		StandManager.BroadcastStandRefresh(currentViewer)

		-- Re-register cooldown in case cleanup cleared it during populateGamepassDisplayFrame
		CooldownManager.playerCooldownRegistry[currentViewer.UserId] = true

		-- Handle cooldown tracking based on UI availability
		local currentState = CooldownManager.playerUIStates[currentViewer.UserId]
		if currentState then
			CooldownManager.activateRefreshCooldownTimer(currentViewer, userInterface, true)
		else
			-- UI was closed during refresh - run background cooldown tracking
			local cooldownDuration = GameConfig.GAMEPASS_CONFIG.REFRESH_COOLDOWN
			local viewerUserId = currentViewer.UserId
			currentViewer:SetAttribute(PLAYER_ATTRIBUTES_REFERENCE.CooldownTime, cooldownDuration)

			local thread = task.spawn(function()
				local remaining = cooldownDuration
				while remaining > 0 do
					task.wait(1)
					remaining -= 1
					if not currentViewer:IsDescendantOf(game) then
						break
					end
					currentViewer:SetAttribute(PLAYER_ATTRIBUTES_REFERENCE.CooldownTime, remaining > 0 and remaining or nil)
				end
				if CooldownManager.playerCooldownRegistry then
					CooldownManager.playerCooldownRegistry[viewerUserId] = nil
				end
				CooldownManager.backgroundCooldownThreads[viewerUserId] = nil
			end)
			CooldownManager.backgroundCooldownThreads[viewerUserId] = thread
		end
	end)

	if not success then
		warn(`[{script.Name}] Error during refresh for {currentViewer.Name}`)
		CooldownManager.playerCooldownRegistry[currentViewer.UserId] = nil
		currentViewer:SetAttribute(PLAYER_ATTRIBUTES_REFERENCE.PromptsDisabled, false)
	end
end

function CooldownManager.initializeRefreshButtonBehavior(currentViewer, userInterface, viewingData)
	if not ValidationUtils.isValidPlayer(currentViewer) or not validateUIComponents(userInterface) then
		warn(`[{script.Name}] Invalid parameters for refresh button`)
		return nil
	end

	-- RefreshButton event handler
	local refreshConnection = userInterface.RefreshButton.MouseButton1Click:Connect(function()
		CooldownManager.handleRefreshButtonClick(currentViewer, userInterface, viewingData)
	end)

	return refreshConnection
end

function CooldownManager.cleanupBackgroundThread(player)
	local userId = player.UserId
	local thread = CooldownManager.backgroundCooldownThreads[userId]
	if thread then
		pcall(task.cancel, thread)
		CooldownManager.backgroundCooldownThreads[userId] = nil
	end
end

-------------------
-- Return Module --
-------------------

return CooldownManager