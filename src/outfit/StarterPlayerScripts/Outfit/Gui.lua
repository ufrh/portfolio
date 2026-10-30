local Gui = {} do
	function Gui.mount(playerGui, template)
		local gui
		for _, child in playerGui:GetChildren() do
			if (child:IsA("ScreenGui") and child.Name == "Catalog") then
				if (not gui or child:GetAttribute("OutfitMounted")) then gui = child end
			end
		end
		gui = gui or template:Clone()
		gui.ResetOnSpawn = false
		gui:SetAttribute("OutfitMounted", true)
		local function removeDuplicate(child)
			if (child ~= gui and child:IsA("ScreenGui") and child.Name == "Catalog") then child:Destroy() end
		end
		local connection = playerGui.ChildAdded:Connect(removeDuplicate)
		for _, child in playerGui:GetChildren() do removeDuplicate(child) end
		gui.Parent = playerGui
		return gui, connection;
	end
end return Gui;
