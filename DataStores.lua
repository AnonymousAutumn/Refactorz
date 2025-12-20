--[[
	DataStores - Centralized DataStore instances for the game.

	Provides pre-configured DataStoreWrapper instances:
	- PlayerStats: Player statistics (regular DataStore)
	- Gifts: Gift data (regular DataStore)
	- Wins: Win leaderboard (ordered DataStore)
	- Donated: Donation leaderboard (ordered DataStore)
	- Raised: Funds raised leaderboard (ordered DataStore)
]]

local DataStores = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modulesFolder = ReplicatedStorage.Modules
local configurationFolder = ReplicatedStorage.Configuration

local DataStoreWrapper = require(modulesFolder.Wrappers.DataStore)
local GameConfig = require(configurationFolder.GameConfig)

DataStores.PlayerStats = DataStoreWrapper.new(GameConfig.DATASTORE.STATS_KEY)
DataStores.Gifts = DataStoreWrapper.new(GameConfig.DATASTORE.GIFTS_KEY)

DataStores.Wins = DataStoreWrapper.new(GameConfig.DATASTORE.WINS_ORDERED_KEY, nil, nil, nil, true)
DataStores.Donated = DataStoreWrapper.new(GameConfig.DATASTORE.DONATED_ORDERED_KEY, nil, nil, nil, true)
DataStores.Raised = DataStoreWrapper.new(GameConfig.DATASTORE.RAISED_ORDERED_KEY, nil, nil, nil, true)

return DataStores