--[[
	ScrollAnimator - Animates scrolling track name labels.

	Features:
	- Horizontal text scrolling
	- Centered/left alignment modes
	- Animation lifecycle management
]]

local ScrollAnimator = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modulesFolder = ReplicatedStorage.Modules
local TweenHelper = require(modulesFolder.Utilities.TweenHelper)

--[[
	Cleans up existing scroll animations.
]]
function ScrollAnimator.cleanupScrollAnimations(scrollState: any)
	if scrollState.tween then
		scrollState.tween:Cancel()
		scrollState.tween = nil
	end

	if scrollState.thread then
		task.cancel(scrollState.thread)
		scrollState.thread = nil
	end
end

--[[
	Sets up label for centered display.
]]
function ScrollAnimator.setupCenteredLabel(trackNameLabel: TextLabel)
	trackNameLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	trackNameLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
	trackNameLabel.Size = UDim2.new(1, 0, 1, 0)
end

--[[
	Sets up label for left-aligned scrolling.
]]
function ScrollAnimator.setupLeftAlignedLabel(trackNameLabel: TextLabel)
	trackNameLabel.AnchorPoint = Vector2.new(0, 0.5)
	trackNameLabel.Position = UDim2.new(0, 0, 0.5, 0)
end

--[[
	Creates the scrolling animation loop.
]]
function ScrollAnimator.createScrollAnimation(trackNameLabel: TextLabel, scrollState: any, textWidth: number, frameWidth: number, config: any)
	trackNameLabel.Size = UDim2.new(0, textWidth, 1, 0)

	local startX = 0
	local endX = -(textWidth - frameWidth)
	local duration = math.abs(endX - startX) / config.SCROLL_SPEED

	scrollState.thread = task.spawn(function()
		while true do
			trackNameLabel.Position = UDim2.new(0, startX, 0.5, 0)

			task.wait(config.SCROLL_INITIAL_DELAY)

			scrollState.tween = TweenHelper.play(
				trackNameLabel,
				TweenInfo.new(duration, Enum.EasingStyle.Linear),
				{ Position = UDim2.new(0, endX, 0.5, 0) }
			)

			scrollState.tween.Completed:Wait()

			task.wait(config.SCROLL_RESET_DELAY)
		end
	end)
end

--[[
	Main entry point to animate track name scrolling.
]]
function ScrollAnimator.animateTrackNameScroll(trackNameLabel: TextLabel, trackFrame: Frame, scrollState: any, config: any)
	ScrollAnimator.cleanupScrollAnimations(scrollState)

	if trackNameLabel.Text == config.BUFFERING_TEXT then
		ScrollAnimator.setupCenteredLabel(trackNameLabel)
		return
	end

	ScrollAnimator.setupLeftAlignedLabel(trackNameLabel)
	task.wait()

	local textWidth = trackNameLabel.TextBounds.X
	local frameWidth = trackFrame.AbsoluteSize.X

	if textWidth <= frameWidth then
		trackNameLabel.Size = UDim2.new(1, 0, 1, 0)
		return
	end

	ScrollAnimator.createScrollAnimation(trackNameLabel, scrollState, textWidth, frameWidth, config)
end

return ScrollAnimator