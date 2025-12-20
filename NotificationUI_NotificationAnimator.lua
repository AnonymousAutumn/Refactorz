--[[
	NotificationAnimator - Handles notification entry/exit animations.

	Features:
	- Fade in/out animations
	- Position tweening for repositioning
	- Special animations for warning/error types
]]

local NotificationAnimator = {}

local TweenService = game:GetService("TweenService")

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

local function createTween(instance: Instance, properties: { [string]: any }, duration: number): Tween
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(instance, tweenInfo, properties)
	tween:Play()
	
	return tween
end

local function setInitialTransparency(textLabel: TextLabel, uiStroke: UIStroke?)
	textLabel.TextTransparency = TRANSPARENCY.HIDDEN
	if uiStroke then
		uiStroke.Transparency = TRANSPARENCY.HIDDEN
	end
end

local function animateTextFadeIn(textLabel: TextLabel)
	createTween(textLabel, {
		TextTransparency = TRANSPARENCY.VISIBLE,
		TextStrokeTransparency = TRANSPARENCY.VISIBLE,
	}, ANIMATION_DURATION.STANDARD)
end

local function animateStrokeFadeIn(uiStroke: UIStroke)
	createTween(uiStroke, { Transparency = TRANSPARENCY.STROKE }, ANIMATION_DURATION.STANDARD)
end

local function applySpecialAnimation(frame: Frame, uiStroke: UIStroke?, typeColor: Color3)
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

local function animateCollapse(frame: Frame)
	frame:TweenSize(
		SIZE.COLLAPSED,
		Enum.EasingDirection.Out,
		Enum.EasingStyle.Quad,
		ANIMATION_DURATION.STANDARD,
		true
	)
end

local function animateTextFadeOut(textLabel: TextLabel)
	createTween(textLabel, {
		TextTransparency = TRANSPARENCY.HIDDEN,
		TextStrokeTransparency = TRANSPARENCY.HIDDEN,
	}, ANIMATION_DURATION.STANDARD)
end

local function animateExpansion(frame: Frame, targetWidth: number)
	frame:TweenSize(
		UDim2.new(0, targetWidth, 1, 0),
		Enum.EasingDirection.Out,
		Enum.EasingStyle.Quad,
		ANIMATION_DURATION.STANDARD,
		true
	)
end

--[[
	Calculates the position for a notification based on queue index.
]]
function NotificationAnimator.calculatePosition(index: number, totalCount: number): UDim2
	local yPosition = -(totalCount - index) * SPACING_MULTIPLIER
	return UDim2.new(0.5, 0, yPosition, 0)
end

--[[
	Calculates the required width for a notification based on text.
]]
function NotificationAnimator.calculateWidth(textLabel: TextLabel): number
	return math.max(textLabel.TextBounds.X + MIN_WIDTH_PADDING, MIN_WIDTH_PADDING)
end

--[[
	Animates a notification entry with expansion and fade-in.
]]
function NotificationAnimator.animateEntry(config: any)
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

--[[
	Animates a notification exit with collapse and fade-out.
]]
function NotificationAnimator.animateExit(frame: Frame, textLabel: TextLabel)
	animateCollapse(frame)
	animateTextFadeOut(textLabel)
end

--[[
	Animates a notification to a new position.
]]
function NotificationAnimator.animateReposition(frame: Frame, newPosition: UDim2)
	frame:TweenPosition(
		newPosition,
		Enum.EasingDirection.Out,
		Enum.EasingStyle.Quad,
		ANIMATION_DURATION.STANDARD,
		true
	)
end

--[[
	Returns the standard animation duration.
]]
function NotificationAnimator.getStandardDuration(): number
	return ANIMATION_DURATION.STANDARD
end

return NotificationAnimator