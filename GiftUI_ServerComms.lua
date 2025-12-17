-----------------
-- Init Module --
-----------------

local ServerComms = {}
ServerComms.safeExecute = nil

---------------
-- Functions --
---------------

function ServerComms.requestLatestGiftDataFromServer(requestFunction)
	local success, retrievedGiftData = pcall(function()
		return requestFunction:InvokeServer()
	end)

	if not success or not retrievedGiftData then
		return nil
	end

	return retrievedGiftData
end

function ServerComms.notifyServerOfGiftClearance(clearEvent)
	if ServerComms.safeExecute then
		ServerComms.safeExecute(function()
			clearEvent:FireServer()
		end)
	end
end

function ServerComms.initiateGiftProcess(toggleEvent, targetUserId)
	if ServerComms.safeExecute then
		ServerComms.safeExecute(function()
			toggleEvent:FireServer(targetUserId)
		end)
	end
end

-------------------
-- Return Module --
-------------------

return ServerComms