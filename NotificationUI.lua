--------------
-- Services --
--------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local networkFolder = ReplicatedStorage.Network
local bindableEvents = networkFolder.Bindables.Events
local remoteEvents = networkFolder.Remotes.Events
local globalNotificationEvent = remoteEvents.CreateNotification
local localNotificationEvent = bindableEvents.CreateNotification

local modulesFolder = ReplicatedStorage.Modules
local Connections = require(modulesFolder.Wrappers.Connections)
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local NotificationAnimator = require(script.NotificationAnimator)
local NotificationQueue = require(script.NotificationQueue)
local SoundManager = require(script.SoundManager)

local instancesFolder = ReplicatedStorage.Instances
local notificationTemplate = instancesFolder.GuiPrefabs.NotificationPrefab

---------------
-- Constants --
---------------

local NOTIFICATION_COLORS = {
	Success = Color3.fromRGB(0, 255, 0),
	Warning = Color3.fromRGB(255, 255, 0),
	Error = Color3.fromRGB(255, 75, 75),
}

local COMPONENT_TEXT_LABEL = "TextLabel"
local COMPONENT_UI_STROKE = "UIStroke"

---------------
-- Variables --
---------------

local notificationQueueMaid = NotificationQueue.new()
local connectionsMaid = Connections.new()

local notificationContainer = nil

---------------
-- Functions --
---------------

local function isValidNotificationType(notificationType)
	return NOTIFICATION_COLORS[notificationType] ~= nil
end

local function safeExecute(func, errorMessage)
	local success, errorDetails = pcall(func)
	if not success then
		warn(`[{script.Name}] {errorMessage}: {tostring(errorDetails)}`)
		return false
	end
	return true
end

local function getUIStroke(frame)
	local uiStroke = frame:FindFirstChild(COMPONENT_UI_STROKE)
	return if ValidationUtils.isValidUIStroke(uiStroke) then uiStroke  else nil
end

local function getTextLabel(frame)
	return frame:FindFirstChild(COMPONENT_TEXT_LABEL)
end

local function isFrameInContainer(frame)
	return frame and frame:IsDescendantOf(notificationContainer)
end

local function repositionSingleNotification(frame, index)
	if not isFrameInContainer(frame) then
		return
	end

	local newPosition = NotificationAnimator.calculatePosition(index, notificationQueueMaid:getCount())

	safeExecute(function()
		NotificationAnimator.animateReposition(frame, newPosition)
	end, "Error repositioning notification")
end

local function repositionNotifications()
	for index, frame in notificationQueueMaid:getAll() do
		repositionSingleNotification(frame, index)
	end
end

local function destroyNotificationFrame(frame)
	safeExecute(function()
		if frame.Parent then
			frame:Destroy()
		end
	end, "Error destroying notification frame")
end

local function handleNotificationRemoval(frame, textLabel)
	NotificationAnimator.animateExit(frame, textLabel)

	task.delay(NotificationAnimator.getStandardDuration(), function()
		destroyNotificationFrame(frame)
		notificationQueueMaid:remove(frame)
		repositionNotifications()
	end)
end

local function validateNotificationParams(message, notificationType)
	if not ValidationUtils.isValidString(message) then
		warn(`[{script.Name}] Invalid message for notification`)
		return false
	end

	if not ValidationUtils.isValidString(notificationType) then
		warn(`[{script.Name}] Invalid notification type`)
		return false
	end

	if not isValidNotificationType(notificationType) then
		warn(`[{script.Name}] Unknown notification type:`, notificationType)
		return false
	end

	return true
end

local function cloneNotificationTemplate()
	local success, clonedFrame = pcall(function()
		return notificationTemplate:Clone()
	end)

	if not success then
		warn(`[{script.Name}] Failed to clone notification template: `, clonedFrame)
		return nil
	end

	return clonedFrame 
end

local function createNotification(message, notificationType)
	if not validateNotificationParams(message, notificationType) then
		return
	end

	local notificationFrame = cloneNotificationTemplate()
	if not notificationFrame then
		return
	end

	local textLabel = getTextLabel(notificationFrame)
	if not textLabel then
		warn(`[{script.Name}] TextLabel not found in notification template`)
		return
	end

	notificationFrame.Parent = notificationContainer
	textLabel.Text = string.upper(message)
	textLabel.TextColor3 = NOTIFICATION_COLORS[notificationType]

	notificationQueueMaid:add(notificationFrame)

	repositionNotifications()

	SoundManager.playForType(notificationType)

	local uiStroke = getUIStroke(notificationFrame)
	NotificationAnimator.animateEntry({
		frame = notificationFrame,
		textLabel = textLabel,
		uiStroke = uiStroke,
		notificationType = notificationType,
		typeColor = NOTIFICATION_COLORS[notificationType],
	})

	notificationQueueMaid:scheduleRemoval(notificationFrame, textLabel, handleNotificationRemoval)
end

local function destroyAllNotifications()
	for _, frame in notificationQueueMaid:getAll() do
		destroyNotificationFrame(frame)
	end
	notificationQueueMaid:clear()
end

local function cleanup()
	destroyAllNotifications()
	connectionsMaid:disconnect()
end

local function initialize()
	local screenGui = playerGui:WaitForChild("NotificationUI", 10)
	if not screenGui then
		warn(`[{script.Name}] NotificationUI ScreenGui not found in PlayerGui`)
		return
	end

	local mainFrame = screenGui:WaitForChild("MainFrame")
	notificationContainer = mainFrame:WaitForChild("Holder")

	if globalNotificationEvent then
		connectionsMaid:add(globalNotificationEvent.OnClientEvent:Connect(createNotification))
	end

	if localNotificationEvent then
		connectionsMaid:add(localNotificationEvent.Event:Connect(createNotification))
	end

	connectionsMaid:add(screenGui.AncestryChanged:Connect(function()
		if not screenGui:IsDescendantOf(game) then
			cleanup()
		end
	end))

	connectionsMaid:add(localPlayer.AncestryChanged:Connect(function()
		if not localPlayer:IsDescendantOf(game) then
			cleanup()
		end
	end))
end

--------------------
-- Initialization --
--------------------

initialize()