--[[
	SpawnCar - Spawns a car for a player.

	Features:
	- Car instantiation
	- Random color assignment
	- Owner attribution
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local instancesFolder = ReplicatedStorage.Instances
local objectsFolder = instancesFolder.Objects
local carTemplate = objectsFolder.Car

local CarConstants = require(carTemplate.Scripts.Constants)
local randomColor = require(script.Parent.randomColor)
local recolorModel = require(script.Parent.recolorModel)

local SPAWN_OFFSET = CFrame.new(0, 20, -10)

--[[
	Spawns a car for the given owner.
]]
local function spawnCar(owner: Player, hrp: BasePart)
	if not owner or not hrp then
		return
	end
	
	local car = carTemplate:Clone()
	local spawnCFrame = hrp.CFrame * SPAWN_OFFSET
	car:PivotTo(spawnCFrame)
	recolorModel(car, randomColor())

	if owner then
		car:SetAttribute(CarConstants.CAR_OWNER_ATTRIBUTE, owner.UserId)
	end

	car.Parent = workspace.Debris
end

return spawnCar