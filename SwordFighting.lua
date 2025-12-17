--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local Connections = require(modulesFolder.Wrappers.Connections)
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local ToolManager = require(script.ToolManager)
local DataPersistence = require(script.DataPersistence)
local EliminationHandler = require(script.EliminationHandler)
local ZoneDetector = require(script.ZoneDetector)
local DeathUIController = require(script.DeathUIController)
local isPlayerInPart = require(script.isPlayerInPart)

local instancesFolder = ReplicatedStorage.Instances
local guiPrefabs = instancesFolder.GuiPrefabs
local bloxxedUIPrefab = guiPrefabs.DeathUIPrefab

local worldFolder = workspace.World
local environmentFolder = worldFolder.Environment
local combatZonePart = environmentFolder.CombatZonePart

---------------
-- Constants --
---------------

local FIGHTING_ATTRIBUTE_NAME = "Fighting"

---------------
-- Variables --
---------------

local connectionsMaid = Connections.new()
local playerConnections = {}

---------------
-- Functions --
---------------

local function getHumanoidFromCharacter(char)
	if not ValidationUtils.isValidCharacter(char) then
		return nil
	end
	local hum = char:FindFirstChild("Humanoid")
	return if ValidationUtils.isValidHumanoid(hum) then hum else nil
end

local function isPlayerInCombat(char)
	return char:GetAttribute(FIGHTING_ATTRIBUTE_NAME) == true
end

local function giveToolWrapper(targetPlayer)
	ToolManager.giveToolToPlayer(targetPlayer, getHumanoidFromCharacter)
end

local function removeToolWrapper(targetPlayer)
	ToolManager.removeToolFromPlayer(targetPlayer)
end

local function recordWinWrapper(userId, wins)
	DataPersistence.recordPlayerWin(userId, wins)
end

local function handleEliminationWrapper(victim, killer)
	EliminationHandler.handlePlayerElimination(victim, killer, recordWinWrapper)
end

local function setupCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		warn(`[{script.Name}] Humanoid not found for {player.Name}`)
		return
	end

	if not playerConnections[player] then
		playerConnections[player] = Connections.new()
	else
		playerConnections[player]:disconnect()
		playerConnections[player] = Connections.new()
	end

	ZoneDetector.startMonitoring(
		player,
		combatZonePart,
		isPlayerInPart,
		giveToolWrapper,
		removeToolWrapper
	)

	playerConnections[player]:add(humanoid.Died:Connect(function()
		if not ValidationUtils.isValidCharacter(character) then
			return
		end

		local wasInCombat = isPlayerInCombat(character)

		ZoneDetector.stopMonitoring(player)

		if not wasInCombat then
			return
		end

		local killerPlayer = EliminationHandler.getKillerFromHumanoid(humanoid)
		handleEliminationWrapper(player, killerPlayer)

		DeathUIController(bloxxedUIPrefab, player)
	end))
end

local function cleanupPlayer(player)

	ZoneDetector.stopMonitoring(player)

	local connections = playerConnections[player]
	if connections then
		connections:disconnect()
		playerConnections[player] = nil
	end
end

local function onPlayerAdded(player)

	connectionsMaid:add(player.CharacterAdded:Connect(function(character)
		setupCharacter(player, character)
	end))

	if player.Character then
		setupCharacter(player, player.Character)
	end
end

local function onPlayerRemoving(player)
	cleanupPlayer(player)
end

local function cleanup()
	for player, _ in pairs(playerConnections) do
		cleanupPlayer(player)
	end

	connectionsMaid:disconnect()
end

local function initialize()

	combatZonePart.Transparency = 1

	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	connectionsMaid:add(Players.PlayerAdded:Connect(onPlayerAdded))
	connectionsMaid:add(Players.PlayerRemoving:Connect(onPlayerRemoving))

	game:BindToClose(cleanup)
end

--------------------
-- Initialization --
--------------------

initialize()