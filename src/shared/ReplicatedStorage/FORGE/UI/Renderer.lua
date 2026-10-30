-- Author -> lolokdev.
-- Last Edit -> September 15, 2026 9:30 PM CDT

local CollectionService = game:GetService('CollectionService')
local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')

local Janitor = require(script.Parent.Parent.Core.Janitor)
local Layout = require(script.Parent.Layout)
local Motion = require(script.Parent.Motion)
local Responsive = require(script.Parent.Responsive)
local Typography = require(script.Parent.Typography)

local Renderer = {} do
	Renderer.Components = {}
	Renderer.Properties = {}

	local function binding(Value)
		return type(Value) == 'table' and Value.__UIBinding == true;
	end

	local function assign(Object, Property, Value, Janitor)
		local ImageRequest = 0
		local function set(Current)
			ImageRequest += 1
			if Property == 'Image' and Current == '$Profile' and (Object:IsA('ImageLabel') or Object:IsA('ImageButton')) then
				local Request = ImageRequest
				Object.Image = ''
				task.defer(function()
					local Player = Players.LocalPlayer
					if not Player or not Object.Parent then return end
					local Success, Image = pcall(function()
						return Players:GetUserThumbnailAsync(Player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
					end)
					if Success and Object.Parent and ImageRequest == Request then Object.Image = Image end
				end)
				return
			end
			pcall(function() Object[Property] = Current end)
		end
		if binding(Value) then
			local Transform = Value.Transform or function(Current) return Current end
			set(Transform(Value.State:Get()))
			Janitor:Add(Value.State.Changed:Connect(function(Current) if Object.Parent then set(Transform(Current)) end end))
		else
			set(Value)
		end
	end

	local function event(Object, Name)
		local SignalName = string.sub(Name, 3)
		local Success, Signal = pcall(function() return Object[SignalName] end)
		if Success and typeof(Signal) == 'RBXScriptSignal' then return Signal end
		local Button = Object:IsA('GuiButton') and Object or Object:FindFirstChildWhichIsA('GuiButton', true)
		if not Button then return nil end
		Success, Signal = pcall(function() return Button[SignalName] end)
		return Success and typeof(Signal) == 'RBXScriptSignal' and Signal or nil;
	end

	local function setText(Target, Value, Janitor)
		if binding(Value) then
			local Transform = Value.Transform or function(Current) return Current end
			Target.Text = tostring(Transform(Value.State:Get()))
			Janitor:Add(Value.State.Changed:Connect(function(Current) if Target.Parent then Target.Text = tostring(Transform(Current)) end end))
		else
			Target.Text = tostring(Value == nil and '' or Value)
		end
	end

	local function textMap(Object, Values, Janitor)
		if binding(Values) or type(Values) ~= 'table' then
			if Object:IsA('TextLabel') or Object:IsA('TextButton') or Object:IsA('TextBox') then setText(Object, Values, Janitor) end
			return
		end
		for Name, Value in pairs(Values) do
			local Target = Object.Name == Name and Object or Object:FindFirstChild(Name, true)
			if Target and (Target:IsA('TextLabel') or Target:IsA('TextButton') or Target:IsA('TextBox')) then
				Typography.Apply(Target, Name == 'Header' and 'Header' or Name == 'Subtext' and 'Subtext' or nil)
				setText(Target, Value, Janitor)
			end
		end
	end

	local function props(Object, Props, Context, Janitor)
		Props = Props or {}
		if Props.Name then Object.Name = Props.Name end
		if Props.Text ~= nil then textMap(Object, Props.Text, Janitor) end
		if Props.TextClass then Typography.Apply(Object, Props.TextClass, Props.TextStyle) end
		if Props.Typography ~= false then Typography.ApplyTree(Object, Props.TypographyMap) end
		if Props.Style then Layout.Apply(Object, Props.Style, Context) end
		if Props.Attributes then for Key, Value in pairs(Props.Attributes) do Object:SetAttribute(Key, Value) end end
		if Props.Tags then for _, Tag in ipairs(Props.Tags) do CollectionService:AddTag(Object, Tag) end end
		for Key, Value in pairs(Props) do
			if Renderer.Properties[Key] then Renderer.Properties[Key](Object, Value, Context, Janitor) end
			if string.sub(Key, 1, 2) == 'On' and type(Value) == 'function' then
				local Signal = event(Object, Key)
				if Signal then
					Janitor:Add(Signal:Connect(Value))
				elseif Key == 'OnActivated' and Object:IsA('GuiObject') then
					Janitor:Add(Object.InputEnded:Connect(function(Input)
						if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then Value() end
					end))
				end
			elseif not Renderer.Properties[Key] and not ({Name=true; Text=true; TextClass=true; TextStyle=true; Typography=true; TypographyMap=true; Style=true; Attributes=true; Tags=true; Motion=true; Ref=true;})[Key] then
				assign(Object, Key, Value, Janitor)
			end
		end
		if Props.Motion then Motion.Attach(Object, Props.Motion, Janitor) end
		if Props.Ref then
			if type(Props.Ref) == 'function' then Props.Ref(Object) elseif type(Props.Ref) == 'table' then Props.Ref.Current = Object end
		end
	end

	local function render(Node, Parent, Context, Janitor)
		if Node == nil or Node == false then return nil end
		if type(Node) == 'function' then return render(Node(), Parent, Context, Janitor) end
		if type(Node) ~= 'table' or not Node.__UINode then return nil end
		if Node.Kind == 'Fragment' then
			local Result = {}
			for _, Child in ipairs(Node.Children or {}) do table.insert(Result, render(Child, Parent, Context, Janitor)) end
			return Result;
		end
		if Node.Kind == 'Dynamic' then
			local Host = Instance.new('Frame')
			Host.Name = Node.Name or '_Dynamic'
			Host.BackgroundTransparency = 1
			Host.BorderSizePixel = 0
			Host.Size = UDim2.fromScale(1, 1)
			Host.Parent = Parent
			local ChildJanitor = Janitor.new()
			Janitor:Add(ChildJanitor)
			local function redraw(Value)
				ChildJanitor:Cleanup()
				for _, Child in ipairs(Host:GetChildren()) do Child:Destroy() end
				render(Node.Render(Value), Host, Context, ChildJanitor)
			end
			redraw(Node.State:Get())
			Janitor:Add(Node.State.Changed:Connect(redraw))
			return Host;
		end
		if Node.Kind == 'Custom' then
			local Factory = Renderer.Components[Node.Component]
			assert(Factory, 'Unknown FORGE.UI custom component: ' .. tostring(Node.Component))
			return render(Factory(Node.Props or {}, Node.Children or {}), Parent, Context, Janitor);
		end
		if Node.Kind == 'Zone' then
			local Zone = Responsive.CreateZone(Node.Zone, {Name = Node.Props.Name; Margin = Node.Props.Margin; ScreenMargin = Context.ScreenMargin; Style = Node.Props.Style;}, Parent, Context)
			for _, Child in ipairs(Node.Children or {}) do render(Child, Zone, Context, Janitor) end
			return Zone;
		end
		if Node.Kind == 'Page' then
			local Object = Instance.new(Node.ClassName or 'Frame')
			props(Object, Node.Props, Context, Janitor)
			Object.AnchorPoint = Vector2.zero
			Object.Position = UDim2.fromScale(0, 0)
			Object.Size = UDim2.fromScale(1, 1)
			Object.AutomaticSize = Enum.AutomaticSize.None
			Object.Parent = (Context.Root and Context.Root.Viewport) or Parent

			local ContentParent = Context.ContentHost or Parent
			for _, Child in ipairs(Node.Children or {}) do
				local Decorator = Child.Kind == 'Element' and ({UICorner=true; UIGradient=true; UIStroke=true; UIShadow=true;})[Child.ClassName] == true
				render(Child, Decorator and Object or ContentParent, Context, Janitor)
			end

			return Object;
		end
		if Node.Kind ~= 'Element' then return nil end
		local Object = Instance.new(Node.ClassName)
		props(Object, Node.Props, Context, Janitor)
		local RenderParent = Object
		local ParentObject = Object
		if Node.Props and Node.Props.Style and Node.Props.Style.Margin then ParentObject, RenderParent = Layout.Margin(Object, Node.Props.Style.Margin) end
		ParentObject.Parent = Parent
		for _, Child in ipairs(Node.Children or {}) do render(Child, RenderParent, Context, Janitor) end
		return Object;
	end

	Renderer.Properties.ScrollBarBinding = function(Object, Config, Context, Janitor)
		Config = Config or {}

		task.defer(function()
			if not Object.Parent then return end

			local Canvas = Object:FindFirstChild(Config.Canvas or '_ScrollCanvas')
			local Vertical = Object:FindFirstChild(Config.Vertical or '_VerticalScrollBar')
			local Horizontal = Object:FindFirstChild(Config.Horizontal or '_HorizontalScrollBar')

			if not Canvas or not Canvas:IsA('ScrollingFrame') then return end

			local Inset = tonumber(Config.Inset) or 0
			local Minimum = tonumber(Config.MinThumbSize) or 24
			local DragAxis, DragTrack, DragThumb

			local function axisEnabled(Axis)
				if Axis == 'Y' then
					return Canvas.ScrollingDirection == Enum.ScrollingDirection.Y or Canvas.ScrollingDirection == Enum.ScrollingDirection.XY
				end

				return Canvas.ScrollingDirection == Enum.ScrollingDirection.X or Canvas.ScrollingDirection == Enum.ScrollingDirection.XY
			end

			local function automaticAxis(Axis)
				if Axis == 'Y' then
					return Canvas.AutomaticCanvasSize == Enum.AutomaticSize.Y or Canvas.AutomaticCanvasSize == Enum.AutomaticSize.XY
				end

				return Canvas.AutomaticCanvasSize == Enum.AutomaticSize.X or Canvas.AutomaticCanvasSize == Enum.AutomaticSize.XY
			end

			local function resolve(Value, Reference)
				return (Value.Scale * Reference) + Value.Offset;
			end

			local function contentExtent(Axis)
				local VerticalAxis = Axis == 'Y'
				local View = VerticalAxis and Canvas.AbsoluteWindowSize.Y or Canvas.AbsoluteWindowSize.X
				local Native = VerticalAxis and Canvas.AbsoluteCanvasSize.Y or Canvas.AbsoluteCanvasSize.X
				local LayoutObject = Canvas:FindFirstChild('_UIListLayout')

				if not automaticAxis(Axis) or not LayoutObject or not LayoutObject:IsA('UIListLayout') then
					return math.max(Native, View), Native;
				end

				local Content = VerticalAxis and LayoutObject.AbsoluteContentSize.Y or LayoutObject.AbsoluteContentSize.X
				local Padding = Canvas:FindFirstChild('_UIPadding')

				if Padding and Padding:IsA('UIPadding') then
					local Reference = VerticalAxis and Canvas.AbsoluteSize.Y or Canvas.AbsoluteSize.X

					if VerticalAxis then
						Content += resolve(Padding.PaddingTop, Reference) + resolve(Padding.PaddingBottom, Reference)
					else
						Content += resolve(Padding.PaddingLeft, Reference) + resolve(Padding.PaddingRight, Reference)
					end
				end

				return math.max(Content, View), Native;
			end

			local function metrics(Axis)
				local VerticalAxis = Axis == 'Y'
				local View = VerticalAxis and Canvas.AbsoluteWindowSize.Y or Canvas.AbsoluteWindowSize.X
				local Current = VerticalAxis and Canvas.CanvasPosition.Y or Canvas.CanvasPosition.X
				local Content, Native = contentExtent(Axis)
				local Maximum = math.max(Content - View, 0)
				local NativeMaximum = math.max(Native - View, 0)
				local AtEnd = Maximum > 0 and Current + View >= Content - 1

				if not automaticAxis(Axis) then
					Maximum = NativeMaximum
				end

				if Maximum <= 0 and NativeMaximum > 0 then
					Maximum = NativeMaximum
				end

				local Ratio = Maximum > 0 and math.clamp(Current / Maximum, 0, 1) or 0
				if AtEnd then Ratio = 1 end

				return View, Content, Maximum, Ratio;
			end

			local function updateAxis(Track, Axis)
				if not Track then return end

				local Thumb = Track:FindFirstChild('_Thumb')
				if not Thumb then return end

				local VerticalAxis = Axis == 'Y'
				local View, Total, Maximum, Ratio = metrics(Axis)
				local TrackSize = VerticalAxis and Track.AbsoluteSize.Y or Track.AbsoluteSize.X

				Track.Visible = axisEnabled(Axis) and Maximum > .5 and TrackSize > 0
				if not Track.Visible then return end

				local Inner = math.max(TrackSize - (Inset * 2), 1)
				local ThumbSize = math.clamp(Inner * math.clamp(View / math.max(Total, 1), 0, 1), math.min(Minimum, Inner), Inner)
				local Travel = math.max(Inner - ThumbSize, 0)
				local Position = Inset + (Travel * Ratio)

				if Ratio <= .001 then
					Position = Inset
				elseif Ratio >= .999 then
					Position = TrackSize - Inset - ThumbSize
				end

				if VerticalAxis then
					Thumb.Size = UDim2.new(1, -(Inset * 2), 0, ThumbSize)
					Thumb.Position = UDim2.fromOffset(Inset, Position)
				else
					Thumb.Size = UDim2.new(0, ThumbSize, 1, -(Inset * 2))
					Thumb.Position = UDim2.fromOffset(Position, Inset)
				end
			end

			local function update()
				updateAxis(Vertical, 'Y')
				updateAxis(Horizontal, 'X')
			end

			local function setFromPointer(Position)
				if not DragAxis or not DragTrack or not DragThumb then return end

				local VerticalAxis = DragAxis == 'Y'
				local TrackStart = (VerticalAxis and DragTrack.AbsolutePosition.Y or DragTrack.AbsolutePosition.X) + Inset
				local TrackSize = VerticalAxis and DragTrack.AbsoluteSize.Y or DragTrack.AbsoluteSize.X
				local ThumbSize = VerticalAxis and DragThumb.AbsoluteSize.Y or DragThumb.AbsoluteSize.X
				local Pointer = VerticalAxis and Position.Y or Position.X
				local Travel = math.max(TrackSize - (Inset * 2) - ThumbSize, 1)
				local Ratio = math.clamp((Pointer - TrackStart - (ThumbSize * .5)) / Travel, 0, 1)
				local _, _, Maximum = metrics(DragAxis)

				if VerticalAxis then
					Canvas.CanvasPosition = Vector2.new(Canvas.CanvasPosition.X, Maximum * Ratio)
				else
					Canvas.CanvasPosition = Vector2.new(Maximum * Ratio, Canvas.CanvasPosition.Y)
				end
			end

			local function bindDrag(Track, Axis)
				if not Track then return end
				local Thumb = Track:FindFirstChild('_Thumb')
				if not Thumb then return end

				Janitor:Add(Thumb.InputBegan:Connect(function(Input)
					if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return end
					DragAxis, DragTrack, DragThumb = Axis, Track, Thumb
					setFromPointer(Input.Position)
				end))
			end

			bindDrag(Vertical, 'Y')
			bindDrag(Horizontal, 'X')

			Janitor:Add(UserInputService.InputChanged:Connect(function(Input)
				if not DragAxis then return end
				if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
					setFromPointer(Input.Position)
				end
			end))

			Janitor:Add(UserInputService.InputEnded:Connect(function(Input)
				if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
					DragAxis, DragTrack, DragThumb = nil, nil, nil
				end
			end))

			Janitor:Add(Canvas:GetPropertyChangedSignal('CanvasPosition'):Connect(update))
			Janitor:Add(Canvas:GetPropertyChangedSignal('AbsoluteCanvasSize'):Connect(update))
			Janitor:Add(Canvas:GetPropertyChangedSignal('AbsoluteWindowSize'):Connect(update))
			Janitor:Add(Canvas:GetPropertyChangedSignal('AutomaticCanvasSize'):Connect(update))
			if Vertical then Janitor:Add(Vertical:GetPropertyChangedSignal('AbsoluteSize'):Connect(update)) end
			if Horizontal then Janitor:Add(Horizontal:GetPropertyChangedSignal('AbsoluteSize'):Connect(update)) end

			local LayoutObject = Canvas:FindFirstChild('_UIListLayout')
			if LayoutObject and LayoutObject:IsA('UIListLayout') then
				Janitor:Add(LayoutObject:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(update))
			end

			update()
		end)
	end

	function Renderer.RegisterComponent(Name, Factory)
		Renderer.Components[Name] = Factory
	end

	function Renderer.RegisterProperty(Name, Handler)
		Renderer.Properties[Name] = Handler
	end

	local function handle(Node, Root, Options)
		local Host = Instance.new('Frame')
		Host.Name = '_AppHost'
		Host.Size = UDim2.fromScale(1, 1)
		Host.BackgroundTransparency = 1
		Host.BorderSizePixel = 0
		Host.Parent = Root.Canvas

		local Context = {
			ReferenceSize = Root.ReferenceSize;
			ScreenMargin = Options.Margin or 0;
			Root = Root;
			ContentHost = Host;
		}

		local ViewJanitor = Janitor.new()
		local Handle = {Root = Root; Host = Host; Instance = nil; Janitor = ViewJanitor;}

		function Handle:Update(NextNode)
			self.Janitor:Cleanup()
			for _, Child in ipairs(self.Host:GetChildren()) do Child:Destroy() end
			if self.PageInstance and self.PageInstance.Parent then self.PageInstance:Destroy() end
			self.PageInstance = nil
			self.Instance = render(NextNode, self.Host, Context, self.Janitor)
			if typeof(self.Instance) == 'Instance' and self.Instance.Parent == Root.Viewport then self.PageInstance = self.Instance end
			return self.Instance;
		end

		function Handle:Destroy()
			self.Janitor:Destroy()
			self.Root:Destroy()
		end

		Handle:Update(Node)
		return Handle;
	end

	local function previewRoot(Parent, Options)
		local Reference = Options.ReferenceSize or Vector2.new(1920, 1080)
		local Container = Instance.new('Frame')
		Container.Name = Options.Name or '_FORGEPreview'
		Container.Size = UDim2.fromScale(1, 1)
		Container.BackgroundTransparency = 1
		Container.BorderSizePixel = 0
		Container.ClipsDescendants = true
		Container.Parent = Parent

		local Canvas = Instance.new('Frame')
		Canvas.Name = '_Canvas'
		Canvas.AnchorPoint = Vector2.new(.5, .5)
		Canvas.Position = UDim2.fromScale(.5, .5)
		Canvas.Size = UDim2.fromOffset(Reference.X, Reference.Y)
		Canvas.BackgroundTransparency = 1
		Canvas.BorderSizePixel = 0
		Canvas.Parent = Container

		local Scale = Instance.new('UIScale')
		Scale.Name = '_PreviewScale'
		Scale.Parent = Canvas

		local function update()
			local Size = Container.AbsoluteSize
			if Size.X <= 0 or Size.Y <= 0 then return end
			Scale.Scale = math.max(.001, math.min(Size.X / Reference.X, Size.Y / Reference.Y))
		end

		local Connection = Container:GetPropertyChangedSignal('AbsoluteSize'):Connect(update)
		task.defer(update)

		return {
			Viewport = Container;
			Container = Container;
			Canvas = Canvas;
			Scale = Scale;
			ReferenceSize = Reference;
			Destroy = function(self)
				Connection:Disconnect()
				self.Viewport:Destroy()
			end;
		};
	end

	function Renderer.Mount(Node, Options)
		Options = Options or {}
		return handle(Node, Responsive.CreateRoot(Options), Options);
	end

	function Renderer.Preview(Node, Parent, Options)
		Options = Options or {}
		assert(typeof(Parent) == 'Instance' and Parent:IsA('GuiObject'), 'FORGE.UI preview parent must be a GuiObject.')
		return handle(Node, previewRoot(Parent, Options), Options);
	end

end

return Renderer;
