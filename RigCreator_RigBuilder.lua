--[[
	RigBuilder - Creates character rigs for viewport display.

	Features:
	- Humanoid model creation from user ID
	- Unwanted instance cleanup
	- Retry logic with timeout
]]

local RigBuilder = {}
RigBuilder.safeExecute = nil
RigBuilder.positionCharacterAtRankLocation = nil

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)

local UNWANTED_INSTANCE_CLASSES = { "Sound", "LocalScript" }
local CHARACTER_RIG_NAME_PREFIX = "ViewportRig_"

local MAX_CHARACTER_CREATION_RETRIES = 3
local CHARACTER_CREATION_RETRY_DELAY = 1
local CHARACTER_CREATION_TIMEOUT = 10

local function shouldRemoveInstance(instance: Instance): boolean
	for _, unwantedClassName in pairs(UNWANTED_INSTANCE_CLASSES) do
		if instance:IsA(unwantedClassName) then
			return true
		end
	end
	return false
end

local function hasTimedOut(startTime: number, timeout: number): boolean
	return os.clock() - startTime > timeout
end

local function createCharacterRig(playerUserId: number, startTime: number): Model
	local rig = Players:CreateHumanoidModelFromUserId(playerUserId)

	if hasTimedOut(startTime, CHARACTER_CREATION_TIMEOUT) then
		error("Character creation timeout")
	end

	return rig
end

local function configureCharacterRig(createdCharacterRig: Model, playerUserId: number, rankPositionReference: Model, worldModel: WorldModel)
	createdCharacterRig.Name = CHARACTER_RIG_NAME_PREFIX .. tostring(playerUserId)

	if RigBuilder.positionCharacterAtRankLocation then
		RigBuilder.positionCharacterAtRankLocation(createdCharacterRig, rankPositionReference)
	end

	RigBuilder.removeUnwantedInstancesFromModel(createdCharacterRig)
	createdCharacterRig.Parent = worldModel
end

local function attemptCharacterCreation(playerUserId: number, rankPositionReference: Model, worldModel: WorldModel, isCancelled: (() -> boolean)?): Model?
	-- Check for cancellation before starting the attempt
	if isCancelled and isCancelled() then
		return nil
	end

	local startTime = os.clock()

	local createSuccess, createdCharacterRig = pcall(function()
		return createCharacterRig(playerUserId, startTime)
	end)

	-- Check for cancellation after the yielding CreateHumanoidModelFromUserId call
	if isCancelled and isCancelled() then
		if createSuccess and createdCharacterRig then
			createdCharacterRig:Destroy()
		end
		return nil
	end

	if not createSuccess or not createdCharacterRig or not createdCharacterRig:IsA("Model") then
		return nil
	end

	local configureSuccess = pcall(function()
		configureCharacterRig(createdCharacterRig, playerUserId, rankPositionReference, worldModel)
	end)

	if not configureSuccess then
		createdCharacterRig:Destroy()
		return nil
	end

	return createdCharacterRig
end

--[[
	Removes unwanted instances (sounds, scripts) from a character model.
]]
function RigBuilder.removeUnwantedInstancesFromModel(characterModel: Model?)
	if not characterModel or not characterModel:IsA("Model") then
		return
	end

	if not RigBuilder.safeExecute then
		return
	end

	RigBuilder.safeExecute(function()
		for _, modelDescendant in pairs(characterModel:GetDescendants()) do
			if shouldRemoveInstance(modelDescendant) then
				modelDescendant:Destroy()
			end
		end
	end)
end

--[[
	Creates a player character model for display in a viewport.
]]
function RigBuilder.createPlayerCharacterForDisplay(playerUserId: number, rankPositionReference: Model?, worldModel: WorldModel?, isCancelled: (() -> boolean)?): Model?
	if not ValidationUtils.isValidUserId(playerUserId) or not rankPositionReference or not rankPositionReference:IsA("Model") then
		return nil
	end

	for attempt = 1, MAX_CHARACTER_CREATION_RETRIES do
		-- Check for cancellation before each attempt
		if isCancelled and isCancelled() then
			return nil
		end

		local createdCharacterRig = attemptCharacterCreation(
			playerUserId,
			rankPositionReference,
			worldModel,
			isCancelled
		)

		if createdCharacterRig then
			return createdCharacterRig
		end

		-- Check for cancellation before waiting for retry
		if attempt < MAX_CHARACTER_CREATION_RETRIES then
			if isCancelled and isCancelled() then
				return nil
			end
			task.wait(CHARACTER_CREATION_RETRY_DELAY * attempt)
		end
	end

	return nil
end

RigBuilder.CHARACTER_RIG_NAME_PREFIX = CHARACTER_RIG_NAME_PREFIX

return RigBuilder