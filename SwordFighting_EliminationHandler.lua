-----------------
-- Init Module --
-----------------

local EliminationHandler = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local networkFolder = ReplicatedStorage.Network
local remoteEvents = networkFolder.Remotes.Events
local updateGameUIRemoteEvent = remoteEvents.UpdateGameUI
local playSoundRemoteEvent = remoteEvents.PlaySound

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)

---------------
-- Constants --
---------------

local BLOXXED_MESSAGE_FORMAT = "Bloxxed %s!"
local KILL_CREDIT = 1

---------------
-- Functions --
---------------

local function getKillerFromCreatorTag(hum)
	local creatorTag = hum:FindFirstChild("creator")
	if not creatorTag or not creatorTag:IsA("ObjectValue") then
		return nil
	end
	
	local creatorValue = (creatorTag ).Value
	return if creatorValue and creatorValue:IsA("Player") then creatorValue else nil
end

local function playSound(targetPlayer, soundEnabled)
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

local function notifyKillerOfElimination(killer, victimName)
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

local function handleEliminationWithKiller(victim, killer, recordWinFunc)
	if not ValidationUtils.isValidPlayer(victim) or not ValidationUtils.isValidPlayer(killer) then
		return
	end
	
	recordWinFunc(killer.UserId, KILL_CREDIT)
	notifyKillerOfElimination(killer, victim.Name)
end

function EliminationHandler.getKillerFromHumanoid(hum)
	return getKillerFromCreatorTag(hum)
end

function EliminationHandler.handlePlayerElimination(victim, killer, recordWinFunc)
	if not ValidationUtils.isValidPlayer(victim) then
		return
	end
	playSound(victim, true)
	
	if killer and ValidationUtils.isValidPlayer(killer) then
		handleEliminationWithKiller(victim, killer, recordWinFunc)
	end
end

-------------------
-- Return Module --
-------------------

return EliminationHandler