-----------------
-- Init Module --
-----------------

local ValidationUtils = {}

--------------
-- Services --
--------------

local Players = game:GetService("Players")

---------------
-- Constants --
---------------

local MIN_USER_ID = 1

---------------
-- Functions --
---------------

function ValidationUtils.isValidPlayer(player)
	if typeof(player) ~= "Instance" then
		return false
	end
	if not player:IsA("Player") then
		return false
	end
	if player.Parent == nil then
		return false
	end
	return Players:FindFirstChild(player.Name) ~= nil
end

function ValidationUtils.isValidUserId(userId)
	if typeof(userId) ~= "number" then
		return false
	end
	return userId >= MIN_USER_ID
end

function ValidationUtils.isValidFrame(frame)
	return typeof(frame) == "Instance" and frame:IsA("Frame") and frame.Parent ~= nil
end

function ValidationUtils.isValidTextLabel(label)
	return typeof(label) == "Instance" and label:IsA("TextLabel")
end

function ValidationUtils.isValidTextButton(button)
	return typeof(button) == "Instance" and button:IsA("TextButton")
end

function ValidationUtils.isValidImageLabel(label)
	return typeof(label) == "Instance" and label:IsA("ImageLabel")
end

function ValidationUtils.isValidUIStroke(stroke)
	return typeof(stroke) == "Instance" and stroke:IsA("UIStroke")
end

function ValidationUtils.isValidUIGradient(gradient)
	return typeof(gradient) == "Instance" and gradient:IsA("UIGradient")
end

function ValidationUtils.isValidScrollingFrame(frame)
	return typeof(frame) == "Instance" and frame:IsA("ScrollingFrame")
end

function ValidationUtils.isValidCharacter(character)
	if typeof(character) ~= "Instance" then
		return false
	end
	if not character:IsA("Model") then
		return false
	end
	if character.Parent == nil then
		return false
	end
	return character:FindFirstChild("Humanoid") ~= nil
end

function ValidationUtils.isValidHumanoid(humanoid)
	if typeof(humanoid) ~= "Instance" then
		return false
	end
	if not humanoid:IsA("Humanoid") then
		return false
	end
	return humanoid.Health > 0
end

function ValidationUtils.isValidFolder(folder)
	return typeof(folder) == "Instance" and folder:IsA("Folder")
end

function ValidationUtils.isValidStringValue(value)
	return typeof(value) == "Instance" and value:IsA("StringValue")
end

function ValidationUtils.isValidString(value)
	return typeof(value) == "string" and #value > 0
end

function ValidationUtils.isValidNumber(value)
	if typeof(value) ~= "number" then
		return false
	end
	if value ~= value then
		return false
	end
	if math.abs(value) == math.huge then
		return false
	end
	return true
end

function ValidationUtils.isValidPositiveInteger(value)
	if typeof(value) ~= "number" then
		return false
	end
	if value <= 0 then
		return false
	end
	return value == math.floor(value)
end

function ValidationUtils.isValidNonNegativeInteger(value)
	if typeof(value) ~= "number" then
		return false
	end
	if value < 0 then
		return false
	end
	return value == math.floor(value)
end

function ValidationUtils.isValidBoolean(value)
	return typeof(value) == "boolean"
end

function ValidationUtils.isValidTable(value)
	return typeof(value) == "table"
end

function ValidationUtils.isInRange(value, min, max)
	return value >= min and value <= max
end

function ValidationUtils.isValidRobuxAmount(amount)
	if not ValidationUtils.isValidNumber(amount) then
		return false
	end
	if amount < 1 then
		return false
	end
	return amount == math.floor(amount)
end

function ValidationUtils.isValidDonationAmount(amount)
	return ValidationUtils.isValidNumber(amount) and amount > 0
end

function ValidationUtils.isValidUsername(username)
	if not ValidationUtils.isValidString(username) then
		return false
	end

	local len = #username
	if len < 3 or len > 20 then
		return false
	end

	if not string.match(username, "^[%w_]+$") then
		return false
	end

	if string.find(username, "__") then
		return false
	end

	return true
end

function ValidationUtils.isValidRankPosition(rank)
	return ValidationUtils.isValidPositiveInteger(rank)
end

function ValidationUtils.isValidRankIndex(index)
	return ValidationUtils.isValidNonNegativeInteger(index)
end

function ValidationUtils.isValidStatisticValue(value)
	return ValidationUtils.isValidNumber(value) and value >= 0
end

function ValidationUtils.isValidDisplayCount(count)
	return ValidationUtils.isValidPositiveInteger(count) and count <= 100
end

function ValidationUtils.hasRequiredFields(data, fields)
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

function ValidationUtils.validateWithError(isValid, errorMessage)
	return {
		isValid = isValid,
		error = if isValid then nil else errorMessage,
	}
end

function ValidationUtils.isValidTrackIndex(index, maxIndex)
	if not ValidationUtils.isValidPositiveInteger(index) then
		return false
	end
	return index <= maxIndex
end

function ValidationUtils.isValidUniverseId(universeId)
	return ValidationUtils.isValidPositiveInteger(universeId)
end

function ValidationUtils.isValidPlaceId(placeId)
	return ValidationUtils.isValidPositiveInteger(placeId)
end

function ValidationUtils.isValidGameId(gameId)
	return ValidationUtils.isValidPlaceId(gameId)
end

function ValidationUtils.isValidGamepassId(gamepassId)
	return ValidationUtils.isValidPositiveInteger(gamepassId)
end

-------------------
-- Return Module --
-------------------

return ValidationUtils