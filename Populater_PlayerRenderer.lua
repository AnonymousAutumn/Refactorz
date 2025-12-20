--[[
	PlayerRenderer - Renders player information in leaderboard entries.

	Features:
	- Avatar image display
	- Username label setup
	- Studio test fallback display
]]

local PlayerRenderer = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)

local STUDIO_TEST_AVATAR_ID = "rbxassetid://11569282129"
local STUDIO_TEST_NAME = "Studio Test Profile"

--[[
	Sets up display for studio testing mode.
]]
function PlayerRenderer.setupStudioTestDisplay(usernameLabel: TextLabel?, avatarImage: ImageLabel?)
	if ValidationUtils.isValidTextLabel(usernameLabel) then
		usernameLabel.Text = STUDIO_TEST_NAME
	end
	if ValidationUtils.isValidImageLabel(avatarImage) then
		avatarImage.Image = STUDIO_TEST_AVATAR_ID
	end
end

--[[
	Sets up display for a real player.
]]
function PlayerRenderer.setupRealPlayerDisplay(usernameLabel: TextLabel?, avatarImage: ImageLabel?, playerUserId: number, formattedUsername: string, config: any)
	if ValidationUtils.isValidTextLabel(usernameLabel) then
		usernameLabel.Text = formattedUsername
	end
	if ValidationUtils.isValidImageLabel(avatarImage) then
		avatarImage.Image = string.format(config.AVATAR_HEADSHOT_URL, playerUserId)
	end
end

return PlayerRenderer