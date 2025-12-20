--[[
	UIRenderer - Renders gift display frames and manages UI updates.

	Features:
	- Gift frame creation and configuration
	- Time label registration
	- Frame cleanup management
]]

local UIRenderer = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modulesFolder = ReplicatedStorage.Modules
local configurationFolder = ReplicatedStorage.Configuration

local GameConfig = require(configurationFolder.GameConfig)
local FormatString = require(modulesFolder.Utilities.FormatString)
local TimeFormatter = require(script.Parent.TimeFormatter)
local ValidationHandler = require(script.Parent.ValidationHandler)

local GIFT_ID_PREFIX = "Gift_"

local function generateGiftIdentifierKey(giftData: any): string
	return `{GIFT_ID_PREFIX}{tostring(giftData.Id)}`
end

local function formatGiftAmount(amount: number): string
	return `{GameConfig.ROBUX_ICON_UTF}{FormatString.formatNumberWithThousandsSeparatorCommas(amount)}`
end

local function formatGiftMessage(gifterName: string, formattedAmount: string): string
	return `{gifterName} gifted you {formattedAmount}!`
end

local function getAvatarHeadshotURL(userId: number): string
	return string.format(GameConfig.AVATAR_HEADSHOT_URL, userId)
end

local function configureGiftDisplayFrame(frame: Frame, giftData: any)
	local gifterUserId = ValidationHandler.retrieveUserIdFromUsername(giftData.Gifter) or 1
	local formattedAmount = formatGiftAmount(giftData.Amount)
	local giftMessage = formatGiftMessage(giftData.Gifter, formattedAmount)

	local textLabel = frame:FindFirstChild("TextLabel")
	if textLabel and textLabel:IsA("TextLabel") then
		textLabel.Text = giftMessage
	end

	local gifterIcon = frame:FindFirstChild("GifterIcon")
	if gifterIcon and gifterIcon:IsA("ImageLabel") then
		gifterIcon.Image = getAvatarHeadshotURL(gifterUserId)
	end

	local timeLabel = frame:FindFirstChild("TimeLabel")
	if timeLabel and timeLabel:IsA("TextLabel") then
		timeLabel.Text = TimeFormatter.calculateRelativeTimeDescription(giftData.Timestamp)
	end
end

local function createGiftDisplayFrameFromData(giftData: any, uiRefs: any): Frame?
	if not ValidationHandler.isValidGiftData(giftData) then
		return nil
	end

	local success, newFrame = pcall(function()
		local frame = uiRefs.giftReceivedPrefab:Clone()
		frame.Name = generateGiftIdentifierKey(giftData)
		frame.Visible = true
		configureGiftDisplayFrame(frame, giftData)
		return frame
	end)

	if success then
		return newFrame 
	end
	return nil
end

local function collectExistingGiftFrames(uiRefs: any): { [string]: Frame }
	local existingFrames = {}
	for i, childFrame in pairs(uiRefs.giftEntriesScrollingFrame:GetChildren()) do
		if childFrame:IsA("Frame") then
			existingFrames[childFrame.Name] = childFrame
		end
	end
	return existingFrames
end

local function updateExistingGiftFrame(frame: Frame, giftData: any, safeExecute: (() -> ()) -> boolean, errorMessage: string?)
	safeExecute(function()
		local timeLabel = frame:FindFirstChild("TimeLabel")
		if timeLabel and timeLabel:IsA("TextLabel") then
			timeLabel.Text = TimeFormatter.calculateRelativeTimeDescription(giftData.Timestamp)
		end
	end, "Error updating existing gift frame")
end

local function createOrUpdateGiftFrame(giftData: any, uiRefs: any, safeExecute: (() -> ()) -> boolean, errorMessage: string?): Frame?
	local giftIdentifierKey = generateGiftIdentifierKey(giftData)
	local existingFrame = uiRefs.giftEntriesScrollingFrame:FindFirstChild(giftIdentifierKey)

	if existingFrame and existingFrame:IsA("Frame") then
		updateExistingGiftFrame(existingFrame, giftData, safeExecute)
		return existingFrame
	else
		local newFrame = createGiftDisplayFrameFromData(giftData, uiRefs)
		if newFrame then
			newFrame.Parent = uiRefs.giftEntriesScrollingFrame
		end
		return newFrame
	end
end

local function registerTimeDisplayEntry(frame: Frame, timestamp: number, timeDisplayEntries: { any })
	local label = frame:FindFirstChild("TimeLabel")
	if label and label:IsA("TextLabel") then
		table.insert(timeDisplayEntries, {
			timeDisplayLabel = label,
			originalTimestamp = timestamp,
		})
	end
end

local function removeInvalidGiftFrames(validKeys: { [string]: boolean }, existingFrames: { [string]: Frame }, safeExecute: (() -> ()) -> boolean, errorMessage: string?)
	for frameIdentifier, frameInstance in pairs(existingFrames) do
		if not validKeys[frameIdentifier] then
			safeExecute(function()
				frameInstance:Destroy()
			end, "Error destroying invalid gift frame")
		end
	end
end

--[[
	Populates the gift display with data from the server.
]]
function UIRenderer.populateGiftDisplayWithServerData(serverGiftDataList: { any }, uiRefs: any, timeDisplayEntries: { any }, safeExecute: (() -> ()) -> boolean, errorMessage: string?)
	local validGiftIdentifierKeys = {}
	local existingGiftDisplayFrames = collectExistingGiftFrames(uiRefs)

	table.clear(timeDisplayEntries)

	for i, individualGiftData in pairs(serverGiftDataList) do
		if not ValidationHandler.isValidGiftData(individualGiftData) then
			continue
		end

		local giftIdentifierKey = generateGiftIdentifierKey(individualGiftData)
		validGiftIdentifierKeys[giftIdentifierKey] = true

		local frame = createOrUpdateGiftFrame(individualGiftData, uiRefs, safeExecute)
		if frame then
			registerTimeDisplayEntry(frame, individualGiftData.Timestamp, timeDisplayEntries)
		end
	end

	removeInvalidGiftFrames(validGiftIdentifierKeys, existingGiftDisplayFrames, safeExecute)
end

return UIRenderer