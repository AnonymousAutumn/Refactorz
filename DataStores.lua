-----------------
-- Init Module --
-----------------

local DataStores = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local modulesFolder = ReplicatedStorage.Modules
local configurationFolder = ReplicatedStorage.Configuration

local DataStoreWrapper = require(modulesFolder.Wrappers.DataStore)
local GameConfig = require(configurationFolder.GameConfig)

--------------------
-- Initialization --
--------------------

DataStores.PlayerStats = DataStoreWrapper.new(GameConfig.DATASTORE.STATS_KEY)
DataStores.Gifts = DataStoreWrapper.new(GameConfig.DATASTORE.GIFTS_KEY)

DataStores.Wins = DataStoreWrapper.new(GameConfig.DATASTORE.WINS_ORDERED_KEY, nil, nil, nil, true)
DataStores.Donated = DataStoreWrapper.new(GameConfig.DATASTORE.DONATED_ORDERED_KEY, nil, nil, nil, true)
DataStores.Raised = DataStoreWrapper.new(GameConfig.DATASTORE.RAISED_ORDERED_KEY, nil, nil, nil, true)

-------------------
-- Return Module --
-------------------

return DataStores