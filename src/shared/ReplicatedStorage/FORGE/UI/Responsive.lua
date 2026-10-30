-- Author -> lolokdev.
-- Last Edit -> September 16, 2026 1:16 AM CDT

local Players, Workspace = game:GetService('Players'), game:GetService('Workspace')
local Theme = require(script.Parent.Theme)
local Layout = require(script.Parent.Layout)

local Responsive = {} do
	local ZoneMap = {
		TopLeft = {Vector2.new(0, 0); UDim2.fromScale(0, 0); 1; 1;},
		Top = {Vector2.new(.5, 0); UDim2.fromScale(.5, 0); 0; 1;},
		TopCenter = {Vector2.new(.5, 0); UDim2.fromScale(.5, 0); 0; 1;},
		TopRight = {Vector2.new(1, 0); UDim2.fromScale(1, 0); -1; 1;},
		Left = {Vector2.new(0, .5); UDim2.fromScale(0, .5); 1; 0;},
		CenterLeft = {Vector2.new(0, .5); UDim2.fromScale(0, .5); 1; 0;},
		Middle = {Vector2.new(.5, .5); UDim2.fromScale(.5, .5); 0; 0;},
		Center = {Vector2.new(.5, .5); UDim2.fromScale(.5, .5); 0; 0;},
		Right = {Vector2.new(1, .5); UDim2.fromScale(1, .5); -1; 0;},
		CenterRight = {Vector2.new(1, .5); UDim2.fromScale(1, .5); -1; 0;},
		BottomLeft = {Vector2.new(0, 1); UDim2.fromScale(0, 1); 1; -1;},
		Bottom = {Vector2.new(.5, 1); UDim2.fromScale(.5, 1); 0; -1;},
		BottomCenter = {Vector2.new(.5, 1); UDim2.fromScale(.5, 1); 0; -1;},
		BottomRight = {Vector2.new(1, 1); UDim2.fromScale(1, 1); -1; -1;};
	}

	local function viewport()
		local Camera = Workspace.CurrentCamera
		return Camera and Camera.ViewportSize or Vector2.new(1920, 1080);
	end

	local function calculate(Viewport, Reference, Mode)
		local X, Y = Viewport.X / Reference.X, Viewport.Y / Reference.Y
		if Mode == 'Fill' then return math.max(X, Y) end
		if Mode == 'Width' then return X end
		if Mode == 'Height' then return Y end
		if Mode == 'None' then return 1 end
		return math.min(X, Y);
	end

	function Responsive.CreateRoot(Options)
		Options = Options or {}
		local PlayerGui = Options.Parent or Players.LocalPlayer:WaitForChild('PlayerGui')
		local Reference = Options.ReferenceSize or Theme.Get('ReferenceSize')
		local Screen = Options.ScreenGui
		local OwnsScreen = not Screen

		if not Screen then
			Screen = Instance.new('ScreenGui')
			Screen.Name = Options.Name or 'FORGE_UI'
			Screen.ResetOnSpawn = Options.ResetOnSpawn == true
			Screen.IgnoreGuiInset = Options.IgnoreGuiInset == true
			Screen.DisplayOrder = Options.DisplayOrder or 0
			Screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			pcall(function() Screen.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets end)
			Screen.Parent = PlayerGui
		end

		local Viewport = Instance.new('Frame')
		Viewport.Name = '_Viewport'
		Viewport.Size = UDim2.fromScale(1, 1)
		Viewport.BackgroundTransparency = 1
		Viewport.BorderSizePixel = 0
		Viewport.ClipsDescendants = false
		Viewport.Parent = Screen

		local Canvas = Instance.new('Frame')
		Canvas.Name = '_Canvas'
		Canvas.AnchorPoint = Vector2.new(.5, .5)
		Canvas.Position = UDim2.fromScale(.5, .5)
		Canvas.Size = UDim2.fromOffset(Reference.X, Reference.Y)
		Canvas.BackgroundTransparency = 1
		Canvas.BorderSizePixel = 0
		Canvas.Parent = Viewport

		local Scale = Instance.new('UIScale')
		Scale.Name = '_ResponsiveScale'
		Scale.Parent = Canvas

		local Config = Theme.Get('Scale')
		local Mode = Options.ScaleMode or Config.Mode
		local MinScale = Options.MinScale or Config.Min
		local MaxScale = Options.MaxScale or Config.Max

		local function update()
			Scale.Scale = math.clamp(calculate(viewport(), Reference, Mode), MinScale, MaxScale)
		end

		update()
		local Connection

		local function connectCamera()
			if Connection then Connection:Disconnect() end
			local Camera = Workspace.CurrentCamera
			if Camera then Connection = Camera:GetPropertyChangedSignal('ViewportSize'):Connect(update) end
			update()
		end

		connectCamera()
		local CameraConnection = Workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(connectCamera)

		return {
			Screen = Screen;
			Viewport = Viewport;
			Canvas = Canvas;
			Scale = Scale;
			ReferenceSize = Reference;
			OwnsScreen = OwnsScreen;
			Destroy = function(self)
				if Connection then Connection:Disconnect() end
				CameraConnection:Disconnect()
				if self.OwnsScreen then self.Screen:Destroy() else self.Viewport:Destroy() end
			end;
		};
	end

	function Responsive.CreateZone(Name, Options, Parent, Context)
		Options = Options or {}
		local Definition = ZoneMap[Name] or ZoneMap.Center
		local Global = Layout.Edge(Options.ScreenMargin or 0)
		local Local = Layout.Edge(Options.Margin or 0)
		local Left, Right = Global.Left + Local.Left, Global.Right + Local.Right
		local Top, Bottom = Global.Top + Local.Top, Global.Bottom + Local.Bottom
		local Root = Context and Context.Root
		local TargetParent = Root and Root.Viewport or Parent

		local Zone = Instance.new('Frame')
		Zone.Name = Options.Name or Name
		Zone.AnchorPoint = Definition[1]
		Zone.Size = UDim2.fromOffset(0, 0)
		Zone.AutomaticSize = Enum.AutomaticSize.XY
		Zone.BackgroundTransparency = 1
		Zone.BorderSizePixel = 0
		Zone.Parent = TargetParent

		local ZoneScale
		if Root and Root.Scale then
			ZoneScale = Instance.new('UIScale')
			ZoneScale.Name = '_ZoneScale'
			ZoneScale.Parent = Zone
		end

		local function update()
			local Scale = Root and Root.Scale and Root.Scale.Scale or 1
			local XOffset = Definition[3] == 1 and Left * Scale or Definition[3] == -1 and -Right * Scale or (Left - Right) * .5 * Scale
			local YOffset = Definition[4] == 1 and Top * Scale or Definition[4] == -1 and -Bottom * Scale or (Top - Bottom) * .5 * Scale
			local Base = Definition[2]
			Zone.Position = UDim2.new(Base.X.Scale, Base.X.Offset + XOffset, Base.Y.Scale, Base.Y.Offset + YOffset)
			if ZoneScale then ZoneScale.Scale = Scale end
		end

		update()
		if Root and Root.Scale then Root.Scale:GetPropertyChangedSignal('Scale'):Connect(update) end
		Layout.Apply(Zone, Options.Style, Context)
		return Zone;
	end
end

return Responsive;
