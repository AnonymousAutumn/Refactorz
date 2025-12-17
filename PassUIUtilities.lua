-----------------
-- Module Init --
-----------------

local PassUIUtilities = {}

---------------
-- Functions --
---------------

function PassUIUtilities.safeWaitForChild(parent, childName, timeout)
	local success, result = pcall(function()
		return parent:WaitForChild(childName, timeout or 5)
	end)
	if success then
		return result
	end
	
	warn(`[{script.Name}] Failed to find child: {childName} in {parent:GetFullName()}`)
	
	return nil
end

function PassUIUtilities.clearChildrenOfClass(container, className)
	local removedCount = 0
	local children = container:GetChildren()
	
	for i = 1, #children do
		local child = children[i]
		if child:IsA(className) then
			child:Destroy()
			removedCount = removedCount + 1
		end
	end
	
	return removedCount
end

function PassUIUtilities.resetGamepassScrollFrame(scrollFrame)
	if not scrollFrame or not scrollFrame:IsA("ScrollingFrame") then
		warn(`[{script.Name}] Invalid scroll frame for reset`)
		return 0
	end
	
	local removedCount = PassUIUtilities.clearChildrenOfClass(scrollFrame, "TextButton")
	scrollFrame.CanvasPosition = Vector2.zero
	
	return removedCount
end

-------------------
-- Return Module --
-------------------

return PassUIUtilities