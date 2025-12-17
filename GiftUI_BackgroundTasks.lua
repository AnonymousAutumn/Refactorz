-----------------
-- Init Module --
-----------------

local BackgroundTasks = {}
BackgroundTasks.requestLatestGiftDataCallback = nil
BackgroundTasks.updateTimeDisplayCallback = nil

---------------
-- Constants --
---------------

local GIFT_DATA_REFRESH_INTERVAL = 10
local TIME_DISPLAY_UPDATE_INTERVAL = 1

---------------
-- Functions --
---------------

function BackgroundTasks.startContinuousGiftDataRefreshLoop(threads)
	local refreshTask = task.spawn(function()
		while true do
			task.wait(GIFT_DATA_REFRESH_INTERVAL)
			if BackgroundTasks.requestLatestGiftDataCallback then
				BackgroundTasks.requestLatestGiftDataCallback()
			end
		end
	end)
	table.insert(threads, refreshTask)
end

function BackgroundTasks.startContinuousTimeDisplayUpdateLoop(threads, giftDisplayFrame)
	local updateTask = task.spawn(function()
		while true do
			task.wait(TIME_DISPLAY_UPDATE_INTERVAL)
			if giftDisplayFrame.Visible and BackgroundTasks.updateTimeDisplayCallback then
				BackgroundTasks.updateTimeDisplayCallback()
			end
		end
	end)
	table.insert(threads, updateTask)
end

-------------------
-- Return Module --
-------------------

return BackgroundTasks