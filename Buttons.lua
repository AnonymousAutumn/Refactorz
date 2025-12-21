-----------------
-- Init Module --
-----------------

local UIButtonHandler = {}

---------------
-- Variables --
---------------

local currentInputCategory = "Unknown"

---------------
-- Functions --
---------------

local function playSound(sound)
	if sound and sound:IsA("Sound") then
		sound:Play()
	end
end

local function trackConnection(connection, tracker)
	if tracker and tracker.track then
		tracker:track(connection)
	end
end

local function isGamepadInput()
	return currentInputCategory == "Gamepad"
end

local function isTouchInput()
	return currentInputCategory == "Touch"
end

function UIButtonHandler.initialize(inputCategorizer)
	if inputCategorizer then
		currentInputCategory = inputCategorizer.getLastInputCategory() or "Unknown"
	end
end

function UIButtonHandler.setupButton(config)
	local button = config.button
	if not button or not (button:IsA("TextButton") or button:IsA("ImageButton")) then
		return
	end

	local hoverSound = config.sounds and config.sounds.hover
	local clickSound = config.sounds and config.sounds.click

	-- Use Activated for cross-platform support (PC, Mobile, Console)
	local clickConnection = button.Activated:Connect(function()
		playSound(clickSound)
		config.onClick(button)
	end)
	trackConnection(clickConnection, config.connectionTracker)

	-- Hover sounds only for non-touch, non-gamepad devices
	if not isTouchInput() and not isGamepadInput() and hoverSound then
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
		if descendant:IsA("TextButton") or descendant:IsA("ImageButton") then
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
			if descendant:IsA("TextButton") or descendant:IsA("ImageButton") then
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
	return isTouchInput()
end

function UIButtonHandler.isOnGamepad()
	return isGamepadInput()
end

function UIButtonHandler.getInputCategory()
	return currentInputCategory
end

function UIButtonHandler.getPrimarySignal(button)
	-- Return Activated for cross-platform compatibility
	return button.Activated
end

-------------------
-- Return Module --
-------------------

return UIButtonHandler
