-----------------
-- Init Module --
-----------------

local HttpClient = {}

--------------
-- Services --
--------------

local HttpService = game:GetService("HttpService")

---------------
-- Constants --
---------------

local RETRY_ATTEMPTS = 3
local RETRY_DELAY = 1
local RATE_LIMIT_RETRY_DELAY = 1.0
local REQUEST_TIMEOUT = 10

local HTTP_STATUSES = {
	OK = 200,
	RATE_LIMITED = 429,
}

local ERROR_MESSAGES = {
	TIMEOUT = "Request timed out",
	RATE_LIMITED = "API rate limit exceeded, retrying...",
}

---------------
-- Functions --
---------------

local function calculateBackoffDelay(attemptNumber, baseDelay)
	return baseDelay * attemptNumber
end

local function hasTimedOut(startTime, timeout)
	return os.clock() - startTime > timeout
end

local function isRateLimitError(errorMessage)
	local lowerMessage = string.lower(errorMessage)
	return string.find(lowerMessage, "429") ~= nil or string.find(lowerMessage, "many") ~= nil
end

function HttpClient.makeRequest(url, maxRetries, onRetry)
	local retries = maxRetries or RETRY_ATTEMPTS
	local lastError = nil
	local lastStatusCode = nil
	local lastWasRateLimited = false

	for attempt = 1, retries do
		local startTime = os.clock()

		local success, responseData = pcall(function()
			local response = HttpService:GetAsync(url)

			if hasTimedOut(startTime, REQUEST_TIMEOUT) then
				error(ERROR_MESSAGES.TIMEOUT)
			end

			return response
		end)

		if success then
			return {
				success = true,
				responseData = responseData,
				statusCode = HTTP_STATUSES.OK,
				error = nil,
				wasRateLimited = false,
			}
		else
			local errorMessage = tostring(responseData)
			lastError = errorMessage

			local isRateLimited = isRateLimitError(errorMessage)
			lastStatusCode = isRateLimited and HTTP_STATUSES.RATE_LIMITED or nil

			if attempt == retries then
				lastWasRateLimited = isRateLimited
			end

			if attempt < retries and onRetry then
				onRetry(attempt, retries, errorMessage)
			end

			if attempt < retries then
				local delay = if isRateLimited
					then calculateBackoffDelay(attempt, RATE_LIMIT_RETRY_DELAY)
					else calculateBackoffDelay(attempt, RETRY_DELAY)
				task.wait(delay)
			end
		end
	end

	return {
		success = false,
		responseData = nil,
		statusCode = lastStatusCode,
		error = lastError,
		wasRateLimited = lastWasRateLimited,
	}
end

-------------------
-- Return Module --
-------------------

return HttpClient