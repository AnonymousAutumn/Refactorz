local RunService = game:GetService("RunService")

local AnimText = {}
AnimText.__index = AnimText

local MAX_DOTS = 3
local FADE_DURATION = 0.1
local HOLD_DURATION = 0.05
local FADE_SPEED = 1 / FADE_DURATION

local DOT_FORMAT = '<font transparency="%.2f"> .</font>'
local BASE_LOADING_TEXT = "LOADING"
local COMPLETION_MESSAGE = "??"

local function updateText (textLabel, text)
	textLabel.Text = text
end

function AnimText.new(headerText, subText)
	local self = setmetatable({}, AnimText)

	self.headerText = headerText
	self.subText = subText

	self._isAnimating = false
	self._animThread = nil

	self._opacities = table.create(MAX_DOTS, 1)

	return self
end

function AnimText:_getLoadingText()
	return self.headerText:GetAttribute("LoadingText")
end

function AnimText:_isComplete()
	return self:_getLoadingText() == COMPLETION_MESSAGE
end

function AnimText:_render()
	local parts = table.create(MAX_DOTS + 1)
	parts[1] = BASE_LOADING_TEXT

	for i = 1, MAX_DOTS do
		parts[i + 1] = string.format(DOT_FORMAT, self._opacities[i])
	end

	updateText(self.headerText, table.concat(parts))
	updateText(self.subText, string.lower(self:_getLoadingText()))
end


---------------------------------------------------------------------
-- Animation Steps
---------------------------------------------------------------------

function AnimText:_fadeDot(index, fadeIn)
	local start = os.clock()

	while true do
		if not self._isAnimating then return false end
		if self:_isComplete() then self:finish(); return false end

		local t = math.min((os.clock() - start) * FADE_SPEED, 1)
		self._opacities[index] = fadeIn and (1 - t) or t

		self:_render()
		if t >= 1 then break end

		RunService.RenderStepped:Wait()
	end

	-- hold
	local holdStart = os.clock()
	while os.clock() - holdStart < HOLD_DURATION do
		if not self._isAnimating then return false end

		self:_render()
		RunService.Heartbeat:Wait()
	end

	return true
end

function AnimText:_cycle()
	-- reset
	for i = 1, MAX_DOTS do
		self._opacities[i] = 1
	end

	-- fade in
	for i = 1, MAX_DOTS do
		if not self:_fadeDot(i, true) then return false end
	end

	-- fade out
	for i = 1, MAX_DOTS do
		if not self:_fadeDot(i, false) then return false end
	end

	return true
end

function AnimText:_run()
	while self._isAnimating do
		if self:_isComplete() then
			self:finish()
			return
		end

		if not self:_cycle() then
			return
		end
	end
end

function AnimText:start()
	if self._isAnimating then return end

	self._isAnimating = true

	self._animThread = task.spawn(function()
		self:_run()
	end)
end

function AnimText:finish()
	if not self._isAnimating then return end
	self._isAnimating = false

	updateText(self.headerText, "??")

	if self._animThread and coroutine.running() ~= self._animThread then
		task.cancel(self._animThread)
	end

	self._animThread = nil
end

function AnimText:stop()
	self:finish()
end

return AnimText