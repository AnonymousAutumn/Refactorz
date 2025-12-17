-----------------
-- Init Module --
-----------------

local ComponentBuilder = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local PassUIUtilities = require(modulesFolder.Utilities.PassUIUtilities)

---------------
-- Constants --
---------------

local UI_COMPONENT_NAMES = {
	"MainFrame",
	"HelpFrame",
	"ItemFrame",
	"LoadingLabel",
	"CloseButton",
	"RefreshButton",
	"TimerLabel",
	"DataLabel",
	"InfoLabel",
	"LinkTextBox",
}

---------------
-- Functions --
---------------

local function validateUIComponents(components)
	if typeof(components) ~= "table" then
		return false
	end
	
	for i = 1, #UI_COMPONENT_NAMES do
		local componentName = UI_COMPONENT_NAMES[i]
		
		if not components[componentName] then
			warn(`[{script.Name}] Missing required UI component: {componentName}`)
			return false
		end
	end
	return true
end

function ComponentBuilder.buildUIComponents(donationInterface)
	local primaryFrame = donationInterface:FindFirstChild("MainFrame")
	if not primaryFrame then
		return nil
	end

	local topNavigationBar = primaryFrame:FindFirstChild("Topbar")
	if not topNavigationBar then
		return nil
	end

	local navigationButtonFrame = topNavigationBar:FindFirstChild("ButtonFrame")
	if not navigationButtonFrame then
		return nil
	end

	local buttonContainer = navigationButtonFrame:FindFirstChild("Holder")
	if not buttonContainer then
		return nil
	end

	local textFrameHolder = topNavigationBar:FindFirstChild("TextFrame")
	if not textFrameHolder then
		return nil
	end

	local textHolder = textFrameHolder:FindFirstChild("Holder")
	if not textHolder then
		return nil
	end

	local components = {
		MainFrame = primaryFrame ,
		HelpFrame = PassUIUtilities.safeWaitForChild(primaryFrame, "HelpFrame") ,
		ItemFrame = PassUIUtilities.safeWaitForChild(primaryFrame, "ItemFrame") ,
		LoadingLabel = PassUIUtilities.safeWaitForChild(primaryFrame, "LoadingLabel") ,
		CloseButton = PassUIUtilities.safeWaitForChild(buttonContainer, "CloseButton") ,
		RefreshButton = PassUIUtilities.safeWaitForChild(buttonContainer, "RefreshButton") ,
		TimerLabel = PassUIUtilities.safeWaitForChild(buttonContainer, "TimerLabel") ,
		DataLabel = PassUIUtilities.safeWaitForChild(textHolder, "TextLabel") ,
		InfoLabel = nil,
		LinkTextBox = nil,
	}

	if components.HelpFrame then
		components.InfoLabel = PassUIUtilities.safeWaitForChild(components.HelpFrame, "InfoLabel") 
		components.LinkTextBox = PassUIUtilities.safeWaitForChild(components.HelpFrame, "LinkTextBox") 
	end

	if not validateUIComponents(components) then
		return nil
	end

	return components
end

function ComponentBuilder.validateUIComponents(components)
	return validateUIComponents(components)
end

-------------------
-- Return Module --
-------------------

return ComponentBuilder