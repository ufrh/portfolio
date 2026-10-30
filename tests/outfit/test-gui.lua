local function screen(name, mounted)
	local gui = {Name = name, attributes = {OutfitMounted = mounted}, ResetOnSpawn = true}
	function gui:IsA(class) return class == "ScreenGui" end
	function gui:GetAttribute(key) return self.attributes[key] end
	function gui:SetAttribute(key, value) self.attributes[key] = value end
	function gui:Destroy() self.destroyed = true end
	function gui:Clone() return screen(self.Name) end
	return gui
end
local function guiContainer(children)
	local callback
	local container = {children = children}
	function container:GetChildren() return self.children end
	container.ChildAdded = {Connect = function(_, value)
		callback = value
		return {Disconnect = function() end}
	end}
	function container:add(child) table.insert(self.children, child); callback(child) end
	return container
end
local owned, duplicate, other = screen("Catalog", true), screen("Catalog"), screen("OtherGui")
local container = guiContainer({duplicate, owned, other})
local mounted = modules.Gui.mount(container, screen("Catalog"))
expect(mounted == owned and duplicate.destroyed, "existing duplicate catalog removed while mounted UI is preserved")
expect(not other.destroyed, "unrelated screen is preserved")
expect(mounted.ResetOnSpawn == false, "mounted catalog survives character loading")
local automatic = screen("Catalog")
container:add(automatic)
expect(automatic.destroyed and not mounted.destroyed, "late automatic StarterGui copy is removed")
container:add(mounted)
expect(not mounted.destroyed, "mount never deletes its own catalog")
local empty = guiContainer({})
local created = modules.Gui.mount(empty, screen("Catalog"))
expect(created.Parent == empty and created:GetAttribute("OutfitMounted"), "empty PlayerGui gets one owned catalog")
local later = screen("Catalog")
empty:add(later)
expect(later.destroyed, "manual clone wins race against subsequent character GUI copy")
