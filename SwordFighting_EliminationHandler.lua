--[[
	EliminationHandler - Handles player elimination and kill credits.

	Features:
	- Kill credit detection
	- Elimination notifications
	- Sound effect triggers
]]

local EliminationHandler = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local networkFolder = ReplicatedStorage.Network
local remoteEvents = networkFolder.Remotes.Events
local updateGameUIRemoteEvent = remoteEvents.UpdateGameUI
local playSoundRemoteEvent = remoteEvents.PlaySound

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)

local BLOXXED_MESSAGE_FORMAT = "Bloxxed %s!"
local KILL_CREDIT = 1

local function getKillerFromCreatorTag(hum: Humanoid): Player?
	local creatorTag = hum:FindFirstChild("creator")
	if not creatorTag or not creatorTag:IsA("ObjectValue") then
		return nil
	end
	
	local creatorValue = (creatorTag ).Value
	return if creatorValue and creatorValue:IsA("Player") then creatorValue else nil
end

local function playSound(targetPlayer: Player, soundEnabled: boolean)
	if not ValidationUtils.isValidPlayer(targetPlayer) then
		return
	end
	
	local success, errorMessage = pcall(function()
		playSoundRemoteEvent:FireClient(targetPlayer, soundEnabled)
	end)
	
	if not success then
		warn(`[{script.Name}] Failed to play sound for player {targetPlayer.Name}: {tostring(errorMessage)}`)
	end
end

local function notifyKillerOfElimination(killer: Player, victimName: string)
	if not ValidationUtils.isValidPlayer(killer) then
		return
	end
	
	local message = `Bloxxed {victimName}!`
	local success, errorMessage = pcall(function()
		updateGameUIRemoteEvent:FireClient(killer, message, nil, true)
	end)
	
	if not success then
		warn(`[{script.Name}] Failed to notify killer {killer.Name}: {tostring(errorMessage)}`)
	end
	
	playSound(killer, false)
end

local function handleEliminationWithKiller(victim: Player, killer: Player, recordWinFunc: (number, number) -> ())
	if not ValidationUtils.isValidPlayer(victim) or not ValidationUtils.isValidPlayer(killer) then
		return
	end
	
	recordWinFunc(killer.UserId, KILL_CREDIT)
	notifyKillerOfElimination(killer, victim.Name)
end

--[[
	Gets the killer player from a humanoid's creator tag.
]]
function EliminationHandler.getKillerFromHumanoid(hum: Humanoid): Player?
	return getKillerFromCreatorTag(hum)
end

--[[
	Handles player elimination and notifies the killer.
]]
function EliminationHandler.handlePlayerElimination(victim: Player, killer: Player?, recordWinFunc: (number, number) -> ())
	if not ValidationUtils.isValidPlayer(victim) then
		return
	end
	playSound(victim, true)
	
	if killer and ValidationUtils.isValidPlayer(killer) then
		handleEliminationWithKiller(victim, killer, recordWinFunc)
	end
end

return EliminationHandler