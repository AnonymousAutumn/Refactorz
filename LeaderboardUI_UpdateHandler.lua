--[[
	UpdateHandler - Handles leaderboard update events from server.

	Features:
	- Remote event connection setup
	- Server ready notification
	- Safe update processing
]]

local UpdateHandler = {}

local CLIENT_READY_MESSAGE = "Ready"

local function safeExecute(func: () -> ()): boolean
	local success, errorMessage = pcall(func)
	if not success then
		warn("Error in UpdateHandler.safeExecute:", errorMessage)
	end
	return success
end

local function handleLeaderboardUpdate(serverLeaderboardData: any, clientHandler: any, updateStateFunc: (any) -> ())
	if typeof(serverLeaderboardData) ~= "table" then
		return
	end

	safeExecute(function()
		clientHandler:processResults(serverLeaderboardData)
	end)
end

--[[
	Sets up update event listener and notifies server of readiness.
]]
function UpdateHandler.setupUpdates(updateRemoteEvent: RemoteEvent?, clientHandler: any?, state: any?, updateStateFunc: (any) -> ()): boolean
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

return UpdateHandler