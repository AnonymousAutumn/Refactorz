--------------
-- Services --
--------------

local UserInputService = game:GetService("UserInputService")
local StarterPlayer = game:GetService("StarterPlayer")

----------------
-- References --
----------------

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")

---------------
-- Constants --
---------------

local ACTIVATION_KEYBIND = Enum.KeyCode.LeftControl

local DEFAULT_WALKSPEED = StarterPlayer.CharacterWalkSpeed
local SPRINT_SPEED = 32

---------------
-- Variables --
---------------

local isSprinting = false

---------------
-- Functions --
---------------

local function isKeybind(input)
	return input.KeyCode == ACTIVATION_KEYBIND
end

local function changeSpeed(input)
	if not isKeybind(input) then
		return
	end
	
	isSprinting = not isSprinting
	humanoid.WalkSpeed = isSprinting and SPRINT_SPEED or DEFAULT_WALKSPEED
end

--------------------
-- Initialization --
--------------------

UserInputService.InputBegan:Connect(changeSpeed)
UserInputService.InputEnded:Connect(changeSpeed)