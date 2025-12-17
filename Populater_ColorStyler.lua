-----------------
-- Init Module --
-----------------

local ColorStyler = {}

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

local DEFAULT_EVEN_ROW_COLOR = Color3.fromRGB(50, 50, 50)
local DEFAULT_ODD_ROW_COLOR = Color3.fromRGB(40, 40, 40)
local RANK_STROKE_THICKNESS = 3

---------------
-- Functions --
---------------

local function getFrameChild(frame, childName)
	return frame:FindFirstChild(childName)
end

function ColorStyler.getRankColor(playerRank, rankColorConfiguration)
	if type(rankColorConfiguration) ~= "table" then
		return nil
	end
	if playerRank > 0 and playerRank <= #rankColorConfiguration then
		return rankColorConfiguration[playerRank]
	end
	return nil
end

function ColorStyler.getAlternatingRowColor(rankPosition)
	return (rankPosition % 2 == 0) and DEFAULT_EVEN_ROW_COLOR or DEFAULT_ODD_ROW_COLOR
end

function ColorStyler.applyStrokeToLabel(label, strokeColor)
	local uiStroke = getFrameChild(label, "UIStroke")
	if ValidationUtils.isValidUIStroke(uiStroke) then
		uiStroke.Thickness = RANK_STROKE_THICKNESS
		uiStroke.Color = strokeColor
	end
end

function ColorStyler.applyStrokeToLabels(labels, strokeColor)
	for _, label in labels do
		if ValidationUtils.isValidTextLabel(label) then
			ColorStyler.applyStrokeToLabel(label, strokeColor)
		end
	end
end

-------------------
-- Return Module --
-------------------

return ColorStyler