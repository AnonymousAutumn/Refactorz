-----------------
-- Init Module --
-----------------

local RigBuilder = {}
RigBuilder.safeExecute = nil
RigBuilder.positionCharacterAtRankLocation = nil

--------------
-- Services --
--------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)

---------------
-- Constants --
---------------

local UNWANTED_INSTANCE_CLASSES = { "Sound", "LocalScript" }
local CHARACTER_RIG_NAME_PREFIX = "ViewportRig_"

local MAX_CHARACTER_CREATION_RETRIES = 3
local CHARACTER_CREATION_RETRY_DELAY = 1
local CHARACTER_CREATION_TIMEOUT = 10

---------------
-- Functions --
---------------

local function shouldRemoveInstance(instance)
	for _, unwantedClassName in ipairs(UNWANTED_INSTANCE_CLASSES) do
		if instance:IsA(unwantedClassName) then
			return true
		end
	end
	return false
end

local function hasTimedOut(startTime, timeout)
	return os.clock() - startTime > timeout
end

local function createCharacterRig(playerUserId, startTime)
	local rig = Players:CreateHumanoidModelFromUserId(playerUserId)

	if hasTimedOut(startTime, CHARACTER_CREATION_TIMEOUT) then
		error("Character creation timeout")
	end

	return rig
end

local function configureCharacterRig(createdCharacterRig, playerUserId, rankPositionReference, worldModel)
	createdCharacterRig.Name = CHARACTER_RIG_NAME_PREFIX .. tostring(playerUserId)

	if RigBuilder.positionCharacterAtRankLocation then
		RigBuilder.positionCharacterAtRankLocation(createdCharacterRig, rankPositionReference)
	end

	RigBuilder.removeUnwantedInstancesFromModel(createdCharacterRig)
	createdCharacterRig.Parent = worldModel
end

local function attemptCharacterCreation(playerUserId, rankPositionReference, worldModel, isCancelled)
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

function RigBuilder.removeUnwantedInstancesFromModel(characterModel)
	if not characterModel or not characterModel:IsA("Model") then
		return
	end

	if not RigBuilder.safeExecute then
		return
	end

	RigBuilder.safeExecute(function()
		for _, modelDescendant in ipairs(characterModel:GetDescendants()) do
			if shouldRemoveInstance(modelDescendant) then
				modelDescendant:Destroy()
			end
		end
	end)
end

function RigBuilder.createPlayerCharacterForDisplay(playerUserId, rankPositionReference, worldModel, isCancelled)
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

--------------------
-- Initialization --
--------------------

RigBuilder.CHARACTER_RIG_NAME_PREFIX = CHARACTER_RIG_NAME_PREFIX

-------------------
-- Return Module --
-------------------

return RigBuilder