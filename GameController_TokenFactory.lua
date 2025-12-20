--[[
	TokenFactory - Creates and animates game tokens.

	Features:
	- Token instantiation
	- Drop animation
	- Victory effects
]]

local TokenFactory = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local instancesFolder = ReplicatedStorage.Instances
local objectsFolder = instancesFolder.Objects
local tokenPrefab = objectsFolder.Token

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

local function getTeamColor(teamIndex: number): string
	return CONFIG.TEAMS[teamIndex] or CONFIG.TEAMS[0]
end

--[[
	Creates a token and animates its drop.
]]
function TokenFactory.createToken(container: Instance, config: any): BasePart?
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

--[[
	Applies visual effects to winning tokens.
]]
function TokenFactory.applyVictoryEffects(token: BasePart)
	token.Material = Enum.Material.Neon
	token.Transparency = 0.25
end

return TokenFactory