local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AvatarEditorService = game:GetService("AvatarEditorService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

local FORGE = require(ReplicatedStorage:WaitForChild("FORGE"))
local Shared = ReplicatedStorage:WaitForChild("OutfitShared")
local Catalog = require(Shared.Catalog)
local Character = require(Shared.Character)
local View = require(script.Parent.Parent.Outfit.View)
local Gui = require(script.Parent.Parent.Outfit.Gui)

local CatalogController = FORGE.Class("Controller", {Name = "CatalogController"}) do
	local player = Players.LocalPlayer

	function CatalogController:notify(text: string)
		self.notice.Text = text
	end

	function CatalogController:request(method: string, ...)
		if (self.busy) then self:notify("Your previous change is still loading."); return false end
		self.busy = true
		self:notify("Loading...")
		local arguments = table.pack(...)
		local success, result = pcall(function()
			return self.service[method](self.service, table.unpack(arguments, 1, arguments.n));
		end)
		self.busy = false
		if (not success or type(result) ~= "table" or not result.ok) then
			self:notify(if (success and type(result) == "table") then result.message else "Connection failed. Try again.")
			return false;
		end
		local decoded, reason = pcall(function()
			for _, key in {"avatar", "equipped", "favorites", "recents", "outfits"} do
				result[key] = HttpService:JSONDecode(result[key .. "JSON"])
			end
		end)
		if (not decoded) then warn("[Catalog] " .. tostring(reason)); self:notify("Couldn't read the response. Try again."); return false end
		self.state = result
		self:renderEquipped()
		self:updateSelection()
		self:updatePreview()
		self:notify("Try on an item · ☆ to star · saved items last this session")
		return true;
	end

	function CatalogController:updateSelection()
		if (not self.state) then return end
		local equipped, favorites = {}, {}
		for _, item in self.state.equipped do equipped[Catalog.key(item)] = true end
		for _, item in self.state.favorites do favorites[Catalog.key(item)] = true end
		for _, card in self.cards do
			if (card.frame.Parent) then
				local key = Catalog.key(card.item)
				card.frame.Preview.SelectionBadge.Visible = equipped[key] == true or self.state.selected == key
				local star = card.frame.Preview:FindFirstChild("Favorite")
				if (star) then star.Text = if (favorites[key]) then "★" else "☆" end
			end
		end
	end

	function CatalogController:activate(item)
		local success
		if (item.itemType == "SavedOutfit" or item.itemType == "RobloxOutfit") then
			success = self:request("applyOutfit", item.id, item.itemType)
		else success = self:request("toggleItem", item.id, item.itemType) end
		if (success) then self:playMotion(item) end
	end

	function CatalogController:render(items)
		self.view:clear(self.view.items)
		self.cards = {}
		self.view.items.CanvasPosition = Vector2.zero
		self.view:message(if (#items == 0) then "Nothing here yet. Try another search or category." else "")
		for index, item in items do
			local favorite, removeSaved
			if (item.itemType ~= "SavedOutfit") then
				favorite = function()
					if (self:request("toggleFavorite", item.id, item.itemType) and self.category == "Starred") then self:load() end
				end
			else
				removeSaved = function()
					if (self:request("deleteOutfit", item.id)) then self:load() end
				end
			end
			local frame = self.view:card(item, index, function() self:activate(item) end, favorite, removeSaved)
			table.insert(self.cards, {frame = frame, item = item})
		end
		self:updateSelection()
		self:updatePage()
	end

	function CatalogController:updatePage()
		local total = #self.pageCache
		local canNext = self.page < total or (self.pages and not self.pages.IsFinished)
		self.view.inner.Page.Text = self.page .. " / " .. math.max(total, 1) .. (if (canNext and self.page == total) then "+" else "")
		self.previous.Active = self.page > 1 and not self.loading
		self.next.Active = canNext == true and not self.loading
		self.view.inner.Page.Previous.Header.TextTransparency = if (self.previous.Active) then 0 else .6
		self.view.inner.Page.Next.Header.TextTransparency = if (self.next.Active) then 0 else .6
	end

	function CatalogController:localItems()
		local state = self.state or {outfits = {}, favorites = {}, recents = {}}
		local source = if (self.category == "Outfits") then state.outfits
			elseif (self.category == "Starred") then state.favorites else state.recents
		local filter = Catalog.subcategories[self.category][self.subcategory].name
		local query = string.lower(self.query)
		local items = {}
		for _, item in source do
			if ((filter == "All" or filter == "My Outfits" or item.category == filter)
				and string.find(string.lower(item.name), query, 1, true)) then table.insert(items, item) end
		end
		local sort = Catalog.sorts[self.sort].value
		if (sort == "PriceLowToHigh" or sort == "PriceHighToLow") then
			table.sort(items, function(a, b)
				local first, second = a.price or 0, b.price or 0
				if (first == second) then return a.id < b.id end
				return if (sort == "PriceLowToHigh") then first < second else first > second;
			end)
		end
		return items;
	end

	function CatalogController:load()
		self.generation += 1
		local generation = self.generation
		self.page, self.pageCache, self.pages = 1, {}, nil
		self.loading = true
		self:updatePage()
		self.view:clear(self.view.items)
		self.cards = {}
		self.view:message("Loading items...")
		local category = self.category
		local subcategory = self.subcategory
		local query, sort = self.query, self.sort
		task.spawn(function()
			local localList = category == "Starred" or category == "Recents"
				or (category == "Outfits" and subcategory == 1)
			local success, result = pcall(function()
				if (localList) then return self:localItems() end
				if (category == "Outfits") then
					return AvatarEditorService:GetOutfitsAsync(Enum.OutfitSource.All, Enum.OutfitType.Avatar);
				end
				return AvatarEditorService:SearchCatalogAsync(Catalog.searchParams(category, subcategory, query, sort));
			end)
			if (generation ~= self.generation or self.stopped) then return end
			self.loading = false
			if (not success) then
				warn("[Catalog] " .. tostring(result))
				local message = if (category == "Outfits") then "Couldn't read your Roblox outfits.\nUse ALLOW ACCESS below, then tap here to retry."
					else "Couldn't load the catalog.\nTap here to retry."
				self.view:message(message, function() self:load() end)
				self:updatePage()
				return;
			end
			if (localList) then
				for offset = 1, math.max(#result, 1), Catalog.pageSize do
					local page = {}
					for index = offset, math.min(offset + Catalog.pageSize - 1, #result) do table.insert(page, result[index]) end
					table.insert(self.pageCache, page)
				end
			else
				self.pages = result
				self.pageCache[1] = self:normalizePage(result:GetCurrentPage())
			end
			self:render(self.pageCache[1])
		end)
	end

	function CatalogController:normalizePage(rawItems)
		local items = {}
		for _, raw in rawItems do
			if (self.category == "Outfits") then
				local name = raw.Name or raw.name or "Roblox outfit"
				if (string.find(string.lower(name), string.lower(self.query), 1, true)) then
					table.insert(items, {id = raw.Id or raw.id, itemType = "RobloxOutfit", name = name, creator = "Roblox outfit", category = "Outfits"})
				end
			else table.insert(items, Catalog.normalize(raw)) end
		end
		return items;
	end

	function CatalogController:changePage(direction: number)
		if (self.loading) then return end
		local target = self.page + direction
		if (target < 1) then return end
		if (self.pageCache[target]) then self.page = target; self:render(self.pageCache[target]); return end
		if (not self.pages or self.pages.IsFinished) then return end
		self.loading = true
		self:updatePage()
		local generation, pages = self.generation, self.pages
		task.spawn(function()
			local success, reason = pcall(function() pages:AdvanceToNextPageAsync() end)
			if (generation ~= self.generation or self.stopped) then return end
			self.loading = false
			if (not success) then self:notify("Couldn't load the next page. Try NEXT again."); self:updatePage(); return end
			self.page = target
			self.pageCache[target] = self:normalizePage(pages:GetCurrentPage())
			self:render(self.pageCache[target])
		end)
	end

	function CatalogController:chooseCategory(category: string)
		self.category, self.subcategory = category, 1
		self.view:clear(self.view.subcategories)
		self.view.subcategories.CanvasPosition = Vector2.zero
		for _, frame in self.view.inner.Category.ScrollingFrame:GetChildren() do
			if (frame:IsA("Frame")) then self.view:select(frame, frame.Name == category) end
		end
		local tabs = {}
		for index, entry in Catalog.subcategories[category] do
			local tab = self.view.templates.SubCategory:Clone() do
				tab.Name = entry.name:gsub("[^%w]", "")
				tab.Header.Text = string.upper(entry.name)
				tab.Size = UDim2.fromOffset(math.max(76, #entry.name * 9 + 24), 28)
				tab.LayoutOrder = index
				tab.Parent = self.view.subcategories
			end
			tabs[index] = tab
			self.view:select(tab, index == 1)
			self.view:button(tab, "Select", function()
				self.subcategory = index
				for selected, other in tabs do self.view:select(other, selected == index) end
				self.allowAccess.Visible = category == "Outfits" and index == 2
				self:load()
			end)
		end
		self.allowAccess.Visible = false
		self:load()
	end

	function CatalogController:renderEquipped()
		self.view:clear(self.view.equipped)
		for index, item in self.state.equipped do
			local frame = self.view.templates.ItemEquipped:Clone() do
				frame.Name = "Equipped_" .. item.id
				frame.LayoutOrder = index
				frame.Parent = self.view.equipped
			end
			self.view:thumbnail(frame, item)
			local remove = self.view:button(frame, "Remove", function() self:request("removeItem", item.id) end)
			local label = Instance.new("TextLabel") do
				label.Name = "ItemName"
				label.Text = item.name .. " · ×"
				label.TextSize = 10
				label.FontFace = self.view.inner.Search.TextBox.FontFace
				label.TextColor3 = remove.TextColor3
				label.BackgroundTransparency = .2
				label.BackgroundColor3 = self.view.inner.BackgroundColor3
				label.Size = UDim2.new(1, 0, 0, 20)
				label.Position = UDim2.new(0, 0, 1, -20)
				label.TextTruncate = Enum.TextTruncate.AtEnd
				label.ZIndex = 11
				label.Parent = frame
			end
		end
	end

	function CatalogController:updatePreview()
		local model = player.Character
		if (not self.state or not model) then return end
		if (self.preview == model and self.previewRevision == self.state.revision) then return end
		self.rigPivot = self.state.creatorPivot
		if (not self.rigPivot or not Character.lock(model, self.rigPivot * CFrame.Angles(0, self.rotation, 0))) then return end
		self.preview, self.previewRevision = model, self.state.revision
		if (self.previewTrack) then self.previewTrack:Stop(.15); self.previewTrack = nil end
	end

	function CatalogController:playMotion(item)
		local model = player.Character
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if (not humanoid or not item.assetType) then return end
		local worn = false
		for _, equipped in self.state.equipped do
			if (equipped.id == item.id) then worn = true; break end
		end
		if (not worn) then return end
		if (item.assetType == "EmoteAnimation") then
			pcall(function() humanoid:PlayEmoteAsync("Emote" .. item.id) end)
			return;
		end
		if (not string.match(item.assetType, "Animation$")) then return end
		local animate = model:FindFirstChild("Animate")
		local name = string.lower(string.gsub(item.assetType, "Animation$", ""))
		local folder = animate and animate:FindFirstChild(name)
		local template = folder and folder:FindFirstChildWhichIsA("Animation")
		local animation = if (template) then template:Clone() else Instance.new("Animation")
		if (not template) then animation.AnimationId = "rbxassetid://" .. item.id end
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if (animator) then
			pcall(function()
				self.previewTrack = animator:LoadAnimation(animation)
				self.previewTrack.Priority = Enum.AnimationPriority.Action
				self.previewTrack.Looped = true
				self.previewTrack:Play(.15)
			end)
		end
		animation:Destroy()
	end

	function CatalogController:saveDialog()
		if (self.dialog) then self.dialog:Destroy(); self.dialog = nil; return end
		local dialog = Instance.new("Frame") do
			dialog.Name = "SaveOutfit"
			dialog.Size = UDim2.fromOffset(330, 120)
			dialog.Position = UDim2.fromOffset(200, 610)
			dialog.BackgroundColor3 = self.view.inner.BackgroundColor3
			dialog.ZIndex = 30
			dialog.Parent = self.view.canvas
		end
		local stroke = Instance.new("UIStroke")
		stroke.Color = self.view.inner.Header.TextColor3
		stroke.Parent = dialog
		local input = self.view.inner.Search.TextBox:Clone() do
			input.Name = "OutfitName"
			input.Size = UDim2.new(1, -24, 0, 40)
			input.Position = UDim2.fromOffset(12, 8)
			input.PlaceholderText = "Outfit name (saved this session)"
			input.Text = ""
			input.ZIndex = 31
			input.Parent = dialog
		end
		local save = self.view:button(dialog, "Save", function()
			if (self:request("saveOutfit", Catalog.text(input.Text, 40))) then
				dialog:Destroy()
				self.dialog = nil
				self:notify("Outfit saved for this session.")
				if (self.category == "Outfits") then self:load() end
			end
		end, "SAVE")
		save.Size = UDim2.fromOffset(130, 40)
		save.Position = UDim2.fromOffset(12, 65)
		save.ZIndex = 32
		local cancel = self.view:button(dialog, "Cancel", function() dialog:Destroy(); self.dialog = nil end, "CANCEL")
		cancel.Size = UDim2.fromOffset(130, 40)
		cancel.Position = UDim2.fromOffset(180, 65)
		cancel.ZIndex = 32
		self.dialog = dialog
		input:CaptureFocus()
	end

	function CatalogController:lockCamera(camLock: Attachment)
		local camera = workspace.CurrentCamera
		self.previousCamera = {kind = camera.CameraType, cframe = camera.CFrame}
		self.cameraKey = "OutfitCreatorCamera"
		local function update()
			local current = workspace.CurrentCamera
			if (current) then
				current.CameraType = Enum.CameraType.Scriptable
				current.CFrame = camLock.WorldCFrame
			end
		end
		RunService:BindToRenderStep(self.cameraKey, Enum.RenderPriority.Camera.Value + 1, update)
		update()
	end

	function CatalogController:Start()
		self.generation, self.previewGeneration = 0, 0
		self.rotation = 0
		self.query, self.sort, self.category, self.subcategory = "", 1, "Clothing", 1
		self.cards, self.pageCache, self.page = {}, {}, 1
		self.service = FORGE.GetService("OutfitService")
		local playerGui = player:WaitForChild("PlayerGui")
		local template = StarterGui:WaitForChild("Catalog", 15)
		assert(template, "Catalog UI is missing from StarterGui.")
		local gui, guiConnection = Gui.mount(playerGui, template)
		self.guiConnection = guiConnection
		self.view = View.new(gui)
		self.view:resize()
		local actions = Instance.new("Frame") do
			actions.Name = "OutfitActions"
			actions.BackgroundTransparency = 1
			actions.Size = UDim2.fromOffset(620, 95)
			actions.Position = UDim2.fromOffset(150, 745)
			actions.Parent = self.view.canvas
		end
		local function action(name, text, x, callback)
			local button = self.view:button(actions, name, callback, text)
			button.Size = UDim2.fromOffset(135, 30)
			button.Position = UDim2.fromOffset(x, 0)
			button.BackgroundColor3 = self.view.inner.BackgroundColor3
			button.BackgroundTransparency = .1
			return button;
		end
		action("Reset", "RESET", 0, function() self:request("reset") end)
		action("SaveOutfit", "SAVE OUTFIT", 140, function() self:saveDialog() end)
		action("Rotate", "ROTATE", 280, function()
			self.rotation += math.rad(45)
			if (self.preview) then self.preview:PivotTo(self.rigPivot * CFrame.Angles(0, self.rotation, 0)) end
		end)
		self.allowAccess = action("AllowAccess", "ALLOW ACCESS", 420, function()
			AvatarEditorService:PromptAllowInventoryReadAccess()
		end)
		self.allowAccess.Visible = false
		self.notice = Instance.new("TextLabel") do
			self.notice.Name = "Status"
			self.notice.BackgroundColor3 = self.view.inner.BackgroundColor3
			self.notice.BackgroundTransparency = .15
			self.notice.TextColor3 = self.view.inner.Header.TextColor3
			self.notice.FontFace = self.view.inner.Search.TextBox.FontFace
			self.notice.TextSize = 13
			self.notice.TextWrapped = true
			self.notice.Size = UDim2.fromOffset(590, 50)
			self.notice.Position = UDim2.fromOffset(0, 36)
			self.notice.Parent = actions
		end
		self.previous = self.view:button(self.view.inner.Page.Previous, "PreviousPage", function()
			if (self.previous.Active) then self:changePage(-1) end
		end)
		self.next = self.view:button(self.view.inner.Page.Next, "NextPage", function()
			if (self.next.Active) then self:changePage(1) end
		end)
		for _, category in Catalog.categories do
			local tab = self.view.inner.Category.ScrollingFrame:FindFirstChild(category)
			assert(tab, "Missing category: " .. category)
			self.view:button(tab, "Select", function() self:chooseCategory(category) end)
		end
		local filter = self.view.inner.Filter
		self.view:button(filter, "ChooseSort", function()
			if (self.sortMenu) then self.sortMenu:Destroy(); self.sortMenu = nil; return end
			local menu = Instance.new("Frame") do
				menu.Name = "SortMenu"
				menu.Size = UDim2.new(1, 0, 0, #Catalog.sorts * 30)
				menu.Position = UDim2.fromOffset(0, -#Catalog.sorts * 30)
				menu.BackgroundColor3 = self.view.inner.BackgroundColor3
				menu.ZIndex = 25
				menu.Parent = filter
			end
			for index, option in Catalog.sorts do
				local button = self.view:button(menu, option.value, function()
					self.sort = index
					filter.Selected.Text = option.label
					menu:Destroy()
					self.sortMenu = nil
					self:load()
				end, option.label)
				button.Size = UDim2.new(1, 0, 0, 30)
				button.Position = UDim2.fromOffset(0, (index - 1) * 30)
				button.ZIndex = 26
			end
			self.sortMenu = menu
		end)
		local search = self.view.inner.Search.TextBox
		search.PlaceholderText = "Enter an item name..."
		search.Text = ""
		self.searchGeneration = 0
		self.view:connect(search:GetPropertyChangedSignal("Text"), function()
			self.searchGeneration += 1
			local generation = self.searchGeneration
			task.delay(.4, function()
				if (generation ~= self.searchGeneration or self.stopped) then return end
				self.query = Catalog.text(search.Text, 80)
				self:load()
			end)
		end)
		self.view:connect(AvatarEditorService.PromptAllowInventoryReadAccessCompleted, function(result)
			if (result == Enum.AvatarPromptResult.Success) then self:load()
			else self:notify("Outfit access was declined. Catalog browsing still works.") end
		end)
		local function bindCharacter(character)
			task.spawn(function()
				character:WaitForChild("Humanoid", 15)
				character:WaitForChild("HumanoidRootPart", 15)
				if (self.stopped or character ~= player.Character) then return end
				self.previewRevision = nil
				self:updatePreview()
			end)
		end
		self.view:connect(player.CharacterAdded, bindCharacter)
		if (player.Character) then bindCharacter(player.Character) end
		local function watchOther(other)
			if (other == player) then return end
			local function hideCharacter(character)
				local function hide(object)
					if (object:IsA("BasePart")) then object.LocalTransparencyModifier = 1 end
				end
				for _, object in character:GetDescendants() do hide(object) end
				self.view:connect(character.DescendantAdded, hide)
			end
			self.view:connect(other.CharacterAdded, hideCharacter)
			if (other.Character) then hideCharacter(other.Character) end
		end
		self.view:connect(Players.PlayerAdded, watchOther)
		for _, other in Players:GetPlayers() do watchOther(other) end
		task.spawn(function()
			local module = player.PlayerScripts:WaitForChild("PlayerModule", 10)
			if (module and not self.stopped) then
				local success, controls = pcall(function() return require(module):GetControls() end)
				if (success and not self.stopped) then self.controls = controls; controls:Disable() end
			end
			for _ = 1, 10 do
				if (self.stopped) then return end
				local success = pcall(function()
					StarterGui:SetCore("ResetButtonCallback", false)
					StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
				end)
				if (success) then return end
				task.wait(1)
			end
		end)
		local camLock = workspace.Terrain:WaitForChild("CamLockAngle", 10)
		assert(camLock and camLock:IsA("Attachment"), "Terrain.CamLockAngle must be an Attachment.")
		local camera = workspace.CurrentCamera
		self:lockCamera(camLock)
		self.view:connect(camera:GetPropertyChangedSignal("ViewportSize"), function() self.view:resize() end)
		self.view:connect(UserInputService.InputBegan, function(input, processed)
			if (processed) then return end
			if (input.KeyCode == Enum.KeyCode.Escape and self.dialog) then self.dialog:Destroy(); self.dialog = nil end
		end)
		self:chooseCategory("Clothing")
		task.spawn(function()
			for _ = 1, 10 do
				if (self.stopped or self:request("getState")) then return end
				task.wait(2)
			end
			self:notify("Avatar couldn't load. Use RESET to retry.")
		end)
	end

	function CatalogController:Stop()
		self.stopped = true
		self.generation += 1
		self.previewGeneration += 1
		if (self.view) then self.view:destroy() end
		if (self.guiConnection) then self.guiConnection:Disconnect() end
		if (self.previewTrack) then self.previewTrack:Stop(.15) end
		if (self.controls) then self.controls:Enable() end
		if (self.cameraKey) then RunService:UnbindFromRenderStep(self.cameraKey) end
		pcall(function() StarterGui:SetCore("ResetButtonCallback", true) end)
		if (self.previousCamera) then
			workspace.CurrentCamera.CameraType = self.previousCamera.kind
			workspace.CurrentCamera.CFrame = self.previousCamera.cframe
		end
	end
end return CatalogController;
