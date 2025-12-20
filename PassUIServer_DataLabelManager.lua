--[[
	DataLabelManager - Manages data label display and animations.

	Features:
	- Player display name resolution
	- Data label animation playback
	- Label update for viewing/own modes
]]

local DataLabelManager = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

local modulesFolder = ReplicatedStorage.Modules
local configurationFolder = ReplicatedStorage.Configuration
local FormatString = require(modulesFolder.Utilities.FormatString)
local PassUIUtilities = require(modulesFolder.Utilities.PassUIUtilities)
local UsernameCache = require(modulesFolder.Caches.UsernameCache)
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local GameConfig = require(configurationFolder.GameConfig)

local uiSoundGroup = SoundService.UI

local ANIMATION_SETTINGS = {
	DATA_LABEL_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 1, true),
}

--[[
	Resolves the display name for a player reference.
	Accepts either a Player instance or a UserId.
]]
function DataLabelManager.resolvePlayerDisplayName(playerReference: Player | number): string
	if typeof(playerReference) == "Instance" and playerReference:IsA("Player") then
		return playerReference.DisplayName or playerReference.Name or "Unknown"
	end

	if not ValidationUtils.isValidUserId(playerReference) then
		warn(`[{script.Name}] Invalid player reference: {tostring(playerReference)}`)
		return "Unknown"
	end

	return UsernameCache.getUsername(playerReference)
end

--[[
	Plays the data label animation with sound effect.
]]
function DataLabelManager.playDataLabelAnimation(player: Player, dataLabel: TextLabel, trackTween: (Player, Tween) -> ())
	local coinJangleSound = uiSoundGroup.Jangle
	if coinJangleSound and coinJangleSound:IsA("Sound") then
		coinJangleSound:Play()
	end

	local labelAnimationTween = TweenService:Create(
		dataLabel.Parent,
		ANIMATION_SETTINGS.DATA_LABEL_TWEEN,
		{ Position = UDim2.new(0.485, 0, 0.75, 0) }
	)

	trackTween(player, labelAnimationTween)
	labelAnimationTween:Play()
end

--[[
	Updates the data label for viewing another player's items.
]]
function DataLabelManager.updateLabelForViewingMode(dataLabel: TextLabel, currentlyViewing: Player | number)
	local targetDisplayName = DataLabelManager.resolvePlayerDisplayName(currentlyViewing)
	dataLabel.RichText = false
	dataLabel.Text = `{targetDisplayName}'s items`
end

--[[
	Updates the data label for viewing own items with raised amount.
]]
function DataLabelManager.updateLabelForOwnMode(dataLabel: TextLabel, viewer: Player): number
	local leaderstats = PassUIUtilities.safeWaitForChild(viewer, "leaderstats", 3)
	local raisedValue = 0

	if leaderstats then
		local raised = PassUIUtilities.safeWaitForChild(leaderstats, "Raised", 3)
		if raised and typeof(raised.Value) == "number" then
			raisedValue = raised.Value
		end
	end

	local formattedRaisedAmount = FormatString.formatNumberWithThousandsSeparatorCommas(raisedValue)
	dataLabel.RichText = true
	dataLabel.Text = string.format(GameConfig.AMOUNT_RAISED_RICHTEXT, formattedRaisedAmount)

	return raisedValue
end

--[[
	Updates the data display label based on viewing context.
]]
function DataLabelManager.updateDataDisplayLabel(dataLabel: TextLabel, timerLabel: TextLabel, refreshButton: GuiButton, viewer: Player, currentlyViewing: Player?, isInGiftingMode: boolean, shouldPlayAnimation: boolean, trackTween: (Player, Tween) -> ())
	if isInGiftingMode or currentlyViewing then
		DataLabelManager.updateLabelForViewingMode(dataLabel, currentlyViewing)
		timerLabel.Visible = false
		refreshButton.Visible = false
	else
		DataLabelManager.updateLabelForOwnMode(dataLabel, viewer)

		if shouldPlayAnimation then
			DataLabelManager.playDataLabelAnimation(viewer, dataLabel, trackTween)
		end
	end
end

return DataLabelManager