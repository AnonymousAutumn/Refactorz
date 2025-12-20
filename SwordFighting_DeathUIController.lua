--[[
	DeathUIController - Displays death UI animation.

	Features:
	- Banner animation with tween effects
	- Stale animation abort handling
	- Auto-cleanup on completion
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modulesFolder = ReplicatedStorage.Modules
local TweenHelper = require(modulesFolder.Utilities.TweenHelper)

local DURATION = {
	FadeIn = 0.2,
	MoveCenter = 0.2,
	Widen = 0.2,
	Hold = 3,
	FadeOut = 0.25,
	AnimationDelay = 0.2,
	ColorTransition = 0.2,
}

local lastShownAtByUserId = {}

local function isValid(instance: Instance): boolean
	return instance ~= nil and instance.Parent ~= nil
end

--[[
	Displays a death UI animation for the target player.
]]
return function(guiTemplate: ScreenGui, targetPlayer: Player)
	task.spawn(function()
		local playerGui = targetPlayer:FindFirstChild("PlayerGui")
		if not playerGui then
			return
		end

		local guiClone = guiTemplate:Clone()
		guiClone.Parent = playerGui

		local banner = guiClone:FindFirstChild("LevelUpBanner")
		local vigilante = guiClone:FindFirstChild("Vigilante")
		local levelUpText = banner and banner:FindFirstChild("LevelUpText")

		if not (banner and vigilante and levelUpText) then
			guiClone:Destroy()
			return
		end
		if not (banner:IsA("Frame") and vigilante:IsA("ImageLabel") and levelUpText:IsA("TextLabel")) then
			guiClone:Destroy()
			return
		end

		local userId = targetPlayer.UserId
		local animationStartTime = os.clock()
		lastShownAtByUserId[userId] = animationStartTime

		local function abortIfStale()
			if lastShownAtByUserId[userId] ~= animationStartTime then
				if isValid(guiClone) then
					guiClone:Destroy()
				end
				return true
			end
			return false
		end

		banner.Position = UDim2.fromScale(-1.5, 0.5)
		banner.BackgroundColor3 = Color3.new(1, 1, 1)
		banner.Size = UDim2.fromScale(1.2, 0.015)
		banner.BackgroundTransparency = 0

		vigilante.ImageTransparency = 1
		levelUpText.Visible = false
		levelUpText.TextTransparency = 0

		TweenHelper.play(vigilante, TweenInfo.new(DURATION.FadeIn), { ImageTransparency = 0 })
		TweenHelper.playAsync(banner, TweenInfo.new(DURATION.MoveCenter), {
			Position = UDim2.fromScale(0.5, 0.5),
		})

		task.wait(DURATION.AnimationDelay)
		if abortIfStale() then
			return
		end

		TweenHelper.playAsync(banner, TweenInfo.new(DURATION.Widen, Enum.EasingStyle.Back), {
			Size = UDim2.fromScale(1.2, 0.25),
		})
		if abortIfStale() then
			return
		end

		levelUpText.Visible = true

		TweenHelper.play(banner, TweenInfo.new(DURATION.ColorTransition), {
			BackgroundColor3 = Color3.fromRGB(255, 0, 0),
			BackgroundTransparency = 0.45,
		})

		task.wait(DURATION.Hold)
		if abortIfStale() then
			return
		end

		local fadeBanner = TweenHelper.play(banner, TweenInfo.new(DURATION.FadeOut), { BackgroundTransparency = 1 })
		TweenHelper.play(vigilante, TweenInfo.new(DURATION.FadeOut), { ImageTransparency = 1 })
		TweenHelper.play(levelUpText, TweenInfo.new(DURATION.FadeOut), { TextTransparency = 1 })

		fadeBanner.Completed:Wait()
		if isValid(guiClone) then
			guiClone:Destroy()
		end
	end)
end