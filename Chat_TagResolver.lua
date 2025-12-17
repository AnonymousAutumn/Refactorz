-----------------
-- Init Module --
-----------------

local TagResolver = {}

--------------
-- Services --
--------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local configurationFolder = ReplicatedStorage.Configuration
local tagConfig = configurationFolder.TagConfig

---------------
-- Functions --
---------------

function TagResolver.getChatTagProperties(message)
	if not message.TextSource and message.Metadata ~= "Global" then
		local tag = tagConfig.Server 
		return tag.UIGradient , tag.Tag.Value
	end

	local source = message.TextSource
	if not source then
		return nil, nil
	end

	if source.UserId == game.CreatorId then
		local tag = tagConfig.Creator 
		return tag.UIGradient , tag.Tag.Value
	end

	local player = Players:GetPlayerByUserId(source.UserId)
	if player and player:IsFriendsWith(game.CreatorId) then
		local tag = tagConfig.Tester 
		return tag.UIGradient , tag.Tag.Value
	end

	return nil, nil
end

-------------------
-- Return Module --
-------------------

return TagResolver