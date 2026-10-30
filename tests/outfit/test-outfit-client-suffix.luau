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
print("PASS: " .. checks .. " total behavior checks including pagination and request races")
