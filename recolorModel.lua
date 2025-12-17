local RECOLOR_TAG = "Recolor"

local function recolorModel(model: Model, color: Color3)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:HasTag(RECOLOR_TAG) then
			descendant.Color = color
		end
	end
end

return recolorModel
