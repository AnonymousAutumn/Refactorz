--[[
	DonationFrameManager - Manages donation display frame lifecycle.

	Features:
	- Frame tracking and limits
	- Layout ordering
	- Automatic cleanup
]]

local MAX_STANDARD_FRAMES = 10
local MAX_LARGE_FRAMES = 5
local FRAME_CLEANUP_INTERVAL = 30

local LARGE_FRAME_LAYOUT_MODIFIER = -1
local STANDARD_FRAME_LAYOUT_MODIFIER = 1

local DonationFrameManager = {}
DonationFrameManager.__index = DonationFrameManager

--[[
	Creates a new DonationFrameManager instance.
]]
function DonationFrameManager.new(largeDonationContainer: Frame, standardDonationContainer: Frame): any
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

--[[
	Removes a frame from the tracking list.
]]
function DonationFrameManager:removeFromTracking(frame: Frame, frameType: string)
	local list = self.activeDonationFrames[frameType]
	for i, tracked in pairs(list) do
		if tracked == frame then
			table.remove(list, i)
			break
		end
	end
end

local function destroyOldestFrame(trackingList: { Frame })
	local oldestFrame = table.remove(trackingList, 1)
	if oldestFrame and oldestFrame.Parent ~= nil then
		oldestFrame:Destroy()
	end
end

--[[
	Enforces frame count limits.
]]
function DonationFrameManager:enforceLimit(frameType: string, maxFrames: number)
	local list = self.activeDonationFrames[frameType]
	while #list >= maxFrames do
		destroyOldestFrame(list)
	end
end

--[[
	Adjusts layout ordering for frames.
]]
function DonationFrameManager:adjustLayoutOrdering(donationDisplayType: string)
	local targetDisplayFrame = if donationDisplayType == "Large"
		then self.largeDonationContainer
		else self.standardDonationContainer
	local layoutOrderModifier = if donationDisplayType == "Large"
		then LARGE_FRAME_LAYOUT_MODIFIER
		else STANDARD_FRAME_LAYOUT_MODIFIER

	local children = targetDisplayFrame:GetChildren()
	for _, donationFrame in pairs(children) do
		if donationFrame:IsA("CanvasGroup") then
			donationFrame.LayoutOrder += layoutOrderModifier
		end
	end
end

--[[
	Schedules cleanup of a frame after delay.
]]
function DonationFrameManager:scheduleCleanup(frame: Frame, frameType: string, delaySeconds: number)
	task.delay(delaySeconds, function()
		self:removeFromTracking(frame, frameType)
		if frame and frame.Parent ~= nil then
			frame:Destroy()
		end
	end)
end

--[[
	Adds a frame to large frames tracking.
]]
function DonationFrameManager:addLargeFrame(frame: Frame)
	table.insert(self.activeDonationFrames.large, frame)
end

--[[
	Adds a frame to standard frames tracking.
]]
function DonationFrameManager:addStandardFrame(frame: Frame)
	table.insert(self.activeDonationFrames.standard, frame)
end

--[[
	Gets the large donation container.
]]
function DonationFrameManager:getLargeContainer(): Frame
	return self.largeDonationContainer
end

--[[
	Gets the standard donation container.
]]
function DonationFrameManager:getStandardContainer(): Frame
	return self.standardDonationContainer
end

--[[
	Gets maximum frame limits.
]]
function DonationFrameManager.getMaxLimits(): (number, number)
	return MAX_LARGE_FRAMES, MAX_STANDARD_FRAMES
end

--[[
	Performs cleanup of orphaned frames.
]]
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

--[[
	Starts the periodic cleanup loop.
]]
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

--[[
	Stops the cleanup loop.
]]
function DonationFrameManager:stopCleanupLoop()
	if self.cleanupThread then
		task.cancel(self.cleanupThread)
		self.cleanupThread = nil
	end
end

--[[
	Destroys all tracked frames.
]]
function DonationFrameManager:destroyAll()
	for _, frame in pairs(self.activeDonationFrames.large) do
		if frame and frame.Parent ~= nil then
			frame:Destroy()
		end
	end
	for _, frame in pairs(self.activeDonationFrames.standard) do
		if frame and frame.Parent ~= nil then
			frame:Destroy()
		end
	end
	table.clear(self.activeDonationFrames.large)
	table.clear(self.activeDonationFrames.standard)
end

--[[
	Shuts down the manager.
]]
function DonationFrameManager:shutdown()
	self.isShuttingDown = true
	self:stopCleanupLoop()
end

return DonationFrameManager