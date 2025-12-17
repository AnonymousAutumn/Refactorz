-----------------
-- Init Module --
-----------------

local FrameValidator = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)

---------------
-- Functions --
---------------

local function getFrameChild(frame, childName)
	return frame:FindFirstChild(childName)
end

function FrameValidator.validateStructure(frame)
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

function FrameValidator.getChild(frame, childName)
	return frame:FindFirstChild(childName)
end

function FrameValidator.getHolderFrame(frame)
	return getFrameChild(frame, "Holder")
end

function FrameValidator.getInfoFrame(holderFrame)
	return getFrameChild(holderFrame, "InfoFrame")
end

function FrameValidator.getAmountFrame(frame)
	return getFrameChild(frame, "AmountFrame")
end

-------------------
-- Return Module --
-------------------

return FrameValidator