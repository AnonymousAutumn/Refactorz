--[[
	Populater - Populates leaderboard display frames with player data.

	Features:
	- Leaderboard entry creation
	- Player data display
	- Rank color styling
]]

local Populater = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local UsernameCache = require(modulesFolder.Caches.UsernameCache)
local FrameValidator = require(script.FrameValidator)
local DisplayFormatter = require(script.DisplayFormatter)
local ColorStyler = require(script.ColorStyler)
local PlayerRenderer = require(script.PlayerRenderer)
local DataExtractor = require(script.DataExtractor)

local function setupRankDisplay(frame: Frame, rankPosition: number)
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

local function applyRankColor(frame: Frame, rankPosition: number, rankColorConfiguration: any)
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

local function setupPlayerDisplay(frame: Frame, playerUserId: number?, config: any)
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

local function setupStatisticDisplay(frame: Frame, statisticValue: number?, config: any)
	local amountFrame = FrameValidator.getAmountFrame(frame)
	local statisticLabel = FrameValidator.getChild(amountFrame, "StatisticLabel")

	if not ValidationUtils.isValidTextLabel(statisticLabel) then
		return
	end

	statisticLabel.Text = DisplayFormatter.formatStatistic(statisticValue, config)
end

--[[
	Creates a new leaderboard entry frame.
]]
function Populater.createLeaderboardEntryFrame(rankPosition: number, frameTemplate: Frame, parentContainer: ScrollingFrame, rankColorConfiguration: any, fadeInAnimationDuration: number): Frame
	local newFrame = frameTemplate:Clone()
	newFrame.LayoutOrder = rankPosition
	newFrame.Visible = false
	newFrame.Parent = parentContainer
	
	setupRankDisplay(newFrame, rankPosition)
	applyRankColor(newFrame, rankPosition, rankColorConfiguration)
	
	return newFrame
end

--[[
	Populates a leaderboard entry frame with player data.
]]
function Populater.populateLeaderboardEntryDataAsync(targetFrame: Frame, playerUserId: number?, playerStatisticValue: number?, displayConfiguration: any)
	if not ValidationUtils.isValidFrame(targetFrame) then
		return
	end
	
	setupPlayerDisplay(targetFrame, playerUserId, displayConfiguration)
	setupStatisticDisplay(targetFrame, playerStatisticValue, displayConfiguration)
	targetFrame.Visible = true
end

--[[
	Extracts leaderboard entries from DataStore pages.
]]
function Populater.extractLeaderboardDataFromPages(dataStorePages: any, maximumEntryCount: number): { any }
	return DataExtractor.extractFromPages(dataStorePages, maximumEntryCount)
end

--[[
	Refreshes all leaderboard display frames with new data.
]]
function Populater.refreshAllLeaderboardDisplayFrames(leaderboardFrames: { Frame }, leaderboardData: { any }, systemConfiguration: any)
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

--[[
	Clears the username cache.
]]
function Populater.clearUsernameCache()
	UsernameCache.clearCache()
end

return Populater