--[[
	TagResolver - Resolves chat tags based on player roles.

	Features:
	- Server message tags
	- Creator/Tester tag detection
	- UIGradient-based tag colors
]]

local TagResolver = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local configurationFolder = ReplicatedStorage.Configuration
local tagConfig = configurationFolder.TagConfig

--[[
	Gets chat tag properties for a message based on sender role.
]]
function TagResolver.getChatTagProperties(message: TextChatMessage): (UIGradient?, string?)
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

return TagResolver