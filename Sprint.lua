--[[ Sprint - Character sprint functionality with keybind control ]]

local UserInputService = game:GetService("UserInputService")
local StarterPlayer = game:GetService("StarterPlayer")

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")

local ACTIVATION_KEYBIND = Enum.KeyCode.LeftControl

local DEFAULT_WALKSPEED = StarterPlayer.CharacterWalkSpeed
local SPRINT_SPEED = 32

local isSprinting = false

local function isKeybind(input: InputObject): boolean
	return input.KeyCode == ACTIVATION_KEYBIND
end

local function changeSpeed(input: InputObject)
	if not isKeybind(input) then
		return
	end
	
	isSprinting = not isSprinting
	humanoid.WalkSpeed = isSprinting and SPRINT_SPEED or DEFAULT_WALKSPEED
end

UserInputService.InputBegan:Connect(changeSpeed)
UserInputService.InputEnded:Connect(changeSpeed)