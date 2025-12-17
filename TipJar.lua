--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

----------------
-- References --
----------------

local networkFolder = ReplicatedStorage.Network
local bindableEvents = networkFolder.Bindables.Events
local toggleUIBindableEvent = bindableEvents.ToggleUI

local modulesFolder = ReplicatedStorage.Modules
local Connections = require(modulesFolder.Wrappers.Connections)
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)

local tipJarTool  = script.Parent
local tipJarHandle = tipJarTool.Handle
local toolProximityPrompt = tipJarHandle.ProximityPrompt

---------------
-- Constants --
---------------

local ATTRIBUTE_PROMPTS_DISABLED = "PromptsDisabled"
local ATTRIBUTE_SHOULD_HIDE_UI = "ShouldHideUI"

local ENABLE_PROMPT_DEBOUNCE = true
local DEBOUNCE_MODE = "player"
local DEBOUNCE_DURATION_SEC = 1.25

---------------
-- Variables --
---------------

local playerFromTool = nil
local connectionsMaid = Connections.new()

local playerCooldownUntil = {}
local toolCooldownUntil = nil

---------------
-- Functions --
---------------

local function triggerUserInterfaceToggle(uiViewingData)
	local success, errorMessage = pcall(function()
		toggleUIBindableEvent:Fire(uiViewingData)
	end)
	if not success then
		warn(`[{script.Name}] Failed to toggle UI: {tostring(errorMessage)}`)
	end
end

local function getToolOwner()
	local parentInstance = tipJarTool.Parent
	if not parentInstance then
		return nil
	end
	return Players:GetPlayerFromCharacter(parentInstance)
end

local function now()
	return os.clock()
end

local function isDebouncedForPlayer(player)
	if not ENABLE_PROMPT_DEBOUNCE or DEBOUNCE_MODE ~= "player" then
		return false
	end
	local untilTime = playerCooldownUntil[player.UserId]
	return untilTime ~= nil and now() < untilTime
end

local function markPlayerDebounced(player)
	if not ENABLE_PROMPT_DEBOUNCE or DEBOUNCE_MODE ~= "player" then
		return
	end
	playerCooldownUntil[player.UserId] = now() + DEBOUNCE_DURATION_SEC
end

local function isDebouncedForTool()
	if not ENABLE_PROMPT_DEBOUNCE or DEBOUNCE_MODE ~= "tool" then
		return false
	end
	return toolCooldownUntil ~= nil and now() < (toolCooldownUntil )
end

local function markToolDebounced()
	if not ENABLE_PROMPT_DEBOUNCE or DEBOUNCE_MODE ~= "tool" then
		return
	end
	toolCooldownUntil = now() + DEBOUNCE_DURATION_SEC
end

local function clearDebounceState()
	table.clear(playerCooldownUntil)
	toolCooldownUntil = nil
end

local function handleToolEquippedByPlayer()
	local owner = getToolOwner()
	if not ValidationUtils.isValidPlayer(owner) then
		return
	end

	currentToolOwnerPlayer = owner

	triggerUserInterfaceToggle({
		Viewer = owner,
		Viewing = nil,
		Visible = true,
	})
end

local function handleToolUnequippedByPlayer()
	if currentToolOwnerPlayer then
		triggerUserInterfaceToggle({
			Viewer = currentToolOwnerPlayer,
			Viewing = nil,
			Visible = false,
		})
	end
	currentToolOwnerPlayer = nil
end

local function unequipCurrentToolIfAny(triggeringPlayer)
	local character = triggeringPlayer.Character or triggeringPlayer.CharacterAdded:Wait()
	if not character then
		return
	end

	local equippedTool = character:FindFirstChildOfClass("Tool")
	if equippedTool then
		local backpack = triggeringPlayer:FindFirstChildOfClass("Backpack")
			or triggeringPlayer:FindFirstChild("Backpack")
		if backpack then
			equippedTool.Parent = backpack
		end
	end
end

local function handleProximityPromptTriggeredByPlayer(triggeringPlayer)
	if not ValidationUtils.isValidPlayer(triggeringPlayer) then
		return
	end
	if triggeringPlayer:GetAttribute(ATTRIBUTE_PROMPTS_DISABLED) then
		return
	end

	if DEBOUNCE_MODE == "player" and isDebouncedForPlayer(triggeringPlayer) then
		return
	elseif DEBOUNCE_MODE == "tool" and isDebouncedForTool() then
		return
	end

	if DEBOUNCE_MODE == "player" then
		markPlayerDebounced(triggeringPlayer)
	elseif DEBOUNCE_MODE == "tool" then
		markToolDebounced()
	end

	task.spawn(function()
		unequipCurrentToolIfAny(triggeringPlayer)

		triggeringPlayer:SetAttribute(ATTRIBUTE_SHOULD_HIDE_UI, true)

		triggerUserInterfaceToggle({
			Viewer = triggeringPlayer,
			Viewing = currentToolOwnerPlayer,
			Visible = true,
		})
	end)
end

local function cleanup()
	connectionsMaid:disconnect()
	clearDebounceState()
	currentToolOwnerPlayer = nil
end

local function initialize()
	connectionsMaid:add(tipJarTool.Equipped:Connect(handleToolEquippedByPlayer))
	connectionsMaid:add(tipJarTool.Unequipped:Connect(handleToolUnequippedByPlayer))
	connectionsMaid:add(toolProximityPrompt.Triggered:Connect(handleProximityPromptTriggeredByPlayer))

	connectionsMaid:add(tipJarTool.AncestryChanged:Connect(function()
		if not tipJarTool:IsDescendantOf(game) then
			cleanup()
		end
	end))
end

--------------------
-- Initialization --
--------------------

initialize()