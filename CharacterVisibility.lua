--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local Connections = require(modulesFolder.Wrappers.Connections)

local networkFolder = ReplicatedStorage.Network
local remoteEvents = networkFolder.Remotes.Events
local updateGameUIEvent = remoteEvents.UpdateGameUI

---------------
-- Constants --
---------------

local COMPLETELY_TRANSPARENT = 1
local FULLY_OPAQUE = 0

local COLLISION_DISABLED = false
local RAYCAST_DISABLED = false
local EFFECTS_DISABLED = false

local HIDEABLE_EFFECT_TYPES = {
	ParticleEmitter = true,
	Sparkles = true,
	Smoke = true,
	Fire = true,
	Beam = true,
}

local YOUR_TURN_MESSAGE = "Your turn!"

---------------
-- Variables --
---------------

local originalStates = {}

local localPlayer = Players.LocalPlayer
local playerControls = nil

local connectionsMaid = Connections.new()

---------------
-- Functions --
---------------

local function setPropertySafely(instance, propertyName, value)
	local success, errorMessage = pcall(function()
		(instance )[propertyName] = value
	end)
	if not success then
		warn(`Failed to set {instance.Name}.{propertyName}: {errorMessage}`)
	end
	return success
end

local function isHideableEffect(instance)
	return HIDEABLE_EFFECT_TYPES[instance.ClassName] == true
end

local function storeOriginalState(instance)
	if originalStates[instance] then
		return
	end

	local state = {}
	if instance:IsA("BasePart") then
		local part = instance 
		state.Transparency = part.Transparency
		state.CanCollide = part.CanCollide
		state.CanQuery = part.CanQuery
	elseif instance:IsA("Decal") then
		local decal = instance 
		state.Transparency = decal.Transparency
	elseif isHideableEffect(instance) then
		state.Enabled = (instance ).Enabled
	else
		return
	end

	originalStates[instance] = state
end

local function restoreAllStates()
	for inst, state in pairs(originalStates) do
		if inst and inst.Parent then
			for propertyName, originalValue in pairs(state) do
				setPropertySafely(inst, propertyName, originalValue)
			end
		end
	end
	table.clear(originalStates)
end

local function hideInstance(instance)
	storeOriginalState(instance)

	if instance:IsA("BasePart") then
		setPropertySafely(instance, "Transparency", COMPLETELY_TRANSPARENT)
		setPropertySafely(instance, "CanCollide", COLLISION_DISABLED)
		setPropertySafely(instance, "CanQuery", RAYCAST_DISABLED)
	elseif instance:IsA("Decal") then
		setPropertySafely(instance, "Transparency", COMPLETELY_TRANSPARENT)
	elseif isHideableEffect(instance) then
		setPropertySafely(instance, "Enabled", EFFECTS_DISABLED)
	end
end

local function hideCharacter(character)
	if not character then
		return
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") or isHideableEffect(descendant) then
			hideInstance(descendant)
		elseif descendant:IsA("Accessory") then
			local handle = descendant:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				hideInstance(handle)
			end
		end
	end
end

local function showCharacter(_character)
	restoreAllStates()
end

local function forEachPlayerCharacter(action)
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			action(player.Character)
		end
	end
end

local function showAllPlayers()
	forEachPlayerCharacter(showCharacter)
end

local function hideAllPlayers()
	forEachPlayerCharacter(hideCharacter)
end

local function enableControls()
	if playerControls and playerControls.Enable then
		playerControls:Enable()
	end
end

local function disableControls()
	if playerControls and playerControls.Disable then
		playerControls:Disable()
	end
end

local function showPlayersAndEnableControls()
	showAllPlayers()
	enableControls()
end

local function hidePlayersAndDisableControls()
	hideAllPlayers()
	disableControls()
end

local function onTurnUIUpdate(turnMessage, _turnTimeout, shouldReset)
	if shouldReset then
		showPlayersAndEnableControls()
	elseif turnMessage == YOUR_TURN_MESSAGE then
		hidePlayersAndDisableControls()
	else
		showPlayersAndEnableControls()
	end
end

local function initializePlayerControls()
	local playerScripts = localPlayer:WaitForChild("PlayerScripts")
	local moduleSuccess, playerModule = pcall(function()
		return playerScripts:WaitForChild("PlayerModule")
	end)
	if not moduleSuccess or not playerModule then
		warn("Failed to access PlayerModule: ", tostring(playerModule))
		return
	end

	local requireSuccess, controlsProvider = pcall(function()
		return require(playerModule)
	end)
	if not requireSuccess or not controlsProvider or not controlsProvider.GetControls then
		warn("Failed to require PlayerModule or GetControls missing")
		return
	end

	local controlsSuccess, controls = pcall(function()
		return controlsProvider:GetControls()
	end)
	if controlsSuccess then
		playerControls = controls
	else
		warn("Failed to get controls: ", tostring(controls))
	end
end

local function initializeNetworkEvents()
	local network = ReplicatedStorage:WaitForChild("Network")
	local remotes = network:WaitForChild("Remotes")
	local remoteEvents = remotes:WaitForChild("Events")
	local updateGameUIEvent = remoteEvents:WaitForChild("UpdateGameUI")

	connectionsMaid:add(updateGameUIEvent.OnClientEvent:Connect(onTurnUIUpdate))
end

local function initialize()
	initializePlayerControls()
	initializeNetworkEvents()

	connectionsMaid:add(localPlayer.CharacterAdded:Connect(showAllPlayers))

	connectionsMaid:add(localPlayer.AncestryChanged:Connect(function()
		if not localPlayer:IsDescendantOf(game) then
			showPlayersAndEnableControls()
			connectionsMaid:disconnect()
		end
	end))
end

--------------------
-- Initialization --
--------------------

initialize()