--[[
	ToolManager - Manages combat tools for players.

	Features:
	- Tool distribution
	- Tool removal
	- Backpack/character detection
]]

local ToolManager = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)

local instancesFolder = ReplicatedStorage.Instances
local toolsFolder = instancesFolder.Tools
local swordPrefab = toolsFolder.ClassicSword

local TOOL_NAME = swordPrefab.Name

local function hasToolInBackpack(targetPlayer: Player): boolean
	if not ValidationUtils.isValidPlayer(targetPlayer) then
		return false
	end
	
	local backpack = targetPlayer:FindFirstChild("Backpack")
	return backpack ~= nil and backpack:FindFirstChild(TOOL_NAME) ~= nil
end

local function hasToolInCharacter(targetPlayer: Player): boolean
	if not ValidationUtils.isValidPlayer(targetPlayer) then
		return false
	end
	
	local char = targetPlayer.Character
	return char ~= nil and char:FindFirstChild(TOOL_NAME) ~= nil
end

local function playerHasTool(targetPlayer: Player): boolean
	return hasToolInBackpack(targetPlayer) or hasToolInCharacter(targetPlayer)
end

--[[
	Gives a tool to the specified player.
]]
function ToolManager.giveToolToPlayer(targetPlayer: Player, getHumanoidFunc: (Model) -> Humanoid?)
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

--[[
	Removes the tool from the specified player.
]]
function ToolManager.removeToolFromPlayer(targetPlayer: Player)
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

return ToolManager