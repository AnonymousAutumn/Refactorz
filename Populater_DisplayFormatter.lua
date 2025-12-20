--[[
	DisplayFormatter - Formats display values for leaderboard entries.

	Features:
	- Username formatting
	- Rank number formatting
	- Statistic value formatting
]]

local DisplayFormatter = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local UsernameCache = require(modulesFolder.Caches.UsernameCache)

local DISPLAY_TYPE_CURRENCY = "currency"

--[[
	Gets a username from user ID via cache.
]]
function DisplayFormatter.getUsernameFromId(playerUserId: number): string
	if not ValidationUtils.isValidUserId(playerUserId) then
		warn(`[{script.Name}] Invalid user ID: {tostring(playerUserId)}`)
		return `<unknown{tonumber(playerUserId) or -1}>`
	end
	return UsernameCache.getUsername(playerUserId)
end

--[[
	Formats username with @ prefix.
]]
function DisplayFormatter.formatUsername(username: string): string
	return `@{username}`
end

--[[
	Formats rank position with # prefix.
]]
function DisplayFormatter.formatRank(rankPosition: number): string
	return `#{rankPosition}`
end

--[[
	Formats statistic value based on display type.
]]
function DisplayFormatter.formatStatistic(statisticValue: number?, config: any): string
	local value = (type(statisticValue) == "number") and statisticValue or 0
	local formattedValue = config.FormatHandler.formatNumberWithThousandsSeparatorCommas(value)

	if config.displayType == DISPLAY_TYPE_CURRENCY then
		return `<font color='#ffb46a'>{config.ROBUX_ICON_UTF}</font> {formattedValue}`
	else
		return `{formattedValue} wins`
	end
end

return DisplayFormatter