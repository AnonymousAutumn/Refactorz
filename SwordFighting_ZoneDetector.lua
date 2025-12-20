--[[
	ZoneDetector - Monitors player zone entry and exit.

	Features:
	- Combat zone detection
	- Player monitoring with heartbeat
	- Zone state tracking
]]

local ZoneDetector = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local networkFolder = ReplicatedStorage.Network
local remoteEvents = networkFolder.Remotes.Events
local updateGameUIRemoteEvent = remoteEvents.UpdateGameUI

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)

local FIGHTING_ATTRIBUTE_NAME = "Fighting"
local ZONE_UPDATE_INTERVAL = 0.2

local COMBAT_MESSAGES = {
	Enter = "Entered combat",
	Exit = "Left combat",
}

local activeMonitors = {}

local function handleCombatZoneEntry(targetPlayer: Player, giveToolFunc: (Player) -> ())
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

local function handleCombatZoneExit(targetPlayer: Player, removeToolFunc: (Player) -> ())
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

--[[
	Stops monitoring a player's zone status.
]]
function ZoneDetector.stopMonitoring(player: Player)
	local monitor = activeMonitors[player]
	if monitor then
		if monitor.connection then
			monitor.connection:Disconnect()
		end
		activeMonitors[player] = nil
	end
end

--[[
	Starts monitoring a player's zone status.
]]
function ZoneDetector.startMonitoring(player: Player, combatZonePart: BasePart, isPlayerInPartFunc: (Player, BasePart) -> boolean, giveToolFunc: (Player) -> (), removeToolFunc: (Player) -> ())
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

--[[
	Checks if a player is being monitored.
]]
function ZoneDetector.isMonitoring(player: Player): boolean
	return activeMonitors[player] ~= nil
end

--[[
	Gets the current zone state for a player.
]]
function ZoneDetector.getZoneState(player: Player): boolean?
	local monitor = activeMonitors[player]
	if monitor then
		return monitor.wasInZone
	end
	return nil
end

return ZoneDetector