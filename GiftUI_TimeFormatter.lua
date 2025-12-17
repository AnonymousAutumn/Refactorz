-----------------
-- Init Module --
-----------------

local TimeFormatter = {}

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

local TIME_THRESHOLDS = {
	MINUTE = 60,
	TWO_MINUTES = 120,
	HOUR = 3600,
	TWO_HOURS = 7200,
	DAY = 86400,
	TWO_DAYS = 172800,
}

local MESSAGE_FORMAT_MINUTES_AGO = "%d minutes ago"
local MESSAGE_FORMAT_HOURS_AGO = "%d hours ago"
local MESSAGE_FORMAT_DAYS_AGO = "%d days ago"

local TIME_DESC_FEW_SECONDS = "a few seconds ago"
local TIME_DESC_MINUTE = "a minute ago"
local TIME_DESC_HOUR = "an hour ago"
local TIME_DESC_DAY = "a day ago"

---------------
-- Functions --
---------------

function TimeFormatter.calculateRelativeTimeDescription(giftTimestamp)
	if not (ValidationUtils.isValidNumber(giftTimestamp) and giftTimestamp >= 0) then
		return TIME_DESC_FEW_SECONDS
	end

	local secondsSinceGift = os.time() - giftTimestamp
	local T = TIME_THRESHOLDS

	if secondsSinceGift < T.MINUTE then
		return TIME_DESC_FEW_SECONDS
	elseif secondsSinceGift < T.TWO_MINUTES then
		return TIME_DESC_MINUTE
	elseif secondsSinceGift < T.HOUR then
		local minutesAgo = math.floor(secondsSinceGift / T.MINUTE)
		return `{minutesAgo} minutes ago`
	elseif secondsSinceGift < T.TWO_HOURS then
		return TIME_DESC_HOUR
	elseif secondsSinceGift < T.DAY then
		local hoursAgo = math.floor(secondsSinceGift / T.HOUR)
		return `{hoursAgo} hours ago`
	elseif secondsSinceGift < T.TWO_DAYS then
		return TIME_DESC_DAY
	else
		local daysAgo = math.floor(secondsSinceGift / T.DAY)
		return `{daysAgo} days ago`
	end
end

function TimeFormatter.updateAllGiftTimeDisplayLabels(timeDisplayEntries, safeExecute, errorMessage)
	for i, timeDisplayEntry in timeDisplayEntries do
		local label = timeDisplayEntry.timeDisplayLabel
		if label and label.Parent then
			safeExecute(function()
				label.Text = TimeFormatter.calculateRelativeTimeDescription(timeDisplayEntry.originalTimestamp)
			end, "Error updating time display label")
		end
	end
end

return TimeFormatter