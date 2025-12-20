--[[
	NotificationQueue - Manages notification queue and display timing.

	Features:
	- Queue add/remove operations
	- Scheduled removal with delay
	- OOP-style class pattern
]]

local NotificationQueue = {}
NotificationQueue.__index = NotificationQueue

local DISPLAY_DURATION = 4

--[[
	Creates a new NotificationQueue instance.
]]
function NotificationQueue.new()
	local self = setmetatable({}, NotificationQueue) 
	self.notifications = {}
	return self 
end

--[[
	Adds a notification frame to the queue.
]]
function NotificationQueue:add(frame: Frame)
	table.insert(self.notifications, frame)
end

--[[
	Removes a notification frame from the queue.
]]
function NotificationQueue:remove(frame: Frame): boolean
	for index, activeFrame in pairs(self.notifications) do
		if activeFrame == frame then
			table.remove(self.notifications, index)
			return true
		end
	end
	return false
end

--[[
	Returns all notification frames in the queue.
]]
function NotificationQueue:getAll(): { Frame }
	return self.notifications
end

--[[
	Returns the number of notifications in the queue.
]]
function NotificationQueue:getCount(): number
	return #self.notifications
end

--[[
	Clears all notifications from the queue.
]]
function NotificationQueue:clear()
	self.notifications = {}
end

--[[
	Schedules a notification for removal after display duration.
]]
function NotificationQueue:scheduleRemoval(frame: Frame, textLabel: TextLabel, onRemove: (Frame, TextLabel) -> ())
	task.delay(DISPLAY_DURATION, function()
		if not frame.Parent then
			return
		end

		onRemove(frame, textLabel)
	end)
end

--[[
	Returns the display duration constant.
]]
function NotificationQueue.getDisplayDuration(): number
	return DISPLAY_DURATION
end

return NotificationQueue