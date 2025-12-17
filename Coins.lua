-----------------
-- Init Module --
-----------------

local CoinsModule = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------
-- References --
----------------

local networkFolder = ReplicatedStorage.Network
local remoteEvents = networkFolder.Remotes.Events
local createCoinsEvent = remoteEvents.CreateCoins

---------------
-- Functions --
---------------

function CoinsModule.SpawnCoins(donor, receiver, amount)
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

function CoinsModule.SpawnCoinsFromPart(part, receiver, amount)
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

-------------------
-- Return Module --
-------------------

return CoinsModule