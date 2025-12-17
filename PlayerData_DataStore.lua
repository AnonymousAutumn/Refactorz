-----------------
-- Init Module --
-----------------

local DataStore = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules

local DataStores = require(modulesFolder.Wrappers.DataStores)
local ValidationUtils = require(modulesFolder.Utilities.ValidationUtils)

---------------
-- Constants --
---------------

local DEFAULT_PLAYER_STATISTICS = {
	Donated = 0,
	Raised = 0,
	Wins = 0,
}

---------------
-- Functions --
---------------

local function validateAndSanitizeStatisticsData(data)
	if type(data) ~= "table" then
		return table.clone(DEFAULT_PLAYER_STATISTICS)
	end

	local sanitizedData = {} 

	for key, defaultValue in DEFAULT_PLAYER_STATISTICS do
		local value = data[key]
		if ValidationUtils.isValidNumber(value) and value >= 0 then
			sanitizedData[key] = value
		else
			sanitizedData[key] = defaultValue
		end
	end

	if type(data.processedReceipts) == "table" then
		sanitizedData.processedReceipts = data.processedReceipts
	end

	return sanitizedData
end

function DataStore.savePlayerStatistics(playerUserId, playerStatisticsData)
	local success, result = DataStores.PlayerStats:updateAsync(
		playerUserId,
		function(oldData)

			if oldData == nil then
				return playerStatisticsData
			end

			local existingData = validateAndSanitizeStatisticsData(oldData)

			for key, newValue in playerStatisticsData do
				if key ~= "processedReceipts" and ValidationUtils.isValidNumber(newValue) and newValue >= 0 then

					existingData[key] = math.max(existingData[key] or 0, newValue)
				end
			end

			return existingData
		end
	)

	if not success then
		warn(`[{script.Name}] Failed to save statistics data for user {playerUserId}: {tostring(result)}`)
		return false
	end

	return true
end

function DataStore.loadPlayerStatistics(playerUserId)
	local success, result = DataStores.PlayerStats:getAsync(playerUserId)

	local sanitizedData
	if success and result then
		sanitizedData = validateAndSanitizeStatisticsData(result)
	else
		sanitizedData = table.clone(DEFAULT_PLAYER_STATISTICS)
	end

	return sanitizedData
end

function DataStore.processReceiptAndIncrementStatistic(playerUserId, purchaseId, statisticName, incrementAmount)
	if not ValidationUtils.isValidUserId(tonumber(playerUserId)) then
		warn(`[{script.Name}] Invalid player user ID for receipt processing: {tostring(playerUserId)}`)
		return false, nil, "invalid_params"
	end

	if type(purchaseId) ~= "string" or purchaseId == "" then
		warn(`[{script.Name}] Invalid purchase ID for receipt processing: {tostring(purchaseId)}`)
		return false, nil, "invalid_params"
	end

	if DEFAULT_PLAYER_STATISTICS[statisticName] == nil then
		warn(`[{script.Name}] Invalid statistic name for receipt processing: {tostring(statisticName)}`)
		return false, nil, "invalid_params"
	end

	if not ValidationUtils.isValidNumber(incrementAmount) or incrementAmount < 1 then
		warn(`[{script.Name}] Invalid increment amount for receipt processing: {tostring(incrementAmount)}`)
		return false, nil, "invalid_params"
	end

	local wasAlreadyProcessed = false
	local newStatValue = nil

	local success, result = DataStores.PlayerStats:updateAsync(
		tostring(playerUserId),
		function(oldData)
			local existingData = validateAndSanitizeStatisticsData(oldData)

			existingData.processedReceipts = existingData.processedReceipts or {}

			if existingData.processedReceipts[purchaseId] then
				wasAlreadyProcessed = true
				return nil
			end

			existingData.processedReceipts[purchaseId] = true
			existingData[statisticName] = (existingData[statisticName] or 0) + incrementAmount
			newStatValue = existingData[statisticName]

			return existingData
		end
	)

	if not success then
		warn(`[{script.Name}] Failed to process receipt for user {playerUserId}: {tostring(result)}`)
		return false, nil, "datastore_error"
	end

	if wasAlreadyProcessed then
		return true, nil, "already_processed"
	end

	return true, newStatValue, "newly_processed"
end

-------------------
-- Return Module --
-------------------

return DataStore