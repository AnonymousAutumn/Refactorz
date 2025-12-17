-----------------
-- Init Module --
-----------------

local WinDetection = {}

---------------
-- Constants --
---------------

local WIN_CONDITION = 4

local DIRECTIONS = {
	{ 1, 0 },
	{ 0, 1 },
	{ 1, 1 },
	{ 1, -1 },
}

---------------
-- Functions --
---------------

function WinDetection.checkWin(boardState, column, row, teamIndex)
	for _, direction in DIRECTIONS do
		local dx, dy = direction[1], direction[2]
		local count = 1
		local positions = { { column, row } }

		for _, multiplier in { 1, -1 } do
			local step = 1
			while true do
				local checkColumn = column + dx * step * multiplier
				local checkRow = row + dy * step * multiplier

				local columnData = boardState[checkColumn]
				if columnData and columnData[checkRow] == teamIndex then
					count += 1
					table.insert(positions, { checkColumn, checkRow })
					step += 1
				else
					break
				end
			end
		end

		if count >= WIN_CONDITION then
			return {
				hasWon = true,
				winningPositions = positions,
			}
		end
	end

	return {
		hasWon = false,
		winningPositions = nil,
	}
end

-------------------
-- Return Module --
-------------------

return WinDetection