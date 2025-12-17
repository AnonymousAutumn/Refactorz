-----------------
-- Init Module --
-----------------

local ResponseParser = {}

--------------
-- Services --
--------------

local HttpService = game:GetService("HttpService")

---------------
-- Constants --
---------------

local ERROR_MESSAGES = {
	DEFAULT = "There was an error. Try again!",
	NO_RESPONSE = "No response data received from API",
	INVALID_DATA = "Invalid data received from API",
	EMPTY_RESPONSE = "Cannot decode empty response data",
}

---------------
-- Functions --
---------------

local function decodeJsonResponse(responseData)
	if not responseData or responseData == "" then
		warn(`[{script.Name}] {ERROR_MESSAGES.EMPTY_RESPONSE}`)
		return false, nil
	end

	local success, decodedData = pcall(function()
		return HttpService:JSONDecode(responseData)
	end)

	if not success then
		warn(`[{script.Name}] JSON decode failed: {tostring(decodedData)}`)
		return false, nil
	end

	return true, decodedData
end

local function extractApiErrorMessage(decodedData)
	if decodedData.Errors and type(decodedData.Errors) == "table" and #decodedData.Errors > 0 then
		local apiError = decodedData.Errors[1]
		local errorMessage = apiError.message or apiError.Message or ERROR_MESSAGES.DEFAULT
		local errorCode = tostring(apiError.code or apiError.Code or "unknown")

		warn(`[{script.Name}] API Error: {errorMessage} (Code: {errorCode})`)
		return errorMessage
	end

	if decodedData.error then
		local errorMsg = tostring(decodedData.error)
		warn(`[{script.Name}] API Error: {errorMsg}`)
		return errorMsg
	end

	return nil
end

function ResponseParser.parseResponse(responseData)
	if not responseData then
		warn(`[{script.Name}] API request failed: {ERROR_MESSAGES.NO_RESPONSE}`)
		return {
			success = false,
			errorMessage = ERROR_MESSAGES.NO_RESPONSE,
			data = nil,
		}
	end

	local decodeSuccess, decodedData = decodeJsonResponse(responseData)

	if not decodeSuccess then
		return {
			success = false,
			errorMessage = ERROR_MESSAGES.INVALID_DATA,
			data = nil,
		}
	end

	local apiError = extractApiErrorMessage(decodedData)
	if apiError then
		return {
			success = false,
			errorMessage = apiError,
			data = nil,
		}
	end

	return {
		success = true,
		errorMessage = "",
		data = decodedData,
	}
end

-------------------
-- Return Module --
-------------------

return ResponseParser