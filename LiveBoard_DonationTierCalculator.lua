local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Configuration = ReplicatedStorage:WaitForChild("Configuration")
local GameConfig = require(Configuration.GameConfig)

local DONATION_TIER_CONFIGURATIONS = GameConfig.LIVE_DONATION_CONFIG.LEVEL_THRESHOLD_CUSTOMIZATION
local HIGH_TIER_THRESHOLD = 2

local DonationTierCalculator = {}

function DonationTierCalculator.determineTierInfo(donationAmount)
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

function DonationTierCalculator.isHighTier(tierInfo)
	return tierInfo.Level >= HIGH_TIER_THRESHOLD
end

function DonationTierCalculator.getHighTierThreshold()
	return HIGH_TIER_THRESHOLD
end

return DonationTierCalculator