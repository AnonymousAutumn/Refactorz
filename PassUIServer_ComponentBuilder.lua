--[[
	ComponentBuilder - Builds and validates UI component references.

	Features:
	- Safely builds UI component tables from screen GUIs
	- Validates required components exist
	- Provides component validation utility
]]

local ComponentBuilder = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modulesFolder = ReplicatedStorage.Modules
local PassUIUtilities = require(modulesFolder.Utilities.PassUIUtilities)

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

export type UIComponents = {
	MainFrame: Frame,
	HelpFrame: Frame?,
	ItemFrame: ScrollingFrame,
	LoadingLabel: TextLabel,
	CloseButton: TextButton,
	RefreshButton: TextButton,
	TimerLabel: TextLabel,
	DataLabel: TextLabel,
	InfoLabel: TextLabel?,
	LinkTextBox: TextBox?,
}

local function validateUIComponents(components: { [string]: Instance? }): boolean
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

--[[
	Builds a table of UI component references from a donation interface.
	Returns nil if any required components are missing.
]]
function ComponentBuilder.buildUIComponents(donationInterface: ScreenGui): UIComponents?
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

--[[
	Validates that all required UI components are present.
]]
function ComponentBuilder.validateUIComponents(components: { [string]: Instance? }): boolean
	return validateUIComponents(components)
end

return ComponentBuilder