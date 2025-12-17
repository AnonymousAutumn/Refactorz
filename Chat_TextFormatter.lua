-----------------
-- Init Module --
-----------------

local TextFormatter = {}

---------------
-- Constants --
---------------

local RICH_TEXT_TAG_PATTERN = "(<[^<>]->)"
local DEFAULT_TEXT_COLOR = "#FFFFFF"

---------------
-- Functions --
---------------

function TextFormatter.stripRichTextTags(text)
	return string.gsub(text, RICH_TEXT_TAG_PATTERN, "")
end

function TextFormatter.countFormatPlaceholders(formatString)
	local _, count = string.gsub(formatString, "%%s", "")
	return count
end

function TextFormatter.formatWithTemplate(template, coloredName, colorValue, prefix)
	local placeholderCount = TextFormatter.countFormatPlaceholders(template)

	if placeholderCount >= 3 then
		local colorString = if typeof(colorValue) == "string" then colorValue else DEFAULT_TEXT_COLOR
		return string.format(template, colorString, coloredName, prefix)
	elseif placeholderCount == 2 then
		return string.format(template, coloredName, prefix)
	elseif placeholderCount == 1 then
		return string.format(template, coloredName)
	end
	
	return if prefix ~= "" then `{coloredName} {prefix}` else coloredName
end

-------------------
-- Return Module --
-------------------

return TextFormatter