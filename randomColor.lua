local random = Random.new()

local function randomColor(): Color3
	local hue = random:NextNumber()
	local sat = random:NextNumber()
	local val = random:NextNumber()

	return Color3.fromHSV(hue, sat, val)
end

return randomColor
