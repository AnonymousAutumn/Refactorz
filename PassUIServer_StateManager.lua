-----------------
-- Init Module --
-----------------

local StateManager = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local Connections = require(modulesFolder.Wrappers.Connections)

---------------
-- Variables --
---------------

StateManager.playerUIStates = {}
StateManager.playerCooldownRegistry = {}

---------------
-- Functions --
---------------

function StateManager.getOrCreatePlayerUIState(player)
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

function StateManager.trackPlayerConnection(player, connection)
	local state = StateManager.getOrCreatePlayerUIState(player)
	state.connections:add(connection)
	return connection
end

function StateManager.trackPlayerTween(player, tween)
	local state = StateManager.getOrCreatePlayerUIState(player)
	table.insert(state.tweens, tween)
	return tween
end

function StateManager.cleanupPlayerResources(player, preserveCooldownThread)
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

function StateManager.cleanupAllStates()
	for userId in next, StateManager.playerUIStates do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			StateManager.cleanupPlayerResources(player, true)
		end
	end

	table.clear(StateManager.playerCooldownRegistry)
	table.clear(StateManager.playerUIStates)
end

function StateManager.isPlayerOnCooldown(player)
	return StateManager.playerCooldownRegistry[player.UserId] ~= nil
end

function StateManager.getPlayerUIState(player)
	return StateManager.playerUIStates[player.UserId]
end

-------------------
-- Return Module --
-------------------

return StateManager