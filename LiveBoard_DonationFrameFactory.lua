local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local modules = ReplicatedStorage:WaitForChild("Modules")
local configuration = ReplicatedStorage:WaitForChild("Configuration")

local FormatString = require(modules.Utilities.FormatString)
local UsernameCache = require(modules.Caches.UsernameCache)
local ValidationUtils = require(modules.Utilities.ValidationUtils)
local GameConfig = require(configuration.GameConfig)

local DonationFrameFactory = {}

local DonationTierCalculator = require(script.Parent.DonationTierCalculator)

local TAG = "[DonationFrameFactory]"

local PLAYER_AVATAR_HEADSHOT_URL_TEMPLATE = GameConfig.AVATAR_HEADSHOT_URL
local ROBUX_CURRENCY_ICON = GameConfig.ROBUX_ICON_UTF

local DONATION_FADE_IN_ANIMATION = TweenInfo.new(0.5)

local STANDARD_FRAME_BASE_LAYOUT_ORDER = 1

local function retrievePlayerUsernameFromId(playerUserId)
	if not ValidationUtils.isValidUserId(playerUserId) then
		warn(`{TAG} Invalid user ID: {tostring(playerUserId)}`)
		return `<unknown{playerUserId}>`
	end

	return UsernameCache.getUsername(playerUserId)
end

local function generateDonationAnnouncementText(donorUserId, recipientUserId, donationAmount)
	local donorName = retrievePlayerUsernameFromId(donorUserId)
	local recipientName = retrievePlayerUsernameFromId(recipientUserId)
	local formattedAmount = `{ROBUX_CURRENCY_ICON}{FormatString.formatNumberWithThousandsSeparatorCommas(donationAmount)}`
	return `{donorName} has donated {formattedAmount} to {recipientName}!`
end

local function configureTextLabel(textLabel, tierInfo, announcementText)
	if not (textLabel and textLabel:IsA("TextLabel")) then
		return
	end
	local lbl = textLabel
	lbl.TextColor3 = tierInfo.Color
	lbl.Text = announcementText
end

local function configureAvatarIcon(avatarIcon, userId)
	if not (avatarIcon and avatarIcon:IsA("ImageLabel")) then
		return
	end
	avatarIcon.Image = string.format(PLAYER_AVATAR_HEADSHOT_URL_TEMPLATE, userId)
end

local function configureDonationDisplayFrame(
	donationFrame,
	donorUserId,
	recipientUserId,
	donationAmount,
	tierInfo,
	trackTween
)
	local announcementTextLabel = donationFrame:FindFirstChild("TextLabel")
	local donorAvatarIcon = donationFrame:FindFirstChild("DonorIcon")
	local recipientAvatarIcon = donationFrame:FindFirstChild("ReceiverIcon")

	local announcementText = generateDonationAnnouncementText(donorUserId, recipientUserId, donationAmount)
	configureTextLabel(announcementTextLabel, tierInfo, announcementText)
	configureAvatarIcon(donorAvatarIcon, donorUserId)
	configureAvatarIcon(recipientAvatarIcon, recipientUserId)

	local fadeInAnimation = TweenService:Create(donationFrame, DONATION_FADE_IN_ANIMATION, { GroupTransparency = 0 })
	trackTween(fadeInAnimation)
	fadeInAnimation:Play()
end

local function configureCountdownBar(countdownBarMain, tierInfo)
	if countdownBarMain and countdownBarMain:IsA("Frame") then
		countdownBarMain.BackgroundColor3 = tierInfo.Color
	end
end

local function createCountdownBarAnimation(
	countdownBarFrame,
	tierInfo,
	trackTween
)
	if not (countdownBarFrame and countdownBarFrame:IsA("Frame")) then
		return nil
	end
	local frame = countdownBarFrame 
	local countdownBarAnimationInfo = TweenInfo.new(tierInfo.Lifetime, Enum.EasingStyle.Linear)
	local countdownBarAnimation = TweenService:Create(frame, countdownBarAnimationInfo, { Size = UDim2.new(0, 0, 0, 5) })
	trackTween(countdownBarAnimation)
	return countdownBarAnimation
end

local function setupCountdownCompletionHandler(countdownBarAnimation, donationFrame, onCompletion, trackConnection)
	local connection = nil
	connection = countdownBarAnimation.Completed:Connect(function()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		onCompletion(donationFrame)
	end)
	if connection then
		trackConnection(connection)
	end
end

function DonationFrameFactory.calculateLayoutOrder(isLargeDonation, donationAmount)
	return if isLargeDonation then -donationAmount else STANDARD_FRAME_BASE_LAYOUT_ORDER
end

function DonationFrameFactory.createFrame(
	liveDonationPrefab,
	donorUserId,
	recipientUserId,
	donationAmount,
	tierInfo,
	isLargeDonation,
	trackTween
)
	local newDonationFrame = liveDonationPrefab:Clone() 
	newDonationFrame.LayoutOrder = DonationFrameFactory.calculateLayoutOrder(isLargeDonation, donationAmount)
	newDonationFrame.GroupTransparency = 1

	configureDonationDisplayFrame(newDonationFrame, donorUserId, recipientUserId, donationAmount, tierInfo, trackTween)

	return newDonationFrame
end

function DonationFrameFactory.setupLargeDonationCountdown(donationFrame, tierInfo, onCountdownComplete, trackTween, trackConnection)
	local countdownBarFrame = donationFrame:FindFirstChild("BarFrame")
	if not countdownBarFrame then
		warn(`{TAG} BarFrame not found in donation template`)
		return false
	end

	local countdownBarMain = countdownBarFrame:FindFirstChild("Main")
	if not countdownBarMain then
		warn(`{TAG} Main bar not found in BarFrame`)
		return false
	end

	if countdownBarFrame:IsA("Frame") then
		countdownBarFrame.Visible = true
	end
	configureCountdownBar(countdownBarMain, tierInfo)

	local countdownBarAnimation = createCountdownBarAnimation(countdownBarFrame, tierInfo, trackTween)
	if countdownBarAnimation then
		setupCountdownCompletionHandler(countdownBarAnimation, donationFrame, onCountdownComplete, trackConnection)
		countdownBarAnimation:Play()
		return true
	end

	return false
end

return DonationFrameFactory