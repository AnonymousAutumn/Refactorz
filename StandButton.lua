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

local networkFolder = ReplicatedStorage.Network
local remoteEvents = networkFolder.Remotes.Events
local toggleStandClaimRemoteEvent = remoteEvents.ToggleStandClaim

local modulesFolder = ReplicatedStorage.Modules
local configurationFolder = ReplicatedStorage.Configuration

local PurchasesWrapper = require(modulesFolder.Wrappers.Purchases)
local gameConfig = require(configurationFolder.GameConfig)

---------------
-- Functions --
---------------

local function initialize()
	local topbarUI = playerGui:WaitForChild("TopbarUI")
	if not topbarUI then
		warn(`[{script.Name}] TopbarUI not found in PlayerGui`)
		return
	end

	local mainFrame = topbarUI:WaitForChild("MainFrame")
	local holder = mainFrame:WaitForChild("Holder")
	local button = holder:WaitForChild("StandButton")

	button.MouseButton1Down:Connect(function()
		toggleStandClaimRemoteEvent:FireServer()
	end)
end

--------------------
-- Initialization --
--------------------

initialize()