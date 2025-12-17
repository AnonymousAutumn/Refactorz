local TweenService = game:GetService("TweenService")

local AnimBackground = {}
AnimBackground.__index = AnimBackground

function AnimBackground.new(imageLabel: ImageLabel)
	local self = setmetatable({}, AnimBackground)
	self.imageLabel = imageLabel
	self._tween = nil
	self._isPlaying = false

	self.TILE_SIZE = 45
	self.TWEEN_INFO = TweenInfo.new(10, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false, 0)

	return self
end

function AnimBackground:start()
	if self._isPlaying then return end

	local img = self.imageLabel
	local tile = self.TILE_SIZE

	img.Position = UDim2.new(0, -tile * 4, 0, 0)

	self._tween = TweenService:Create(img, self.TWEEN_INFO, {
		Position = UDim2.new(0, 0, 0, -tile * 4)
	})

	self._tween:Play()
	self._isPlaying = true
end

function AnimBackground:stop()
	if not self._isPlaying then return end
	
	self._tween:Cancel()
	self._tween = nil
	self._isPlaying = false
end

return AnimBackground