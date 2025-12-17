-----------------
-- Init Module --
-----------------

local DisplayRenderer = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local configurationFolder = ReplicatedStorage.Configuration
local FormatString = require(modulesFolder.Utilities.FormatString)
local PassUIUtilities = require(modulesFolder.Utilities.PassUIUtilities)
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local GameConfig = require(configurationFolder.GameConfig)

local instancesFolder = ReplicatedStorage.Instances
local guiPrefabs = instancesFolder.GuiPrefabs
local passButtonPrefab = guiPrefabs.PassButtonPrefab

---------------
-- Constants --
---------------

local MAX_GAMEPASS_DISPLAY = 100
local VIEWING_ATTRIBUTE_NAME = "Viewing"

---------------
-- Functions --
---------------

local function isValidGamepassData(data)
	return typeof(data) == "table"
		and typeof(data.Name) == "string"
		and ValidationUtils.isValidUserId(data.Id)
		and typeof(data.Price) == "number"
		and data.Price >= 0
end

local function buildGamepassDisplayTemplate(gamepassData)
	if not isValidGamepassData(gamepassData) then
		warn(`[{script.Name}] Invalid gamepass data for template`)

		return nil
	end

	local success, clonedTemplate = pcall(function()
		local template = passButtonPrefab:Clone()

		template.Name = gamepassData.Name
		template:SetAttribute("AssetId", gamepassData.Id)
		template.LayoutOrder = gamepassData.Price

		local priceWithCommas = FormatString.formatNumberWithThousandsSeparatorCommas(gamepassData.Price)
		template.ItemPrice.Text = `<font color='#ffb46a'>{GameConfig.ROBUX_ICON_UTF}</font> {priceWithCommas}`
		template.ItemIcon.Image = gamepassData.Icon or ""

		return template
	end)

	if not success then
		warn(`[{script.Name}] Failed to build gamepass template: {tostring(clonedTemplate)}`)
		return nil
	end

	return clonedTemplate 
end

function DisplayRenderer.truncateGamepassList(gamepasses)
	if #gamepasses <= MAX_GAMEPASS_DISPLAY then
		return gamepasses
	end

	warn(`[{script.Name}] Gamepass count ({#gamepasses}) exceeds limit ({MAX_GAMEPASS_DISPLAY}), truncating`)
	
	local truncated = {}
	for i = 1, MAX_GAMEPASS_DISPLAY do
		truncated[#truncated + 1] = gamepasses[i]
	end
	
	return truncated
end

function DisplayRenderer.configureEmptyStateVisibility(userInterface, availableGamepasses, isOwnerViewingOwnPasses)
	local shouldDisplayEmptyState = isOwnerViewingOwnPasses and #availableGamepasses == 0
	if userInterface.InfoLabel then
		userInterface.InfoLabel.Visible = shouldDisplayEmptyState
	end
	if userInterface.LinkTextBox then
		userInterface.LinkTextBox.Visible = shouldDisplayEmptyState
	end
end

function DisplayRenderer.configureEmptyStateMessages(userInterface, targetPlayerData, gamepassCount)
	if not userInterface.InfoLabel or not userInterface.LinkTextBox then
		return
	end

	if targetPlayerData and targetPlayerData.games and #targetPlayerData.games == 0 then
		userInterface.InfoLabel.Text = GameConfig.GAMEPASS_CONFIG.NO_EXPERIENCES_STRING
		userInterface.LinkTextBox.Text = GameConfig.GAMEPASS_CONFIG.CREATION_PAGE_URL
	elseif gamepassCount == 0 then
		userInterface.InfoLabel.Text = GameConfig.GAMEPASS_CONFIG.NO_PASSES_STRING
		if targetPlayerData and targetPlayerData.games and #targetPlayerData.games > 0 then
			userInterface.LinkTextBox.Text = string.format(
				GameConfig.GAMEPASS_CONFIG.PASSES_PAGE_URL,
				targetPlayerData.games[1]
			)
		end
	end
end

function DisplayRenderer.shouldShowLoadingLabel(userInterface, availableGamepasses, isViewingOwnPasses,viewingContext)
	if userInterface.InfoLabel and userInterface.LinkTextBox then
		if userInterface.InfoLabel.Visible and userInterface.LinkTextBox.Visible then
			return false
		end
	end

	if not isViewingOwnPasses and #availableGamepasses == 0 then
		return true
	end

	if viewingContext.Viewing and #availableGamepasses == 0 then
		return true
	end

	return false
end

function DisplayRenderer.displayGamepasses(scrollFrame, gamepasses, currentViewer,targetUserId)
	PassUIUtilities.resetGamepassScrollFrame(scrollFrame)

	for i = 1, #gamepasses do
		local gamepassInfo = gamepasses[i]

		if currentViewer:GetAttribute(VIEWING_ATTRIBUTE_NAME) ~= targetUserId then
			PassUIUtilities.resetGamepassScrollFrame(scrollFrame)
			break
		end

		if not scrollFrame:FindFirstChild(gamepassInfo.Name) then
			local template = buildGamepassDisplayTemplate(gamepassInfo)
			if template then
				template.Parent = scrollFrame
			end
		end
	end
end

-------------------
-- Return Module --
-------------------

return DisplayRenderer