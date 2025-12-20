--[[
	TweenHelper - Utility wrapper for TweenService with presets and tracking.

	Features:
	- Common animation presets (FastFadeIn, Bounce, Elastic, etc.)
	- Tween tracker for batch cancellation
	- Sync and async play methods
	- Sequence playback support
]]

local TweenService = game:GetService("TweenService")

local DEFAULT_TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local TweenHelper = {}

-- Common animation presets
TweenHelper.Presets = {
	FastFadeIn = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	FastFadeOut = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	Smooth = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Bounce = TweenInfo.new(0.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
	Elastic = TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
	Spring = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

export type TweenTracker = {
	activeTweens: { Tween },
	play: (self: TweenTracker, target: Instance, tweenInfo: TweenInfo, properties: { [string]: any }) -> Tween,
	playAsync: (self: TweenTracker, target: Instance, tweenInfo: TweenInfo, properties: { [string]: any }) -> (),
	playSequence: (self: TweenTracker, sequence: { { target: Instance, tweenInfo: TweenInfo, properties: { [string]: any }, waitForCompletion: boolean? } }) -> (),
	cancelAll: (self: TweenTracker) -> (),
	cancel: (self: TweenTracker, tween: Tween) -> (),
}

--[[
	Creates a tween tracker that manages multiple active tweens.
	Useful for UI components that need to cancel all animations on cleanup.
]]
function TweenHelper.createTracker(): TweenTracker
	local self = {
		activeTweens = {},
	}

	--[[
		Creates and plays a tween, tracking it for later cancellation.
	]]
	function self:play(target: Instance, tweenInfo: TweenInfo, properties: { [string]: any }): Tween
		local tween = TweenService:Create(target, tweenInfo, properties)

		table.insert(self.activeTweens, tween)

		tween.Completed:Once(function()
			local index = table.find(self.activeTweens, tween)
			if index then
				table.remove(self.activeTweens, index)
			end
		end)

		tween:Play()
		return tween
	end

	--[[
		Plays a tween and waits for it to complete before returning.
	]]
	function self:playAsync(target: Instance, tweenInfo: TweenInfo, properties: { [string]: any })
		local tween = self:play(target, tweenInfo, properties)
		tween.Completed:Wait()
	end

	--[[
		Plays a sequence of tweens, optionally waiting between steps.
	]]
	function self:playSequence(sequence)
		for _, step in sequence do
			if step.waitForCompletion then
				self:playAsync(step.target, step.tweenInfo, step.properties)
			else
				self:play(step.target, step.tweenInfo, step.properties)
			end
		end
	end

	--[[
		Cancels all active tweens and clears the tracker.
	]]
	function self:cancelAll()
		for _, tween in self.activeTweens do
			pcall(tween.Cancel, tween)
		end
		self.activeTweens = {}
	end

	--[[
		Cancels a specific tween and removes it from tracking.
	]]
	function self:cancel(tween: Tween)
		local index = table.find(self.activeTweens, tween)
		if index then
			pcall(tween.Cancel, tween)
			table.remove(self.activeTweens, index)
		end
	end

	return self
end

--[[
	Creates and plays a standalone tween (not tracked).
]]
function TweenHelper.play(target: Instance, tweenInfo: TweenInfo?, properties: { [string]: any }): Tween
	local info = tweenInfo or DEFAULT_TWEEN_INFO
	local tween = TweenService:Create(target, info, properties)
	tween:Play()
	return tween
end

--[[
	Creates and plays a tween, waiting for completion before returning.
]]
function TweenHelper.playAsync(target: Instance, tweenInfo: TweenInfo?, properties: { [string]: any })
	local tween = TweenHelper.play(target, tweenInfo, properties)
	tween.Completed:Wait()
end

return TweenHelper