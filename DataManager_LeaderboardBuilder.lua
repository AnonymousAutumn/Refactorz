--[[
	LeaderboardBuilder - Creates and manages player leaderboard displays.

	Features:
	- Creates leaderstats folder with tracked statistics
	- Configurable display priorities for leaderboard ordering
	- Loads initial values from PlayerData
]]

local LeaderboardBuilder = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modulesFolder = ReplicatedStorage.Modules
local PlayerData = require(modulesFolder.Managers.PlayerData)

local TRACKED_STATISTICS = { "Donated", "Raised", "Wins" }
local DEFAULT_VALUE = 0

local DISPLAY_PRIORITIES: { [string]: number } = {
	Donated = 2,
	Raised = 1,
	Wins = 0,
}

local function getDisplayPriority(statisticName: string): number?
	return DISPLAY_PRIORITIES[statisticName]
end

local function createPriorityValue(statisticName: string, parent: Instance)
	local priority = getDisplayPriority(statisticName)
	if not priority then
		return
	end

	local priorityValue = Instance.new("NumberValue")
	priorityValue.Name = "Priority"
	priorityValue.Value = priority
	priorityValue.Parent = parent
end

local function createStatisticValue(statisticName: string, initialValue: number, parent: Instance): IntValue?
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

local function createLeaderstatsFolder(player: Player): Folder
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	folder.Parent = player
	return folder
end

local function createAllStatistics(playerUserId: number, leaderboardFolder: Folder)
	for _, statisticName in pairs(TRACKED_STATISTICS) do
		local statisticValue = PlayerData:GetPlayerStatisticValue(playerUserId, statisticName) or DEFAULT_VALUE

		local valueObject = createStatisticValue(statisticName, statisticValue, leaderboardFolder)
		if not valueObject then
			error(`Failed to create value object for {statisticName}`)
		end
	end
end

--[[
	Creates a leaderboard (leaderstats folder) for a player.
	Returns true on success, false on failure.
]]
function LeaderboardBuilder.createLeaderboard(player: Player): boolean
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

--[[
	Returns the leaderstats folder for a player.
]]
function LeaderboardBuilder.getLeaderstatsFolder(player: Player): Folder?
	return player:WaitForChild("leaderstats")
end

--[[
	Returns the IntValue for a specific statistic, or nil if not found.
]]
function LeaderboardBuilder.getStatisticObject(leaderboardFolder: Folder, statisticName: string): IntValue?
	local statObject = leaderboardFolder:FindFirstChild(statisticName)
	if not statObject or not statObject:IsA("IntValue") then
		return nil
	end
	return statObject
end

return LeaderboardBuilder