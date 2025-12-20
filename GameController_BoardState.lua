--[[
	BoardState - Manages Connect4 board state.

	Features:
	- Grid state tracking
	- Token placement
	- Win condition support
]]

local BoardState = {}
BoardState.__index = BoardState

--[[
	Creates a new board state instance.
]]
function BoardState.new(rows: number, columns: number): any
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

--[[
	Finds the lowest empty row in a column.
]]
function BoardState:findLowestAvailableRow(column: number): number?
	for row = 1, self.rows do
		if not self.state[column][row] then
			return row
		end
	end
	return nil
end

--[[
	Checks if the board is completely full.
]]
function BoardState:isBoardFull(): boolean
	for column = 1, self.columns do
		if self:findLowestAvailableRow(column) then
			return false
		end
	end
	return true
end

--[[
	Places a token at the specified position.
]]
function BoardState:placeToken(column: number, row: number, teamIndex: number, tokenInstance: BasePart?)
	self.state[column][row] = teamIndex
	if tokenInstance then
		self.tokenInstances[column][row] = tokenInstance
	end
end

--[[
	Gets the token instance at a position.
]]
function BoardState:getTokenInstance(column: number, row: number): BasePart?
	local columnData = self.tokenInstances[column]
	if columnData then
		return columnData[row]
	end
	return nil
end

--[[
	Resets the board to empty state.
]]
function BoardState:reset()
	for column = 1, self.columns do
		for row = 1, self.rows do
			self.state[column][row] = nil
			self.tokenInstances[column][row] = nil
		end
	end
end

--[[
	Gets the team index at a position.
]]
function BoardState:getState(column: number, row: number): number?
	local columnData = self.state[column]
	if columnData then
		return columnData[row]
	end
	return nil
end

return BoardState