-----------------
-- Init Module --
-----------------

local MessageDisplay = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local TextChannels = TextChatService:WaitForChild("TextChannels")
local SystemChannel = TextChannels:WaitForChild("RBXSystem")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local configurationFolder = ReplicatedStorage.Configuration

local FormatString = require(modulesFolder.Utilities.FormatString)
local RainbowifyString = require(modulesFolder.Utilities.RainbowifyString)
local GameConfig = require(configurationFolder.GameConfig)

---------------
-- Functions --
---------------

function MessageDisplay.displayRobuxTransaction(sender, receiver, action, amount, useRainbow)
	local formattedRobux = FormatString.formatNumberWithThousandsSeparatorCommas(amount)
	local baseMessage = `{sender} {action} <font color='#ffb46a'>{GameConfig.ROBUX_ICON_UTF}</font>{formattedRobux} to {receiver}!`

	local finalMessage = if useRainbow then RainbowifyString(baseMessage) else baseMessage
	local metadata = if useRainbow then "Global" else nil

	SystemChannel:DisplaySystemMessage(finalMessage, metadata)
end

-------------------
-- Return Module --
-------------------

return MessageDisplay