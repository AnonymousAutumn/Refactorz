--[[
	GradientProcessor - Applies gradient colors to text.

	Features:
	- UIGradient color extraction
	- Per-character color interpolation
	- Rich text gradient output
]]

local GradientProcessor = {}

local RGB_MULTIPLIER = 255

--[[
	Validates that an instance is a valid UIGradient with keypoints.
]]
function GradientProcessor.isValidUIGradient(instance: any): boolean
	if typeof(instance) ~= "Instance" or not instance:IsA("UIGradient") then
		return false
	end

	local colorSequence = instance.Color
	return colorSequence ~= nil
		and colorSequence.Keypoints ~= nil
		and #colorSequence.Keypoints > 0
end

local function color3ToRGB(color: Color3): (number, number, number)
	return math.floor(color.R * RGB_MULTIPLIER),
		math.floor(color.G * RGB_MULTIPLIER),
		math.floor(color.B * RGB_MULTIPLIER)
end

local function createColoredCharacter(character: string, color: Color3): string
	local r, g, b = color3ToRGB(color)
	return `<font color='rgb({r},{g},{b})'>{character}</font>`
end

local function extractColorKeypoints(gradient: UIGradient): { any }?
	local keypoints = gradient.Color.Keypoints
	if #keypoints == 0 then
		return nil
	end

	local extractedKeypoints = table.create(#keypoints)

	for index, keypoint in pairs(keypoints) do
		extractedKeypoints[index] = {
			Time = keypoint.Time,
			R = keypoint.Value.R,
			G = keypoint.Value.G,
			B = keypoint.Value.B,
		}
	end

	table.sort(extractedKeypoints, function(first, second)
		return first.Time < second.Time
	end)

	return extractedKeypoints
end

local function interpolateGradientColor(keypoints: { any }, time: number): Color3
	local keypointCount = #keypoints

	if keypointCount == 1 then
		local keypoint = keypoints[1]
		return Color3.new(keypoint.R, keypoint.G, keypoint.B)
	end

	local firstKeypoint = keypoints[1]
	local lastKeypoint = keypoints[keypointCount]

	if time <= firstKeypoint.Time then
		return Color3.new(firstKeypoint.R, firstKeypoint.G, firstKeypoint.B)
	end

	if time >= lastKeypoint.Time then
		return Color3.new(lastKeypoint.R, lastKeypoint.G, lastKeypoint.B)
	end

	for i = 1, keypointCount - 1 do
		local currentKeypoint = keypoints[i]
		local nextKeypoint = keypoints[i + 1]

		if time >= currentKeypoint.Time and time <= nextKeypoint.Time then
			local alpha = (time - currentKeypoint.Time) / (nextKeypoint.Time - currentKeypoint.Time)
			local currentColor = Color3.new(currentKeypoint.R, currentKeypoint.G, currentKeypoint.B)
			local nextColor = Color3.new(nextKeypoint.R, nextKeypoint.G, nextKeypoint.B)
			return currentColor:Lerp(nextColor, alpha)
		end
	end

	return Color3.new(lastKeypoint.R, lastKeypoint.G, lastKeypoint.B)
end

local function applyGradientToText(text: string, keypoints: { any }): string
	local textLength = #text

	if textLength <= 1 then
		return text
	end

	local characters = table.create(textLength)
	local lengthMinusOne = textLength - 1

	for i = 1, textLength do
		local time = (i - 1) / lengthMinusOne
		local color = interpolateGradientColor(keypoints, time)
		local character = string.sub(text, i, i)
		characters[i] = createColoredCharacter(character, color)
	end

	return table.concat(characters)
end

--[[
	Processes text with gradient colors from a UIGradient.
]]
function GradientProcessor.processGradientText(gradient: UIGradient, text: string, stripRichTextFunc: (string) -> string): string
	if not GradientProcessor.isValidUIGradient(gradient) then
		return text
	end

	local keypoints = extractColorKeypoints(gradient )
	if not keypoints or #keypoints == 0 then
		return text
	end

	local plainText = stripRichTextFunc(text)
	if #plainText == 0 then
		return text
	end

	return applyGradientToText(plainText, keypoints)
end

return GradientProcessor