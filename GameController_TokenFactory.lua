-----------------
-- Init Module --
-----------------

local TokenFactory = {}

--------------
-- Services --
--------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

----------------
-- References --
----------------

local instancesFolder = ReplicatedStorage.Instances
local objectsFolder = instancesFolder.Objects
local tokenPrefab = objectsFolder.Token

---------------
-- Constants --
---------------

local CONFIG = {
	TOKEN = {
		DROP_HEIGHT_OFFSET = 10,
		SIZE = Vector3.new(0.1, 0.9 * 0.9, 3),
	},
	ANIMATION = {
		DROP = TweenInfo.new(0.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
	},
	TEAMS = {
		[0] = "Bright red",
		[1] = "Gold",
	},
}

---------------
-- Functions --
---------------

local function getTeamColor(teamIndex)
	return CONFIG.TEAMS[teamIndex] or CONFIG.TEAMS[0]
end

function TokenFactory.createToken(container, config)
	if not config.triggerPosition then
		return nil
	end

	local token = tokenPrefab:Clone()
	token.Parent = container

	local finalY = config.basePlateYPosition + (config.row - 1) * config.tokenHeight
	local startY = finalY + CONFIG.TOKEN.DROP_HEIGHT_OFFSET

	token.Size = CONFIG.TOKEN.SIZE
	token.Position = Vector3.new(config.triggerPosition.X, startY, config.triggerPosition.Z)
	token.BrickColor = BrickColor.new(getTeamColor(config.teamIndex))

	if config.boardRotation then
		token.Rotation = Vector3.new(0, config.boardRotation.Y, 0)
	end

	local finalPosition = Vector3.new(config.triggerPosition.X, finalY, config.triggerPosition.Z)
	local tween = TweenService:Create(token, CONFIG.ANIMATION.DROP, { Position = finalPosition })
	tween:Play()

	return token
end

function TokenFactory.applyVictoryEffects(token)
	token.Material = Enum.Material.Neon
	token.Transparency = 0.25
end

-------------------
-- Return Module --
-------------------

return TokenFactory