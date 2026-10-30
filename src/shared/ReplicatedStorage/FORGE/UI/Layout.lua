-- Author -> lolokdev.
-- Last Edit -> September 15, 2026 6:02 PM CDT

local Layout = {} do
	local function edge(Value)
		if type(Value) == 'number' then return {Top = Value; Right = Value; Bottom = Value; Left = Value;} end
		if type(Value) ~= 'table' then return {Top = 0; Right = 0; Bottom = 0; Left = 0;} end
		if #Value > 0 then
			if #Value == 1 then return {Top = Value[1]; Right = Value[1]; Bottom = Value[1]; Left = Value[1];} end
			if #Value == 2 then return {Top = Value[1]; Right = Value[2]; Bottom = Value[1]; Left = Value[2];} end
			if #Value == 3 then return {Top = Value[1]; Right = Value[2]; Bottom = Value[3]; Left = Value[2];} end
			return {Top = Value[1]; Right = Value[2]; Bottom = Value[3]; Left = Value[4];}
		end
		return {Top = Value.Top or Value.Y or 0; Right = Value.Right or Value.X or 0; Bottom = Value.Bottom or Value.Y or 0; Left = Value.Left or Value.X or 0;};
	end

	local function length(Value, Axis, Context)
		if typeof(Value) == 'UDim' then return Value end
		if type(Value) == 'number' then return UDim.new(0, Value) end
		if type(Value) ~= 'string' then return nil end
		if Value == 'auto' then return 'auto' end
		local Number = tonumber(string.match(Value, '^([%-%d%.]+)%%$'))
		if Number then return UDim.new(Number / 100, 0) end
		Number = tonumber(string.match(Value, '^([%-%d%.]+)px$'))
		if Number then return UDim.new(0, Number) end
		Number = tonumber(string.match(Value, '^([%-%d%.]+)vw$'))
		if Number then return UDim.new(0, Context.ReferenceSize.X * Number / 100) end
		Number = tonumber(string.match(Value, '^([%-%d%.]+)vh$'))
		if Number then return UDim.new(0, Context.ReferenceSize.Y * Number / 100) end
		Number = tonumber(Value)
		return Number and UDim.new(0, Number) or nil;
	end

	local function padding(Parent, Value)
		local Edge = edge(Value)
		local Object = Parent:FindFirstChild('_UIPadding')
		if not Object then Object = Instance.new('UIPadding'); Object.Name = '_UIPadding'; Object.Parent = Parent end
		Object.PaddingTop = UDim.new(0, Edge.Top)
		Object.PaddingRight = UDim.new(0, Edge.Right)
		Object.PaddingBottom = UDim.new(0, Edge.Bottom)
		Object.PaddingLeft = UDim.new(0, Edge.Left)
	end

	local function list(Parent, Style)
		local Object = Parent:FindFirstChild('_UIListLayout')
		if not Object then Object = Instance.new('UIListLayout'); Object.Name = '_UIListLayout'; Object.Parent = Parent end
		Object.FillDirection = Style.Direction == 'Row' and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
		Object.Padding = UDim.new(0, Style.Gap or 0)
		Object.HorizontalAlignment = ({Start = Enum.HorizontalAlignment.Left; Center = Enum.HorizontalAlignment.Center; End = Enum.HorizontalAlignment.Right;})[Style.Align] or Enum.HorizontalAlignment.Left
		Object.VerticalAlignment = ({Start = Enum.VerticalAlignment.Top; Center = Enum.VerticalAlignment.Center; End = Enum.VerticalAlignment.Bottom;})[Style.Justify] or Enum.VerticalAlignment.Top
		Object.SortOrder = Enum.SortOrder.LayoutOrder
	end

	function Layout.Edge(...)
		local Values = {...}
		if #Values == 1 and type(Values[1]) == 'table' then return edge(Values[1]) end
		return edge(Values);
	end

	function Layout.Apply(Object, Style, Context)
		Style = Style or {}
		Context = Context or {ReferenceSize = Vector2.new(1920, 1080);}
		if not Object:IsA('GuiObject') then return Object end
		local Width = length(Style.Width, 'X', Context)
		local Height = length(Style.Height, 'Y', Context)
		local AutoX, AutoY = Width == 'auto', Height == 'auto'
		if Width ~= nil and Width ~= 'auto' then Object.Size = UDim2.new(Width.Scale, Width.Offset, Object.Size.Y.Scale, Object.Size.Y.Offset) end
		if Height ~= nil and Height ~= 'auto' then Object.Size = UDim2.new(Object.Size.X.Scale, Object.Size.X.Offset, Height.Scale, Height.Offset) end
		if AutoX and AutoY then Object.AutomaticSize = Enum.AutomaticSize.XY elseif AutoX then Object.AutomaticSize = Enum.AutomaticSize.X elseif AutoY then Object.AutomaticSize = Enum.AutomaticSize.Y end
		if Style.Padding then padding(Object, Style.Padding) end
		if Style.Direction or Style.Gap or Style.Align or Style.Justify then list(Object, Style) end
		if Style.ClipsDescendants ~= nil then Object.ClipsDescendants = Style.ClipsDescendants end
		if Style.Visible ~= nil then Object.Visible = Style.Visible end
		if Style.ZIndex ~= nil then Object.ZIndex = Style.ZIndex end
		if Style.LayoutOrder ~= nil then Object.LayoutOrder = Style.LayoutOrder end
		if Style.AnchorPoint ~= nil then Object.AnchorPoint = Style.AnchorPoint end
		if Style.Position ~= nil then Object.Position = Style.Position end
		if Style.BackgroundTransparency ~= nil then Object.BackgroundTransparency = Style.BackgroundTransparency end
		if Style.BackgroundColor3 ~= nil then Object.BackgroundColor3 = Style.BackgroundColor3 end
		if Style.AspectRatio then
			local Ratio = Object:FindFirstChild('_UIAspectRatioConstraint') or Instance.new('UIAspectRatioConstraint')
			Ratio.Name = '_UIAspectRatioConstraint'; Ratio.AspectRatio = Style.AspectRatio; Ratio.Parent = Object
		end
		if Style.MinSize or Style.MaxSize then
			local Constraint = Object:FindFirstChild('_UISizeConstraint') or Instance.new('UISizeConstraint')
			Constraint.Name = '_UISizeConstraint'
			Constraint.MinSize = Style.MinSize or Vector2.zero
			Constraint.MaxSize = Style.MaxSize or Vector2.new(1000000, 1000000)
			Constraint.Parent = Object
		end
		return Object;
	end

	function Layout.Margin(Object, Value)
		local Edge = edge(Value)
		if Edge.Top == 0 and Edge.Right == 0 and Edge.Bottom == 0 and Edge.Left == 0 then return Object, Object end
		local Wrapper = Instance.new('Frame')
		Wrapper.Name = '_Margin'
		Wrapper.BackgroundTransparency = 1
		Wrapper.BorderSizePixel = 0
		Wrapper.LayoutOrder = Object.LayoutOrder
		Wrapper.Size = UDim2.new(Object.Size.X.Scale, Object.Size.X.Offset + Edge.Left + Edge.Right, Object.Size.Y.Scale, Object.Size.Y.Offset + Edge.Top + Edge.Bottom)
		Wrapper.AutomaticSize = Object.AutomaticSize
		Object.LayoutOrder = 0
		Object.AnchorPoint = Vector2.zero
		Object.Position = UDim2.fromOffset(Edge.Left, Edge.Top)
		Object.Parent = Wrapper
		return Wrapper, Object;
	end
end

return Layout;
