--[[
	EnhancedValidation - Advanced validation with constraints, bounds, and custom validators.

	Extends ValidationUtils with:
	- Configurable number/string bounds
	- Custom validator callbacks
	- Remote argument batch validation
	- Physics-based action validation
]]

local EnhancedValidation = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)

local DEFAULT_STRING_MAX_LENGTH = 1000
local DEFAULT_NUMBER_MIN = -1e9
local DEFAULT_NUMBER_MAX = 1e9

export type ValidationConstraints = {
	min: number?,
	max: number?,
	minLength: number?,
	maxLength: number?,
	allowNil: boolean?,
	customValidator: ((any) -> boolean)?,
}

local function validateArgumentType(value: any, expectedType: string, allowNil: boolean?): boolean
	if allowNil and value == nil then
		return true
	end
	return typeof(value) == expectedType
end

local function validateNumberBounds(value: number, constraints: ValidationConstraints?): boolean
	if not ValidationUtils.isValidNumber(value) then
		return false
	end

	local min = if constraints and constraints.min then constraints.min else DEFAULT_NUMBER_MIN
	local max = if constraints and constraints.max then constraints.max else DEFAULT_NUMBER_MAX

	return value >= min and value <= max
end

local function validateStringLength(value: string, constraints: ValidationConstraints?): boolean
	local length = #value
	local minLength = if constraints and constraints.minLength then constraints.minLength else 0
	local maxLength = if constraints and constraints.maxLength then constraints.maxLength else DEFAULT_STRING_MAX_LENGTH

	return length >= minLength and length <= maxLength
end

local function validateNumberSanity(value: any): boolean
	if typeof(value) ~= "number" then
		return true
	end
	return ValidationUtils.isValidNumber(value)
end

local function validateSingleArgument(value: any, expectedType: string, constraints: ValidationConstraints?): boolean
	local allowNil = constraints and constraints.allowNil or false

	if not validateArgumentType(value, expectedType, allowNil) then
		return false
	end

	if allowNil and value == nil then
		return true
	end

	if expectedType == "number" then
		if not validateNumberSanity(value) then
			return false
		end
		if not validateNumberBounds(value, constraints) then
			return false
		end
	elseif expectedType == "string" then
		if not validateStringLength(value, constraints) then
			return false
		end
	end

	if constraints and constraints.customValidator then
		if not constraints.customValidator(value) then
			return false
		end
	end

	return true
end

--[[
	Validates multiple arguments from a RemoteEvent call.
	Each validation is a tuple: {value, expectedType, constraints?}
]]
function EnhancedValidation.validateRemoteArgs(player: Player, validations: {{any}}): boolean
	if not ValidationUtils.isValidPlayer(player) then
		warn("[EnhancedValidation] Invalid player in RemoteEvent")
		return false
	end

	for _, validation in validations do
		local value = validation[1]
		local expectedType = validation[2]
		local constraints = validation[3]

		if not validateSingleArgument(value, expectedType, constraints) then
			warn(`[EnhancedValidation] Invalid argument from player {player.Name}: expected {expectedType}`)
			return false
		end
	end

	return true
end

--[[
	Validates a player instance is valid and in-game.
]]
function EnhancedValidation.validatePlayer(player: any): boolean
	return ValidationUtils.isValidPlayer(player)
end

--[[
	Validates a number is within optional min/max bounds.
]]
function EnhancedValidation.validateNumber(value: any, min: number?, max: number?): boolean
	return validateSingleArgument(value, "number", {
		min = min,
		max = max,
	})
end

--[[
	Validates a string is within optional length bounds.
]]
function EnhancedValidation.validateString(value: any, minLength: number?, maxLength: number?): boolean
	return validateSingleArgument(value, "string", {
		minLength = minLength,
		maxLength = maxLength,
	})
end

--[[
	Validates a positive integer with optional maximum.
]]
function EnhancedValidation.validatePositiveInteger(value: any, max: number?): boolean
	if not ValidationUtils.isValidNumber(value) then
		return false
	end

	if value < 1 or value ~= math.floor(value) then
		return false
	end

	if max and value > max then
		return false
	end

	return true
end

--[[
	Validates a Roblox user ID.
]]
function EnhancedValidation.validateUserId(userId: any): boolean
	return ValidationUtils.isValidUserId(userId)
end

--[[
	Validates a table has all required fields.
]]
function EnhancedValidation.validateRequiredFields(data: any, requiredFields: {string}): boolean
	return ValidationUtils.hasRequiredFields(data, requiredFields)
end

--[[
	Validates an action is physically possible based on player distance to target.
	Returns true if no target position is provided.
]]
function EnhancedValidation.isActionPhysicallyPossible(player: Player, targetPosition: Vector3?, maxDistance: number?): boolean
	if not ValidationUtils.isValidPlayer(player) then
		return false
	end

	local character = player.Character
	if not ValidationUtils.isValidCharacter(character) then
		return false
	end

	if not targetPosition then
		return true
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart or not humanoidRootPart:IsA("BasePart") then
		return false
	end

	local distance = (humanoidRootPart.Position - targetPosition).Magnitude
	local max = maxDistance or 100

	return distance <= max
end

--[[
	Validates all elements in an array are valid numbers.
]]
function EnhancedValidation.validateNumberArray(array: any): boolean
	if typeof(array) ~= "table" then
		return false
	end

	for _, value in array do
		if not ValidationUtils.isValidNumber(value) then
			return false
		end
	end

	return true
end

--[[
	Validates a Vector3 has finite components.
]]
function EnhancedValidation.validateVector3(vector: any): boolean
	if typeof(vector) ~= "Vector3" then
		return false
	end

	return ValidationUtils.isValidNumber(vector.X)
		and ValidationUtils.isValidNumber(vector.Y)
		and ValidationUtils.isValidNumber(vector.Z)
end

--[[
	Validates a CFrame has finite position components.
]]
function EnhancedValidation.validateCFrame(cframe: any): boolean
	if typeof(cframe) ~= "CFrame" then
		return false
	end

	local position = cframe.Position
	return ValidationUtils.isValidNumber(position.X)
		and ValidationUtils.isValidNumber(position.Y)
		and ValidationUtils.isValidNumber(position.Z)
end

return EnhancedValidation