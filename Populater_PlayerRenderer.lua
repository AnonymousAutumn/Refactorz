-----------------
-- Init Module --
-----------------

local PlayerRenderer = {}

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

local STUDIO_TEST_AVATAR_ID = "rbxassetid://11569282129"
local STUDIO_TEST_NAME = "Studio Test Profile"

---------------
-- Functions --
---------------

function PlayerRenderer.setupStudioTestDisplay(usernameLabel, avatarImage)
	if ValidationUtils.isValidTextLabel(usernameLabel) then
		usernameLabel.Text = STUDIO_TEST_NAME
	end
	if ValidationUtils.isValidImageLabel(avatarImage) then
		avatarImage.Image = STUDIO_TEST_AVATAR_ID
	end
end

function PlayerRenderer.setupRealPlayerDisplay(usernameLabel, avatarImage, playerUserId, formattedUsername, config)
	if ValidationUtils.isValidTextLabel(usernameLabel) then
		usernameLabel.Text = formattedUsername
	end
	if ValidationUtils.isValidImageLabel(avatarImage) then
		avatarImage.Image = string.format(config.AVATAR_HEADSHOT_URL, playerUserId)
	end
end

-------------------
-- Return Module --
-------------------

return PlayerRenderer