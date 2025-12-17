--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

----------------
-- References --
----------------

local networkFolder = ReplicatedStorage.Network
local remoteEvents = networkFolder.Remotes.Events
local sendMessageEvent = remoteEvents.SendMessage

local modulesFolder = ReplicatedStorage.Modules
local Connections = require(modulesFolder.Wrappers.Connections)
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local GradientProcessor = require(script.GradientProcessor)
local TextFormatter = require(script.TextFormatter)
local TagResolver = require(script.TagResolver)
local MessageDisplay = require(script.MessageDisplay)

---------------
-- Constants --
---------------

local DEFAULT_TEXT_COLOR = "#FFFFFF"

---------------
-- Variables --
---------------

local connectionsMaid = Connections.new()

---------------
-- Functions --
---------------

local function createChatTag(tagColorOrGradient, playerName, message)
	local prefix = if message and message.PrefixText then message.PrefixText else ""
	local nameString = tostring(playerName)
	local formattedName
	local colorString = DEFAULT_TEXT_COLOR
	local usesGradient = false

	if ValidationUtils.isValidFolder(tagColorOrGradient) then
		local gradient = tagColorOrGradient:FindFirstChildOfClass("UIGradient")

		if gradient then
			usesGradient = true
			formattedName = GradientProcessor.processGradientText(
				gradient,
				nameString,
				TextFormatter.stripRichTextTags
			)
		else
			local colorValue = tagColorOrGradient:FindFirstChild("COLOR")
			if ValidationUtils.isValidStringValue(colorValue) then
				colorString = (colorValue ).Value
			end
			formattedName = `<font color='{colorString}'>{nameString}</font>`
		end
	elseif GradientProcessor.isValidUIGradient(tagColorOrGradient) then
		usesGradient = true
		formattedName = GradientProcessor.processGradientText(
			tagColorOrGradient,
			nameString,
			TextFormatter.stripRichTextTags
		)
	elseif typeof(tagColorOrGradient) == "string" then
		colorString = tagColorOrGradient
		formattedName = `<font color='{colorString}'>{nameString}</font>`
	else
		formattedName = `<font color='{DEFAULT_TEXT_COLOR}'>{nameString}</font>`
	end

	if usesGradient then
		return `<b>{formattedName}</b> {prefix}`
	end
	return `<font color='{colorString}'><b>{formattedName}</b></font> {prefix}`
end

local function onIncomingMessage(message)
	local properties = Instance.new("TextChatMessageProperties")
	local tagColor, tagName = TagResolver.getChatTagProperties(message)

	if tagColor and tagName then
		properties.PrefixText = createChatTag(tagColor, tagName, message)
	end

	return properties
end

local function initialize()
	TextChatService.OnIncomingMessage = onIncomingMessage
	
	connectionsMaid:add(sendMessageEvent.OnClientEvent:Connect(MessageDisplay.displayRobuxTransaction))
end

--------------------
-- Initialization --
--------------------

initialize()