-----------------
-- Module Init --
-----------------

local NotificationHelper = {}
NotificationHelper.Types = {
	SUCCESS = "Success",
	WARNING = "Warning",
	ERROR = "Error",
	INFO = "Info",
}

---------------
-- Functions --
---------------

function NotificationHelper.send(event, message, notificationType)
	local success, errorMessage = pcall(function()
		event:Fire(message, notificationType or NotificationHelper.Types.INFO)
	end)

	if not success then
		warn(`[{script.Name}] Failed to send notification: {tostring(errorMessage)}`)
		return false
	end

	return true
end

function NotificationHelper.sendSuccess(event, message)
	return NotificationHelper.send(event, message, NotificationHelper.Types.SUCCESS)
end

function NotificationHelper.sendWarning(event, message)
	return NotificationHelper.send(event, message, NotificationHelper.Types.WARNING)
end

function NotificationHelper.sendError(event, message)
	return NotificationHelper.send(event, message, NotificationHelper.Types.ERROR)
end

function NotificationHelper.sendInfo(event, message)
	return NotificationHelper.send(event, message, NotificationHelper.Types.INFO)
end

-------------------
-- Return Module --
-------------------

return NotificationHelper