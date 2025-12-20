--[[
	FrameValidator - Validates leaderboard frame structure.

	Features:
	- Frame hierarchy validation
	- Child element accessors
	- Structure verification
]]

local FrameValidator = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)

local function getFrameChild(frame: Instance, childName: string): Instance?
	return frame:FindFirstChild(childName)
end

--[[
	Validates that a frame has the expected structure.
]]
function FrameValidator.validateStructure(frame: Frame?): boolean
	if not ValidationUtils.isValidFrame(frame) then
		return false
	end
	
	local holderFrame = getFrameChild(frame, "Holder")
	if not holderFrame then
		return false
	end
	
	local infoFrame = getFrameChild(holderFrame, "InfoFrame")
	if not infoFrame then
		return false
	end
	return true
end

--[[
	Gets a child element by name.
]]
function FrameValidator.getChild(frame: Instance, childName: string): Instance?
	return frame:FindFirstChild(childName)
end

--[[
	Gets the holder frame child.
]]
function FrameValidator.getHolderFrame(frame: Instance): Instance?
	return getFrameChild(frame, "Holder")
end

--[[
	Gets the info frame child.
]]
function FrameValidator.getInfoFrame(holderFrame: Instance): Instance?
	return getFrameChild(holderFrame, "InfoFrame")
end

--[[
	Gets the amount frame child.
]]
function FrameValidator.getAmountFrame(frame: Instance): Instance?
	return getFrameChild(frame, "AmountFrame")
end

return FrameValidator