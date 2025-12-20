--[[
	ValidationUtils - Comprehensive validation predicates for Roblox types and game values.

	All functions return boolean and are stateless (safe to call from any context).
]]

local ValidationUtils = {}

local Players = game:GetService("Players")

local MIN_USER_ID = 1

--[[
	Validates that a value is an active Player instance in the game.
	Returns false if player is nil, wrong type, or has left the game.
]]
function ValidationUtils.isValidPlayer(player: any): boolean
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false
	end
	-- Check player is still in the game (not leaving/left)
	return player.Parent ~= nil and player:IsDescendantOf(Players)
end

function ValidationUtils.isValidUserId(userId: any): boolean
	return typeof(userId) == "number" and userId >= MIN_USER_ID
end

function ValidationUtils.isValidFrame(frame: any): boolean
	return typeof(frame) == "Instance" and frame:IsA("Frame") and frame.Parent ~= nil
end

function ValidationUtils.isValidTextLabel(label: any): boolean
	return typeof(label) == "Instance" and label:IsA("TextLabel")
end

function ValidationUtils.isValidTextButton(button: any): boolean
	return typeof(button) == "Instance" and button:IsA("TextButton")
end

function ValidationUtils.isValidImageLabel(label: any): boolean
	return typeof(label) == "Instance" and label:IsA("ImageLabel")
end

function ValidationUtils.isValidUIStroke(stroke: any): boolean
	return typeof(stroke) == "Instance" and stroke:IsA("UIStroke")
end

function ValidationUtils.isValidUIGradient(gradient: any): boolean
	return typeof(gradient) == "Instance" and gradient:IsA("UIGradient")
end

function ValidationUtils.isValidScrollingFrame(frame: any): boolean
	return typeof(frame) == "Instance" and frame:IsA("ScrollingFrame")
end

function ValidationUtils.isValidCharacter(character: any): boolean
	if typeof(character) ~= "Instance" or not character:IsA("Model") then
		return false
	end
	return character.Parent ~= nil and character:FindFirstChild("Humanoid") ~= nil
end

function ValidationUtils.isValidHumanoid(humanoid: any): boolean
	if typeof(humanoid) ~= "Instance" or not humanoid:IsA("Humanoid") then
		return false
	end
	return humanoid.Health > 0
end

function ValidationUtils.isValidFolder(folder: any): boolean
	return typeof(folder) == "Instance" and folder:IsA("Folder")
end

function ValidationUtils.isValidStringValue(value: any): boolean
	return typeof(value) == "Instance" and value:IsA("StringValue")
end

function ValidationUtils.isValidString(value: any): boolean
	return typeof(value) == "string" and #value > 0
end

--[[
	Validates a number is finite (not NaN or infinity).
]]
function ValidationUtils.isValidNumber(value: any): boolean
	if typeof(value) ~= "number" then
		return false
	end
	-- NaN check: NaN is the only value that doesn't equal itself
	if value ~= value then
		return false
	end
	-- Infinity check
	return math.abs(value) ~= math.huge
end

function ValidationUtils.isValidPositiveInteger(value: any): boolean
	return typeof(value) == "number" and value > 0 and value == math.floor(value)
end

function ValidationUtils.isValidNonNegativeInteger(value: any): boolean
	return typeof(value) == "number" and value >= 0 and value == math.floor(value)
end

function ValidationUtils.isValidBoolean(value: any): boolean
	return typeof(value) == "boolean"
end

function ValidationUtils.isValidTable(value: any): boolean
	return typeof(value) == "table"
end

function ValidationUtils.isInRange(value: number, min: number, max: number): boolean
	return value >= min and value <= max
end

function ValidationUtils.isValidRobuxAmount(amount: any): boolean
	return ValidationUtils.isValidNumber(amount) and amount >= 1 and amount == math.floor(amount)
end

function ValidationUtils.isValidDonationAmount(amount: any): boolean
	return ValidationUtils.isValidNumber(amount) and amount > 0
end

--[[
	Validates Roblox username format:
	- 3-20 characters
	- Alphanumeric and underscores only
	- No consecutive underscores
]]
function ValidationUtils.isValidUsername(username: any): boolean
	if not ValidationUtils.isValidString(username) then
		return false
	end

	local len = #username
	if len < 3 or len > 20 then
		return false
	end

	-- Only alphanumeric and underscores allowed
	if not string.match(username, "^[%w_]+$") then
		return false
	end

	-- No consecutive underscores
	if string.find(username, "__") then
		return false
	end

	return true
end

function ValidationUtils.isValidRankPosition(rank: any): boolean
	return ValidationUtils.isValidPositiveInteger(rank)
end

function ValidationUtils.isValidRankIndex(index: any): boolean
	return ValidationUtils.isValidNonNegativeInteger(index)
end

function ValidationUtils.isValidStatisticValue(value: any): boolean
	return ValidationUtils.isValidNumber(value) and value >= 0
end

function ValidationUtils.isValidDisplayCount(count: any): boolean
	return ValidationUtils.isValidPositiveInteger(count) and count <= 100
end

function ValidationUtils.hasRequiredFields(data: any, fields: {string}): boolean
	if not ValidationUtils.isValidTable(data) then
		return false
	end

	for _, field in fields do
		if data[field] == nil then
			return false
		end
	end

	return true
end

function ValidationUtils.validateWithError(isValid: boolean, errorMessage: string): {isValid: boolean, error: string?}
	return {
		isValid = isValid,
		error = if isValid then nil else errorMessage,
	}
end

function ValidationUtils.isValidTrackIndex(index: any, maxIndex: number): boolean
	return ValidationUtils.isValidPositiveInteger(index) and index <= maxIndex
end

function ValidationUtils.isValidUniverseId(universeId: any): boolean
	return ValidationUtils.isValidPositiveInteger(universeId)
end

function ValidationUtils.isValidPlaceId(placeId: any): boolean
	return ValidationUtils.isValidPositiveInteger(placeId)
end

function ValidationUtils.isValidGameId(gameId: any): boolean
	return ValidationUtils.isValidPlaceId(gameId)
end

function ValidationUtils.isValidGamepassId(gamepassId: any): boolean
	return ValidationUtils.isValidPositiveInteger(gamepassId)
end

return ValidationUtils