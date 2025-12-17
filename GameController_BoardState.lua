-----------------
-- Init Module --
-----------------

local BoardState = {}
BoardState.__index = BoardState

---------------
-- Functions --
---------------

function BoardState.new(rows, columns)
	local self = setmetatable({}, BoardState) 

	self.rows = rows
	self.columns = columns
	self.state = {}
	self.tokenInstances = {}

	for column = 1, columns do
		self.state[column] = table.create(rows)
		self.tokenInstances[column] = table.create(rows)
	end

	return self 
end

function BoardState:findLowestAvailableRow(column)
	for row = 1, self.rows do
		if not self.state[column][row] then
			return row
		end
	end
	return nil
end

function BoardState:isBoardFull()
	for column = 1, self.columns do
		if self:findLowestAvailableRow(column) then
			return false
		end
	end
	return true
end

function BoardState:placeToken(column, row, teamIndex, tokenInstance)
	self.state[column][row] = teamIndex
	if tokenInstance then
		self.tokenInstances[column][row] = tokenInstance
	end
end

function BoardState:getTokenInstance(column, row)
	local columnData = self.tokenInstances[column]
	if columnData then
		return columnData[row]
	end
	return nil
end

function BoardState:reset()
	for column = 1, self.columns do
		for row = 1, self.rows do
			self.state[column][row] = nil
			self.tokenInstances[column][row] = nil
		end
	end
end

function BoardState:getState(column, row)
	local columnData = self.state[column]
	if columnData then
		return columnData[row]
	end
	return nil
end

-------------------
-- Return Module --
-------------------

return BoardState