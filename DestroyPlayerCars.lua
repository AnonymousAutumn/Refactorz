local function destroyPlayerCars(player)
	local cars = workspace.Debris:GetChildren()

	for _, car in cars do
		if car:GetAttribute("owner") == player.UserId then
			car:Destroy()
		end
	end
end

return destroyPlayerCars