--[[
	CoinsModule - Spawns visual coin effects.

	Features:
	- Coin spawning from player
	- Coin spawning from part
]]

local CoinsModule = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local networkFolder = ReplicatedStorage.Network
local remoteEvents = networkFolder.Remotes.Events
local createCoinsEvent = remoteEvents.CreateCoins

--[[
	Spawns coins from a donor player to a receiver.
]]
function CoinsModule.SpawnCoins(donor: Player, receiver: Player, amount: number)
	local donorChar = donor.Character
	local donorRoot = donorChar and donorChar.PrimaryPart
	if not donorRoot then return end

	local spawnDelay = math.min(amount * 0.05, 0.5) / math.max(amount, 1)

	for i = 0, amount - 1 do
		createCoinsEvent:FireClient(receiver, {
			pos = donorRoot.Position,
			delay = i * spawnDelay,
			targetUserId = receiver.UserId,
		})
	end
end

--[[
	Spawns coins from a part to a receiver.
]]
function CoinsModule.SpawnCoinsFromPart(part: BasePart, receiver: Player, amount: number)
	if not part then return end

	local spawnDelay = math.min(amount * 0.05, 0.5) / math.max(amount, 1)

	for i = 0, amount - 1 do
		createCoinsEvent:FireClient(receiver, {
			pos = part.Position,
			delay = i * spawnDelay,
			targetUserId = receiver.UserId,
		})
	end
end

return CoinsModule