--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

----------------
-- References --
----------------

local localPlayer = Players.LocalPlayer

local networkFolder = ReplicatedStorage.Network
local remoteEvents = networkFolder.Remotes.Events
local createHighlightEvent = remoteEvents.CreateHighlight

local modulesFolder = ReplicatedStorage.Modules
local Connections = require(modulesFolder.Wrappers.Connections)

---------------
-- Constants --
---------------

local HIGHLIGHT_CONFIG = {
	instanceName = "PlayerHighlight",
	fillTransparency = 1,
	outlineColor = Color3.fromRGB(255, 255, 255),
	depthMode = Enum.HighlightDepthMode.AlwaysOnTop,
}

---------------
-- Variables --
---------------

local connectionsMaid = Connections.new()
local activeHighlight = nil

---------------
-- Functions --
---------------

local function removeActiveHighlight()
	if activeHighlight then
		activeHighlight:Destroy()
		activeHighlight = nil
	end
end

local function createHighlight(targetCharacter)
	if not targetCharacter or not targetCharacter.Parent then
		return nil
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = HIGHLIGHT_CONFIG.instanceName
	highlight.Adornee = targetCharacter
	highlight.FillTransparency = HIGHLIGHT_CONFIG.fillTransparency
	highlight.OutlineColor = HIGHLIGHT_CONFIG.outlineColor
	highlight.DepthMode = HIGHLIGHT_CONFIG.depthMode
	highlight.Parent = targetCharacter

	return highlight
end

local function resolveTargetPlayer(arg)

	if typeof(arg) == "Instance" and arg:IsA("Player") then
		return arg
	end

	if typeof(arg) == "number" and arg > 0 then
		return Players:GetPlayerByUserId(arg)
	end
	return nil
end

local function onHighlightRequest(targetRef)

	removeActiveHighlight()

	if targetRef == nil then
		return
	end

	local targetPlayer = resolveTargetPlayer(targetRef)
	if not targetPlayer then
		return
	end

	local targetCharacter = targetPlayer.Character
	if not targetCharacter then
		return
	end

	activeHighlight = createHighlight(targetCharacter)
end

local function onCharacterAdded(character)

	removeActiveHighlight()
end

local function onLocalPlayerDied()
	removeActiveHighlight()
end

local function setupCharacterEvents(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		connectionsMaid:add(humanoid.Died:Connect(onLocalPlayerDied))
	end
end

local function cleanup()
	removeActiveHighlight()
	connectionsMaid:disconnect()
end

local function initialize()

	connectionsMaid:add(createHighlightEvent.OnClientEvent:Connect(onHighlightRequest))

	connectionsMaid:add(localPlayer.CharacterAdded:Connect(function(character)
		onCharacterAdded(character)
		setupCharacterEvents(character)
	end))

	if localPlayer.Character then
		setupCharacterEvents(localPlayer.Character)
	end

	connectionsMaid:add(localPlayer.AncestryChanged:Connect(function()
		if not localPlayer:IsDescendantOf(game) then
			cleanup()
		end
	end))
end

--------------------
-- Initialization --
--------------------

initialize()