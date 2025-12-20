--!strict

--[[
	ConnectAll - Batch-connects multiple signals to a single handler.

	Returns an array of connections that can be individually disconnected.

	Example usage:
		local connections = connectAll({signalA, signalB}, print)

		eventA:Fire("Hello from A")
		eventB:Fire("Hello from B")

		-- Cleanup
		for _, connection in connections do
			connection:Disconnect()
		end
]]

local Signal = require(script.Parent.Signal)

type Handler = (...any) -> ...any

local function connectAll(signals: { RBXScriptSignal | Signal.ClassType }, handler: Handler)
	local connections: { RBXScriptConnection | Signal.SignalConnection } = {}

	for _, signal in signals do
		local connection: RBXScriptConnection | Signal.SignalConnection = (signal :: any):Connect(handler)
		table.insert(connections, connection)
	end

	return connections
end

return connectAll
