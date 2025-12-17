-----------------
-- Init Module --
-----------------

local ScrollAnimator = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local TweenHelper = require(modulesFolder.Utilities.TweenHelper)

---------------
-- Functions --
---------------

function ScrollAnimator.cleanupScrollAnimations(scrollState)
	if scrollState.tween then
		scrollState.tween:Cancel()
		scrollState.tween = nil
	end

	if scrollState.thread then
		task.cancel(scrollState.thread)
		scrollState.thread = nil
	end
end

function ScrollAnimator.setupCenteredLabel(trackNameLabel)
	trackNameLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	trackNameLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
	trackNameLabel.Size = UDim2.new(1, 0, 1, 0)
end

function ScrollAnimator.setupLeftAlignedLabel(trackNameLabel)
	trackNameLabel.AnchorPoint = Vector2.new(0, 0.5)
	trackNameLabel.Position = UDim2.new(0, 0, 0.5, 0)
end

function ScrollAnimator.createScrollAnimation(trackNameLabel, scrollState, textWidth, frameWidth, config)
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

function ScrollAnimator.animateTrackNameScroll(trackNameLabel, trackFrame, scrollState, config)
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

-------------------
-- Return Module --
-------------------

return ScrollAnimator