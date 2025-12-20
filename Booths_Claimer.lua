--[[
	StandModule - Manages booth claiming and ownership.

	Features:
	- Booth claiming
	- Player positioning
	- Display population
]]

local StandModule = {}
StandModule.__index = StandModule

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local networkFolder = ReplicatedStorage.Network
local remoteEvents = networkFolder.Remotes.Events
local sendNotificationRemoteEvent = remoteEvents.CreateNotification

local modulesFolder = ReplicatedStorage.Modules
local GamepassCacheManager = require(modulesFolder.Caches.PassCache)
local FormatString = require(modulesFolder.Utilities.FormatString)
local Connections = require(modulesFolder.Wrappers.Connections)

--[[
	Creates a new StandModule instance.
]]
function StandModule.new(stand: Model, claimFunc: (Player, any) -> (), refreshEvent: RemoteEvent, claimedStands: { [Model]: any })
	local self = setmetatable({}, StandModule)
	self.Stand = stand
	self.Positioner = stand.Positioner
	self.Prompt = stand.PromptHolder.Attachment.ProximityPrompt
	self.Data = stand.DataHolder.Holder.MainFrame
	self.PassesHolder = stand.PassesHolder
	self.Owner = nil
	self.ClaimFunc = claimFunc
	self.RefreshEvent = refreshEvent
	self.ClaimedStands = claimedStands
	self.connectionsMaid = Connections.new()

	self:_connectPrompt()
	return self
end

function StandModule:_connectPrompt()
	self.Prompt.Triggered:Connect(function(player)
		if self.Owner then return end
		self.ClaimFunc(player, self)
	end)
end

function StandModule:_populateFrame(reset)
	local claimedData = self.ClaimedStands[self.Stand]
	if not claimedData then return end
	local gamepasses = claimedData.gamepasses or {}

	self.RefreshEvent:FireAllClients(self.Stand, gamepasses, reset)
end

function StandModule:_movePlayer(player)
	if not player then return end

	local character = player.Character

	if not character then return end

	local primaryPart = character.PrimaryPart

	if primaryPart then
		character:PivotTo(self.Positioner.CFrame)
	end
end

function StandModule:Populate(player)
	if not self.Owner then return end

	local displayName = player.DisplayName or player.Name
	self.Data.OwnerName.Text = `{displayName}'s Stand`

	local leaderstats = player:FindFirstChild("leaderstats")
	local raisedStat = leaderstats and leaderstats:FindFirstChild("Raised")

	if raisedStat then
		local updateRaisedDisplay = function()
			self.Data.RaisedAmount.Text = `Raised: {FormatString.formatNumberWithThousandsSeparatorCommas(raisedStat.Value)}`
		end

		self.Data.RaisedAmount.Visible = true
		updateRaisedDisplay()

		self.connectionsMaid:add(
			raisedStat:GetPropertyChangedSignal("Value"):Connect(updateRaisedDisplay)
		)
	end

	self:_populateFrame()
	self:_movePlayer(player)
end

function StandModule:Claim(player)
	self.Owner = player
	self.Stand:SetAttribute("Owner", player.Name)
	self.Prompt.Enabled = false
	self:Populate(player)
	sendNotificationRemoteEvent:FireClient(player, "Successfully claimed a booth!", "Success")
end

function StandModule:Reset()
	self.Stand:SetAttribute("Owner", "")
	self.Prompt.Enabled = true

	if self.Owner then
		self:_populateFrame(true)
	end

	self.Owner = nil
	self.Data.OwnerName.Text = "UNCLAIMED"
	self.Data.RaisedAmount.Visible = false

	self.connectionsMaid:disconnect()
end

return StandModule