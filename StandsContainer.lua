--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

----------------
-- References --
----------------

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local networkFolder = ReplicatedStorage.Network
local bindableEvents = networkFolder.Bindables.Events
local remoteEvents = networkFolder.Remotes.Events
local unclaimStand = remoteEvents.UnclaimStand
local refreshStand = remoteEvents.RefreshStand
local sendNotificationRemoteEvent = bindableEvents.CreateNotification

local modulesFolder = ReplicatedStorage.Modules
local configurationFolder = ReplicatedStorage.Configuration

local Connections = require(modulesFolder.Wrappers.Connections)
local GamepassCacheManager = require(modulesFolder.Caches.PassCache)
local ButtonWrapper = require(modulesFolder.Wrappers.Buttons)
local PurchaseWrapper = require(modulesFolder.Wrappers.Purchases)
local NotificationHelper = require(modulesFolder.Utilities.NotificationHelper)
local InputCategorizer = require(modulesFolder.Utilities.InputCategorizer)
local FormatString = require(modulesFolder.Utilities.FormatString)
local GameConfig = require(configurationFolder.GameConfig)

local instancesFolder = ReplicatedStorage.Instances
local standUIPrefab = instancesFolder.GuiPrefabs.StandUIPrefab
local passButtonPrefab = instancesFolder.GuiPrefabs.PassButtonPrefab

local uiSoundGroup = SoundService.UI
local feedbackSoundGroup = SoundService.Feedback

---------------
-- Variables --
---------------

local playerStandUIs = {}
local screenGuiRef = nil

local connectionsMaid = Connections.new()

----------------
-- Functions --

local function handlePurchase(button)
	local assetId = button:GetAttribute("AssetId")

	PurchaseWrapper.attemptPurchase({
		player = player,
		assetId = assetId,
		isDevProduct = false,
		sounds = {
			click = uiSoundGroup.Click,
			error = feedbackSoundGroup.Error,
		},
		onError = function(errorType, message)
			NotificationHelper.sendWarning(sendNotificationRemoteEvent, message)
		end,
	})
end

local function setupAllButtons(frame)
	ButtonWrapper.setupAllButtons(frame, handlePurchase, {hover = uiSoundGroup.Hover}, nil, true)
end

local function handleSurfaceGui(surfaceGui)
	if not surfaceGui:IsA("SurfaceGui") then
		return
	end
	
	local itemFrame = surfaceGui:FindFirstChild("ItemFrame", true)
	if not itemFrame then
		return
	end

	local layout = itemFrame:FindFirstChildWhichIsA("UIListLayout")
	if layout then
		local function updateCanvas()
			pcall(function()
				itemFrame.CanvasSize = UDim2.new(0, layout.AbsoluteContentSize.X, 0, layout.AbsoluteContentSize.Y)
			end)
		end
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
		updateCanvas()
	end

	setupAllButtons(itemFrame)
end

local function populateStandUI(standModel, gamepasses, remove)
	if remove then
		local existingUI = playerStandUIs[standModel]
		if existingUI then
			existingUI:Destroy()
			playerStandUIs[standModel] = nil
		end
		return
	end

	if not standModel then
		return
	end

	if playerStandUIs[standModel] then
		playerStandUIs[standModel]:Destroy()
		playerStandUIs[standModel] = nil
	end

	local templateGui = standUIPrefab:Clone()
	templateGui.Name = "StandUI_" .. player.Name
	templateGui.Adornee = standModel:FindFirstChild("PassesHolder")
	templateGui.Parent = screenGuiRef

	playerStandUIs[standModel] = templateGui

	local itemFrame = templateGui:FindFirstChild("ItemFrame", true)
	if itemFrame and gamepasses then
		for _, pass in ipairs(gamepasses) do
			local formattedPrice = FormatString.formatNumberWithThousandsSeparatorCommas(pass.Price)
			local passTemplate = passButtonPrefab:Clone()
			passTemplate:SetAttribute("AssetId", pass.Id)
			passTemplate.Name = pass.Name
			passTemplate.LayoutOrder = pass.Price
			passTemplate.ItemPrice.Text = "<font color='#ffb46a'>"
				.. GameConfig.ROBUX_ICON_UTF
				.. "</font> "
				.. formattedPrice
			passTemplate.ItemIcon.Image = pass.Icon or ""
			passTemplate.Parent = itemFrame
		end
	end

	handleSurfaceGui(templateGui)
end

local function cleanup()
	for _, ui in pairs(playerStandUIs) do
		if ui then
			ui:Destroy()
		end
	end
	table.clear(playerStandUIs)
	connectionsMaid:disconnect()
end

local function initialize()
	local screenGui = playerGui:WaitForChild("StandsContainer")
	if not screenGui then
		warn(`[{script.Name}] StandsContainer ScreenGui not found in PlayerGui`)
		return
	end
	screenGuiRef = screenGui

	ButtonWrapper.initialize(InputCategorizer)

	connectionsMaid:add(unclaimStand.OnClientEvent:Connect(function(standModel, gamepasses, remove)
		if gamepasses and typeof(gamepasses) ~= "table" then
			gamepasses = {}
		end
		populateStandUI(standModel, gamepasses, remove)
	end))

	connectionsMaid:add(refreshStand.OnClientEvent:Connect(function(standModel, gamepasses, remove)
		if gamepasses and typeof(gamepasses) ~= "table" then
			gamepasses = {}
		end
		populateStandUI(standModel, gamepasses, remove)
	end))

	connectionsMaid:add(screenGui.AncestryChanged:Connect(function()
		if not screenGui:IsDescendantOf(game) then
			cleanup()
		end
	end))

	connectionsMaid:add(player.AncestryChanged:Connect(function()
		if not player:IsDescendantOf(game) then
			cleanup()
		end
	end))
end

--------------------
-- Initialization --
--------------------

initialize()