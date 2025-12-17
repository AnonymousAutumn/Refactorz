-----------------
-- Init Module --
-----------------

local ValidationHandler = {}

--------------
-- Services --
--------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)

---------------
-- Constants --
---------------

local ERROR_INVALID_USERNAME = "INVALID USERNAME"
local ERROR_CANNOT_GIFT_SELF = "CANNOT GIFT TO YOURSELF"

---------------
-- Functions --
---------------

function ValidationHandler.isValidGiftData(data)
	if typeof(data) ~= "table" then
		return false
	end
	return data.Id ~= nil
		and ValidationUtils.isValidString(data.Gifter)
		and ValidationUtils.isValidNumber(data.Amount)
		and data.Amount >= 0
		and ValidationUtils.isValidNumber(data.Timestamp)
		and data.Timestamp >= 0
end

function ValidationHandler.retrieveUserIdFromUsername(playerUsername)
	if not ValidationUtils.isValidUsername(playerUsername) then
		return nil
	end
	local success, result = pcall(Players.GetUserIdFromNameAsync, Players, playerUsername)
	return success and result or nil
end

function ValidationHandler.retrieveUsernameFromUserId(userId)
	if not (ValidationUtils.isValidNumber(userId) and userId >= 0) then
		return nil
	end
	local success, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	return success and result or nil
end

function ValidationHandler.validateUsernameInput(username, displayTemporaryErrorMessage)
	if not ValidationUtils.isValidUsername(username) then
		displayTemporaryErrorMessage(ERROR_INVALID_USERNAME)
		return false
	end
	return true
end

function ValidationHandler.validateTargetUserId(userId, displayTemporaryErrorMessage)
	if not userId then
		displayTemporaryErrorMessage(ERROR_INVALID_USERNAME)
		return false
	end
	return true
end

function ValidationHandler.validateTargetUsername(username, displayTemporaryErrorMessage)
	if not username then
		displayTemporaryErrorMessage(ERROR_INVALID_USERNAME)
		return false
	end
	return true
end

function ValidationHandler.isGiftingToSelf(username, localPlayerName, displayTemporaryErrorMessage)
	if username == localPlayerName then
		displayTemporaryErrorMessage(ERROR_CANNOT_GIFT_SELF)
		return true
	end
	return false
end

-------------------
-- Return Module --
-------------------

return ValidationHandler