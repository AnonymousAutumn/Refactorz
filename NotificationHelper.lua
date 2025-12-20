--[[
	NotificationHelper - Utility for sending typed notifications via events.

	Provides type-safe notification sending with error handling.
]]

local NotificationHelper = {}

-- Notification type constants
NotificationHelper.Types = {
	SUCCESS = "Success",
	WARNING = "Warning",
	ERROR = "Error",
	INFO = "Info",
}

export type NotificationType = "Success" | "Warning" | "Error" | "Info"

--[[
	Sends a notification through the provided event.
	Returns true on success, false on failure.
]]
function NotificationHelper.send(event: BindableEvent, message: string, notificationType: NotificationType?): boolean
	local success, errorMessage = pcall(function()
		event:Fire(message, notificationType or NotificationHelper.Types.INFO)
	end)

	if not success then
		warn(`[{script.Name}] Failed to send notification: {tostring(errorMessage)}`)
		return false
	end

	return true
end

--[[
	Sends a success notification.
]]
function NotificationHelper.sendSuccess(event: BindableEvent, message: string): boolean
	return NotificationHelper.send(event, message, NotificationHelper.Types.SUCCESS)
end

--[[
	Sends a warning notification.
]]
function NotificationHelper.sendWarning(event: BindableEvent, message: string): boolean
	return NotificationHelper.send(event, message, NotificationHelper.Types.WARNING)
end

--[[
	Sends an error notification.
]]
function NotificationHelper.sendError(event: BindableEvent, message: string): boolean
	return NotificationHelper.send(event, message, NotificationHelper.Types.ERROR)
end

--[[
	Sends an info notification.
]]
function NotificationHelper.sendInfo(event: BindableEvent, message: string): boolean
	return NotificationHelper.send(event, message, NotificationHelper.Types.INFO)
end

return NotificationHelper