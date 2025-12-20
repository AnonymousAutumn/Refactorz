--[[ Sounds - Manages game sound playback ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer

local networkFolder = ReplicatedStorage.Network
local remoteEvents = networkFolder.Remotes.Events
local playSoundRemoteEvent = remoteEvents:WaitForChild("PlaySound")

local modulesFolder = ReplicatedStorage.Modules
local Connections = require(modulesFolder.Wrappers.Connections)

local feedbackGroup = SoundService.Feedback
local defeatSound = feedbackGroup.Defeat
local victorySound = feedbackGroup.Victory

local connectionsMaid = Connections.new()

local function getSoundForOutcome(playerWasDefeated: boolean): Sound?
	local soundCandidate = if playerWasDefeated then defeatSound else victorySound
	return if soundCandidate:IsA("Sound") then soundCandidate else nil
end

local function handleSoundRequest(playerWasDefeated: boolean)
	if typeof(playerWasDefeated) ~= "boolean" then
		return
	end

	local soundToPlay = getSoundForOutcome(playerWasDefeated)
	if soundToPlay then
		soundToPlay:Play()
	end
end

local function initialize()
	connectionsMaid:add(playSoundRemoteEvent.OnClientEvent:Connect(handleSoundRequest))

	if localPlayer then
		connectionsMaid:add(
			localPlayer.AncestryChanged:Connect(function()
				if not localPlayer:IsDescendantOf(game) then
					connectionsMaid:disconnect()
				end
			end)
		)
	end
end

initialize()