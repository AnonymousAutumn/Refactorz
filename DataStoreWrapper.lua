-----------------
-- Init Module --
-----------------

local DataStoreWrapper = {}
DataStoreWrapper.__index = DataStoreWrapper

--------------
-- Services --
--------------

local DataStoreService = game:GetService("DataStoreService")

----------------
-- References --
----------------

local retryAsync = require(script.retryAsync)
local ThreadQueue = require(script.ThreadQueue)

---------------
-- Constants --
---------------

local RETRY_CONSTANT_SECONDS = 1
local RETRY_EXPONENT_SECONDS = 2
local MAX_ATTEMPTS = 3

local dataStoreOptions = Instance.new("DataStoreOptions")
dataStoreOptions:SetExperimentalFeatures({ v2 = true })

---------------
-- Functions --
---------------

function DataStoreWrapper.new(name, maxAttempts, retryConstant, retryExponent, isOrdered)
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

function DataStoreWrapper._attemptAsync(self, key, operation, optionalRetryFunctionHandler)
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

function DataStoreWrapper._onQueuePop(self, operation, optionalRetryFunctionHandler)
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

function DataStoreWrapper.getAsync(self, key, optionalRetryFunctionHandler)
	return self:_attemptAsync(key, function(dataStore)
		return dataStore:GetAsync(key)
	end, optionalRetryFunctionHandler)
end

function DataStoreWrapper.setAsync(self, key, value, userIds, options, optionalRetryFunctionHandler)
	return self:_attemptAsync(key, function(dataStore)
		return dataStore:SetAsync(key, value, userIds, options)
	end, optionalRetryFunctionHandler)
end

function DataStoreWrapper.removeAsync(self, key, optionalRetryFunctionHandler)
	return self:_attemptAsync(key, function(dataStore)
		return dataStore:RemoveAsync(key)
	end, optionalRetryFunctionHandler)
end

function DataStoreWrapper.updateAsync(self, key, transformFunction, optionalRetryFunctionHandler)
	return self:_attemptAsync(key, function(dataStore)
		return dataStore:UpdateAsync(key, transformFunction)
	end, optionalRetryFunctionHandler)
end

function DataStoreWrapper.incrementAsync(self, key, delta, optionalRetryFunctionHandler)
	return self:_attemptAsync(key, function(dataStore)
		return dataStore:IncrementAsync(key, delta)
	end, optionalRetryFunctionHandler)
end

function DataStoreWrapper.getSortedAsync(self, ascending, pageSize, minValue, maxValue, optionalRetryFunctionHandler)
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

function DataStoreWrapper.getDataStore(self)
	if self._isOrdered then
		return self:getOrderedDataStore()
	end

	if not self._dataStore then
		self._dataStore = DataStoreService:GetDataStore(self._name, nil, dataStoreOptions)
	end

	return self._dataStore
end

function DataStoreWrapper.getOrderedDataStore(self)
	if not self._orderedDataStore then
		self._orderedDataStore = DataStoreService:GetOrderedDataStore(self._name)
	end

	return self._orderedDataStore
end

function DataStoreWrapper.getQueueLength(self, key)
	local length = 0
	local threadQueue = self._keyQueues[key]

	if threadQueue then
		length = threadQueue:getLength()
	end

	return length
end

function DataStoreWrapper.areAllQueuesEmpty(self)
	for _, threadQueue in pairs(self._keyQueues) do
		if threadQueue:getLength() > 0 then
			return false
		end
	end

	return true
end

function DataStoreWrapper.skipAllQueuesToLastEnqueued(self)
	for _, threadQueue in pairs(self._keyQueues) do
		threadQueue:skipToLastEnqueued()
	end
end

-------------------
-- Return Module --
-------------------

return DataStoreWrapper	