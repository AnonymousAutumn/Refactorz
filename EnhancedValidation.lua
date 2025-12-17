-----------------
-- Init Module --
-----------------

local EnhancedValidation = {}

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
-- Constants --
---------------

local DEFAULT_STRING_MAX_LENGTH = 1000
local DEFAULT_NUMBER_MIN = -1e9
local DEFAULT_NUMBER_MAX = 1e9

---------------
-- Functions --
---------------

local function validateArgumentType(value, expectedType, allowNil)
	if allowNil and value == nil then
		return true
	end

	return typeof(value) == expectedType
end

local function validateNumberBounds(value, constraints)
	if not ValidationUtils.isValidNumber(value) then
		return false
	end

	local min = if constraints and constraints.min then constraints.min else DEFAULT_NUMBER_MIN
	local max = if constraints and constraints.max then constraints.max else DEFAULT_NUMBER_MAX

	return value >= min and value <= max
end

local function validateStringLength(value, constraints)
	local length = #value
	local minLength = if constraints and constraints.minLength then constraints.minLength else 0
	local maxLength = if constraints and constraints.maxLength then constraints.maxLength else DEFAULT_STRING_MAX_LENGTH

	return length >= minLength and length <= maxLength
end

local function validateNumberSanity(value)
	if typeof(value) ~= "number" then
		return true
	end

	return ValidationUtils.isValidNumber(value)
end

local function validateSingleArgument(value, expectedType, constraints)
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

function EnhancedValidation.validateRemoteArgs(player, validations)
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

function EnhancedValidation.validatePlayer(player)
	return ValidationUtils.isValidPlayer(player)
end

function EnhancedValidation.validateNumber(value, min, max)
	return validateSingleArgument(value, "number", {
		min = min,
		max = max,
	})
end

function EnhancedValidation.validateString(value, minLength, maxLength)
	return validateSingleArgument(value, "string", {
		minLength = minLength,
		maxLength = maxLength,
	})
end

function EnhancedValidation.validatePositiveInteger(value, max)
	if not ValidationUtils.isValidNumber(value) then
		return false
	end

	if value < 1 then
		return false
	end

	if value ~= math.floor(value) then
		return false
	end

	if max and value > max then
		return false
	end

	return true
end

function EnhancedValidation.validateUserId(userId)
	return ValidationUtils.isValidUserId(userId)
end

function EnhancedValidation.validateRequiredFields(data, requiredFields)
	return ValidationUtils.hasRequiredFields(data, requiredFields)
end

function EnhancedValidation.isActionPhysicallyPossible(player, targetPosition, maxDistance)
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

function EnhancedValidation.validateNumberArray(array)
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

function EnhancedValidation.validateVector3(vector)
	if typeof(vector) ~= "Vector3" then
		return false
	end

	return ValidationUtils.isValidNumber(vector.X)
		and ValidationUtils.isValidNumber(vector.Y)
		and ValidationUtils.isValidNumber(vector.Z)
end

function EnhancedValidation.validateCFrame(cframe)
	if typeof(cframe) ~= "CFrame" then
		return false
	end

	local position = cframe.Position
	return ValidationUtils.isValidNumber(position.X)
		and ValidationUtils.isValidNumber(position.Y)
		and ValidationUtils.isValidNumber(position.Z)
end

-------------------
-- Return Module --
-------------------

return EnhancedValidation