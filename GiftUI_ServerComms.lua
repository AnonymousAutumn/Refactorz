--[[
	ServerComms - Handles server communication for gift operations.

	Features:
	- Gift data retrieval
	- Gift clearance notification
	- Gift process initiation
]]

local ServerComms = {}
ServerComms.safeExecute = nil

--[[
	Requests the latest gift data from the server.
]]
function ServerComms.requestLatestGiftDataFromServer(requestFunction: RemoteFunction): { any }?
	local success, retrievedGiftData = pcall(function()
		return requestFunction:InvokeServer()
	end)

	if not success or not retrievedGiftData then
		return nil
	end

	return retrievedGiftData
end

--[[
	Notifies the server that gifts have been cleared.
]]
function ServerComms.notifyServerOfGiftClearance(clearEvent: RemoteEvent)
	if ServerComms.safeExecute then
		ServerComms.safeExecute(function()
			clearEvent:FireServer()
		end)
	end
end

--[[
	Initiates the gift process for a target user.
]]
function ServerComms.initiateGiftProcess(toggleEvent: RemoteEvent, targetUserId: number)
	if ServerComms.safeExecute then
		ServerComms.safeExecute(function()
			toggleEvent:FireServer(targetUserId)
		end)
	end
end

return ServerComms