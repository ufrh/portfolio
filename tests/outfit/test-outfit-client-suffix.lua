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
environment.CFrame = {Angles = function() return 1 end}
controller.rigPivot, controller.rotation, controller.previewGeneration = 1, 0, 0
controller.showroomRig = {GetDescendants = function() return {} end, FindFirstChild = function() return nil end}
local clonedModels = {}
local failRig = false
controller.rigTemplate = {Clone = function()
	local model = {HumanoidRootPart = {}, DescendantAdded = signal()}
	function model:PivotTo() end
	function model:GetDescendants() return {} end
	function model:FindFirstChild() return nil end
	function model:Destroy() self.destroyed = true end
	model.Humanoid = {ApplyDescriptionAsync = function(_, description)
		if failRig then error("Engine rejected appearance") end
		model.appliedShirt = description.Shirt
	end}
	table.insert(clonedModels, model)
	return model
end}
controller.state = {avatar = avatar(call(first, "getState")), revision = 1}
controller:updatePreview()
flush()
local preview = controller.preview
expect(preview == clonedModels[1] and preview.appliedShirt ~= nil, "preview uses authored rig clone")
controller.state.revision = 2
failRig = true
controller:updatePreview()
flush()
expect(controller.preview == preview and not preview.destroyed, "failed rig update retains visible look")
expect(clonedModels[2].destroyed and controller.previewRevision == nil, "failed rig update is cleaned up and retryable")
failRig = false
controller:updatePreview()
flush()
expect(preview.destroyed and controller.preview == clonedModels[3], "successful retry replaces old rig")
preview = controller.preview
controller.state.revision = 3
controller:updatePreview()
controller.previewGeneration += 1
flush()
expect(controller.preview == preview and clonedModels[4].destroyed, "stale rig update cannot replace preview")
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
print("PASS: " .. checks .. " total behavior checks including rig previews and camera lock")
