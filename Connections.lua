--[[
	Connections - Lightweight Maid pattern for managing RBXScriptConnections.

	Collects connections and disconnects them all when prompted.
	Useful for cleanup on player leave, GUI destruction, etc.

	Based on: https://github.com/Quenty/NevermoreEngine/blob/version2/Modules/Shared/Events/Maid.lua
]]

local Signal = require(script.Parent.Signal)

type EitherConnection = RBXScriptConnection | Signal.SignalConnection

local Connections = {}
Connections.__index = Connections

export type ClassType = typeof(setmetatable(
	{} :: {
		_connections: { EitherConnection },
	},
	Connections
))

function Connections.new(): ClassType
	local self = setmetatable({
		_connections = {},
	}, Connections)

	return self
end

--[[
	Adds one or more connections to be tracked.
	Duplicate connections are silently ignored to avoid errors in hot paths.
]]
function Connections.add(self: ClassType, ...: EitherConnection)
	for _, connection in { ... } do
		if not table.find(self._connections, connection) then
			table.insert(self._connections, connection)
		end
	end
end

--[[
	Removes a connection from tracking (does not disconnect it).
]]
function Connections.remove(self: ClassType, connection: EitherConnection)
	local index = table.find(self._connections, connection)
	if index then
		table.remove(self._connections, index)
	end
end

--[[
	Disconnects all tracked connections and clears the list.
]]
function Connections.disconnect(self: ClassType)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}
end

--[[
	Returns the number of tracked connections.
]]
function Connections.getCount(self: ClassType): number
	return #self._connections
end

return Connections
