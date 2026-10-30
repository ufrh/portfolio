local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

local View = {} do
	View.__index = View

	function View.new(gui: ScreenGui)
		local self = setmetatable({}, View) do
			self.gui = gui
			self.inner = gui:WaitForChild("Inner")
			self.equipped = gui:WaitForChild("Equipped"):WaitForChild("ScrollingFrame")
			self.templates = StarterGui:WaitForChild("Components")
			self.items = self.inner.ItemList.ScrollingFrame
			self.subcategories = self.inner.SubCategory.ScrollingFrame
			self.connections = {}
			self.cards = {}
			self.viewports = {}
			self.lastViewportUpdate = 0
			gui.ResetOnSpawn = false
			gui.IgnoreGuiInset = true
			gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
			self.items.ScrollingDirection = Enum.ScrollingDirection.Y
			self.items.AutomaticCanvasSize = Enum.AutomaticSize.Y
			self.items.CanvasSize = UDim2.fromOffset(0, 0)
			self.equipped.ScrollingDirection = Enum.ScrollingDirection.Y
			self.equipped.AutomaticCanvasSize = Enum.AutomaticSize.Y
			self.equipped.CanvasSize = UDim2.fromOffset(0, 0)
			table.insert(self.connections, RunService.RenderStepped:Connect(function()
				local now = os.clock()
				if (now - self.lastViewportUpdate < 1 / 30) then return end
				self.lastViewportUpdate = now
				local angle = now * .55
				local screen = workspace.CurrentCamera.ViewportSize
				for index = #self.viewports, 1, -1 do
					local entry = self.viewports[index]
					if (not entry.viewport.Parent) then table.remove(self.viewports, index)
					else
						local position, size = entry.viewport.AbsolutePosition, entry.viewport.AbsoluteSize
						if (position.X + size.X >= 0 and position.X <= screen.X and position.Y + size.Y >= 0 and position.Y <= screen.Y) then
							local orbit = Vector3.new(math.sin(angle) * entry.distance, 0, math.cos(angle) * entry.distance)
							entry.camera.CFrame = CFrame.lookAt(entry.target + orbit, entry.target)
						end
					end
				end
			end))
		end return self;
	end

	function View:connect(signal, callback)
		local connection = signal:Connect(callback)
		table.insert(self.connections, connection)
		return connection;
	end

	function View:button(parent, name: string, callback, label: string?)
		local button = Instance.new("TextButton") do
			button.Name = name
			button.Size = UDim2.fromScale(1, 1)
			button.BackgroundTransparency = 1
			button.Text = label or ""
			button.TextColor3 = self.inner.Header.TextColor3
			button.FontFace = self.inner.Header.FontFace
			button.TextSize = 12
			button.AutoButtonColor = false
			button.ZIndex = 10
			button.Parent = parent
		end
		button.Activated:Connect(callback)
		button.MouseEnter:Connect(function()
			TweenService:Create(button, TweenInfo.new(.12), {BackgroundTransparency = .92}):Play()
		end)
		button.MouseLeave:Connect(function()
			TweenService:Create(button, TweenInfo.new(.12), {BackgroundTransparency = 1}):Play()
		end)
		return button;
	end

	function View:clear(container)
		for _, child in container:GetChildren() do
			if (child:IsA("GuiObject")) then child:Destroy() end
		end
	end

	function View:message(text: string, retry)
		if (self.messageLabel) then self.messageLabel:Destroy(); self.messageLabel = nil end
	end

	function View:thumbnail(parent, item)
		local viewport = parent:FindFirstChildWhichIsA("ViewportFrame")
		if (viewport) then viewport.Visible = false end
		local image = Instance.new("ImageLabel") do
			image.Name = "Thumbnail"
			image.Size = UDim2.fromScale(1, 1)
			image.BackgroundTransparency = 1
			image.ScaleType = Enum.ScaleType.Fit
			local kind = if (item.itemType == "Bundle") then "BundleThumbnail"
				elseif (item.itemType == "RobloxOutfit") then "Outfit" else "Asset"
			if (item.itemType ~= "SavedOutfit") then
				image.Image = "rbxthumb://type=" .. kind .. "&id=" .. item.id .. "&w=150&h=150"
			end
			image.Parent = parent
		end
		if (item.itemType == "SavedOutfit") then
			local icon = self.inner.Header:Clone()
			icon.Name = "OutfitIcon"
			icon.Text = "OUTFIT\n" .. item.id
			icon.TextSize = 18
			icon.Size = UDim2.fromScale(1, 1)
			icon.Position = UDim2.fromOffset(0, 0)
			icon.Parent = image
		end
	end

	function View:preview(parent, source: Model)
		local viewport = parent:FindFirstChildWhichIsA("ViewportFrame")
		if (not viewport) then return end
		for _, child in viewport:GetChildren() do
			if (child:IsA("Camera") or child:IsA("WorldModel")) then child:Destroy() end
		end
		local world = Instance.new("WorldModel")
		world.Name = "PreviewWorld"
		world.Parent = viewport
		local model = source:Clone()
		model.Name = "PreviewModel"
		model.Parent = world
		model:PivotTo(CFrame.new())
		local visible = {}
		for name in string.gmatch(source:GetAttribute("PreviewBodyParts") or "", "[^,]+") do visible[name] = true end
		local groups = {
			Head = {Head = true},
			Torso = {UpperTorso = true, LowerTorso = true},
			LeftArm = {LeftUpperArm = true, LeftLowerArm = true, LeftHand = true},
			RightArm = {RightUpperArm = true, RightLowerArm = true, RightHand = true},
			LeftLeg = {LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true},
			RightLeg = {RightUpperLeg = true, RightLowerLeg = true, RightFoot = true}
		}
		local visibleParts = {}
		for group in visible do
			for name in groups[group] or {} do visibleParts[name] = true end
		end
		for _, object in model:GetChildren() do
			if (object:IsA("BasePart") and object.Name ~= "HumanoidRootPart") then
				if (not visibleParts[object.Name]) then
					object.Transparency = 1
					object.CastShadow = false
					for _, detail in object:GetDescendants() do
						if (detail:IsA("Decal") or detail:IsA("Texture")) then detail.Transparency = 1 end
					end
				end
			end
		end
		local minimum, maximum
		for _, object in model:GetDescendants() do
			if (object:IsA("BasePart") and object.Name ~= "HumanoidRootPart" and object.Transparency < .98) then
				local low, high = object.Position - object.Size / 2, object.Position + object.Size / 2
				minimum = if (minimum) then Vector3.new(math.min(minimum.X, low.X), math.min(minimum.Y, low.Y), math.min(minimum.Z, low.Z)) else low
				maximum = if (maximum) then Vector3.new(math.max(maximum.X, high.X), math.max(maximum.Y, high.Y), math.max(maximum.Z, high.Z)) else high
			end
		end
		if (not minimum) then world:Destroy(); viewport.Visible = false; return false end
		local target, size = (minimum + maximum) / 2, maximum - minimum
		local camera = Instance.new("Camera")
		camera.FieldOfView = 35
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		viewport.Visible = true
		local thumbnail = parent:FindFirstChild("Thumbnail")
		if (thumbnail) then thumbnail:Destroy() end
		local radius = math.max(size.X, size.Y, size.Z) / 2
		local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.18
		table.insert(self.viewports, {viewport = viewport, camera = camera, distance = math.max(distance, 2), target = target})
		return true;
	end

	function View:card(item, index: number, activate, favorite, removeSaved)
		local card = self.templates.Item:Clone() do
			card.Name = item.itemType .. "_" .. item.id
			card.LayoutOrder = index
			card.Size = UDim2.fromOffset(134, 180)
		end
		local preview = card:FindFirstChild("Frame")
		preview.Name = "Preview"
		local selected = preview:FindFirstChild("Frame")
		selected.Name = "SelectionBadge"
		selected.Visible = false
		selected.ZIndex = 11
		selected.Checkmark.ZIndex = 12
		for _, child in card:GetChildren() do
			if (child:IsA("TextLabel")) then
				if (string.sub(child.Text, 1, 3) == "by ") then
					child.Name = "Creator"
					child.RichText = false
					child.Text = if (item.creator == "") then "" else "by " .. item.creator
					child.LayoutOrder = 3
					local price = child:FindFirstChildWhichIsA("TextLabel")
					if (price) then
						price.Name = "Price"
						price.RichText = false
						price.Text = if (item.price == 0) then "FREE" elseif (item.price) then item.price .. " R$" else ""
					end
				else
					child.Name = "ItemName"
					child.RichText = false
					child.Text = item.name
					child.TextTruncate = Enum.TextTruncate.AtEnd
					child.LayoutOrder = 2
				end
			end
		end
		preview.LayoutOrder = 1
		self:thumbnail(preview, item)
		self:button(preview, "TryOn", activate)
		if (favorite) then
			local star = self:button(preview, "Favorite", favorite, "☆")
			star.Size = UDim2.fromOffset(30, 30)
			star.Position = UDim2.new(1, -32, 0, 2)
			star.TextSize = 22
			star.ZIndex = 15
		end
		if (removeSaved) then
			local remove = self:button(preview, "Delete", removeSaved, "×")
			remove.Size = UDim2.fromOffset(30, 30)
			remove.Position = UDim2.new(1, -32, 0, 2)
			remove.TextSize = 22
			remove.ZIndex = 15
		end
		card.Parent = self.items
		return card;
	end

	function View:select(frame, selected: boolean)
		local marker = frame:FindFirstChild("ActiveUnderline")
		if (marker) then marker.Visible = selected end
	end

	function View:resize()
		local camera = workspace.CurrentCamera
		local size = camera.ViewportSize
		if (not self.canvas) then
			local roots = {}
			for _, child in self.gui:GetChildren() do
				if (child:IsA("GuiObject")) then table.insert(roots, child) end
			end
			self.canvas = Instance.new("Frame") do
				self.canvas.Name = "ReferenceCanvas"
				self.canvas.BackgroundTransparency = 1
				self.canvas.Size = UDim2.fromOffset(1583, 864)
				self.canvas.AnchorPoint = Vector2.new(.5, .5)
				self.canvas.Position = UDim2.fromScale(.5, .5)
				self.canvas.Parent = self.gui
			end
			self.scale = Instance.new("UIScale")
			self.scale.Parent = self.canvas
			for _, child in roots do child.Parent = self.canvas end
		end
		self.scale.Scale = math.min(size.X / 1583, size.Y / 864)
	end

	function View:destroy()
		for _, connection in self.connections do connection:Disconnect() end
	end
end return View;
