----------------
-- References --
----------------

local connect4BoardsFolder = workspace.Connect4Boards
local GameController = require(script.GameController)

---------------
-- Variables --
---------------

local activeBoardControllers = {}

---------------
-- Functions --
---------------

local function setupConnect4GameBoards()
	local boardModelCollection = connect4BoardsFolder:GetChildren()
	local initializedBoardControllers = table.create(#boardModelCollection)

	for _, boardModel in boardModelCollection do
		local success, boardGameController = pcall(function()
			return GameController.new(boardModel)
		end)

		if success and boardGameController then
			table.insert(initializedBoardControllers, boardGameController)
		else
			warn(`[{script.Name}] Failed to initialize board controller`)
		end
	end

	return initializedBoardControllers
end

local function initialize()
	activeBoardControllers = setupConnect4GameBoards()
end

--------------------
-- Initialization --
--------------------

initialize()