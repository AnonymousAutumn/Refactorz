-----------------
-- Init Module --
-----------------

local AnimationController = {}
AnimationController.safeExecute = nil

---------------
-- Constants --
---------------

local CHARACTER_IDLE_ANIMATION_IDS = {
	R15 = "rbxassetid://507766388",
	R6 = "rbxassetid://180435571",
}

---------------
-- Functions --
---------------

local function createAndLoadAnimation(animator, animationId)
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	local idleTrack = animator:LoadAnimation(animation)
	idleTrack.Looped = true
	animation:Destroy()
	return idleTrack
end

function AnimationController.startCharacterIdleAnimation(characterHumanoid)
	if not characterHumanoid or not characterHumanoid:IsA("Humanoid") then
		return nil
	end

	local success, animationTrack = pcall(function()
		local animator = characterHumanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = characterHumanoid
		end

		local rigType = characterHumanoid.RigType
		local idleAnimationId = (rigType == Enum.HumanoidRigType.R15) and CHARACTER_IDLE_ANIMATION_IDS.R15 or CHARACTER_IDLE_ANIMATION_IDS.R6

		local track = createAndLoadAnimation(animator, idleAnimationId)
		track:Play()
		return track
	end)

	return (success and animationTrack and animationTrack:IsA("AnimationTrack")) and animationTrack or nil
end

function AnimationController.cleanupAnimationTrack(animationTrack)
	if not animationTrack then
		return
	end

	if not AnimationController.safeExecute then
		return
	end

	AnimationController.safeExecute(function()
		if animationTrack.IsPlaying then
			animationTrack:Stop()
		end
		animationTrack:Destroy()
	end)
end

-------------------
-- Return Module --
-------------------

return AnimationController