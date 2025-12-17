-----------------
-- Init Module --
-----------------

local ZoneDetector = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

----------------
-- References --
----------------

local networkFolder = ReplicatedStorage.Network
local remoteEvents = networkFolder.Remotes.Events
local updateGameUIRemoteEvent = remoteEvents.UpdateGameUI

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)

---------------
-- Constants --
---------------

local FIGHTING_ATTRIBUTE_NAME = "Fighting"
local ZONE_UPDATE_INTERVAL = 0.2

local COMBAT_MESSAGES = {
	Enter = "Entered combat",
	Exit = "Left combat",
}

---------------
-- Variables --
---------------

local activeMonitors = {}

---------------
-- Functions --
---------------

local function handleCombatZoneEntry(targetPlayer, giveToolFunc)
	if not ValidationUtils.isValidPlayer(targetPlayer) then
		return
	end
	
	local char = targetPlayer.Character
	if not char then
		return
	end
	
	local success, errorMessage = pcall(function()
		giveToolFunc(targetPlayer)
		updateGameUIRemoteEvent:FireClient(targetPlayer, COMBAT_MESSAGES.Enter, nil, true)
		char:SetAttribute(FIGHTING_ATTRIBUTE_NAME, true)
	end)
	if not success then
		warn(`[{script.Name}] Failed to handle zone entry for {targetPlayer.Name}: {tostring(errorMessage)}`)
	end
end

local function handleCombatZoneExit(targetPlayer, removeToolFunc)
	if not ValidationUtils.isValidPlayer(targetPlayer) then
		return
	end
	
	local char = targetPlayer.Character
	if not char then
		return
	end
	
	local success, errorMessage = pcall(function()
		removeToolFunc(targetPlayer)
		updateGameUIRemoteEvent:FireClient(targetPlayer, COMBAT_MESSAGES.Exit, nil, true)
		char:SetAttribute(FIGHTING_ATTRIBUTE_NAME, false)
	end)
	if not success then
		warn(`[{script.Name}] Failed to handle zone exit for {targetPlayer.Name}: {tostring(errorMessage)}`)
	end
end

function ZoneDetector.stopMonitoring(player)
	local monitor = activeMonitors[player]
	if monitor then
		if monitor.connection then
			monitor.connection:Disconnect()
		end
		activeMonitors[player] = nil
	end
end

function ZoneDetector.startMonitoring(player, combatZonePart, isPlayerInPartFunc, giveToolFunc, removeToolFunc)
	ZoneDetector.stopMonitoring(player)

	local lastZoneUpdate = 0
	local wasPlayerInZone = false

	local function updatePlayerZoneStatus()

		if not ValidationUtils.isValidPlayer(player) then
			ZoneDetector.stopMonitoring(player)
			return
		end

		local isInZone = isPlayerInPartFunc(player, combatZonePart)

		if isInZone and not wasPlayerInZone then
			handleCombatZoneEntry(player, giveToolFunc)
		elseif not isInZone and wasPlayerInZone then
			handleCombatZoneExit(player, removeToolFunc)
		end

		wasPlayerInZone = isInZone

		local monitor = activeMonitors[player]
		if monitor then
			monitor.wasInZone = isInZone
		end
	end

	local connection = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - lastZoneUpdate
		if elapsed < ZONE_UPDATE_INTERVAL then
			return
		end
		lastZoneUpdate = os.clock()
		updatePlayerZoneStatus()
	end)

	activeMonitors[player] = {
		connection = connection,
		wasInZone = false,
	}
end

function ZoneDetector.isMonitoring(player)
	return activeMonitors[player] ~= nil
end

function ZoneDetector.getZoneState(player)
	local monitor = activeMonitors[player]
	if monitor then
		return monitor.wasInZone
	end
	return nil
end

-------------------
-- Return Module --
-------------------

return ZoneDetector