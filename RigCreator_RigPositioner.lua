-----------------
-- Init Module --
-----------------

local RigPositioner = {}
RigPositioner.safeExecute = nil

---------------
-- Functions --
---------------

local function getR15PositionTarget(rankPositionReference, characterRootPart, humanoid)
	local r15PositionTarget = rankPositionReference:FindFirstChild("R15")
	if not r15PositionTarget or not r15PositionTarget:IsA("BasePart") then
		return nil
	end

	local r15HeightOffset = humanoid.HipHeight + (characterRootPart.Size.Y * 0.5)
	return r15PositionTarget.CFrame * CFrame.new(0, r15HeightOffset, 0)
end

local function getR6PositionTarget(rankPositionReference)
	local r6PositionTarget = rankPositionReference:FindFirstChild("R6")
	return (r6PositionTarget and r6PositionTarget:IsA("BasePart")) and r6PositionTarget.CFrame or nil
end

function RigPositioner.positionCharacterAtRankLocation(characterRig, rankPositionReference)
	if not characterRig or not characterRig:IsA("Model") or not rankPositionReference or not rankPositionReference:IsA("Model") then
		return false
	end

	if not RigPositioner.safeExecute then
		return false
	end

	return RigPositioner.safeExecute(function()
		local characterHumanoid = characterRig:FindFirstChildOfClass("Humanoid")
		local characterRootPart = characterRig:FindFirstChild("HumanoidRootPart")

		if not characterHumanoid or not characterRootPart then
			return
		end

		local targetCFrame
		if characterHumanoid.RigType == Enum.HumanoidRigType.R15 then
			targetCFrame = getR15PositionTarget(rankPositionReference, characterRootPart, characterHumanoid)
			if targetCFrame then
				characterRig:PivotTo(targetCFrame)
			end
		else
			targetCFrame = getR6PositionTarget(rankPositionReference)
			if targetCFrame then
				characterRootPart.CFrame = targetCFrame
			end
		end
	end)
end

-------------------
-- Return Module --
-------------------

return RigPositioner