-----------------
-- Init Module --
-----------------

local Connect4GameBoard = {}
Connect4GameBoard.__index = Connect4GameBoard

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local networkFolder = ReplicatedStorage.Network
local connect4Bindables = networkFolder.Bindables.Connect4
local connect4Remotes = networkFolder.Remotes.Connect4

local moldulesFolder = ReplicatedStorage.Modules
local configurationFolder = ReplicatedStorage.Configuration
local PlayerData = require(moldulesFolder.Managers.PlayerData)
local DataStores = require(moldulesFolder.Wrappers.DataStores)
local GameConfig = require(configurationFolder.GameConfig)
local WinDetection = require(script.WinDetection)
local TokenFactory = require(script.TokenFactory)
local BoardState = require(script.BoardState)
local PlayerNotifications = require(script.PlayerNotifications)
local CameraController = require(script.CameraController)
local GameTiming = require(script.GameTiming)

---------------
-- Constants --
---------------

local ROWS = 5
local COLUMNS = 8
local MAX_PLAYER_DISTANCE = 15
local DISTANCE_CHECK_INTERVAL = 0.5
local PLAYER_CAPACITY = 2
local TOKEN_HEIGHT = 0.9

---------------
-- Functions --
---------------

local function updateWinsDataStore(playerId, increment)
	local success, result = DataStores.Wins:incrementAsync(tostring(playerId), increment)

	if not success then
		warn(`Failed to update DataStore for player {tostring(playerId)}: {tostring(result)}`)
		return 0
	end

	return result or 0
end

local function recordPlayerWin(playerUserId, wins)
	updateWinsDataStore(playerUserId, wins)
	PlayerData:IncrementPlayerStatistic(playerUserId, "Wins", wins)
end

function Connect4GameBoard.new(boardModel)
	local self = setmetatable({}, Connect4GameBoard) 

	self.boardModel = boardModel
	self.tokenContainer = boardModel:WaitForChild("Tokens")
	self.basePlateYPosition = boardModel:WaitForChild("Base").Position.Y
	self.gameObjectHolder = boardModel:WaitForChild("ObjectHolder")
	self.columnTriggers = boardModel:WaitForChild("Triggers")
	self.joinGamePrompt = self.gameObjectHolder:WaitForChild("ProximityPrompt")
	self.gameCameraPart = boardModel:WaitForChild("CameraPart")

	self.columnTriggerPositions = {}
	self.currentGamePlayers = {}
	self.activePlayerIndex = 0
	self.boardState = BoardState.new(ROWS, COLUMNS)
	self.timingManager = GameTiming.new()
	self.isTokenCurrentlyDropping = false
	self.isGameCurrentlyActive = false

	self._lastDistanceCheck = 0
	self._cachedBoardPosition = nil

	self:_setupColumnTriggers()
	self:_setupJoinPrompt()
	self:_connectEvents()
	self:_startDistanceMonitoring()
	self:_updateJoinPrompt()

	return self 
end

function Connect4GameBoard:_setupColumnTriggers()
	for _, trigger in self.columnTriggers:GetChildren() do
		if not trigger:IsA("BasePart") then
			continue
		end

		local columnIndex = tonumber(trigger.Name:match("C(%d+)"))
		if not columnIndex then
			continue
		end

		self.columnTriggerPositions[columnIndex] = trigger.Position

		local clickDetector = trigger:FindFirstChild("ClickDetector")
		if clickDetector and clickDetector:IsA("ClickDetector") then
			clickDetector.MouseClick:Connect(function(player)
				self:_attemptTokenDrop(player, columnIndex)
			end)
		end
	end
end

function Connect4GameBoard:_setupJoinPrompt()
	self.joinGamePrompt.Triggered:Connect(function(player)
		if self.isGameCurrentlyActive then
			return
		end

		local playerIndex = table.find(self.currentGamePlayers, player)
		if playerIndex then
			table.remove(self.currentGamePlayers, playerIndex)
			PlayerNotifications.sendToPlayer(player, "left the queue", nil, false)
			self:_updateJoinPrompt()
			return
		end

		connect4Bindables.KickPlayer:Fire(player)

		if #self.currentGamePlayers < PLAYER_CAPACITY then
			table.insert(self.currentGamePlayers, player)
			self:_updateJoinPrompt()

			if #self.currentGamePlayers == PLAYER_CAPACITY then
				self:_startGame()
			else
				PlayerNotifications.sendToPlayer(player, "joined the queue", nil, false)
			end
		end
	end)
end

function Connect4GameBoard:_connectEvents()
	connect4Bindables.DropToken.Event:Connect(function(player, column)
		self:_attemptTokenDrop(player, column)
	end)

	connect4Bindables.KickPlayer.Event:Connect(function(player)
		if table.find(self.currentGamePlayers, player) then
			PlayerNotifications.sendToPlayersExcept(self.currentGamePlayers, `{player.Name} stopped playing`, player)
			self:_resetGame(true)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:_handlePlayerLeaving(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid")
			humanoid.Died:Connect(function()
				self:_handlePlayerLeaving(player)
			end)
		end)
	end)

	connect4Remotes.PlayerExited.OnServerEvent:Connect(function(player)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then
			warn(`[{script.Name}] Invalid player in PlayerExited RemoteEvent`)
			return
		end
		connect4Bindables.KickPlayer:Fire(player)
	end)
end

function Connect4GameBoard:_handlePlayerLeaving(player)
	if table.find(self.currentGamePlayers, player) then
		PlayerNotifications.sendToPlayersExcept(self.currentGamePlayers, `{player.Name} stopped playing`, player)
		self:_resetGame(true)
	end
end

function Connect4GameBoard:_startDistanceMonitoring()
	RunService.Heartbeat:Connect(function()
		if not self.boardModel or not self.currentGamePlayers then
			return
		end

		local now = tick()
		if now - (self._lastDistanceCheck or 0) < DISTANCE_CHECK_INTERVAL then
			return
		end
		self._lastDistanceCheck = now

		local boardPosition = self._cachedBoardPosition or self.boardModel:GetPivot().Position
		self._cachedBoardPosition = boardPosition

		for i = #self.currentGamePlayers, 1, -1 do
			local player = self.currentGamePlayers[i]
			local character = player.Character
			if not character then
				continue
			end

			local hrp = character:FindFirstChild("HumanoidRootPart")
			if not hrp then
				continue
			end

			local distance = (hrp.Position - boardPosition).Magnitude

			if distance > MAX_PLAYER_DISTANCE then
				table.remove(self.currentGamePlayers, i)
				PlayerNotifications.sendToPlayer(player, "left the queue", nil, false)
				PlayerNotifications.sendToPlayersExcept(self.currentGamePlayers, `{player.Name} stopped playing`, player)
				self:_updateJoinPrompt()

				if self.isGameCurrentlyActive then
					self:_resetGame(true)
				end
			end
		end
	end)
end

function Connect4GameBoard:_updateJoinPrompt()
	if self.joinGamePrompt then
		self.joinGamePrompt.Enabled = not self.isGameCurrentlyActive
		self.joinGamePrompt.ActionText = `Join ({tostring(#self.currentGamePlayers)}/{tostring(PLAYER_CAPACITY)} Players)`
	end
end

function Connect4GameBoard:_switchTurn()
	self.activePlayerIndex = 1 - self.activePlayerIndex
end

function Connect4GameBoard:_startGame()
	self.isGameCurrentlyActive = true
	self.activePlayerIndex = 0
	self:_updateJoinPrompt()

	for i, player in self.currentGamePlayers do
		local isPlayerTurn = (self.activePlayerIndex == (i - 1))
		local message = isPlayerTurn and "Your turn!" or "Waiting for opponent..."
		local timeout = isPlayerTurn and GameTiming.getTurnTimeout() or nil

		PlayerNotifications.sendToPlayer(player, message, timeout, isPlayerTurn)
		CameraController.updatePlayerCamera(player, isPlayerTurn, self.gameCameraPart.CFrame)
	end

	self.timingManager:startTurnTimeout(function()
		PlayerNotifications.sendToPlayers(self.currentGamePlayers, "Turn timed out. Resetting game...")
		GameTiming.scheduleReset(function()
			self:_resetGame(true)
		end)
	end)
end

function Connect4GameBoard:_resetGame(shouldResetUI)
	self.isGameCurrentlyActive = false
	self.timingManager:cancelCurrentTimeout()

	if shouldResetUI then
		PlayerNotifications.clearAllUI(self.currentGamePlayers)
	end

	CameraController.resetAllCameras(self.currentGamePlayers)
	self.boardState:reset()

	local tokens = self.tokenContainer:GetChildren()
	for _, token in tokens do
		token:Destroy()
	end

	self.activePlayerIndex = 0
	self.currentGamePlayers = {}
	self._cachedBoardPosition = nil

	self:_updateJoinPrompt()
end

function Connect4GameBoard:_attemptTokenDrop(player, column)
	if not self.isGameCurrentlyActive or self.isTokenCurrentlyDropping then
		return false
	end

	if self.currentGamePlayers[self.activePlayerIndex + 1] ~= player then
		return false
	end

	local row = self.boardState:findLowestAvailableRow(column)
	if not row then
		return false
	end

	self.isTokenCurrentlyDropping = true

	local boardRotation = nil
	if self.boardModel:FindFirstChild("LeftBase") then
		boardRotation = self.boardModel.LeftBase.Rotation
	end

	local token = TokenFactory.createToken(self.tokenContainer, {
		column = column,
		row = row,
		teamIndex = self.activePlayerIndex,
		triggerPosition = self.columnTriggerPositions[column],
		basePlateYPosition = self.basePlateYPosition,
		tokenHeight = TOKEN_HEIGHT,
		boardRotation = boardRotation,
	})

	self.boardState:placeToken(column, row, self.activePlayerIndex, token)
	self.timingManager:cancelCurrentTimeout()

	local winResult = WinDetection.checkWin(self.boardState.state, column, row, self.activePlayerIndex)

	if winResult.hasWon then
		self:_handleWin(player, winResult.winningPositions)
	else
		self:_handleContinueOrDraw()
	end

	return true
end

function Connect4GameBoard:_handleWin(winner, winningPositions: { { number } })
	for _, position in winningPositions do
		local token = self.boardState:getTokenInstance(position[1], position[2])
		if token then
			TokenFactory.applyVictoryEffects(token)
		end
	end

	if self.gameObjectHolder:FindFirstChild("Win") then
		self.gameObjectHolder.Win:Play()
	end
	self.isGameCurrentlyActive = false

	for _, player in self.currentGamePlayers do
		PlayerNotifications.sendToPlayer(player, `{winner.Name} won!`, nil, false)
		connect4Remotes.Cleanup:FireClient(player)
	end

	recordPlayerWin(winner.UserId, 1)

	GameTiming.scheduleReset(function()
		self:_resetGame(true)
		self.isTokenCurrentlyDropping = false
	end)
end

function Connect4GameBoard:_handleContinueOrDraw()
	if self.boardState:isBoardFull() then
		self:_handleDraw()
	else
		self:_continueGame()
	end
end

function Connect4GameBoard:_handleDraw()
	self.isGameCurrentlyActive = false

	for _, player in self.currentGamePlayers do
		if self.gameObjectHolder:FindFirstChild("Draw") then
			self.gameObjectHolder.Draw:Play()
		end
		PlayerNotifications.sendToPlayer(player, "It's a draw!", nil, false)
		connect4Remotes.Cleanup:FireClient(player)
	end

	GameTiming.scheduleReset(function()
		self:_resetGame(true)
		self.isTokenCurrentlyDropping = false
	end)
end

function Connect4GameBoard:_continueGame()
	if self.gameObjectHolder:FindFirstChild("Click") then
		self.gameObjectHolder.Click:Play()
	end
	self:_switchTurn()

	for i, player in self.currentGamePlayers do
		local isPlayerTurn = (self.activePlayerIndex == (i - 1))
		local message = isPlayerTurn and "Your turn!" or "Waiting for opponent..."
		local timeout = isPlayerTurn and GameTiming.getTurnTimeout() or nil

		PlayerNotifications.sendToPlayer(player, message, timeout, isPlayerTurn)
		CameraController.updatePlayerCamera(player, isPlayerTurn, self.gameCameraPart.CFrame)
	end

	self.timingManager:startTurnTimeout(function()
		PlayerNotifications.sendToPlayers(self.currentGamePlayers, "Turn timed out. Resetting game...")
		GameTiming.scheduleReset(function()
			self:_resetGame(true)
		end)
	end)

	GameTiming.scheduleDropCooldown(function()
		self.isTokenCurrentlyDropping = false
	end)
end

-------------------
-- Return Module --
-------------------

return Connect4GameBoard