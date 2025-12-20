--[[ CarKeys - Tool script for spawning player vehicles with cooldown management ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local modulesFolder = ReplicatedStorage.Modules
local utilitiesFolder = modulesFolder.Utilities
local SpawnCar = require(utilitiesFolder.Vehicle.SpawnCar)
local DestroyPlayerCars = require(utilitiesFolder.Vehicle.DestroyPlayerCars)

local carKeysTool = script.Parent
local useSound = carKeysTool.UseSound

local TOOL_COOLDOWN = 5

local lastUseTime = 0

local function spawnVehicle()
	-- Cooldown check
	local currentTime = os.clock()
	if currentTime - lastUseTime < TOOL_COOLDOWN then
		return
	end
	lastUseTime = currentTime

	local character = carKeysTool.Parent
	if not character then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	useSound:Play()

	DestroyPlayerCars(player)
	SpawnCar(player, hrp)
end

carKeysTool.Activated:Connect(spawnVehicle)