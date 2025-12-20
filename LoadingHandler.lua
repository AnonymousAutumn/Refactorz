--[[ LoadingHandler - Manages the loading screen and asset preloading ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")

local WaitForGameLoadedAsync = require(script.Parent.waitForGameLoadedAsync)
WaitForGameLoadedAsync()

local networkFolder = ReplicatedStorage.Network
local dataLoadedRemoteEvent = networkFolder.Signals.DataLoaded

local modulesFolder = ReplicatedStorage.Modules
local UIController = require(script.Parent.UIController)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local loadingScreenPrefab = ReplicatedFirst.Instances.LoadingScreenPrefab
local loadingScreenInstance = loadingScreenPrefab:Clone() 

local mainFrame = loadingScreenInstance.MainFrame
local backgroundImageLabel = mainFrame.Background
local headerTextLabel = mainFrame.HeaderText
local subTextLabel = mainFrame.SubText

local ASSETS_TO_PRELOAD = {
	{"Image", "rbxassetid://121480522"},
	{"Image", "rbxassetid://3926307971"},
	{"Image", "rbxassetid://14829181141"},
	{"Image", "rbxassetid://9131051542"},
	{"Image", "rbxassetid://77362651529596"},
	{"Image", "rbxassetid://17342199692"},
	{"Image", "rbxassetid://17551413159"},
	{"Image", "rbxassetid://17551410483"},

	{"Sound", "rbxassetid://16772109134"},
	{"Sound", "rbxassetid://16772080247"},
	{"Sound", "rbxassetid://16772074498"},
	{"Sound", "rbxassetid://118296674"},
	{"Sound", "rbxassetid://16772076271"},
}

local FADE_TWEEN_INFO = TweenInfo.new(
	1,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out,
	0, 
	false, 
	0
)

local STATUS_MESSAGES = {
	LOADING_DATA = "Loading data",
	LOADING_GAME = "Loading game",
	LOADING_ASSETS = "Loading assets",
	LOADING_FINISHED = "??",
}

local COMPLETION_DELAY = 1.5
local DELAY_ASSET_LOAD_TIME = 3.5

local isLoadingComplete = false

local function preloadAssets()
	local assets = {}

	for _, asset in ASSETS_TO_PRELOAD do
		if asset[1] == "Image" then
			local imageAsset = Instance.new("ImageLabel")
			imageAsset.Image = asset[2]
			imageAsset.Parent = script
			table.insert(assets, imageAsset)
		elseif asset[1] == "Sound" then
			local soundAsset = Instance.new("Sound")
			soundAsset.SoundId = asset[2]
			soundAsset.Parent = script
			table.insert(assets, soundAsset)
		end
	end
	if #assets > 0 then
		ContentProvider:PreloadAsync(assets)
	end
end

local function updateTextLabels(text: string)
	headerTextLabel:SetAttribute("LoadingText", text)
	subTextLabel.Text = text
end

local function createTweens()
	local tweens = {}

	table.insert(tweens, TweenService:Create(mainFrame, FADE_TWEEN_INFO, {BackgroundTransparency = 1}))
	table.insert(tweens, TweenService:Create(backgroundImageLabel, FADE_TWEEN_INFO, {ImageTransparency = 1}))
	table.insert(tweens, TweenService:Create(headerTextLabel, FADE_TWEEN_INFO, {TextTransparency = 1, TextStrokeTransparency = 1}))
	
	return tweens
end

local function cleanup()
	localPlayer:SetAttribute("Loaded", true)

	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
	
	loadingScreenInstance:Destroy()
	script:Destroy()
end

local function beginLoading()
	loadingScreenInstance.Parent = playerGui
	
	updateTextLabels(STATUS_MESSAGES.LOADING_DATA)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
end

local function finishLoading(uiControllerInstance: any)
	if isLoadingComplete then return end
	isLoadingComplete = true

	uiControllerInstance:finish()
	
	updateTextLabels(STATUS_MESSAGES.LOADING_FINISHED)
	subTextLabel.Visible = false
	
	task.wait(COMPLETION_DELAY)

	local fadeAnimations = createTweens()
	for _, animation in fadeAnimations do
		animation:Play()
	end

	fadeAnimations[1].Completed:Once(function()
		cleanup()
	end)
end

local function executeLoadingSequence(uiControllerInstance: any)
	if isLoadingComplete then return end

	updateTextLabels(STATUS_MESSAGES.LOADING_GAME)
	task.wait(DELAY_ASSET_LOAD_TIME)

	updateTextLabels(STATUS_MESSAGES.LOADING_ASSETS)
	preloadAssets()
	finishLoading(uiControllerInstance)
end

local function initialize()
	beginLoading()
	
	local controller = UIController.new(loadingScreenInstance)
	controller:start()

	dataLoadedRemoteEvent.OnClientEvent:Once(function()
		executeLoadingSequence(controller)
	end)
end

initialize()