-----------------
-- Init Module --
-----------------

local DataLabelManager = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local configurationFolder = ReplicatedStorage.Configuration
local FormatString = require(modulesFolder.Utilities.FormatString)
local PassUIUtilities = require(modulesFolder.Utilities.PassUIUtilities)
local UsernameCache = require(modulesFolder.Caches.UsernameCache)
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local GameConfig = require(configurationFolder.GameConfig)

local uiSoundGroup = SoundService.UI

---------------
-- Constants --
---------------

local ANIMATION_SETTINGS = {
	DATA_LABEL_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 1, true),
}

---------------
-- Functions --
---------------

function DataLabelManager.resolvePlayerDisplayName(playerReference)
	if typeof(playerReference) == "Instance" and playerReference:IsA("Player") then
		return playerReference.DisplayName or playerReference.Name or "Unknown"
	end

	if not ValidationUtils.isValidUserId(playerReference) then
		warn(`[{script.Name}] Invalid player reference: {tostring(playerReference)}`)
		return "Unknown"
	end

	return UsernameCache.getUsername(playerReference)
end

function DataLabelManager.playDataLabelAnimation(player, dataLabel, trackTween)
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

function DataLabelManager.updateLabelForViewingMode(dataLabel, currentlyViewing)
	local targetDisplayName = DataLabelManager.resolvePlayerDisplayName(currentlyViewing)
	dataLabel.RichText = false
	dataLabel.Text = `{targetDisplayName}'s items`
end

function DataLabelManager.updateLabelForOwnMode(dataLabel, viewer)
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

function DataLabelManager.updateDataDisplayLabel(dataLabel, timerLabel, refreshButton, viewer, currentlyViewing, isInGiftingMode, shouldPlayAnimation, trackTween)
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

-------------------
-- Return Module --
-------------------

return DataLabelManager