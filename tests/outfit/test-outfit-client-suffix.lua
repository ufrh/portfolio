local controller = registry.CatalogController
local messages, rendered = {}, {}
controller.view = {
	items = {}, clear = function() end,
	message = function(_, text) table.insert(messages, text) end
}
controller.cards = {}
controller.notice = {}
controller.updatePage = function() end
controller.render = function(_, items) table.insert(rendered, items) end
controller.generation = 0
controller.category = "Clothing"
controller.subcategory = 1
controller.sort = 1
controller.query = "old"
controller.state = {outfits = {}, favorites = {}, recents = {}}
local catalogCalls = {}
function editor:SearchCatalogAsync(params)
	table.insert(catalogCalls, params.SearchKeyword)
	local index = 1
	local pages = {IsFinished = false}
	function pages:GetCurrentPage() return {{Id = if index == 1 then 100 else 101, Name = params.SearchKeyword, AssetType = "Shirt"}} end
	function pages:AdvanceToNextPageAsync()
		if self.fail then error("network error") end
		index += 1
		self.IsFinished = true
	end
	return pages
end
controller:load()
controller.query = "new"
controller:load()
flush()
expect(#rendered == 1 and rendered[1][1].name == "new", "stale search response ignored")
expect(controller.page == 1 and not controller.loading, "search begins on page one")
controller.pages.fail = true
controller:changePage(1)
flush()
expect(controller.page == 1 and not controller.loading, "failed pagination keeps current page")
controller.pages.fail = false
controller:changePage(1)
flush()
expect(controller.page == 2 and rendered[#rendered][1].id == 101, "next page loaded")
controller:changePage(-1)
expect(controller.page == 1 and rendered[#rendered][1].id == 100, "previous uses cached page")
controller:changePage(1)
controller:changePage(1)
expect(controller.page == 2, "finished pagination does not overrun")
controller.pages.IsFinished = false
controller:changePage(1)
controller.category = "Recents"
controller.query = ""
controller.state.recents = {{id = 200, itemType = "Asset", name = "Hat", category = "Accessories"}}
controller:load()
flush()
expect(controller.page == 1 and rendered[#rendered][1].id == 200, "old page fetch cannot overwrite new category")
controller.category = "Starred"
controller:load()
flush()
expect(#rendered[#rendered] == 0 and controller.page == 1, "empty favorites render safely")
controller.category = "Recents"
controller.subcategory = 2
controller:load()
flush()
expect(#rendered[#rendered] == 0, "library subcategory filters items")
controller.category = "Clothing"
controller.subcategory = 1
function editor:SearchCatalogAsync() error("API down") end
controller:load()
flush()
expect(not controller.loading and string.find(messages[#messages], "retry"), "catalog error exposes retry")
local rotationBase = setmetatable({}, {__mul = function(_, angle) return angle end})
environment.CFrame = {Angles = function(_, angle) return angle end}
controller.rotation = 0
controller.hrpPosition = {WorldCFrame = {Rotation = rotationBase}}
controller.state = {revision = 1, equipped = {}}
controller:updatePreview()
expect(controller.preview == first.Character, "creator uses actual player character")
expect(not first.Character.HumanoidRootPart.Anchored, "client leaves root physics-driven")
controller:setRotation(1.25)
expect(first.Character.HumanoidRootPart:FindFirstChild("OutfitOrientation").CFrame == 1.25, "rotation updates AlignOrientation target")
local mouse = {UserInputType = "MouseButton1", Position = {X = 100}}
controller:beginDrag(mouse, false)
controller:drag({UserInputType = "MouseMovement", Position = {X = 140}})
expect(math.abs(controller.rotation - .85) < .001, "mouse drag rotates through AlignOrientation")
controller:endDrag(mouse)
expect(controller.dragInput == nil, "rotation drag ends cleanly")
controller:beginDrag(mouse, true)
expect(controller.dragInput == nil, "UI interactions do not begin rotation drag")
local previous = controller.preview
modules.Character.constrain(second.Character, hrpPosition)
first.Character = second.Character
controller.state.revision = 2
controller:updatePreview()
expect(controller.preview == second.Character and not previous.destroyed, "replacement character is bound without destroying old model")
local active = first.Character
first.Character = nil
controller.state.revision = 3
controller:updatePreview()
expect(controller.preview == active, "missing character does not crash UI refresh")
first.Character = active
controller:updatePreview()
expect(controller.previewRevision == 3, "late character can refresh successfully")
local render, priority
function services.RunService:BindToRenderStep(_, value, callback) priority, render = value, callback end
EnumMock.RenderPriority = {Camera = {Value = 200}}
EnumMock.CameraType = {Scriptable = "Scriptable"}
environment.workspace.CurrentCamera = {CameraType = "Custom", CFrame = 12}
local camLock = {WorldCFrame = 50}
controller:lockCamera(camLock)
expect(environment.workspace.CurrentCamera.CFrame == 50, "camera moves to attachment immediately")
expect(environment.workspace.CurrentCamera.CameraType == "Scriptable" and priority == 201, "camera overrides default camera update")
camLock.WorldCFrame = 99
render()
expect(environment.workspace.CurrentCamera.CFrame == 99, "camera follows attachment WorldCFrame")
environment.workspace.CurrentCamera = {}
render()
expect(environment.workspace.CurrentCamera.CFrame == 99, "replacement camera inherits attachment lock")
print("PASS: " .. checks .. " total behavior checks including character movement locks and camera lock")
