--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local networkFolder = ReplicatedStorage.Network
local remoteEvents = networkFolder.Remotes.Events
local giveKeysEvent = remoteEvents.GiveKeys

local instancesFolder = ReplicatedStorage.Instances
local toolsFolder = instancesFolder.Tools
local carKeys = toolsFolder.CarKeys

---------------
-- Functions --
---------------

local function giveKeys(player)
	if not player then
		return
	end
	
	local clone = carKeys:Clone()
	clone.Parent = player.Backpack
end

--------------------
-- Initialization --
--------------------

giveKeysEvent.OnServerEvent:Connect(giveKeys)