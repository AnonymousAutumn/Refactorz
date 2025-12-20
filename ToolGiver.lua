--[[ ToolGiver - Server script that gives tools to players ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local networkFolder = ReplicatedStorage.Network
local remoteEvents = networkFolder.Remotes.Events
local giveKeysEvent = remoteEvents.GiveKeys

local instancesFolder = ReplicatedStorage.Instances
local toolsFolder = instancesFolder.Tools
local carKeys = toolsFolder.CarKeys

local function giveKeys(player: Player)
	if not player then
		return
	end
	
	local clone = carKeys:Clone()
	clone.Parent = player.Backpack
end

giveKeysEvent.OnServerEvent:Connect(giveKeys)