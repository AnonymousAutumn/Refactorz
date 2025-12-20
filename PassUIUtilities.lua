--[[
	PassUIUtilities - Utility functions for Pass UI management.

	Provides safe child waiting, UI clearing, and scroll frame reset helpers.
]]

local PassUIUtilities = {}

--[[
	Safely waits for a child instance with timeout and error handling.
	Returns nil if the child is not found within the timeout.
]]
function PassUIUtilities.safeWaitForChild(parent: Instance, childName: string, timeout: number?): Instance?
	local success, result = pcall(function()
		return parent:WaitForChild(childName, timeout or 5)
	end)

	if success then
		return result
	end

	warn(`[{script.Name}] Failed to find child: {childName} in {parent:GetFullName()}`)
	return nil
end

--[[
	Destroys all children of a specific class from a container.
	Returns the number of children removed.
]]
function PassUIUtilities.clearChildrenOfClass(container: Instance, className: string): number
	local removedCount = 0
	local children = container:GetChildren()

	for i = 1, #children do
		local child = children[i]
		if child:IsA(className) then
			child:Destroy()
			removedCount += 1
		end
	end

	return removedCount
end

--[[
	Resets a gamepass scroll frame by removing all TextButtons and resetting scroll position.
	Returns the number of buttons removed.
]]
function PassUIUtilities.resetGamepassScrollFrame(scrollFrame: ScrollingFrame?): number
	if not scrollFrame or not scrollFrame:IsA("ScrollingFrame") then
		warn(`[{script.Name}] Invalid scroll frame for reset`)
		return 0
	end

	local removedCount = PassUIUtilities.clearChildrenOfClass(scrollFrame, "TextButton")
	scrollFrame.CanvasPosition = Vector2.zero

	return removedCount
end

return PassUIUtilities