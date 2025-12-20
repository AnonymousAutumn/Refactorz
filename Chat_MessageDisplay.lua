--[[
	MessageDisplay - Displays transaction messages in chat.

	Features:
	- Robux transaction formatting
	- Rainbow text for global broadcasts
]]

local MessageDisplay = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local TextChannels = TextChatService:WaitForChild("TextChannels")
local SystemChannel = TextChannels:WaitForChild("RBXSystem")

local modulesFolder = ReplicatedStorage.Modules
local configurationFolder = ReplicatedStorage.Configuration

local FormatString = require(modulesFolder.Utilities.FormatString)
local RainbowifyString = require(modulesFolder.Utilities.RainbowifyString)
local GameConfig = require(configurationFolder.GameConfig)

--[[
	Displays a Robux transaction message in the system channel.
]]
function MessageDisplay.displayRobuxTransaction(sender: string, receiver: string, action: string, amount: number, useRainbow: boolean?)
	local formattedRobux = FormatString.formatNumberWithThousandsSeparatorCommas(amount)
	local baseMessage = `{sender} {action} <font color='#ffb46a'>{GameConfig.ROBUX_ICON_UTF}</font>{formattedRobux} to {receiver}!`

	local finalMessage = if useRainbow then RainbowifyString(baseMessage) else baseMessage
	local metadata = if useRainbow then "Global" else nil

	SystemChannel:DisplaySystemMessage(finalMessage, metadata)
end

return MessageDisplay