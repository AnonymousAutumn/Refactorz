--[[
	DonationEffect - Client-side coin visual effects for donations.

	Features:
	- Coin spawning and animation
	- Particle effects on spawn/pickup
	- Smooth tracking to target player
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local debrisFolder = workspace.Debris

local networkFolder = ReplicatedStorage.Network
local remoteEvents = networkFolder.Remotes.Events
local createCoinsRemoteEvent = remoteEvents.CreateCoins

local instancesFolder = ReplicatedStorage.Instances
local objectsFolder = instancesFolder.Objects
local effectsFolder = instancesFolder.Effects
local coinPrefab = objectsFolder.Coin

local LERP_SPEED_MIN = 0.08
local LERP_SPEED_MAX = 0.25
local LERP_DISTANCE_MAX = 50
local VELOCITY_PREDICTION = 0.15

local coins = {}
local spawnQueue = {}

local function spawnEffect(name: string, position: Vector3): Part?
	local template = effectsFolder:FindFirstChild(name, true)
	if not template then return end

	local maxDistance = template:GetAttribute("distance")
	if maxDistance then
		local camera = workspace.CurrentCamera
		if camera and (position - camera.CFrame.Position).Magnitude > maxDistance then
			return
		end
	end

	local effect = template:Clone()
	effect.Position = position
	effect.Parent = debrisFolder

	local maxLifetime = 0

	for _, child in pairs(effect:GetDescendants()) do
		if child:IsA("ParticleEmitter") then
			local emitCount = child:GetAttribute("emit")
			local life = child:GetAttribute("life") or 0

			if emitCount then
				child:Emit(emitCount)
				child.Rate = 0
			end

			local totalLife = life + child.Lifetime.Max
			maxLifetime = math.max(maxLifetime, totalLife)

		elseif child:IsA("Sound") then
			local variation = child:GetAttribute("variation")
			if variation then
				child.PlaybackSpeed *= 1 + (math.random() - 0.5) * 2 * variation
			end
			child:Play()

			local soundLength = child.TimeLength / child.PlaybackSpeed
			maxLifetime = math.max(maxLifetime, soundLength)
		end
	end

	Debris:AddItem(effect, math.max(maxLifetime + 0.5, 2))

	return effect
end

local function getTargetInfo(userId: number): (Vector3?, Vector3?)
	local player = Players:GetPlayerByUserId(userId)
	if not player then return nil, nil end

	local character = player.Character
	local root = character and character.PrimaryPart
	if not root then return nil, nil end

	return root.Position, root.AssemblyLinearVelocity
end

local function spawnCoin(position: Vector3, targetUserId: number)
	local coin = coinPrefab:Clone()
	coin.CFrame = CFrame.new(position)
	coin.Anchored = true
	coin.CanCollide = false
	coin.Parent = workspace

	local angle = math.random() * math.pi * 2
	local burstOffset = Vector3.new(math.cos(angle) * 3, 4, math.sin(angle) * 3)

	table.insert(coins, {
		instance = coin,
		mesh = coin:FindFirstChild("Mesh"),
		position = position,
		burstTarget = position + burstOffset,
		angle = math.random() * math.pi * 2,
		targetUserId = targetUserId,
		phase = "burst",
		burstProgress = 0,
	})

	spawnEffect("CoinSpawn", position)
end

local function update(dt: number)
	local now = tick()
	for i = #spawnQueue, 1, -1 do
		local queued = spawnQueue[i]
		if now >= queued.time then
			spawnCoin(queued.pos, queued.targetUserId)
			table.remove(spawnQueue, i)
		end
	end

	local instances, cframes = {}, {}

	for i = #coins, 1, -1 do
		local coin = coins[i]
		coin.angle += dt * 5

		if coin.phase == "burst" then

			coin.burstProgress += dt * 3
			coin.position = coin.position:Lerp(coin.burstTarget, 0.2)

			if coin.burstProgress >= 1 then
				coin.phase = "track"
			end
		else

			local targetPos, targetVel = getTargetInfo(coin.targetUserId)

			if targetPos then

				local predictedPos = targetPos + (targetVel or Vector3.zero) * VELOCITY_PREDICTION

				local distance = (coin.position - predictedPos).Magnitude
				local t = math.clamp(distance / LERP_DISTANCE_MAX, 0, 1)
				local lerpSpeed = LERP_SPEED_MIN + (LERP_SPEED_MAX - LERP_SPEED_MIN) * t

				coin.position = coin.position:Lerp(predictedPos, lerpSpeed)

				if (coin.position - targetPos).Magnitude < 2 then
					spawnEffect("PickupFx", coin.position)
					coin.instance:Destroy()
					table.remove(coins, i)
					continue
				end
			else

				coin.instance:Destroy()
				table.remove(coins, i)
				continue
			end
		end

		if coin.mesh then
			local cf = CFrame.new(coin.position + Vector3.new(0, 2, 0))
				* CFrame.fromEulerAnglesYXZ(math.rad(90), coin.angle, 0)
			table.insert(instances, coin.mesh)
			table.insert(cframes, cf)
		end
	end

	if #instances > 0 then
		workspace:BulkMoveTo(instances, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

createCoinsRemoteEvent.OnClientEvent:Connect(function(data: any)
	table.insert(spawnQueue, {
		pos = data.pos,
		time = tick() + (data.delay or 0),
		targetUserId = data.targetUserId,
	})
end)

RunService.Heartbeat:Connect(update)