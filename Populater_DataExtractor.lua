--[[
	DataExtractor - Extracts leaderboard data from DataStore pages.

	Features:
	- Page iteration with safety limits
	- Entry validation
	- Multi-page data extraction
]]

local DataExtractor = {}

local MAX_PAGE_ITERATIONS = 100

local function isValidLeaderboardEntry(entry: any): boolean
	return type(entry) == "table" and entry.key ~= nil and entry.value ~= nil
end

local function extractEntriesFromPage(currentPageData: { any }, extractedEntries: { any }, maximumEntryCount: number): boolean
	if type(currentPageData) ~= "table" then
		warn(`[{script.Name}] Current page data is not a table`)
		
		return false
	end
	
	for _, entryData in pairs(currentPageData) do
		if isValidLeaderboardEntry(entryData) then
			table.insert(extractedEntries, entryData)
			
			if #extractedEntries >= maximumEntryCount then
				return true
			end
		end
	end
	return false
end

local function getCurrentPage(dataStorePages: any): (boolean, { any }?)
	local success, currentPageData = pcall(function()
		return dataStorePages:GetCurrentPage()
	end)
	if not success then
		warn(`[{script.Name}] Failed to get current page: {tostring(currentPageData)}`)
		return false, nil
	end
	return true, currentPageData
end

local function advanceToNextPage(dataStorePages: any): boolean
	local advanceSuccess, advanceError = pcall(function()
		dataStorePages:AdvanceToNextPageAsync()
	end)
	if not advanceSuccess then
		warn(`[{script.Name}] Failed to advance to next page: {tostring(advanceError)}`)
		return false
	end
	return true
end

--[[
	Extracts entries from DataStore pages up to maximum count.
]]
function DataExtractor.extractFromPages(dataStorePages: any, maximumEntryCount: number): { any }
	local extractedEntries = {}
	local pageIterations = 0

	repeat
		pageIterations += 1
		if pageIterations > MAX_PAGE_ITERATIONS then
			warn(`[{script.Name}] Maximum page iterations ({MAX_PAGE_ITERATIONS}) reached, stopping extraction`)
			break
		end

		local success, currentPageData = getCurrentPage(dataStorePages)
		if not success then
			break
		end

		local reachedMax = extractEntriesFromPage(currentPageData, extractedEntries, maximumEntryCount)
		if reachedMax or #extractedEntries >= maximumEntryCount or dataStorePages.IsFinished then
			break
		end

		if not advanceToNextPage(dataStorePages) then
			break
		end
	until false

	return extractedEntries
end

return DataExtractor