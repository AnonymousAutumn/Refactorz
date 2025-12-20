--[[
	StateManager - Manages UI state per player.

	Features:
	- Player UI state creation and retrieval
	- Connection and tween tracking
	- Resource cleanup management
]]

local StateManager = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local modulesFolder = ReplicatedStorage.Modules
local Connections = require(modulesFolder.Wrappers.Connections)

StateManager.playerUIStates = {}
StateManager.playerCooldownRegistry = {}

--[[
	Gets or creates UI state for a player.
]]
function StateManager.getOrCreatePlayerUIState(player: Player): any
	local userId = player.UserId
	if not StateManager.playerUIStates[userId] then
		StateManager.playerUIStates[userId] = {
			connections = Connections.new(),
			tweens = {},
			cooldownThread = nil,
			isGifting = false,
			lastRefreshTime = nil,
		}
	end
	return StateManager.playerUIStates[userId]
end

--[[
	Tracks a connection for a player's UI state.
]]
function StateManager.trackPlayerConnection(player: Player, connection: RBXScriptConnection): RBXScriptConnection
	local state = StateManager.getOrCreatePlayerUIState(player)
	state.connections:add(connection)
	return connection
end

--[[
	Tracks a tween for a player's UI state.
]]
function StateManager.trackPlayerTween(player: Player, tween: Tween): Tween
	local state = StateManager.getOrCreatePlayerUIState(player)
	table.insert(state.tweens, tween)
	return tween
end

--[[
	Cleans up all resources for a player.
	Optionally preserves the cooldown thread.
]]
function StateManager.cleanupPlayerResources(player: Player, preserveCooldownThread: boolean?)
	local userId = player.UserId
	local state = StateManager.playerUIStates[userId]
	if not state then
		return
	end

	state.connections:disconnect()

	for _, tween in ipairs(state.tweens) do
		pcall(function()
			if tween then
				tween:Cancel()
			end
		end)
	end
	table.clear(state.tweens)

	if state.cooldownThread and not preserveCooldownThread then
		task.cancel(state.cooldownThread)
		state.cooldownThread = nil
	end

	if preserveCooldownThread and state.cooldownThread then
		state.connections = Connections.new()
	else
		StateManager.playerUIStates[userId] = nil
		StateManager.playerCooldownRegistry[userId] = nil
	end
end

--[[
	Cleans up all player UI states.
]]
function StateManager.cleanupAllStates()
	for userId in pairs(StateManager.playerUIStates) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			StateManager.cleanupPlayerResources(player, true)
		end
	end

	table.clear(StateManager.playerCooldownRegistry)
	table.clear(StateManager.playerUIStates)
end

--[[
	Checks if a player is currently on cooldown.
]]
function StateManager.isPlayerOnCooldown(player: Player): boolean
	return StateManager.playerCooldownRegistry[player.UserId] ~= nil
end

--[[
	Gets the UI state for a player if it exists.
]]
function StateManager.getPlayerUIState(player: Player): any?
	return StateManager.playerUIStates[player.UserId]
end

return StateManager