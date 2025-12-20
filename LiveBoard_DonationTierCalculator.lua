--[[
	DonationTierCalculator - Determines donation tier based on amount.

	Features:
	- Tier threshold lookup
	- High tier detection
	- Tier configuration access
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Configuration = ReplicatedStorage:WaitForChild("Configuration")
local GameConfig = require(Configuration.GameConfig)

local DONATION_TIER_CONFIGURATIONS = GameConfig.LIVE_DONATION_CONFIG.LEVEL_THRESHOLD_CUSTOMIZATION
local HIGH_TIER_THRESHOLD = 2

local DonationTierCalculator = {}

--[[
	Determines the tier info for a donation amount.
]]
function DonationTierCalculator.determineTierInfo(donationAmount: number): any
	for tierLevel = #DONATION_TIER_CONFIGURATIONS, 1, -1 do
		local tierConfiguration = DONATION_TIER_CONFIGURATIONS[tierLevel]
		if donationAmount >= tierConfiguration.Threshold then
			return {
				Level = tierLevel,
				Lifetime = tierConfiguration.Lifetime,
				Color = tierConfiguration.Color,
			}
		end
	end

	local lowest = DONATION_TIER_CONFIGURATIONS[1]
	return {
		Level = 1,
		Lifetime = lowest.Lifetime,
		Color = lowest.Color,
	}
end

--[[
	Checks if a tier qualifies as high tier.
]]
function DonationTierCalculator.isHighTier(tierInfo: any): boolean
	return tierInfo.Level >= HIGH_TIER_THRESHOLD
end

--[[
	Gets the high tier threshold level.
]]
function DonationTierCalculator.getHighTierThreshold(): number
	return HIGH_TIER_THRESHOLD
end

return DonationTierCalculator