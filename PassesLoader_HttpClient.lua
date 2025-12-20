--[[
	HttpClient - Makes HTTP requests with retry and rate limit handling.

	Features:
	- Automatic retry with exponential backoff
	- Rate limit detection and handling
	- Request timeout protection
]]

local HttpClient = {}

local HttpService = game:GetService("HttpService")

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

export type HttpResult = {
	success: boolean,
	responseData: string?,
	statusCode: number?,
	error: string?,
	wasRateLimited: boolean,
}

type RetryCallback = (attempt: number, maxRetries: number, errorMessage: string) -> ()

local function calculateBackoffDelay(attemptNumber: number, baseDelay: number): number
	return baseDelay * attemptNumber
end

local function hasTimedOut(startTime: number, timeout: number): boolean
	return os.clock() - startTime > timeout
end

local function isRateLimitError(errorMessage: string): boolean
	local lowerMessage = string.lower(errorMessage)
	return string.find(lowerMessage, "429") ~= nil or string.find(lowerMessage, "many") ~= nil
end

--[[
	Makes an HTTP GET request with automatic retry on failure.
	Returns an HttpResult with success status, response data, and error information.
]]
function HttpClient.makeRequest(url: string, maxRetries: number?, onRetry: RetryCallback?): HttpResult
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

return HttpClient