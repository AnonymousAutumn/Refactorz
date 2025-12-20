--[[
	DataStoreWrapper - Wrapper for Roblox DataStore with retry logic and queue management.

	Features:
	- Exponential backoff retry on failure
	- Per-key thread queuing to prevent race conditions
	- Support for both regular and ordered DataStores
	- Configurable retry parameters
]]

local DataStoreWrapper = {}
DataStoreWrapper.__index = DataStoreWrapper

local DataStoreService = game:GetService("DataStoreService")

local retryAsync = require(script.retryAsync)
local ThreadQueue = require(script.ThreadQueue)

local RETRY_CONSTANT_SECONDS = 1
local RETRY_EXPONENT_SECONDS = 2
local MAX_ATTEMPTS = 3

local dataStoreOptions = Instance.new("DataStoreOptions")
dataStoreOptions:SetExperimentalFeatures({ v2 = true })

type RetryHandler = (attemptNumber: number, errorMessage: string) -> boolean
type TransformFunction = (oldValue: any) -> any

--[[
	Creates a new DataStoreWrapper instance.
]]
function DataStoreWrapper.new(name: string, maxAttempts: number?, retryConstant: number?, retryExponent: number?, isOrdered: boolean?)
	local self = {
		_name = name,
		_maxAttempts = maxAttempts or MAX_ATTEMPTS,
		_retryConstant = retryConstant or RETRY_CONSTANT_SECONDS,
		_retryExponent = retryExponent or RETRY_EXPONENT_SECONDS,
		_keyQueues = {},
		_isOrdered = isOrdered or false,
		_dataStore = nil,
		_orderedDataStore = nil,
	}
	setmetatable(self, DataStoreWrapper)

	return self
end

function DataStoreWrapper._attemptAsync(self, key: string, operation: (dataStore: DataStore) -> any, optionalRetryFunctionHandler: RetryHandler?)
	local queue = self._keyQueues[key]

	if not queue then
		queue = ThreadQueue.new()
		self._keyQueues[key] = queue
	end

	local queueReturnValues = {
		queue:submitAsync(function()
			return self:_onQueuePop(operation, optionalRetryFunctionHandler)
		end),
	}

	if queue:getLength() == 0 then
		self._keyQueues[key] = nil
	end

	return table.unpack(queueReturnValues)
end

function DataStoreWrapper._onQueuePop(self, operation: (dataStore: DataStore) -> any, optionalRetryFunctionHandler: RetryHandler?)
	local attemptReturnValues = {
		retryAsync(function()
			local dataStore = self:getDataStore()
			return operation(dataStore)
		end, self._maxAttempts, self._retryConstant, self._retryExponent, optionalRetryFunctionHandler),
	}

	local attemptSuccess = table.remove(attemptReturnValues, 1) 

	if not attemptSuccess then
		local errorMessage = attemptReturnValues[1]
		error(errorMessage)
	end

	return table.unpack(attemptReturnValues)
end

--[[
	Retrieves a value from the DataStore by key.
]]
function DataStoreWrapper.getAsync(self, key: string, optionalRetryFunctionHandler: RetryHandler?): any
	return self:_attemptAsync(key, function(dataStore)
		return dataStore:GetAsync(key)
	end, optionalRetryFunctionHandler)
end

--[[
	Sets a value in the DataStore by key.
]]
function DataStoreWrapper.setAsync(self, key: string, value: any, userIds: {number}?, options: DataStoreSetOptions?, optionalRetryFunctionHandler: RetryHandler?)
	return self:_attemptAsync(key, function(dataStore)
		return dataStore:SetAsync(key, value, userIds, options)
	end, optionalRetryFunctionHandler)
end

--[[
	Removes a key from the DataStore.
]]
function DataStoreWrapper.removeAsync(self, key: string, optionalRetryFunctionHandler: RetryHandler?)
	return self:_attemptAsync(key, function(dataStore)
		return dataStore:RemoveAsync(key)
	end, optionalRetryFunctionHandler)
end

--[[
	Updates a value in the DataStore using a transform function.
]]
function DataStoreWrapper.updateAsync(self, key: string, transformFunction: TransformFunction, optionalRetryFunctionHandler: RetryHandler?)
	return self:_attemptAsync(key, function(dataStore)
		return dataStore:UpdateAsync(key, transformFunction)
	end, optionalRetryFunctionHandler)
end

--[[
	Increments a numeric value in the DataStore by delta.
]]
function DataStoreWrapper.incrementAsync(self, key: string, delta: number, optionalRetryFunctionHandler: RetryHandler?)
	return self:_attemptAsync(key, function(dataStore)
		return dataStore:IncrementAsync(key, delta)
	end, optionalRetryFunctionHandler)
end

--[[
	Retrieves sorted data from an OrderedDataStore.
	Only works when isOrdered = true.
]]
function DataStoreWrapper.getSortedAsync(self, ascending: boolean, pageSize: number, minValue: number?, maxValue: number?, optionalRetryFunctionHandler: RetryHandler?): DataStorePages
	if not self._isOrdered then
		return false, "getSortedAsync requires an OrderedDataStore (isOrdered = true)"
	end

	local syntheticKey = "__getSortedAsync__"

	local queue = self._keyQueues[syntheticKey]
	if not queue then
		queue = ThreadQueue.new()
		self._keyQueues[syntheticKey] = queue
	end

	local queueReturnValues = {
		queue:submitAsync(function()
			local attemptReturnValues = {
				retryAsync(function()
					local orderedDataStore = self:getOrderedDataStore()
					return orderedDataStore:GetSortedAsync(ascending, pageSize, minValue, maxValue)
				end, self._maxAttempts, self._retryConstant, self._retryExponent, optionalRetryFunctionHandler),
			}

			local attemptSuccess = table.remove(attemptReturnValues, 1) 
			if not attemptSuccess then
				error(attemptReturnValues[1])
			end

			return table.unpack(attemptReturnValues)
		end),
	}

	if queue:getLength() == 0 then
		self._keyQueues[syntheticKey] = nil
	end

	return table.unpack(queueReturnValues)
end

--[[
	Returns the underlying DataStore instance (lazy-loaded).
]]
function DataStoreWrapper.getDataStore(self): DataStore
	if self._isOrdered then
		return self:getOrderedDataStore()
	end

	if not self._dataStore then
		self._dataStore = DataStoreService:GetDataStore(self._name, nil, dataStoreOptions)
	end

	return self._dataStore
end

--[[
	Returns the underlying OrderedDataStore instance (lazy-loaded).
]]
function DataStoreWrapper.getOrderedDataStore(self): OrderedDataStore
	if not self._orderedDataStore then
		self._orderedDataStore = DataStoreService:GetOrderedDataStore(self._name)
	end

	return self._orderedDataStore
end

--[[
	Returns the number of pending operations for a specific key.
]]
function DataStoreWrapper.getQueueLength(self, key: string): number
	local length = 0
	local threadQueue = self._keyQueues[key]

	if threadQueue then
		length = threadQueue:getLength()
	end

	return length
end

--[[
	Returns true if all operation queues are empty.
]]
function DataStoreWrapper.areAllQueuesEmpty(self): boolean
	for _, threadQueue in pairs(self._keyQueues) do
		if threadQueue:getLength() > 0 then
			return false
		end
	end

	return true
end

--[[
	Skips all queued operations except the last one for each key.
]]
function DataStoreWrapper.skipAllQueuesToLastEnqueued(self)
	for _, threadQueue in pairs(self._keyQueues) do
		threadQueue:skipToLastEnqueued()
	end
end

return DataStoreWrapper