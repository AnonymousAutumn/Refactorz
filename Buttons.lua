-----------------
-- Init Module --
-----------------

local UIButtonHandler = {}

---------------
-- Variables --
---------------

local isUserOnTouchDevice = false

---------------
-- Functions --
---------------

local function playSound(sound)
	if sound and sound:IsA("Sound") then
		sound:Play()
	end
end

local function getPrimaryInteractionSignal(button)
	return if isUserOnTouchDevice then button.TouchTap else button.MouseButton1Down
end

local function trackConnection(connection, tracker)
	if tracker and tracker.track then
		tracker:track(connection)
	end
end

function UIButtonHandler.initialize(inputCategorizer)
	if inputCategorizer then
		isUserOnTouchDevice = inputCategorizer.getLastInputCategory() == "Touch"
	end
end

function UIButtonHandler.setupButton(config)
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

function UIButtonHandler.setupButtons(buttons, onClick, sounds, connectionTracker)
	for _, button in buttons do
		UIButtonHandler.setupButton({
			button = button,
			onClick = onClick,
			sounds = sounds,
			connectionTracker = connectionTracker,
		})
	end
end

function UIButtonHandler.setupAllButtons(container, onClick, sounds, connectionTracker, watchForNew)
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

function UIButtonHandler.isOnTouchDevice()
	return isUserOnTouchDevice
end

function UIButtonHandler.getPrimarySignal(button)
	return getPrimaryInteractionSignal(button)
end

-------------------
-- Return Module --
-------------------

return UIButtonHandler