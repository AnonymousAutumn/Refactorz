local TweenService = game:GetService("TweenService")

local TextController = require(script.TextController)
local AnimBackground = require(script.AnimateBackground)

local Controller = {}
Controller.__index = Controller

function Controller.new(loadingGui)
	local self = setmetatable({}, Controller)
	self.loadingGui = loadingGui
	self._isStarted = false

	self.mainFrame = loadingGui:FindFirstChild("MainFrame")
	self.headerText = self.mainFrame:FindFirstChild("HeaderText")
	self.subText = self.mainFrame:FindFirstChild("SubText")
	self.background = self.mainFrame:FindFirstChild("Background")

	self._textAnim = nil
	self._backgroundAnim = nil

	return self
end

function Controller:start()
	if self._isStarted then return end
	self._isStarted = true

	self._textAnim = TextController.new(self.headerText, self.subText)
	self._backgroundAnim = AnimBackground.new(self.background)

	self._textAnim:start()
	self._backgroundAnim:start()
end

function Controller:finish()
	self.headerText:SetAttribute("LoadingText", "??")
	self._textAnim:finish()
end

return Controller