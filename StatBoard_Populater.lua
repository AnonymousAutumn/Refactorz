-----------------
-- Init Module --
-----------------

local Populater = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local UsernameCache = require(modulesFolder.Caches.UsernameCache)
local FrameValidator = require(script.FrameValidator)
local DisplayFormatter = require(script.DisplayFormatter)
local ColorStyler = require(script.ColorStyler)
local PlayerRenderer = require(script.PlayerRenderer)
local DataExtractor = require(script.DataExtractor)

---------------
-- Functions --
---------------

local function setupRankDisplay(frame, rankPosition)
	if not FrameValidator.validateStructure(frame) then
		return
	end
	
	local holderFrame = FrameValidator.getHolderFrame(frame)
	local infoFrame = FrameValidator.getInfoFrame(holderFrame)
	local rankLabel = FrameValidator.getChild(infoFrame, "RankLabel")

	if ValidationUtils.isValidTextLabel(rankLabel) then
		rankLabel.Text = DisplayFormatter.formatRank(rankPosition)
	end
end

local function applyRankColor(frame, rankPosition, rankColorConfiguration)
	if not FrameValidator.validateStructure(frame) then
		return
	end

	local rankColor = ColorStyler.getRankColor(rankPosition, rankColorConfiguration)
	if not rankColor then
		frame.BackgroundColor3 = ColorStyler.getAlternatingRowColor(rankPosition)
		return
	end

	local holderFrame = FrameValidator.getHolderFrame(frame)
	local infoFrame = FrameValidator.getInfoFrame(holderFrame)
	local amountFrame = FrameValidator.getAmountFrame(frame)

	local rankLabel = FrameValidator.getChild(infoFrame, "RankLabel")
	local usernameLabel = FrameValidator.getChild(holderFrame, "UsernameLabel")
	local statisticLabel = FrameValidator.getChild(amountFrame, "StatisticLabel")

	frame.BackgroundColor3 = rankColor.BACKGROUNDCOLOR

	local labels = {}
	if ValidationUtils.isValidTextLabel(rankLabel) then
		table.insert(labels, rankLabel)
	end
	if ValidationUtils.isValidTextLabel(usernameLabel) then
		table.insert(labels, usernameLabel)
	end
	if ValidationUtils.isValidTextLabel(statisticLabel) then
		table.insert(labels, statisticLabel)
	end

	ColorStyler.applyStrokeToLabels(labels, rankColor.STROKECOLOR)
end

local function setupPlayerDisplay(frame, playerUserId, config)
	if not FrameValidator.validateStructure(frame) then
		return
	end

	local holderFrame = FrameValidator.getHolderFrame(frame)
	local infoFrame = FrameValidator.getInfoFrame(holderFrame)
	local usernameLabel = FrameValidator.getChild(holderFrame, "UsernameLabel")
	local avatarImage = FrameValidator.getChild(infoFrame, "AvatarImage")

	if not ValidationUtils.isValidUserId(playerUserId) then
		PlayerRenderer.setupStudioTestDisplay(usernameLabel, avatarImage)
	else
		local username = DisplayFormatter.getUsernameFromId(playerUserId)
		local formattedUsername = DisplayFormatter.formatUsername(username)
		PlayerRenderer.setupRealPlayerDisplay(usernameLabel, avatarImage, playerUserId, formattedUsername, config)
	end
end

local function setupStatisticDisplay(frame, statisticValue, config)
	local amountFrame = FrameValidator.getAmountFrame(frame)
	local statisticLabel = FrameValidator.getChild(amountFrame, "StatisticLabel")

	if not ValidationUtils.isValidTextLabel(statisticLabel) then
		return
	end

	statisticLabel.Text = DisplayFormatter.formatStatistic(statisticValue, config)
end

function Populater.createLeaderboardEntryFrame(rankPosition, frameTemplate, parentContainer, rankColorConfiguration, fadeInAnimationDuration)
	local newFrame = frameTemplate:Clone()
	newFrame.LayoutOrder = rankPosition
	newFrame.Visible = false
	newFrame.Parent = parentContainer
	
	setupRankDisplay(newFrame, rankPosition)
	applyRankColor(newFrame, rankPosition, rankColorConfiguration)
	
	return newFrame
end

function Populater.populateLeaderboardEntryDataAsync(targetFrame, playerUserId, playerStatisticValue, displayConfiguration)
	if not ValidationUtils.isValidFrame(targetFrame) then
		return
	end
	
	setupPlayerDisplay(targetFrame, playerUserId, displayConfiguration)
	setupStatisticDisplay(targetFrame, playerStatisticValue, displayConfiguration)
	targetFrame.Visible = true
end

function Populater.extractLeaderboardDataFromPages(dataStorePages, maximumEntryCount)
	return DataExtractor.extractFromPages(dataStorePages, maximumEntryCount)
end

function Populater.refreshAllLeaderboardDisplayFrames(leaderboardFrames, leaderboardData, systemConfiguration)
	local displayCount = systemConfiguration.LEADERBOARD_CONFIG.DISPLAY_COUNT
	for frameIndex = 1, displayCount do
		local entryData = leaderboardData[frameIndex]
		local displayFrame = leaderboardFrames[frameIndex]

		if not ValidationUtils.isValidFrame(displayFrame) then
			continue
		end

		if entryData and type(entryData) == "table" then
			Populater.populateLeaderboardEntryDataAsync(
				displayFrame,
				tonumber(entryData.key),
				entryData.value,
				systemConfiguration
			)
		else
			displayFrame.Visible = false
		end
	end
end

function Populater.clearUsernameCache()
	UsernameCache.clearCache()
end

-------------------
-- Return Module --
-------------------

return Populater