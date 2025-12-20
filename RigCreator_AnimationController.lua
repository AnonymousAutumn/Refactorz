--[[
	AnimationController - Manages character idle animations.

	Features:
	- R15 and R6 idle animation support
	- Animation track lifecycle management
	- Safe animation cleanup
]]

local AnimationController = {}
AnimationController.safeExecute = nil

local CHARACTER_IDLE_ANIMATION_IDS = {
	R15 = "rbxassetid://507766388",
	R6 = "rbxassetid://180435571",
}

local function createAndLoadAnimation(animator: Animator, animationId: string): AnimationTrack
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	local idleTrack = animator:LoadAnimation(animation)
	idleTrack.Looped = true
	animation:Destroy()
	return idleTrack
end

--[[
	Starts the idle animation for a character humanoid.
]]
function AnimationController.startCharacterIdleAnimation(characterHumanoid: Humanoid?): AnimationTrack?
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

--[[
	Cleans up an animation track by stopping and destroying it.
]]
function AnimationController.cleanupAnimationTrack(animationTrack: AnimationTrack?)
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

return AnimationController