-----------------
-- Init Module --
-----------------

local NotificationAnimator = {}

--------------
-- Services --
--------------

local TweenService = game:GetService("TweenService")

---------------
-- Constants --
---------------

local ANIMATION_DURATION = {
	STANDARD = 0.3,
	SPECIAL = 0.8,
}

local TRANSPARENCY = {
	VISIBLE = 0,
	HIDDEN = 1,
	STROKE = 0.25,
}

local POSITION = {
	DEFAULT = UDim2.new(0.5, 0, 0, 0),
	SPECIAL_OFFSET = UDim2.new(0.45, 0, 0, 0),
}

local SIZE = {
	COLLAPSED = UDim2.new(0, 0, 1, 0),
}

local SPACING_MULTIPLIER = 1.4
local MIN_WIDTH_PADDING = 50

---------------
-- Functions --
---------------

local function createTween(instance, properties, duration)
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(instance, tweenInfo, properties)
	tween:Play()
	
	return tween
end

local function setInitialTransparency(textLabel, uiStroke)
	textLabel.TextTransparency = TRANSPARENCY.HIDDEN
	if uiStroke then
		uiStroke.Transparency = TRANSPARENCY.HIDDEN
	end
end

local function animateTextFadeIn(textLabel)
	createTween(textLabel, {
		TextTransparency = TRANSPARENCY.VISIBLE,
		TextStrokeTransparency = TRANSPARENCY.VISIBLE,
	}, ANIMATION_DURATION.STANDARD)
end

local function animateStrokeFadeIn(uiStroke)
	createTween(uiStroke, { Transparency = TRANSPARENCY.STROKE }, ANIMATION_DURATION.STANDARD)
end

local function applySpecialAnimation(frame, uiStroke, typeColor)
	frame.Position = POSITION.SPECIAL_OFFSET

	frame:TweenPosition(
		POSITION.DEFAULT,
		Enum.EasingDirection.Out,
		Enum.EasingStyle.Elastic,
		ANIMATION_DURATION.SPECIAL,
		true
	)

	if uiStroke then
		uiStroke.Color = typeColor
	end
end

local function animateCollapse(frame)
	frame:TweenSize(
		SIZE.COLLAPSED,
		Enum.EasingDirection.Out,
		Enum.EasingStyle.Quad,
		ANIMATION_DURATION.STANDARD,
		true
	)
end

local function animateTextFadeOut(textLabel)
	createTween(textLabel, {
		TextTransparency = TRANSPARENCY.HIDDEN,
		TextStrokeTransparency = TRANSPARENCY.HIDDEN,
	}, ANIMATION_DURATION.STANDARD)
end

local function animateExpansion(frame, targetWidth)
	frame:TweenSize(
		UDim2.new(0, targetWidth, 1, 0),
		Enum.EasingDirection.Out,
		Enum.EasingStyle.Quad,
		ANIMATION_DURATION.STANDARD,
		true
	)
end

function NotificationAnimator.calculatePosition(index, totalCount)
	local yPosition = -(totalCount - index) * SPACING_MULTIPLIER
	return UDim2.new(0.5, 0, yPosition, 0)
end

function NotificationAnimator.calculateWidth(textLabel)
	return math.max(textLabel.TextBounds.X + MIN_WIDTH_PADDING, MIN_WIDTH_PADDING)
end

function NotificationAnimator.animateEntry(config)
	setInitialTransparency(config.textLabel, config.uiStroke)

	local targetWidth = NotificationAnimator.calculateWidth(config.textLabel)
	config.frame.Size = UDim2.new(0, targetWidth - MIN_WIDTH_PADDING, 1, 0)

	animateExpansion(config.frame, targetWidth)
	animateTextFadeIn(config.textLabel)

	if config.uiStroke then
		animateStrokeFadeIn(config.uiStroke)
	end

	if config.notificationType ~= "Success" and config.typeColor then
		applySpecialAnimation(config.frame, config.uiStroke, config.typeColor)
	end
end

function NotificationAnimator.animateExit(frame, textLabel)
	animateCollapse(frame)
	animateTextFadeOut(textLabel)
end

function NotificationAnimator.animateReposition(frame, newPosition)
	frame:TweenPosition(
		newPosition,
		Enum.EasingDirection.Out,
		Enum.EasingStyle.Quad,
		ANIMATION_DURATION.STANDARD,
		true
	)
end

function NotificationAnimator.getStandardDuration()
	return ANIMATION_DURATION.STANDARD
end

-------------------
-- Return Module --
-------------------

return NotificationAnimator