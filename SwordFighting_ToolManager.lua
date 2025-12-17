-----------------
-- Init Module --
-----------------

local ToolManager = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)

local instancesFolder = ReplicatedStorage.Instances
local toolsFolder = instancesFolder.Tools
local swordPrefab = toolsFolder.ClassicSword

---------------
-- Constants --
---------------

local TOOL_NAME = swordPrefab.Name

---------------
-- Functions --
---------------

local function hasToolInBackpack(targetPlayer)
	if not ValidationUtils.isValidPlayer(targetPlayer) then
		return false
	end
	
	local backpack = targetPlayer:FindFirstChild("Backpack")
	return backpack ~= nil and backpack:FindFirstChild(TOOL_NAME) ~= nil
end

local function hasToolInCharacter(targetPlayer)
	if not ValidationUtils.isValidPlayer(targetPlayer) then
		return false
	end
	
	local char = targetPlayer.Character
	return char ~= nil and char:FindFirstChild(TOOL_NAME) ~= nil
end

local function playerHasTool(targetPlayer)
	return hasToolInBackpack(targetPlayer) or hasToolInCharacter(targetPlayer)
end

function ToolManager.giveToolToPlayer(targetPlayer, getHumanoidFunc: (Model) -> Humanoid?)
	if not ValidationUtils.isValidPlayer(targetPlayer) then
		return
	end
	
	if playerHasTool(targetPlayer) then
		return
	end
	
	local char = targetPlayer.Character
	if not char then
		return
	end
	
	local hum = getHumanoidFunc(char)
	if not hum then
		return
	end
	
	local success, errorMessage = pcall(function()
		local toolClone = swordPrefab:Clone()
		toolClone.Parent = targetPlayer.Backpack
		hum:EquipTool(toolClone)
	end)
	
	if not success then
		warn(`[{script.Name}] Failed to give tool to player {targetPlayer.Name}: {tostring(errorMessage)}`)
	end
end

function ToolManager.removeToolFromPlayer(targetPlayer)
	if not ValidationUtils.isValidPlayer(targetPlayer) then
		return
	end
	
	local success, errorMessage = pcall(function()
		local backpack = targetPlayer:FindFirstChild("Backpack")
		if backpack then
			local toolInBackpack = backpack:FindFirstChild(TOOL_NAME)
			if toolInBackpack then
				toolInBackpack:Destroy()
			end
		end
		
		local char = targetPlayer.Character
		if char then
			local toolInCharacter = char:FindFirstChild(TOOL_NAME)
			if toolInCharacter then
				toolInCharacter:Destroy()
			end
		end
	end)
	if not success then
		warn(`[{script.Name}] Failed to remove tool from player {targetPlayer.Name}: {tostring(errorMessage)}`)
	end
end

-------------------
-- Return Module --
-------------------

return ToolManager