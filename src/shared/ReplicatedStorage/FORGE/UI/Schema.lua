-- Author -> lolokdev.
-- Last Edit -> September 16, 2026 12:46 AM CDT

local Schema = {} do
	Schema.Version = 6
	Schema.Zones = {'TopLeft', 'TopCenter', 'TopRight', 'CenterLeft', 'Center', 'CenterRight', 'BottomLeft', 'BottomCenter', 'BottomRight'}
	Schema.Surfaces = {'Clear', 'Cream', 'CreamSoft', 'Gold', 'Dark', 'Success', 'Danger'}
	Schema.Direction = {'Row', 'Column'}
	Schema.Align = {'Start', 'Center', 'End'}
	Schema.Justify = {'Start', 'Center', 'End'}
	Schema.TextAlignment = {'Left', 'Center', 'Right'}
	Schema.VerticalAlignment = {'Top', 'Center', 'Bottom'}
	Schema.AutomaticSize = {'None', 'X', 'Y', 'XY'}
	Schema.ScaleMode = {'Fit', 'Fill', 'Width', 'Height', 'None'}
	Schema.ScrollingDirection = {'X', 'Y', 'XY'}
	Schema.ScaleType = {'Stretch', 'Slice', 'Tile', 'Fit', 'Crop'}
	Schema.Categories = {
		{Id = 'Layout'; Label = 'LAYOUT'; Items = {'Panel', 'Card', 'Stack', 'Row', 'Grid', 'Scroller', 'Spacer', 'Divider'};};
		{Id = 'Controls'; Label = 'CONTROLS'; Items = {'PillButton', 'PillSubtext', 'IconButton', 'TextInput', 'ProgressBar', 'Badge'};};
		{Id = 'Feedback'; Label = 'FEEDBACK'; Items = {'Notification', 'Achievement', 'ShinyText', 'Modal', 'Overlay'};};
		{Id = 'Content'; Label = 'CONTENT'; Items = {'Header', 'Subtext', 'Text', 'Image'};};
	}

	Schema.DocumentFields = {
		{Name = 'AutoShow'; Type = 'boolean'; Group = 'Runtime'; Description = 'Automatically mounts this document when FORGE.UI starts.';};
		{Name = 'Group'; Type = 'string'; Group = 'Runtime'; Description = 'Screens sharing a group can replace or close each other.';};
		{Name = 'CloseOthers'; Type = 'boolean'; Group = 'Runtime'; Description = 'Showing this document hides other open documents in its group.';};
		{Name = 'KeepAlive'; Type = 'boolean'; Group = 'Runtime'; Description = 'When hidden, keep its ScreenGui mounted instead of destroying it.';};
		{Name = 'DisplayOrder'; Type = 'number'; Group = 'Runtime';};
		{Name = 'Controller'; Type = 'string'; Group = 'Runtime'; Description = 'Optional FORGE controller used by Controller event actions.';};
		{Name = 'ScaleMode'; Type = 'choice'; Choices = Schema.ScaleMode; Group = 'Responsive';};
		{Name = 'Margin'; Type = 'edge'; Group = 'Responsive';};
		{Name = 'ReferenceSize'; Type = 'vector2'; Group = 'Responsive'; Description = 'Design canvas size, usually 1920, 1080.';};
		{Name = 'IgnoreGuiInset'; Type = 'boolean'; Group = 'Responsive';};
		{Name = 'ResetOnSpawn'; Type = 'boolean'; Group = 'Responsive';};
		{Name = 'MinScale'; Type = 'number'; Group = 'Responsive';};
		{Name = 'MaxScale'; Type = 'number'; Group = 'Responsive';};
	}

	local function fields(...)
		local Result = {}
		for _, Set in ipairs({...}) do
			for _, Field in ipairs(Set or {}) do table.insert(Result, Field) end
		end
		return Result;
	end

	local Identity = {
		{Name = 'Name'; Type = 'string'; Group = 'Identity';};
	}

	local Layout = {
		{Name = 'Width'; Type = 'size'; Group = 'Layout';};
		{Name = 'Height'; Type = 'size'; Group = 'Layout';};
		{Name = 'Margin'; Type = 'edge'; Group = 'Layout';};
		{Name = 'Padding'; Type = 'edge'; Group = 'Layout';};
		{Name = 'LayoutOrder'; Type = 'number'; Group = 'Layout';};
		{Name = 'Visible'; Path = 'Native.Visible'; Type = 'boolean'; Group = 'Layout'; Default = true;};
		{Name = 'AutomaticSize'; Path = 'Native.AutomaticSize'; Type = 'enum'; Enum = 'AutomaticSize'; Choices = Schema.AutomaticSize; Group = 'Layout';};
	}

	local Transform = {
		{Name = 'Position'; Path = 'Native.Position'; Type = 'udim2'; Group = 'Transform';};
		{Name = 'AnchorPoint'; Path = 'Native.AnchorPoint'; Type = 'vector2'; Group = 'Transform';};
		{Name = 'Rotation'; Path = 'Native.Rotation'; Type = 'number'; Group = 'Transform';};
		{Name = 'ZIndex'; Path = 'Native.ZIndex'; Type = 'number'; Group = 'Transform';};
	}

	local Appearance = {
		{Name = 'Surface'; Type = 'surface'; Group = 'Appearance';};
		{Name = 'BackgroundColor3'; Type = 'color'; Group = 'Appearance';};
		{Name = 'BackgroundTransparency'; Type = 'number'; Min = 0; Max = 1; Group = 'Appearance';};
		{Name = 'ClipsDescendants'; Type = 'boolean'; Group = 'Appearance';};
		{Name = 'Shine'; Type = 'boolean'; Group = 'Appearance'; Description = 'Enables this component surface and border shine layers.';};
		{Name = 'CornerRadius'; Path = 'SurfaceStyle.Corner.Radius'; Type = 'number'; Group = 'Chrome';};
		{Name = 'GradientRotation'; Path = 'SurfaceStyle.Gradient.Rotation'; Type = 'number'; Group = 'Chrome';};
		{Name = 'StrokeColor'; Path = 'SurfaceStyle.Stroke.Color'; Type = 'color'; Group = 'Chrome';};
		{Name = 'StrokeThickness'; Path = 'SurfaceStyle.Stroke.Thickness'; Type = 'number'; Group = 'Chrome';};
		{Name = 'StrokeTransparency'; Path = 'SurfaceStyle.Stroke.Transparency'; Type = 'number'; Min = 0; Max = 1; Group = 'Chrome';};
		{Name = 'ShadowColor'; Path = 'SurfaceStyle.Shadows.1.Color'; Type = 'color'; Group = 'Shadow';};
		{Name = 'ShadowTransparency'; Path = 'SurfaceStyle.Shadows.1.Transparency'; Type = 'number'; Min = 0; Max = 1; Group = 'Shadow';};
		{Name = 'ShadowOffset'; Path = 'SurfaceStyle.Shadows.1.Offset'; Type = 'udim2'; Group = 'Shadow';};
		{Name = 'ShadowBlur'; Path = 'SurfaceStyle.Shadows.1.BlurRadius'; Type = 'udim'; Group = 'Shadow';};
		{Name = 'ShadowSpread'; Path = 'SurfaceStyle.Shadows.1.Spread'; Type = 'udim2'; Group = 'Shadow';};
	}

	local Flex = {
		{Name = 'Gap'; Type = 'number'; Group = 'Flex';};
		{Name = 'Direction'; Type = 'choice'; Choices = Schema.Direction; Group = 'Flex';};
		{Name = 'Align'; Type = 'choice'; Choices = Schema.Align; Group = 'Flex';};
		{Name = 'Justify'; Type = 'choice'; Choices = Schema.Justify; Group = 'Flex';};
	}

	local Interaction = {
		{Name = 'Disabled'; Type = 'boolean'; Group = 'Interaction';};
		{Name = 'Active'; Path = 'Native.Active'; Type = 'boolean'; Group = 'Interaction';};
		{Name = 'Selectable'; Path = 'Native.Selectable'; Type = 'boolean'; Group = 'Interaction';};
	}

	local HeaderText = {
		{Name = 'Header'; Type = 'string'; Group = 'Content';};
		{Name = 'HeaderClass'; Type = 'string'; Group = 'Typography';};
		{Name = 'HeaderColor'; Path = 'HeaderNative.TextColor3'; Type = 'color'; Group = 'Typography';};
		{Name = 'HeaderSize'; Path = 'HeaderNative.TextSize'; Type = 'number'; Group = 'Typography';};
		{Name = 'HeaderTransparency'; Path = 'HeaderNative.TextTransparency'; Type = 'number'; Min = 0; Max = 1; Group = 'Typography';};
		{Name = 'HeaderWrapped'; Path = 'HeaderNative.TextWrapped'; Type = 'boolean'; Group = 'Typography';};
		{Name = 'HeaderScaled'; Path = 'HeaderNative.TextScaled'; Type = 'boolean'; Group = 'Typography';};
		{Name = 'HeaderRichText'; Path = 'HeaderNative.RichText'; Type = 'boolean'; Group = 'Typography';};
		{Name = 'HeaderXAlignment'; Path = 'HeaderNative.TextXAlignment'; Type = 'enum'; Enum = 'TextXAlignment'; Choices = Schema.TextAlignment; Group = 'Typography';};
		{Name = 'HeaderYAlignment'; Path = 'HeaderNative.TextYAlignment'; Type = 'enum'; Enum = 'TextYAlignment'; Choices = Schema.VerticalAlignment; Group = 'Typography';};
		{Name = 'HeaderStrokeColor'; Path = 'HeaderNative.TextStrokeColor3'; Type = 'color'; Group = 'Typography';};
		{Name = 'HeaderStrokeTransparency'; Path = 'HeaderNative.TextStrokeTransparency'; Type = 'number'; Min = 0; Max = 1; Group = 'Typography';};
	}

	local SubText = {
		{Name = 'Subtext'; Type = 'string'; Group = 'Content';};
		{Name = 'SubtextClass'; Type = 'string'; Group = 'Typography';};
		{Name = 'SubtextColor'; Path = 'SubtextNative.TextColor3'; Type = 'color'; Group = 'Typography';};
		{Name = 'SubtextSize'; Path = 'SubtextNative.TextSize'; Type = 'number'; Group = 'Typography';};
		{Name = 'SubtextTransparency'; Path = 'SubtextNative.TextTransparency'; Type = 'number'; Min = 0; Max = 1; Group = 'Typography';};
		{Name = 'SubtextWrapped'; Path = 'SubtextNative.TextWrapped'; Type = 'boolean'; Group = 'Typography';};
		{Name = 'SubtextScaled'; Path = 'SubtextNative.TextScaled'; Type = 'boolean'; Group = 'Typography';};
		{Name = 'SubtextRichText'; Path = 'SubtextNative.RichText'; Type = 'boolean'; Group = 'Typography';};
		{Name = 'SubtextXAlignment'; Path = 'SubtextNative.TextXAlignment'; Type = 'enum'; Enum = 'TextXAlignment'; Choices = Schema.TextAlignment; Group = 'Typography';};
		{Name = 'SubtextYAlignment'; Path = 'SubtextNative.TextYAlignment'; Type = 'enum'; Enum = 'TextYAlignment'; Choices = Schema.VerticalAlignment; Group = 'Typography';};
	}

	local Icon = {
		{Name = 'Icon'; Type = 'string'; Group = 'Icon';};
		{Name = 'IconSize'; Type = 'number'; Group = 'Icon';};
		{Name = 'IconColor3'; Type = 'color'; Group = 'Icon';};
		{Name = 'IconTransparency'; Type = 'number'; Min = 0; Max = 1; Group = 'Icon';};
		{Name = 'IconRotation'; Type = 'number'; Group = 'Icon';};
		{Name = 'IconScaleType'; Type = 'enum'; Enum = 'ScaleType'; Choices = Schema.ScaleType; Group = 'Icon';};
	}

	local Common = fields(Identity, Layout, Transform, Appearance)
	local Container = fields(Common, Flex)
	local Button = fields(Common, HeaderText, Interaction)
	local ButtonSub = fields(Common, HeaderText, SubText, Icon, Interaction)

	Schema.Components = {
		Page = {Container = true; Fields = fields(Container, {{Name = 'FillViewport'; Type = 'boolean'; Group = 'Layout'; Description = 'Makes the Page surface fill the complete viewport while its content remains on the responsive design canvas.';}}); Defaults = {Name = 'Page'; Surface = 'Clear'; Width = '100%'; Height = '100%'; FillViewport = true;};};
		Panel = {Container = true; Fields = Container; Defaults = {Surface = 'Cream'; Width = 520; Height = 'auto';};};
		Card = {Container = true; Fields = Container; Defaults = {Surface = 'CreamSoft'; Width = 360; Height = 'auto';};};
		Stack = {Container = true; Fields = Container; Defaults = {Surface = 'Clear'; Width = 'auto'; Height = 'auto'; Gap = 10; Align = 'Center'; Direction = 'Column';};};
		Row = {Container = true; Fields = Container; Defaults = {Surface = 'Clear'; Width = 'auto'; Height = 'auto'; Gap = 10; Align = 'Center'; Direction = 'Row';};};
		Grid = {Container = true; Fields = fields(Common, {
			{Name = 'CellSize'; Type = 'vector2'; Group = 'Grid';};
			{Name = 'CellPadding'; Type = 'vector2'; Group = 'Grid';};
			{Name = 'Columns'; Type = 'number'; Group = 'Grid';};
			{Name = 'HorizontalAlignment'; Type = 'choice'; Choices = Schema.Align; Group = 'Grid';};
			{Name = 'VerticalAlignment'; Type = 'choice'; Choices = Schema.VerticalAlignment; Group = 'Grid';};
		}); Defaults = {Width = 600; Height = 400; CellSize = Vector2.new(220, 110); CellPadding = Vector2.new(12, 12);};};
		Scroller = {Container = true; Fields = fields(Container, {
			{Name = 'AutomaticCanvasSize'; Type = 'enum'; Enum = 'AutomaticSize'; Choices = Schema.AutomaticSize; Group = 'Scrolling';};
			{Name = 'ScrollingDirection'; Type = 'enum'; Enum = 'ScrollingDirection'; Choices = Schema.ScrollingDirection; Group = 'Scrolling';};
			{Name = 'CustomScrollBar'; Type = 'boolean'; Group = 'Scrolling';};
			{Name = 'ScrollBarThickness'; Type = 'number'; Group = 'Scrolling';};
			{Name = 'ScrollBarMargin'; Type = 'number'; Group = 'Scrolling';};
			{Name = 'ScrollBarInset'; Type = 'number'; Group = 'Scrolling';};
			{Name = 'MinThumbSize'; Type = 'number'; Group = 'Scrolling';};
			{Name = 'ScrollBarTrackSurface'; Type = 'surface'; Group = 'Scrolling';};
			{Name = 'ScrollBarThumbSurface'; Type = 'surface'; Group = 'Scrolling';};
		}); Defaults = {Width = 500; Height = 320; Gap = 10; AutomaticCanvasSize = Enum.AutomaticSize.Y; CustomScrollBar = true; ScrollBarThickness = 5; ScrollBarInset = 0;};};
		Spacer = {Container = false; Fields = fields(Identity, Layout, Transform); Defaults = {Width = 10; Height = 10;};};
		Divider = {Container = false; Fields = Common; Defaults = {Width = '100%'; Height = 2;};};
		PillButton = {Container = false; Motion = true; Fields = Button; Defaults = {Header = 'BUTTON'; HeaderClass = 'Button'; Shine = true;}; Events = {'Activated'};};
		PillSubtext = {Container = false; Motion = true; Fields = ButtonSub; Defaults = {Header = 'BUTTON'; Subtext = 'SUBTEXT'; HeaderClass = 'Header'; SubtextClass = 'Subtext'; Shine = true;}; Events = {'Activated'};};
		IconButton = {Container = false; Motion = true; Fields = fields(Common, Icon, Interaction, {
			{Name = 'ImageColor3'; Type = 'color'; Group = 'Icon';};
			{Name = 'ImageTransparency'; Type = 'number'; Min = 0; Max = 1; Group = 'Icon';};
			{Name = 'ScaleType'; Type = 'enum'; Enum = 'ScaleType'; Choices = Schema.ScaleType; Group = 'Icon';};
		}); Defaults = {Shine = true;}; Events = {'Activated'};};
		TextInput = {Container = false; Fields = fields(Common, {
			{Name = 'Placeholder'; Type = 'string'; Group = 'Content';};
			{Name = 'Text'; Type = 'string'; Group = 'Content';};
			{Name = 'TextClass'; Type = 'string'; Group = 'Typography';};
			{Name = 'ClearTextOnFocus'; Type = 'boolean'; Group = 'Interaction';};
			{Name = 'TextColor3'; Path = 'Native.TextColor3'; Type = 'color'; Group = 'Typography';};
			{Name = 'TextSize'; Path = 'Native.TextSize'; Type = 'number'; Group = 'Typography';};
			{Name = 'TextXAlignment'; Path = 'Native.TextXAlignment'; Type = 'enum'; Enum = 'TextXAlignment'; Choices = Schema.TextAlignment; Group = 'Typography';};
		}); Defaults = {Placeholder = 'TYPE HERE...'; Width = 360; Height = 56;};};
		ProgressBar = {Container = false; Fields = fields(Common, {
			{Name = 'Value'; Type = 'number'; Min = 0; Max = 1; Group = 'Content';};
			{Name = 'FillSurface'; Type = 'surface'; Group = 'Appearance';};
		}); Defaults = {Value = .5; Width = 360; Height = 22; FillSurface = 'Gold';};};
		Badge = {Container = false; Fields = fields(Common, HeaderText); Defaults = {Header = 'BADGE'; Width = 180; Height = 42;};};
		Notification = {Container = false; Fields = ButtonSub; Defaults = {Header = 'NOTIFICATION'; Subtext = 'SUBTEXT';}; Events = {'Activated'};};
		Achievement = {Container = false; Motion = true; Fields = ButtonSub; Defaults = {Header = 'ACHIEVEMENT'; Subtext = 'SUBTEXT'; HeaderClass = 'Header'; SubtextClass = 'Subtext'; Shine = true;}; Events = {'Activated'};};
		ShinyText = {Container = false; Motion = true; Fields = fields(Common, HeaderText); Defaults = {Header = 'RUCKUS'; HeaderClass = 'Hero'; Shine = true;};};
		Modal = {Container = true; Fields = fields(Container, HeaderText, SubText); Defaults = {Surface = 'Cream'; Width = 560; Height = 'auto';};};
		Overlay = {Container = true; Fields = Container; Defaults = {Surface = 'Clear'; Width = '100%'; Height = '100%'; BackgroundTransparency = .35;};};
		Header = {Container = false; Fields = fields(Identity, Layout, Transform, {
			{Name = 'Text'; Type = 'string'; Group = 'Content';};
			{Name = 'TextClass'; Type = 'string'; Group = 'Typography';};
			{Name = 'TextColor3'; Path = 'Native.TextColor3'; Type = 'color'; Group = 'Typography';};
			{Name = 'TextSize'; Path = 'Native.TextSize'; Type = 'number'; Group = 'Typography';};
			{Name = 'TextTransparency'; Path = 'Native.TextTransparency'; Type = 'number'; Min = 0; Max = 1; Group = 'Typography';};
			{Name = 'TextWrapped'; Path = 'Native.TextWrapped'; Type = 'boolean'; Group = 'Typography';};
			{Name = 'TextScaled'; Path = 'Native.TextScaled'; Type = 'boolean'; Group = 'Typography';};
			{Name = 'RichText'; Path = 'Native.RichText'; Type = 'boolean'; Group = 'Typography';};
			{Name = 'TextXAlignment'; Path = 'Native.TextXAlignment'; Type = 'enum'; Enum = 'TextXAlignment'; Choices = Schema.TextAlignment; Group = 'Typography';};
			{Name = 'TextYAlignment'; Path = 'Native.TextYAlignment'; Type = 'enum'; Enum = 'TextYAlignment'; Choices = Schema.VerticalAlignment; Group = 'Typography';};
			{Name = 'TextStrokeColor3'; Path = 'Native.TextStrokeColor3'; Type = 'color'; Group = 'Typography';};
			{Name = 'TextStrokeTransparency'; Path = 'Native.TextStrokeTransparency'; Type = 'number'; Min = 0; Max = 1; Group = 'Typography';};
		}); Defaults = {Text = 'HEADER'; Width = 260; Height = 36;};};
		Subtext = {Container = false; Fields = fields(Identity, Layout, Transform, {
			{Name = 'Text'; Type = 'string'; Group = 'Content';};
			{Name = 'TextClass'; Type = 'string'; Group = 'Typography';};
			{Name = 'TextColor3'; Path = 'Native.TextColor3'; Type = 'color'; Group = 'Typography';};
			{Name = 'TextSize'; Path = 'Native.TextSize'; Type = 'number'; Group = 'Typography';};
			{Name = 'TextTransparency'; Path = 'Native.TextTransparency'; Type = 'number'; Min = 0; Max = 1; Group = 'Typography';};
			{Name = 'TextWrapped'; Path = 'Native.TextWrapped'; Type = 'boolean'; Group = 'Typography';};
			{Name = 'TextXAlignment'; Path = 'Native.TextXAlignment'; Type = 'enum'; Enum = 'TextXAlignment'; Choices = Schema.TextAlignment; Group = 'Typography';};
		}); Defaults = {Text = 'SUBTEXT'; Width = 260; Height = 24;};};
		Text = {Container = false; Fields = fields(Identity, Layout, Transform, {
			{Name = 'Text'; Type = 'string'; Group = 'Content';};
			{Name = 'TextClass'; Type = 'string'; Group = 'Typography';};
			{Name = 'TextColor3'; Path = 'Native.TextColor3'; Type = 'color'; Group = 'Typography';};
			{Name = 'TextSize'; Path = 'Native.TextSize'; Type = 'number'; Group = 'Typography';};
			{Name = 'TextWrapped'; Path = 'Native.TextWrapped'; Type = 'boolean'; Group = 'Typography';};
			{Name = 'TextXAlignment'; Path = 'Native.TextXAlignment'; Type = 'enum'; Enum = 'TextXAlignment'; Choices = Schema.TextAlignment; Group = 'Typography';};
		}); Defaults = {Text = 'TEXT'; Width = 260; Height = 28;};};
		Image = {Container = false; Fields = fields(Identity, Layout, Transform, {
			{Name = 'Image'; Type = 'string'; Group = 'Image';};
			{Name = 'ImageColor3'; Type = 'color'; Group = 'Image';};
			{Name = 'ImageTransparency'; Type = 'number'; Min = 0; Max = 1; Group = 'Image';};
			{Name = 'ScaleType'; Type = 'enum'; Enum = 'ScaleType'; Choices = Schema.ScaleType; Group = 'Image';};
			{Name = 'AspectRatio'; Type = 'number'; Group = 'Image';};
		}); Defaults = {Width = 100; Height = 100;};};
	}

	Schema.Zone = {
		Container = true;
		Fields = {
			{Name = 'Zone'; Type = 'zone'; Group = 'Layout';};
			{Name = 'Name'; Type = 'string'; Group = 'Identity';};
			{Name = 'Margin'; Type = 'edge'; Group = 'Layout';};
			{Name = 'Visible'; Path = 'Native.Visible'; Type = 'boolean'; Group = 'Layout'; Default = true;};
		};
		Defaults = {Zone = 'Center';};
	}

	function Schema.Get(Name)
		if Name == 'Zone' then return Schema.Zone end
		return Schema.Components[Name];
	end

	function Schema.IsContainer(Node)
		if not Node then return false end
		if Node.Kind == 'Zone' then return true end
		if Node.Kind == 'Component' then
			local Definition = Schema.Components[Node.Component]
			return Definition and Definition.Container == true or false;
		end
		return Node.Kind == 'Fragment';
	end
end

return Schema;
