--[[
	UIButtonHandler - Handles UI button interactions.

	Features:
	- Touch and mouse input support
	- Sound effects
	- Button setup utilities
]]

local UIButtonHandler = {}

local isUserOnTouchDevice = false

local function playSound(sound: Sound?)
	if sound and sound:IsA("Sound") then
		sound:Play()
	end
end

local function getPrimaryInteractionSignal(button: TextButton): RBXScriptSignal
	return if isUserOnTouchDevice then button.TouchTap else button.MouseButton1Down
end

local function trackConnection(connection: RBXScriptConnection, tracker: any)
	if tracker and tracker.track then
		tracker:track(connection)
	end
end

--[[
	Initializes the button handler with input categorizer.
]]
function UIButtonHandler.initialize(inputCategorizer: any)
	if inputCategorizer then
		isUserOnTouchDevice = inputCategorizer.getLastInputCategory() == "Touch"
	end
end

--[[
	Sets up a single button with click and hover handling.
]]
function UIButtonHandler.setupButton(config: any)
	local button = config.button
	if not button or not button:IsA("TextButton") then
		return
	end

	local hoverSound = config.sounds and config.sounds.hover
	local clickSound = config.sounds and config.sounds.click

	local clickConnection = getPrimaryInteractionSignal(button):Connect(function()
		playSound(clickSound)
		config.onClick(button)
	end)
	trackConnection(clickConnection, config.connectionTracker)

	if not isUserOnTouchDevice and hoverSound then
		local hoverConnection = button.MouseEnter:Connect(function()
			playSound(hoverSound)
		end)
		trackConnection(hoverConnection, config.connectionTracker)
	end
end

--[[
	Sets up multiple buttons with the same handlers.
]]
function UIButtonHandler.setupButtons(buttons: { TextButton }, onClick: (TextButton) -> (), sounds: any?, connectionTracker: any?)
	for _, button in buttons do
		UIButtonHandler.setupButton({
			button = button,
			onClick = onClick,
			sounds = sounds,
			connectionTracker = connectionTracker,
		})
	end
end

--[[
	Sets up all TextButtons in a container.
]]
function UIButtonHandler.setupAllButtons(container: Instance, onClick: (TextButton) -> (), sounds: any?, connectionTracker: any?, watchForNew: boolean?)
	for _, descendant in container:GetDescendants() do
		if descendant:IsA("TextButton") then
			UIButtonHandler.setupButton({
				button = descendant,
				onClick = onClick,
				sounds = sounds,
				connectionTracker = connectionTracker,
			})
		end
	end

	if watchForNew then
		local connection = container.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("TextButton") then
				UIButtonHandler.setupButton({
					button = descendant,
					onClick = onClick,
					sounds = sounds,
					connectionTracker = connectionTracker,
				})
			end
		end)
		trackConnection(connection, connectionTracker)
	end
end

--[[
	Returns whether the user is on a touch device.
]]
function UIButtonHandler.isOnTouchDevice(): boolean
	return isUserOnTouchDevice
end

--[[
	Gets the primary interaction signal for a button.
]]
function UIButtonHandler.getPrimarySignal(button: TextButton): RBXScriptSignal
	return getPrimaryInteractionSignal(button)
end

return UIButtonHandler