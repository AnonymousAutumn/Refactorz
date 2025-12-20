--[[
	ColorStyler - Applies color styling to leaderboard entries.

	Features:
	- Rank color assignment
	- Alternating row colors
	- Text stroke styling
]]

local ColorStyler = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)

local DEFAULT_EVEN_ROW_COLOR = Color3.fromRGB(50, 50, 50)
local DEFAULT_ODD_ROW_COLOR = Color3.fromRGB(40, 40, 40)
local RANK_STROKE_THICKNESS = 3

local function getFrameChild(frame: Instance, childName: string): Instance?
	return frame:FindFirstChild(childName)
end

--[[
	Gets the color configuration for a specific rank.
]]
function ColorStyler.getRankColor(playerRank: number, rankColorConfiguration: { any }?): any?
	if type(rankColorConfiguration) ~= "table" then
		return nil
	end
	if playerRank > 0 and playerRank <= #rankColorConfiguration then
		return rankColorConfiguration[playerRank]
	end
	return nil
end

--[[
	Gets alternating row background color.
]]
function ColorStyler.getAlternatingRowColor(rankPosition: number): Color3
	return (rankPosition % 2 == 0) and DEFAULT_EVEN_ROW_COLOR or DEFAULT_ODD_ROW_COLOR
end

--[[
	Applies stroke styling to a single label.
]]
function ColorStyler.applyStrokeToLabel(label: TextLabel, strokeColor: Color3)
	local uiStroke = getFrameChild(label, "UIStroke")
	if ValidationUtils.isValidUIStroke(uiStroke) then
		uiStroke.Thickness = RANK_STROKE_THICKNESS
		uiStroke.Color = strokeColor
	end
end

--[[
	Applies stroke styling to multiple labels.
]]
function ColorStyler.applyStrokeToLabels(labels: { TextLabel }, strokeColor: Color3)
	for _, label in pairs(labels) do
		if ValidationUtils.isValidTextLabel(label) then
			ColorStyler.applyStrokeToLabel(label, strokeColor)
		end
	end
end

return ColorStyler