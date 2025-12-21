--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

----------------
-- References --
----------------

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local networkFolder = ReplicatedStorage:WaitForChild("Network")
local remoteEvents = networkFolder.Remotes.Events
local giveKeysEvent = remoteEvents.GiveKeys

local modulesFolder = ReplicatedStorage.Modules
local configurationFolder = ReplicatedStorage.Configuration
local Connections = require(modulesFolder.Wrappers.Connections)
local PurchasesWrapper = require(modulesFolder.Wrappers.Purchases)
local GameConfig = require(configurationFolder.GameConfig)

---------------
-- Constants --
---------------

local MONETIZATION = GameConfig.MONETIZATION
local CAR_KEYS_PASS = MONETIZATION.CAR_KEYS
local STAND_ACCESS_PASS = MONETIZATION.STAND_ACCESS

---------------
-- Variables --
---------------

local connectionsMaid = Connections.new()

local ownsCarKeys = false
local ownsStandAccess = false

local function giveCarKeys()
	giveKeysEvent:FireServer(localPlayer)
end

local function enableUnclaimStandButton()
	local topbarUI = playerGui:WaitForChild("TopbarUI", 10)
	if not topbarUI then
		warn("TopbarUI not found in PlayerGui")
		return
	end
	local mainFrame = topbarUI:WaitForChild("MainFrame")
	local holder = mainFrame:WaitForChild("Holder")
	local button = holder:WaitForChild("StandButton")

	button.Visible = true
end


local function onAttributeChanged(attributeName)
	local attributeValue = localPlayer:GetAttribute(attributeName)

	if attributeValue ~= true then
		return
	end

	local id = tonumber(attributeName)
	if not id then 
		return 
	end

	if id == CAR_KEYS_PASS and not ownsCarKeys then
		ownsCarKeys = true
		giveCarKeys()
	elseif id == STAND_ACCESS_PASS and not ownsStandAccess then
		ownsStandAccess = true

		enableUnclaimStandButton()
	end
end

local function onCharacterAdded(character)
	if ownsCarKeys then

		task.defer(function()
			giveCarKeys()
		end)
	end
end

local function cleanup()
	connectionsMaid:disconnect()
end

local function initialize()
	local carKeysCheckSuccess, hasCarKeys = PurchasesWrapper.doesPlayerOwnPass(localPlayer, CAR_KEYS_PASS)
	local standAccessCheckSuccess, hasStandAccess = PurchasesWrapper.doesPlayerOwnPass(localPlayer, STAND_ACCESS_PASS)

	if hasCarKeys then
		ownsCarKeys = true
		giveCarKeys()
	end

	if hasStandAccess then
		ownsStandAccess = true

		enableUnclaimStandButton()
	end

	connectionsMaid:add(localPlayer.AttributeChanged:Connect(onAttributeChanged))
	connectionsMaid:add(localPlayer.CharacterAdded:Connect(onCharacterAdded))
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