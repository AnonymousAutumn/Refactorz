--[[
	ValidationHandler - Validates gift-related user inputs.

	Features:
	- Gift data validation
	- Username/UserId lookup
	- Input validation with error display
]]

local ValidationHandler = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)

local ERROR_INVALID_USERNAME = "INVALID USERNAME"
local ERROR_CANNOT_GIFT_SELF = "CANNOT GIFT TO YOURSELF"

--[[
	Validates gift data structure.
]]
function ValidationHandler.isValidGiftData(data: any): boolean
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

--[[
	Retrieves a UserId from a username.
]]
function ValidationHandler.retrieveUserIdFromUsername(playerUsername: string): number?
	if not ValidationUtils.isValidUsername(playerUsername) then
		return nil
	end
	local success, result = pcall(Players.GetUserIdFromNameAsync, Players, playerUsername)
	return success and result or nil
end

--[[
	Retrieves a username from a UserId.
]]
function ValidationHandler.retrieveUsernameFromUserId(userId: number): string?
	if not (ValidationUtils.isValidNumber(userId) and userId >= 0) then
		return nil
	end
	local success, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	return success and result or nil
end

--[[
	Validates username input and displays error if invalid.
]]
function ValidationHandler.validateUsernameInput(username: string, displayTemporaryErrorMessage: (string) -> ()): boolean
	if not ValidationUtils.isValidUsername(username) then
		displayTemporaryErrorMessage(ERROR_INVALID_USERNAME)
		return false
	end
	return true
end

--[[
	Validates target UserId and displays error if invalid.
]]
function ValidationHandler.validateTargetUserId(userId: number?, displayTemporaryErrorMessage: (string) -> ()): boolean
	if not userId then
		displayTemporaryErrorMessage(ERROR_INVALID_USERNAME)
		return false
	end
	return true
end

--[[
	Validates target username and displays error if invalid.
]]
function ValidationHandler.validateTargetUsername(username: string?, displayTemporaryErrorMessage: (string) -> ()): boolean
	if not username then
		displayTemporaryErrorMessage(ERROR_INVALID_USERNAME)
		return false
	end
	return true
end

--[[
	Checks if the user is attempting to gift to themselves.
]]
function ValidationHandler.isGiftingToSelf(username: string, localPlayerName: string, displayTemporaryErrorMessage: (string) -> ()): boolean
	if username == localPlayerName then
		displayTemporaryErrorMessage(ERROR_CANNOT_GIFT_SELF)
		return true
	end
	return false
end

return ValidationHandler