--[[
	BackgroundTasks - Manages background refresh loops for gift data.

	Features:
	- Continuous gift data refresh
	- Time display update loop
]]

local BackgroundTasks = {}
BackgroundTasks.requestLatestGiftDataCallback = nil
BackgroundTasks.updateTimeDisplayCallback = nil

local GIFT_DATA_REFRESH_INTERVAL = 10
local TIME_DISPLAY_UPDATE_INTERVAL = 1

--[[
	Starts a continuous loop to refresh gift data from the server.
]]
function BackgroundTasks.startContinuousGiftDataRefreshLoop(threads: { thread })
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

--[[
	Starts a continuous loop to update time display labels.
]]
function BackgroundTasks.startContinuousTimeDisplayUpdateLoop(threads: { thread }, giftDisplayFrame: Frame)
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

return BackgroundTasks