-----------------
-- Init Module --
-----------------

local DisplayFormatter = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local UsernameCache = require(modulesFolder.Caches.UsernameCache)

---------------
-- Constants --
---------------

local DISPLAY_TYPE_CURRENCY = "currency"

---------------
-- Functions --
---------------

function DisplayFormatter.getUsernameFromId(playerUserId)
	if not ValidationUtils.isValidUserId(playerUserId) then
		warn(`[{script.Name}] Invalid user ID: {tostring(playerUserId)}`)
		return `<unknown{tonumber(playerUserId) or -1}>`
	end
	return UsernameCache.getUsername(playerUserId)
end

function DisplayFormatter.formatUsername(username)
	return `@{username}`
end

function DisplayFormatter.formatRank(rankPosition)
	return `#{rankPosition}`
end

function DisplayFormatter.formatStatistic(statisticValue, config)
	local value = (type(statisticValue) == "number") and statisticValue or 0
	local formattedValue = config.FormatHandler.formatNumberWithThousandsSeparatorCommas(value)

	if config.displayType == DISPLAY_TYPE_CURRENCY then
		return `<font color='#ffb46a'>{config.ROBUX_ICON_UTF}</font> {formattedValue}`
	else
		return `{formattedValue} wins`
	end
end

-------------------
-- Return Module --
-------------------

return DisplayFormatter