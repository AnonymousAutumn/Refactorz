--[[
	TextFormatter - Text formatting utilities for chat.

	Features:
	- Rich text tag stripping
	- Template placeholder formatting
]]

local TextFormatter = {}

local RICH_TEXT_TAG_PATTERN = "(<[^<>]->)"
local DEFAULT_TEXT_COLOR = "#FFFFFF"

--[[
	Strips rich text tags from a string.
]]
function TextFormatter.stripRichTextTags(text: string): string
	return string.gsub(text, RICH_TEXT_TAG_PATTERN, "")
end

--[[
	Counts the number of %s placeholders in a format string.
]]
function TextFormatter.countFormatPlaceholders(formatString: string): number
	local _, count = string.gsub(formatString, "%%s", "")
	return count
end

--[[
	Formats text using a template with placeholders.
]]
function TextFormatter.formatWithTemplate(template: string, coloredName: string, colorValue: string?, prefix: string): string
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

return TextFormatter