local MAX_STANDARD_FRAMES = 10
local MAX_LARGE_FRAMES = 5
local FRAME_CLEANUP_INTERVAL = 30

local LARGE_FRAME_LAYOUT_MODIFIER = -1
local STANDARD_FRAME_LAYOUT_MODIFIER = 1

local DonationFrameManager = {}
DonationFrameManager.__index = DonationFrameManager

function DonationFrameManager.new(largeDonationContainer, standardDonationContainer)
	local self = setmetatable({}, DonationFrameManager) 

	self.activeDonationFrames = {
		large = {},
		standard = {},
	} 

	self.largeDonationContainer = largeDonationContainer
	self.standardDonationContainer = standardDonationContainer
	self.cleanupThread = nil
	self.isShuttingDown = false

	return self
end

function DonationFrameManager:removeFromTracking(frame, frameType)
	local list = self.activeDonationFrames[frameType]
	for i, tracked in list do
		if tracked == frame then
			table.remove(list, i)
			break
		end
	end
end

local function destroyOldestFrame(trackingList)
	local oldestFrame = table.remove(trackingList, 1)
	if oldestFrame and oldestFrame.Parent ~= nil then
		oldestFrame:Destroy()
	end
end

function DonationFrameManager:enforceLimit(frameType, maxFrames)
	local list = self.activeDonationFrames[frameType]
	while #list >= maxFrames do
		destroyOldestFrame(list)
	end
end

function DonationFrameManager:adjustLayoutOrdering(donationDisplayType)
	local targetDisplayFrame = if donationDisplayType == "Large"
		then self.largeDonationContainer
		else self.standardDonationContainer
	local layoutOrderModifier = if donationDisplayType == "Large"
		then LARGE_FRAME_LAYOUT_MODIFIER
		else STANDARD_FRAME_LAYOUT_MODIFIER

	local children = targetDisplayFrame:GetChildren()
	for _, donationFrame in children do
		if donationFrame:IsA("CanvasGroup") then
			donationFrame.LayoutOrder += layoutOrderModifier
		end
	end
end

function DonationFrameManager:scheduleCleanup(frame, frameType, delaySeconds)
	task.delay(delaySeconds, function()
		self:removeFromTracking(frame, frameType)
		if frame and frame.Parent ~= nil then
			frame:Destroy()
		end
	end)
end

function DonationFrameManager:addLargeFrame(frame)
	table.insert(self.activeDonationFrames.large, frame)
end

function DonationFrameManager:addStandardFrame(frame)
	table.insert(self.activeDonationFrames.standard, frame)
end

function DonationFrameManager:getLargeContainer()
	return self.largeDonationContainer
end

function DonationFrameManager:getStandardContainer()
	return self.standardDonationContainer
end

function DonationFrameManager.getMaxLimits()
	return MAX_LARGE_FRAMES, MAX_STANDARD_FRAMES
end

function DonationFrameManager:performCleanup()
	if self.isShuttingDown then
		return
	end

	local cleanedCount = 0

	for i = #self.activeDonationFrames.large, 1, -1 do
		local frame = self.activeDonationFrames.large[i]
		if not (frame and frame.Parent ~= nil) then
			table.remove(self.activeDonationFrames.large, i)
			cleanedCount += 1
		end
	end

	for i = #self.activeDonationFrames.standard, 1, -1 do
		local frame = self.activeDonationFrames.standard[i]
		if not (frame and frame.Parent ~= nil) then
			table.remove(self.activeDonationFrames.standard, i)
			cleanedCount += 1
		end
	end
end

function DonationFrameManager:startCleanupLoop()
	if self.cleanupThread then
		return
	end

	self.cleanupThread = task.spawn(function()
		while not self.isShuttingDown do
			task.wait(FRAME_CLEANUP_INTERVAL)
			self:performCleanup()
		end
	end)
end

function DonationFrameManager:stopCleanupLoop()
	if self.cleanupThread then
		task.cancel(self.cleanupThread)
		self.cleanupThread = nil
	end
end

function DonationFrameManager:destroyAll()
	for _, frame in self.activeDonationFrames.large do
		if frame and frame.Parent ~= nil then
			frame:Destroy()
		end
	end
	for _, frame in self.activeDonationFrames.standard do
		if frame and frame.Parent ~= nil then
			frame:Destroy()
		end
	end
	table.clear(self.activeDonationFrames.large)
	table.clear(self.activeDonationFrames.standard)
end

function DonationFrameManager:shutdown()
	self.isShuttingDown = true
	self:stopCleanupLoop()
end

return DonationFrameManager