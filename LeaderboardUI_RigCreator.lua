--[[
	LeaderboardCharacterDisplayManager - Manages character display in leaderboard viewports.

	Features:
	- Character rig creation and cleanup
	- Rank-based positioning
	- Animation management
	- Race condition prevention via version tracking
]]

local LeaderboardCharacterDisplayManager = {}
LeaderboardCharacterDisplayManager.__index = LeaderboardCharacterDisplayManager

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modulesFolder = ReplicatedStorage.Modules
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)
local RigBuilder = require(script.RigBuilder)
local RigPositioner = require(script.RigPositioner)
local AnimationController = require(script.AnimationController)

local LEADERBOARD_RANK_POSITIONS = { "Gold", "Silver", "Bronze" }
local MAX_CHARACTERS_DISPLAYED = 3
local COMPONENT_WAIT_TIMEOUT = 10

local function isValidRankIndex(rankIndex: number): boolean
	return typeof(rankIndex) == "number" and rankIndex >= 1 and rankIndex <= #LEADERBOARD_RANK_POSITIONS
end

local function safeExecute(func: () -> ()): boolean
	return pcall(func)
end

local function waitForChildSafe(parent: Instance, childName: string, timeout: number): Instance?
	local success, child = pcall(function()
		return parent:WaitForChild(childName, timeout)
	end)
	return success and child or nil
end

local function initializeComponents(leaderboardSurfaceGui: SurfaceGui): (ViewportFrame, WorldModel)
	local mainFrame = waitForChildSafe(leaderboardSurfaceGui, "MainFrame", COMPONENT_WAIT_TIMEOUT)
	if not mainFrame or not mainFrame:IsA("ViewportFrame") then
		error("MainFrame not found")
	end

	local worldModel = waitForChildSafe(mainFrame, "WorldModel", COMPONENT_WAIT_TIMEOUT)
	if not worldModel or not worldModel:IsA("WorldModel") then
		error("WorldModel not found")
	end

	return mainFrame, worldModel
end

--[[
	Creates a new LeaderboardCharacterDisplayManager instance.
]]
function LeaderboardCharacterDisplayManager.new(leaderboardSurfaceGui: SurfaceGui?): any?
	if not leaderboardSurfaceGui or not leaderboardSurfaceGui:IsA("SurfaceGui") then
		return nil
	end

	local self = setmetatable({}, LeaderboardCharacterDisplayManager)

	local success = pcall(function()
		self.LeaderboardInterface = leaderboardSurfaceGui
		local mainFrame, worldModel = initializeComponents(leaderboardSurfaceGui)
		self.MainFrame = mainFrame
		self.CharacterDisplayWorldModel = worldModel
		self.DisplayedCharacterRigs = {}
		self.updateVersion = 0 -- Track update version to prevent race conditions
	end)

	return success and self or nil
end

local function cleanupCharacterRig(rigData: any)
	if rigData.animationTrack then
		AnimationController.cleanupAnimationTrack(rigData.animationTrack)
	end

	if rigData.model and rigData.model.Parent then
		rigData.model:Destroy()
	end
end

--[[
	Clears all displayed character rigs.
]]
function LeaderboardCharacterDisplayManager:clearAllDisplayedCharacters()
	safeExecute(function()
		for _, rigData in pairs(self.DisplayedCharacterRigs) do
			cleanupCharacterRig(rigData)
		end

		for _, child in pairs(self.CharacterDisplayWorldModel:GetChildren()) do
			if child.Name:match("^" .. RigBuilder.CHARACTER_RIG_NAME_PREFIX) then
				child:Destroy()
			end
		end

		table.clear(self.DisplayedCharacterRigs)
	end)
end

--[[
	Creates a cancellation check function bound to the current update version.
	Returns true if the update has been superseded and should be cancelled.
]]
local function createCancellationCheck(self, capturedVersion)
	return function()
		return self.updateVersion ~= capturedVersion
	end
end

local function processSinglePlayerCharacter(self: any, playerUserId: number, rankIndex: number, isCancelled: () -> boolean): any?
	if not ValidationUtils.isValidUserId(playerUserId) or not isValidRankIndex(rankIndex) then
		return nil
	end

	-- Check for cancellation before starting work
	if isCancelled() then
		return nil
	end

	local currentRankName = LEADERBOARD_RANK_POSITIONS[rankIndex]
	local rankPositionReferenceModel = self.CharacterDisplayWorldModel:FindFirstChild(currentRankName)
	if not rankPositionReferenceModel or not rankPositionReferenceModel:IsA("Model") then
		return nil
	end

	-- Pass cancellation check to RigBuilder for checking during retries
	local createdCharacterRig = RigBuilder.createPlayerCharacterForDisplay(
		playerUserId,
		rankPositionReferenceModel,
		self.CharacterDisplayWorldModel,
		isCancelled
	)

	-- Check for cancellation after the yielding operation completes
	if isCancelled() then
		if createdCharacterRig then
			createdCharacterRig:Destroy()
		end
		return nil
	end

	if createdCharacterRig then
		local humanoid = createdCharacterRig:FindFirstChildOfClass("Humanoid")
		local track = humanoid and AnimationController.startCharacterIdleAnimation(humanoid) or nil

		return {
			model = createdCharacterRig,
			animationTrack = track,
			userId = playerUserId,
			rank = rankIndex,
		}
	end

	return nil
end

--[[
	Processes leaderboard results and displays top player characters.
]]
function LeaderboardCharacterDisplayManager:processResults(topPlayerUserIds: { number })
	if typeof(topPlayerUserIds) ~= "table" then
		return
	end

	-- Increment version to invalidate any in-progress updates
	self.updateVersion = self.updateVersion + 1
	local currentVersion = self.updateVersion
	local isCancelled = createCancellationCheck(self, currentVersion)

	local displayCount = math.min(#topPlayerUserIds, MAX_CHARACTERS_DISPLAYED)

	safeExecute(function()
		self:clearAllDisplayedCharacters()

		for rankIndex = 1, displayCount do
			-- Check if a newer update has started before processing each rank
			if isCancelled() then
				return
			end

			local playerUserId = topPlayerUserIds[rankIndex]
			local rigData = processSinglePlayerCharacter(self, playerUserId, rankIndex, isCancelled)

			-- Final check before adding to displayed rigs
			if isCancelled() then
				if rigData and rigData.model then
					rigData.model:Destroy()
				end
				return
			end

			if rigData then
				table.insert(self.DisplayedCharacterRigs, rigData)
			end
		end
	end)
end

--[[
	Cleans up all resources and cancels pending updates.
]]
function LeaderboardCharacterDisplayManager:cleanup()
	self.updateVersion = self.updateVersion + 1

	self:clearAllDisplayedCharacters()
	self.LeaderboardInterface = nil
	self.MainFrame = nil
	self.CharacterDisplayWorldModel = nil
end

RigBuilder.safeExecute = safeExecute
RigBuilder.positionCharacterAtRankLocation = function(characterRig, rankPositionReference)
	return RigPositioner.positionCharacterAtRankLocation(characterRig, rankPositionReference)
end

RigPositioner.safeExecute = safeExecute
AnimationController.safeExecute = safeExecute

return LeaderboardCharacterDisplayManager