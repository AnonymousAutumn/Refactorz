-----------------
-- Init Module --
-----------------

local NotificationQueue = {}
NotificationQueue.__index = NotificationQueue

---------------
-- Constants --
---------------

local DISPLAY_DURATION = 4

---------------
-- Functions --
---------------

function NotificationQueue.new()
	local self = setmetatable({}, NotificationQueue) 
	self.notifications = {}
	return self 
end

function NotificationQueue:add(frame)
	table.insert(self.notifications, frame)
end

function NotificationQueue:remove(frame)
	for index, activeFrame in self.notifications do
		if activeFrame == frame then
			table.remove(self.notifications, index)
			return true
		end
	end
	return false
end

function NotificationQueue:getAll()
	return self.notifications
end

function NotificationQueue:getCount()
	return #self.notifications
end

function NotificationQueue:clear()
	self.notifications = {}
end

function NotificationQueue:scheduleRemoval(frame, textLabel, onRemove)
	task.delay(DISPLAY_DURATION, function()
		if not frame.Parent then
			return
		end

		onRemove(frame, textLabel)
	end)
end

function NotificationQueue.getDisplayDuration()
	return DISPLAY_DURATION
end

-------------------
-- Return Module --
-------------------

return NotificationQueue