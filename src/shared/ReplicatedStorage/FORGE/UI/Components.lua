-- Author -> lolokdev.
-- Last Edit -> September 16, 2026 12:46 AM CDT

local Nodes = require(script.Parent.Nodes)
local Theme = require(script.Parent.Theme)
local ThemeBuilder = require(script.Parent.ThemeBuilder)

local Components = {} do
	local function merge(...)
		return ThemeBuilder.MergeTables(...);
	end

	local function component(Name)
		return Theme.Get('Components.' .. Name) or {};
	end

	local function surface(Name, Overrides)
		return merge(Theme.Get('Surfaces.' .. tostring(Name or 'Clear')) or {}, Overrides or {});
	end

	local function sequence(Value)
		if typeof(Value) == 'ColorSequence' then return Value end
		if typeof(Value) == 'Color3' then return ColorSequence.new(Value) end
		return ColorSequence.new(Color3.new(1, 1, 1));
	end

	local function numberSequence(Value)
		if typeof(Value) == 'NumberSequence' then return Value end
		if type(Value) == 'number' then return NumberSequence.new(Value) end
		return nil;
	end

	local function decoratorNodes(Definition)
		local Children = {}
		if Definition.Corner then
			table.insert(Children, Nodes.Element('UICorner', {
				Name = '_Corner';
				CornerRadius = UDim.new(0, Definition.Corner.Radius or 0);
			}))
		end
		if Definition.Gradient then
			local Gradient = Definition.Gradient
			table.insert(Children, Nodes.Element('UIGradient', {
				Name = Gradient.Name == 'ShineSurfaceGradient' and 'BaseSurfaceGradient' or Gradient.Name or '_Gradient';
				Color = sequence(Gradient.Color);
				Rotation = Gradient.Rotation or 0;
				Transparency = numberSequence(Gradient.Transparency) or NumberSequence.new(0);
				Offset = Gradient.Offset or Vector2.zero;
			}))
		end
		if Definition.ShineOverlay then
			local Shine = Definition.ShineOverlay
			local OverlayChildren = {}
			if Definition.Corner then
				table.insert(OverlayChildren, Nodes.Element('UICorner', {
					Name = '_Corner';
					CornerRadius = UDim.new(0, Definition.Corner.Radius or 0);
				}))
			end
			table.insert(OverlayChildren, Nodes.Element('UIGradient', {
				Name = Shine.Name or 'ShineSurfaceGradient';
				Color = sequence(Shine.Color);
				Rotation = Shine.Rotation or 108;
				Transparency = numberSequence(Shine.Transparency) or NumberSequence.new(0);
				Offset = Shine.Offset or Vector2.new(-1.15, 0);
			}))
			table.insert(Children, Nodes.Element('Frame', {
				Name = '_ShineOverlay';
				Active = false;
				Selectable = false;
				Interactable = false;
				Visible = false;
				BackgroundColor3 = Shine.BackgroundColor3 or Color3.new(1, 1, 1);
				BackgroundTransparency = Shine.BackgroundTransparency or .78;
				BorderSizePixel = 0;
				AnchorPoint = Vector2.zero;
				Position = UDim2.fromScale(0, 0);
				Size = UDim2.fromScale(1, 1);
				ZIndex = Shine.ZIndex or 2;
			}, OverlayChildren))
		end
		if Definition.Stroke then
			local Stroke = Definition.Stroke
			table.insert(Children, Nodes.Element('UIStroke', {
				Name = '_Stroke';
				Color = Stroke.Color or Color3.new(1, 1, 1);
				Thickness = Stroke.Thickness or 1;
				Transparency = Stroke.Transparency or 0;
				ApplyStrokeMode = Stroke.ApplyStrokeMode or Enum.ApplyStrokeMode.Border;
				LineJoinMode = Stroke.LineJoinMode or Enum.LineJoinMode.Round;
			}))

			if Stroke.Gradient then
				local Gradient = Stroke.Gradient
				local Transient = Gradient.Name == 'ShineBorderGradient'
				table.insert(Children, Nodes.Element('UIStroke', {
					Name = '_ShineStroke';
					Color = Color3.new(1, 1, 1);
					Thickness = Stroke.ShineThickness or Stroke.Thickness or 1;
					Transparency = Transient and 1 or (Stroke.ShineTransparency or 0);
					Attributes = {FORGEUIBorderShineTransparency = Stroke.ShineTransparency or 0;};
					ApplyStrokeMode = Stroke.ApplyStrokeMode or Enum.ApplyStrokeMode.Border;
					LineJoinMode = Stroke.LineJoinMode or Enum.LineJoinMode.Round;
				}, {
					Nodes.Element('UIGradient', {
						Name = Gradient.Name or 'ShineBorderGradient';
						Color = sequence(Gradient.Color);
						Rotation = Gradient.Rotation or 0;
						Transparency = numberSequence(Gradient.Transparency) or NumberSequence.new(0);
						Offset = Gradient.Offset or Vector2.zero;
					});
				}))
			end
		end
		for Index, Shadow in ipairs(Definition.Shadows or {}) do
			table.insert(Children, Nodes.Element('UIShadow', {
				Name = '_Shadow' .. Index;
				Color = Shadow.Color or Color3.new(0, 0, 0);
				Transparency = Shadow.Transparency or 0;
				Offset = Shadow.Offset or UDim2.fromOffset(0, 4);
				BlurRadius = Shadow.BlurRadius or UDim.new(0, 10);
				Spread = Shadow.Spread or UDim2.fromOffset(0, 0);
				ZIndex = Shadow.ZIndex or Index;
			}))
		end
		return Children;
	end

	local function style(Default, Props)
		local Result = merge(Default or {}, Props.Style or {})
		if Props.Width ~= nil then Result.Width = Props.Width end
		if Props.Height ~= nil then Result.Height = Props.Height end
		if Props.Margin ~= nil then Result.Margin = Props.Margin end
		if Props.Padding ~= nil then Result.Padding = Props.Padding end
		if Props.Gap ~= nil then Result.Gap = Props.Gap end
		if Props.LayoutOrder ~= nil then Result.LayoutOrder = Props.LayoutOrder end
		if Props.Visible ~= nil then Result.Visible = Props.Visible end
		if Props.ZIndex ~= nil then Result.ZIndex = Props.ZIndex end
		return Result;
	end

	local function common(Props, Style)
		local Result = merge(Props.Native or {}, {
			Name = Props.Name;
			Style = Style;
			Ref = Props.Ref;
			Attributes = Props.Attributes;
			Tags = Props.Tags;
			Motion = Props.Motion;
		})
		for Key, Value in pairs(Props) do
			if string.sub(Key, 1, 2) == 'On' and type(Value) == 'function' then Result[Key] = Value end
		end
		return Result;
	end

	local function text(Name, Value, ClassName, Props)
		Props = Props or {}
		return Nodes.Element('TextLabel', merge({
			Name = Name;
			Text = Value or '';
			TextClass = ClassName;
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			TextXAlignment = Props.TextXAlignment or Enum.TextXAlignment.Left;
			TextYAlignment = Props.TextYAlignment or Enum.TextYAlignment.Center;
			ZIndex = Props.ZIndex or 4;
			Style = Props.Style;
		}, Props.Native or {}));
	end

	local function icon(Value, Size, ZIndex, Props)
		if not Value then return nil end
		Props = Props or {}
		return Nodes.Element('ImageLabel', {
			Name = 'Icon';
			Size = UDim2.fromOffset(Size or 36, Size or 36);
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Image = Value;
			ImageColor3 = Props.IconColor3 or Color3.new(1, 1, 1);
			ImageTransparency = Props.IconTransparency or 0;
			ScaleType = Props.IconScaleType or Enum.ScaleType.Fit;
			Rotation = Props.IconRotation or 0;
			ZIndex = ZIndex or 4;
		});
	end

	local function append(Target, Value)
		if Value then table.insert(Target, Value) end
	end

	local function surfaceElement(ClassName, Props, Children, ComponentName)
		local Definition = component(ComponentName or 'Panel')
		local Surface = surface(Props.Surface or Props.Variant or Definition.Surface or 'Clear', Props.SurfaceStyle)
		if Props.Shine == false then
			Surface.ShineOverlay = nil
		end
		local Style = style({
			Width = Definition.Width;
			Height = Definition.Height;
			Padding = Props.Padding or Definition.Padding;
			Gap = Props.Gap or Definition.Gap;
			Direction = Props.Direction or Definition.Direction;
			Align = Props.Align or Definition.Align;
			Justify = Props.Justify or Definition.Justify;
		}, Props)
		local AllChildren = decoratorNodes(Surface)
		local RootStyle = Style
		if Surface.ShineOverlay then
			RootStyle = merge({}, Style)
			RootStyle.Padding = nil
			RootStyle.Gap = nil
			RootStyle.Direction = nil
			RootStyle.Align = nil
			RootStyle.Justify = nil
			local ContentStyle = {
				Width = Style.Width == 'auto' and 'auto' or '100%';
				Height = Style.Height == 'auto' and 'auto' or '100%';
				Padding = Style.Padding;
				Gap = Style.Gap;
				Direction = Style.Direction;
				Align = Style.Align;
				Justify = Style.Justify;
			}
			table.insert(AllChildren, Nodes.Element('Frame', {
				Name = '_Content';
				Active = false;
				Selectable = false;
				Interactable = false;
				BackgroundTransparency = 1;
				BorderSizePixel = 0;
				Style = ContentStyle;
				ZIndex = 3;
			}, Children or {}))
		else
			for _, Child in ipairs(Children or {}) do append(AllChildren, Child) end
		end
		local Root = common(Props, RootStyle)
		Root.BackgroundColor3 = Props.BackgroundColor3 or Surface.BackgroundColor3 or Color3.new(1, 1, 1)
		Root.BackgroundTransparency = Props.BackgroundTransparency ~= nil and Props.BackgroundTransparency or Surface.BackgroundTransparency or 1
		Root.BorderSizePixel = 0
		Root.ClipsDescendants = Props.ClipsDescendants == true
		return Nodes.Element(ClassName, Root, AllChildren);
	end

	function Components.Text(Props)
		Props = Props or {}
		return text(Props.Name or 'Text', Props.Text or '', Props.Class or Props.TextClass or 'Body', {
			TextXAlignment = Props.TextXAlignment;
			TextYAlignment = Props.TextYAlignment;
			Style = style({Width = Props.Width or 'auto'; Height = Props.Height or 'auto';}, Props);
			Native = Props.Native;
		});
	end

	function Components.Header(Props)
		Props = Props or {}
		Props.Class = Props.Class or 'Header'
		Props.Name = Props.Name or 'Header'
		return Components.Text(Props);
	end

	function Components.Subtext(Props)
		Props = Props or {}
		Props.Class = Props.Class or 'Subtext'
		Props.Name = Props.Name or 'Subtext'
		return Components.Text(Props);
	end

	function Components.Image(Props)
		Props = Props or {}
		local Root = common(Props, style({Width = Props.Width or 48; Height = Props.Height or 48;}, Props))
		Root.BackgroundTransparency = Props.BackgroundTransparency == nil and 1 or Props.BackgroundTransparency
		Root.BorderSizePixel = 0
		Root.Image = Props.Image or Props.Icon or ''
		Root.ImageColor3 = Props.ImageColor3 or Color3.new(1, 1, 1)
		Root.ImageTransparency = Props.ImageTransparency or 0
		Root.ScaleType = Props.ScaleType or Enum.ScaleType.Fit
		if Props.Button then Root.AutoButtonColor = false end
		return Nodes.Element(Props.Button and 'ImageButton' or 'ImageLabel', Root, {
			Nodes.Element('UIAspectRatioConstraint', {AspectRatio = Props.AspectRatio or 1;});
		});
	end

	function Components.Surface(Props, Children)
		Props = Props or {}
		return surfaceElement(Props.ClassName or 'Frame', Props, Children, Props.ComponentStyle or 'Panel');
	end

	function Components.Frame(Props, Children)
		Props = Props or {}
		Props.Surface = Props.Surface or 'Clear'
		return surfaceElement('Frame', Props, Children, 'Frame');
	end

	function Components.Panel(Props, Children)
		Props = Props or {}
		return surfaceElement('Frame', Props, Children, 'Panel');
	end

	function Components.Card(Props, Children)
		Props = Props or {}
		return surfaceElement('Frame', Props, Children, 'Card');
	end

	function Components.Page(Props, Children)
		Props = Props or {}
		Props.Surface = Props.Surface or 'Clear'
		Props.Width = Props.Width or '100%'
		Props.Height = Props.Height or '100%'
		if Props.FillViewport == nil then Props.FillViewport = true end

		local Root = surfaceElement('Frame', Props, Children, 'Frame')
		if Props.FillViewport ~= false then Root.Kind = 'Page' end
		return Root;
	end

	function Components.Stack(Props, Children)
		Props = Props or {}
		Props.Surface = Props.Surface or 'Clear'
		Props.Style = merge({Direction = 'Column'; Gap = Props.Gap or 10; Align = Props.Align or 'Start'; Justify = Props.Justify or 'Start'; Width = Props.Width or 'auto'; Height = Props.Height or 'auto';}, Props.Style or {})
		return surfaceElement('Frame', Props, Children, 'Frame');
	end

	function Components.Row(Props, Children)
		Props = Props or {}
		Props.Surface = Props.Surface or 'Clear'
		Props.Style = merge({Direction = 'Row'; Gap = Props.Gap or 10; Align = Props.Align or 'Center'; Justify = Props.Justify or 'Start'; Width = Props.Width or 'auto'; Height = Props.Height or 'auto';}, Props.Style or {})
		return surfaceElement('Frame', Props, Children, 'Frame');
	end

	function Components.PillButton(Props)
		Props = Props or {}
		local Definition = component('PillButton')
		Props.Motion = Props.Motion or Definition.Motion
		Props.Shine = Props.Shine ~= false
		local Children = {}
		append(Children, icon(Props.Icon, Props.IconSize or 32, 3, Props))
		append(Children, text('Header', Props.Header or Props.Text or 'BUTTON', Props.TextClass or Props.HeaderClass or 'Button', {
			TextXAlignment = Props.Icon and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center;
			Style = {Width = Props.Icon and 'auto' or '100%'; Height = '100%';};
			Native = Props.HeaderNative;
		}))
		local Root = surfaceElement('TextButton', Props, Children, 'PillButton')
		Root.Props.Text = ''
		Root.Props.AutoButtonColor = false
		Root.Props.Active = Props.Disabled ~= true
		Root.Props.Interactable = Props.Disabled ~= true
		return Root;
	end

	function Components.PillSubtext(Props)
		Props = Props or {}
		local Definition = component('PillSubtext')
		Props.Motion = Props.Motion or Definition.Motion
		Props.Shine = Props.Shine ~= false
		local HasIcon = Props.Icon ~= nil
		local Alignment = HasIcon and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
		local TextStack = Nodes.Element('Frame', {
			Name = 'TextStack';
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Style = {Width = HasIcon and 'auto' or '100%'; Height = '100%'; Direction = 'Column'; Gap = 0; Align = 'Center'; Justify = 'Center';};
		}, {
			text('Header', Props.Header or 'HEADER', Props.HeaderClass or 'Header', {TextXAlignment = Alignment; Style = {Width = '100%'; Height = 'auto';}; Native = Props.HeaderNative;}),
			text('Subtext', Props.Subtext or '', Props.SubtextClass or 'Subtext', {TextXAlignment = Alignment; Style = {Width = '100%'; Height = 'auto';}; Native = Props.SubtextNative;});
		})
		local Children = {}
		append(Children, icon(Props.Icon, Props.IconSize or 34, 3, Props))
		append(Children, TextStack)
		local Root = surfaceElement('TextButton', Props, Children, 'PillSubtext')
		Root.Props.Text = ''
		Root.Props.AutoButtonColor = false
		Root.Props.Active = Props.Disabled ~= true
		Root.Props.Interactable = Props.Disabled ~= true
		return Root;
	end

	function Components.IconButton(Props)
		Props = Props or {}
		local Definition = component('IconButton')
		Props.Motion = Props.Motion or Definition.Motion
		Props.Shine = Props.Shine ~= false
		local Root = surfaceElement('ImageButton', Props, {}, 'IconButton')
		Root.Props.Image = Props.Icon or Props.Image or ''
		Root.Props.ScaleType = Props.ScaleType or Enum.ScaleType.Fit
		Root.Props.AutoButtonColor = false
		Root.Props.Active = Props.Disabled ~= true
		Root.Props.Interactable = Props.Disabled ~= true
		Root.Props.ImageColor3 = Props.ImageColor3 or Color3.new(1, 1, 1)
		Root.Props.ImageTransparency = Props.ImageTransparency or 0
		return Root;
	end

	local function messageComponent(Name, Props)
		Props = Props or {}
		local Children = {}
		if Props.Icon then
			append(Children, surfaceElement('Frame', {
				Name = 'IconContainer'; Surface = Props.IconSurface or 'Cream'; Width = Props.IconContainerSize or 62; Height = Props.IconContainerSize or 62; Padding = {10;};
			}, {icon(Props.Icon, Props.IconSize or 38, 4, Props)}, 'Card'))
		end
		local TextStack = Nodes.Element('Frame', {
			Name = 'TextStack'; BackgroundTransparency = 1; BorderSizePixel = 0;
			Style = {Width = 'auto'; Height = '100%'; Direction = 'Column'; Gap = 1; Justify = 'Center';};
		}, {
			text('Header', Props.Header or string.upper(Name), Props.HeaderClass or 'Header', {Style = {Width = 'auto'; Height = 'auto';}; Native = Props.HeaderNative;}),
			text('Subtext', Props.Subtext or '', Props.SubtextClass or 'Subtext', {Style = {Width = 'auto'; Height = 'auto';}; Native = Props.SubtextNative;});
		})
		append(Children, TextStack)
		return surfaceElement(Props.OnActivated and 'TextButton' or 'Frame', Props, Children, Name);
	end

	function Components.Notification(Props)
		return messageComponent('Notification', Props);
	end

	function Components.Achievement(Props)
		Props = Props or {}
		Props.Shine = Props.Shine ~= false
		return messageComponent('Achievement', Props);
	end

	function Components.ShinyText(Props)
		Props = Props or {}
		Props.Shine = Props.Shine ~= false
		local Label = text('Header', Props.Header or Props.Text or 'EMPHASIZED TEXT!', Props.TextClass or 'Hero', {
			TextXAlignment = Enum.TextXAlignment.Center;
			Style = {Width = '100%'; Height = '100%';};
			Native = Props.HeaderNative;
		})
		return surfaceElement('Frame', Props, {Label}, 'ShinyText');
	end

	function Components.Modal(Props, Children)
		Props = Props or {}
		local Items = {}
		if Props.Header then append(Items, text('Header', Props.Header, Props.HeaderClass or 'Header', {Style = {Width = '100%'; Height = 'auto';}; Native = Props.HeaderNative;})) end
		if Props.Subtext then append(Items, text('Subtext', Props.Subtext, Props.SubtextClass or 'Subtext', {Style = {Width = '100%'; Height = 'auto';}; Native = Props.SubtextNative;})) end
		for _, Child in ipairs(Children or {}) do append(Items, Child) end
		Props.Style = merge({Direction = 'Column'; Gap = Props.Gap or component('Modal').Gap or 16;}, Props.Style or {})
		return surfaceElement('Frame', Props, Items, 'Modal');
	end

	function Components.Scroller(Props, Children)
		Props = Props or {}
		local Definition = component('Scroller')
		local AutomaticCanvasSize = Props.AutomaticCanvasSize or Enum.AutomaticSize.Y
		local Automatic = AutomaticCanvasSize ~= Enum.AutomaticSize.None
		local Padding = Props.Padding

		if Padding == nil and Automatic then
			Padding = {Definition.AutoCanvasPadding or 5;}
		end

		local WrapperStyle = merge(Props.Style or {})
		WrapperStyle.Width = Props.Width or WrapperStyle.Width or Definition.Width or '100%'
		WrapperStyle.Height = Props.Height or WrapperStyle.Height or Definition.Height or '100%'
		if Props.Margin ~= nil then WrapperStyle.Margin = Props.Margin end
		if Props.LayoutOrder ~= nil then WrapperStyle.LayoutOrder = Props.LayoutOrder end
		if Props.Visible ~= nil then WrapperStyle.Visible = Props.Visible end
		if Props.ZIndex ~= nil then WrapperStyle.ZIndex = Props.ZIndex end
		WrapperStyle.Padding = nil
		WrapperStyle.Direction = nil
		WrapperStyle.Gap = nil
		WrapperStyle.Align = nil
		WrapperStyle.Justify = nil

		local CanvasStyle = {
			Width = '100%';
			Height = '100%';
			Padding = Padding;
			Direction = Props.Direction or (Props.Style and Props.Style.Direction) or 'Column';
			Gap = Props.Gap or (Props.Style and Props.Style.Gap) or Definition.Gap or 10;
			Align = Props.Align or (Props.Style and Props.Style.Align) or 'Start';
			Justify = Props.Justify or (Props.Style and Props.Style.Justify) or 'Start';
		}

		local CanvasProps = common({
			Name = '_ScrollCanvas';
			Native = Props.Native;
			Ref = Props.Ref;
			Attributes = Props.Attributes;
			Tags = Props.Tags;
		}, CanvasStyle)

		CanvasProps.BackgroundTransparency = Props.BackgroundTransparency == nil and 1 or Props.BackgroundTransparency
		CanvasProps.BackgroundColor3 = Props.BackgroundColor3 or Color3.new(1, 1, 1)
		CanvasProps.BorderSizePixel = 0
		CanvasProps.AutomaticCanvasSize = AutomaticCanvasSize
		CanvasProps.CanvasSize = Props.CanvasSize or UDim2.new()
		local Thickness = Props.ScrollBarThickness or Definition.ScrollBarThickness or 7
		local CustomScrollBar = Props.CustomScrollBar == true
		CanvasProps.ScrollBarThickness = CustomScrollBar and 0 or math.max(9, Thickness)
		CanvasProps.ScrollBarImageColor3 = Props.ScrollBarImageColor3 or Theme.Get('Colors.Gold') or Color3.new(1, 1, 1)
		CanvasProps.ScrollBarImageTransparency = Props.ScrollBarImageTransparency or 0
		CanvasProps.ScrollingDirection = Props.ScrollingDirection or Enum.ScrollingDirection.Y
		CanvasProps.ClipsDescendants = true

		for Key, Value in pairs(Props) do
			if string.sub(Key, 1, 2) == 'On' and type(Value) == 'function' then CanvasProps[Key] = Value end
		end

		local Margin = Props.ScrollBarMargin == nil and (Definition.ScrollBarMargin or 0) or Props.ScrollBarMargin
		local Inset = Props.ScrollBarInset == nil and (Definition.ScrollBarInset or 1) or Props.ScrollBarInset
		local TrackSurface = Props.ScrollBarTrackSurface or Definition.ScrollBarTrackSurface or 'CreamSoft'
		local ThumbSurface = Props.ScrollBarThumbSurface or Definition.ScrollBarThumbSurface or 'Gold'
		local MinThumbSize = Props.MinThumbSize or Definition.MinThumbSize or 24

		local function Bar(Name, Axis)
			local Vertical = Axis == 'Y'
			local Thumb = surfaceElement('Frame', {
				Name = '_Thumb';
				Surface = ThumbSurface;
				SurfaceStyle = {Shadows = false;};
				ClipsDescendants = false;
				Native = {
					Active = true;
					AnchorPoint = Vector2.zero;
					Position = UDim2.fromOffset(Inset, Inset);
					Size = Vertical and UDim2.new(1, -(Inset * 2), 0, MinThumbSize) or UDim2.new(0, MinThumbSize, 1, -(Inset * 2));
				};
			}, {}, 'Frame')

			return surfaceElement('Frame', {
				Name = Name;
				Surface = TrackSurface;
				SurfaceStyle = {Shadows = false;};
				ClipsDescendants = true;
				Native = {
					Active = true;
					AnchorPoint = Vertical and Vector2.new(1, 0) or Vector2.new(0, 1);
					Position = Vertical and UDim2.new(1, -Margin, 0, Margin) or UDim2.new(0, Margin, 1, -Margin);
					Size = Vertical and UDim2.new(0, Thickness, 1, -(Margin * 2)) or UDim2.new(1, -(Margin * 2), 0, Thickness);
					Visible = false;
					ZIndex = Props.ScrollBarZIndex or 50;
				};
			}, {Thumb}, 'Frame')
		end

		local Items = {
			Nodes.Element('ScrollingFrame', CanvasProps, Children or {});
		}

		if CustomScrollBar then
			table.insert(Items, Bar('_VerticalScrollBar', 'Y'))
			table.insert(Items, Bar('_HorizontalScrollBar', 'X'))
		end

		return Nodes.Element('Frame', {
			Name = Props.Name or 'Scroller';
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Style = WrapperStyle;
			ScrollBarBinding = not CustomScrollBar and nil or {
				Canvas = '_ScrollCanvas';
				Vertical = '_VerticalScrollBar';
				Horizontal = '_HorizontalScrollBar';
				Inset = Inset;
				MinThumbSize = MinThumbSize;
			};
		}, Items);
	end

	function Components.Divider(Props)
		Props = Props or {}
		return Nodes.Element('Frame', common(Props, style({Width = Props.Width or '100%'; Height = Props.Height or 2;}, Props)), {
			Nodes.Element('UICorner', {CornerRadius = UDim.new(1, 0);});
		});
	end

	function Components.Badge(Props)
		Props = Props or {}
		Props.Width = Props.Width or 'auto'
		Props.Height = Props.Height or 34
		Props.Padding = Props.Padding or {5, 12;}
		Props.Surface = Props.Surface or 'Gold'
		return surfaceElement('Frame', Props, {
			text('Header', Props.Text or Props.Header or 'BADGE', Props.TextClass or 'Caption', {TextXAlignment = Enum.TextXAlignment.Center; Style = {Width = 'auto'; Height = '100%';};});
		}, 'Card');
	end

	function Components.ProgressBar(Props)
		Props = Props or {}
		local Definition = component('ProgressBar')
		local Value = Props.Value
		local FillSize

		if type(Value) == 'table' and Value.__UIBinding == true then
			FillSize = {
				__UIBinding = true;
				State = Value.State;
				Transform = function(Current)
					Current = Value.Transform and Value.Transform(Current) or Current
					return UDim2.fromScale(math.clamp(tonumber(Current) or 0, 0, 1), 1);
				end;
			}
		else
			FillSize = UDim2.fromScale(math.clamp(tonumber(Value) or 0, 0, 1), 1)
		end

		local FillSurface = surface(Props.FillSurface or Definition.FillSurface or 'Gold', Props.FillSurfaceStyle)
		local FillChildren = decoratorNodes(FillSurface)
		local TrackProps = merge({
			Surface = Props.Surface or Definition.Surface or 'CreamSoft';
			Width = Props.Width or Definition.Width or 320;
			Height = Props.Height or Definition.Height or 22;
			Padding = Props.Padding or Definition.Padding or {0;};
		}, Props)

		return surfaceElement('Frame', TrackProps, {
			Nodes.Element('Frame', {
				Name = 'Fill';
				AnchorPoint = Vector2.zero;
				Position = UDim2.fromScale(0, 0);
				Size = FillSize;
				BackgroundColor3 = FillSurface.BackgroundColor3 or Theme.Get('Colors.Gold');
				BackgroundTransparency = FillSurface.BackgroundTransparency or 0;
				BorderSizePixel = 0;
			}, FillChildren);
		}, 'ProgressBar');
	end

	function Components.Overlay(Props, Children)
		Props = Props or {}
		Props.Surface = Props.Surface or 'Clear'
		Props.Width = Props.Width or '100%'
		Props.Height = Props.Height or '100%'
		Props.BackgroundColor3 = Props.BackgroundColor3 or Color3.new(0, 0, 0)
		Props.BackgroundTransparency = Props.BackgroundTransparency == nil and .35 or Props.BackgroundTransparency
		return surfaceElement('Frame', Props, Children, 'Frame');
	end

	function Components.Spacer(Props)
		Props = Props or {}
		return Nodes.Element('Frame', {
			Name = Props.Name or 'Spacer';
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Style = style({Width = Props.Width or 1; Height = Props.Height or 1;}, Props);
		});
	end

	function Components.Grid(Props, Children)
		Props = Props or {}
		local Cell = Props.CellSize or Vector2.new(220, 110)
		local Padding = Props.CellPadding or Vector2.new(12, 12)
		local Horizontal = Props.HorizontalAlignment
		local Vertical = Props.VerticalAlignment
		if type(Horizontal) == 'string' then
			Horizontal = ({Start = Enum.HorizontalAlignment.Left; Center = Enum.HorizontalAlignment.Center; End = Enum.HorizontalAlignment.Right;})[Horizontal]
		end
		if type(Vertical) == 'string' then
			Vertical = ({Top = Enum.VerticalAlignment.Top; Center = Enum.VerticalAlignment.Center; Bottom = Enum.VerticalAlignment.Bottom;})[Vertical]
		end
		local Items = {
			Nodes.Element('UIGridLayout', {
				Name = '_UIGridLayout';
				CellSize = UDim2.fromOffset(Cell.X, Cell.Y);
				CellPadding = UDim2.fromOffset(Padding.X, Padding.Y);
				FillDirectionMaxCells = Props.Columns or 0;
				SortOrder = Enum.SortOrder.LayoutOrder;
				HorizontalAlignment = Horizontal or Enum.HorizontalAlignment.Left;
				VerticalAlignment = Vertical or Enum.VerticalAlignment.Top;
			});
		}
		for _, Child in ipairs(Children or {}) do append(Items, Child) end
		return Components.Frame(merge({Width = Props.Width or '100%'; Height = Props.Height or '100%'; Padding = Props.Padding;}, Props), Items);
	end

	function Components.TextInput(Props)
		Props = Props or {}
		local Surface = surface(Props.Surface or 'CreamSoft', Props.SurfaceStyle)
		local Children = decoratorNodes(Surface)
		local Root = common(Props, style({Width = Props.Width or 360; Height = Props.Height or 58; Padding = Props.Padding or {8, 16;};}, Props))
		Root.BackgroundColor3 = Surface.BackgroundColor3
		Root.BackgroundTransparency = Surface.BackgroundTransparency or 0
		Root.BorderSizePixel = 0
		Root.Text = Props.Text or ''
		Root.PlaceholderText = Props.Placeholder or Props.PlaceholderText or 'Enter text...'
		Root.ClearTextOnFocus = Props.ClearTextOnFocus == true
		Root.TextClass = Props.TextClass or 'Body'
		return Nodes.Element('TextBox', Root, Children);
	end
	Components.Button = Components.PillButton
	Components.Container = Components.Panel
	Components.Scroll = Components.Scroller
end

return Components;
