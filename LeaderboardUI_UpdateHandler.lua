-----------------
-- Init Module --
-----------------

local UpdateHandler = {}

---------------
-- Constants --
---------------

local CLIENT_READY_MESSAGE = "Ready"

---------------
-- Functions --
---------------

local function safeExecute(func)
	local success, errorMessage = pcall(func)
	if not success then
		warn("Error in UpdateHandler.safeExecute:", errorMessage)
	end
	return success
end

local function handleLeaderboardUpdate(serverLeaderboardData, clientHandler, updateStateFunc)
	if typeof(serverLeaderboardData) ~= "table" then
		return
	end

	safeExecute(function()
		clientHandler:processResults(serverLeaderboardData)
	end)
end

function UpdateHandler.setupUpdates(updateRemoteEvent, clientHandler, state, updateStateFunc)
	if not updateRemoteEvent or not updateRemoteEvent:IsA("RemoteEvent") or not clientHandler or not state then
		return false
	end

	return safeExecute(function()
		local updateConnection = updateRemoteEvent.OnClientEvent:Connect(function(serverLeaderboardData)
			updateStateFunc(state)
			handleLeaderboardUpdate(serverLeaderboardData, clientHandler, updateStateFunc)
		end)
		table.insert(state.connections, updateConnection)

		updateRemoteEvent:FireServer(CLIENT_READY_MESSAGE)
	end)
end

-------------------
-- Return Module --
-------------------

return UpdateHandler