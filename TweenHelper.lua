-----------------
-- Init Module --
-----------------

local TweenHelper = {}
TweenHelper.Presets = {
	FastFadeIn = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	FastFadeOut = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	Smooth = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Bounce = TweenInfo.new(0.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
	Elastic = TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
	Spring = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

--------------
-- Services --
--------------

local TweenService = game:GetService("TweenService")

---------------
-- Constants --
---------------

local DEFAULT_TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

---------------
-- Functions --
---------------

function TweenHelper.createTracker()
	local self = {} 
	self.activeTweens = {}

	function self:play(target, tweenInfo, properties)
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

	function self:playAsync(target, tweenInfo, properties)
		local tween = self:play(target, tweenInfo, properties)
		tween.Completed:Wait()
	end

	function self:playSequence(sequence)
		for _, step in sequence do
			if step.waitForCompletion then
				self:playAsync(step.target, step.tweenInfo, step.properties)
			else
				self:play(step.target, step.tweenInfo, step.properties)
			end
		end
	end

	function self:cancelAll()
		for _, tween in self.activeTweens do
			pcall(function()
				tween:Cancel()
			end)
		end
		self.activeTweens = {}
	end

	function self:cancel(tween)
		local index = table.find(self.activeTweens, tween)
		if index then
			pcall(function()
				tween:Cancel()
			end)
			table.remove(self.activeTweens, index)
		end
	end

	return self 
end

function TweenHelper.play(target, tweenInfo, properties)
	
	local info = tweenInfo or DEFAULT_TWEEN_INFO
	local tween = TweenService:Create(target, info, properties)
	tween:Play()
	
	return tween
end

function TweenHelper.playAsync(target, tweenInfo, properties)
	local tween = TweenHelper.play(target, tweenInfo, properties)
	tween.Completed:Wait()
end

-------------------
-- Return Module --
-------------------

return TweenHelper