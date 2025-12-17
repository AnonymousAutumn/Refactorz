-----------------
-- Init Module --
-----------------

local LeaderboardBuilder = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local PlayerData = require(modulesFolder.Managers.PlayerData)

---------------
-- Constants --
---------------

local TRACKED_STATISTICS = { "Donated", "Raised", "Wins" }
local DEFAULT_VALUE = 0

local DISPLAY_PRIORITIES = {
	Donated = 2,
	Raised = 1,
	Wins = 0,
}

---------------
-- Functions --
---------------

local function getDisplayPriority(statisticName)
	return DISPLAY_PRIORITIES[statisticName]
end

local function createPriorityValue(statisticName, parent)
	local priority = getDisplayPriority(statisticName)
	if not priority then
		return
	end

	local priorityValue = Instance.new("NumberValue")
	priorityValue.Name = "Priority"
	priorityValue.Value = priority
	priorityValue.Parent = parent
end

local function createStatisticValue(statisticName, initialValue, parent)
	local success, valueObject = pcall(function()
		local intValue = Instance.new("IntValue")
		intValue.Name = statisticName
		intValue.Value = initialValue
		intValue.Parent = parent

		createPriorityValue(statisticName, intValue)
		return intValue
	end)

	if not success then
		warn(`[{script.Name}] Failed to create value object for {statisticName}: {tostring(valueObject)}`)
		return nil
	end

	return valueObject
end

local function createLeaderstatsFolder(player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	folder.Parent = player
	return folder
end

local function createAllStatistics(playerUserId, leaderboardFolder)
	for _, statisticName in TRACKED_STATISTICS do
		local statisticValue = PlayerData:GetPlayerStatisticValue(playerUserId, statisticName) or DEFAULT_VALUE

		local valueObject = createStatisticValue(statisticName, statisticValue, leaderboardFolder)
		if not valueObject then
			error(`Failed to create value object for {statisticName}`)
		end
	end
end

function LeaderboardBuilder.createLeaderboard(player)
	local success, errorMessage = pcall(function()
		PlayerData:CachePlayerStatisticsDataInMemory(player.UserId)

		local leaderboardFolder = createLeaderstatsFolder(player)
		createAllStatistics(player.UserId, leaderboardFolder)
	end)

	if not success then
		warn(`[{script.Name}] Failed to create leaderboard for {player.Name} (UserId: {player.UserId}): {tostring(errorMessage)}`)
		return false
	end

	return true
end

function LeaderboardBuilder.getLeaderstatsFolder(player)
	return player:WaitForChild("leaderstats")
end

function LeaderboardBuilder.getStatisticObject(leaderboardFolder, statisticName)
	local statObject = leaderboardFolder:FindFirstChild(statisticName)
	if not statObject or not statObject:IsA("IntValue") then
		return nil
	end
	return statObject
end

-------------------
-- Return Module --
-------------------

return LeaderboardBuilder