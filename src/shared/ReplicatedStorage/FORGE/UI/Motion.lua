-- Author -> lolokdev.
-- Last Edit -> September 15, 2026 8:42 PM CDT

local TweenService = game:GetService('TweenService')
local Theme = require(script.Parent.Theme)

local Motion = {} do
	Motion.Presets = {}
	Motion.BorderShineVersion = 1

	local GradientOffsets = setmetatable({}, {__mode = 'k'})
	local GradientTweens = setmetatable({}, {__mode = 'k'})
	local BorderTweens = setmetatable({}, {__mode = 'k'})
	local OverlayTransparencies = setmetatable({}, {__mode = 'k'})
	local OverlayTweens = setmetatable({}, {__mode = 'k'})

	local function scale(Object)
		local Scale = Object:FindFirstChild('_FORGEUIScale')
		if not Scale then Scale = Instance.new('UIScale'); Scale.Name = '_FORGEUIScale'; Scale.Parent = Object end
		return Scale;
	end

	local function target(Object, Path)
		if Path then
			local Current = Object
			for Part in string.gmatch(Path, '[^/%.]+') do Current = Current and Current:FindFirstChild(Part) end
			if Current then return Current end
		end
		if Object:IsA('GuiButton') then return Object end
		return Object:FindFirstChildWhichIsA('GuiButton', true) or Object;
	end

	local function transparencyProperty(Object)
		if Object:IsA('TextLabel') or Object:IsA('TextButton') or Object:IsA('TextBox') then return 'TextTransparency' end
		if Object:IsA('ImageLabel') or Object:IsA('ImageButton') then return 'ImageTransparency' end
		if Object:IsA('GuiObject') then return 'BackgroundTransparency' end
		return nil;
	end

	local function gradients(Object)
		local Result = {}
		local Overlay = Object:FindFirstChild('_ShineOverlay')
		if Overlay and Overlay:IsA('Frame') then
			local Gradient = Overlay:FindFirstChild('ShineSurfaceGradient')
			if Gradient and Gradient:IsA('UIGradient') then table.insert(Result, Gradient) end
		end
		return Result;
	end

	local function shineOverlay(Gradient)
		local Parent = Gradient and Gradient.Parent
		return Parent and Parent:IsA('GuiObject') and Parent.Name == '_ShineOverlay' and Parent or nil;
	end

	local function baseOffset(Gradient)
		local Base = GradientOffsets[Gradient]
		if Base == nil then
			Base = Gradient.Offset
			GradientOffsets[Gradient] = Base
		end
		return Base;
	end

	local function cancel(Gradient)
		local Existing = GradientTweens[Gradient]
		if Existing then Existing:Cancel(); GradientTweens[Gradient] = nil end
	end

	local function tween(Gradient, Offset, Duration, Style, Direction, Completed)
		if not Gradient.Parent then return nil end
		cancel(Gradient)
		local Tween = TweenService:Create(
			Gradient,
			TweenInfo.new(Duration, Style or Enum.EasingStyle.Quint, Direction or Enum.EasingDirection.Out),
			{Offset = Offset}
		)
		GradientTweens[Gradient] = Tween
		Tween.Completed:Once(function(State)
			if GradientTweens[Gradient] == Tween then GradientTweens[Gradient] = nil end
			if State == Enum.PlaybackState.Completed and Completed then Completed() end
		end)
		Tween:Play()
		return Tween;
	end

	function Motion.Register(Name, Definition)
		Motion.Presets[Name] = Definition
	end

	function Motion.Get(Name)
		return Motion.Presets[Name] or Theme.Get('Motion.' .. tostring(Name));
	end

	function Motion.Play(Object, Name, Overrides)
		local Definition = Motion.Get(Name)
		if not Definition or not Object or not Object.Parent then return nil end
		local Config = table.clone(Definition)
		for Key, Value in pairs(Overrides or {}) do Config[Key] = Value end
		local Duration = Config.Duration or .15
		local Style = Config.EasingStyle or Enum.EasingStyle.Quad
		local Direction = Config.EasingDirection or Enum.EasingDirection.Out
		local TweenInfoObject = TweenInfo.new(Duration, Style, Direction)
		local Tweens = {}
		if Config.ToScale or Config.FromScale then
			local Scale = scale(Object)
			if Config.FromScale then Scale.Scale = Config.FromScale end
			local Tween = TweenService:Create(Scale, TweenInfoObject, {Scale = Config.ToScale or 1;})
			Tween:Play()
			table.insert(Tweens, Tween)
		end
		if Config.Offset and Object:IsA('GuiObject') then
			local Base = Object.Position
			Object.Position = Base + UDim2.fromOffset(Config.Offset.X, Config.Offset.Y)
			local Tween = TweenService:Create(Object, TweenInfoObject, {Position = Base;})
			Tween:Play()
			table.insert(Tweens, Tween)
		end
		if Config.FromTransparency ~= nil then
			local Property = transparencyProperty(Object)
			if Property then
				local Base = Object[Property]
				Object[Property] = Config.FromTransparency
				local Tween = TweenService:Create(Object, TweenInfoObject, {[Property] = Base;})
				Tween:Play()
				table.insert(Tweens, Tween)
			end
		end
		return Tweens;
	end

	local function borderShine(Object, Enter, Duration)
		local Stroke = Object:FindFirstChild('_ShineStroke')
		if not Stroke or not Stroke:IsA('UIStroke') then return end
		local Gradient = Stroke:FindFirstChild('ShineBorderGradient')
		if not Gradient or not Gradient:IsA('UIGradient') then return end
		local Existing = BorderTweens[Stroke]
		if Existing then Existing:Cancel(); BorderTweens[Stroke] = nil end
		cancel(Gradient)
		local Base = baseOffset(Gradient)
		local Target = Stroke:GetAttribute('FORGEUIBorderShineTransparency') or 0
		if Enter then
			Gradient.Offset = Base
			Stroke.Transparency = 1
			local Fade = TweenService:Create(Stroke, TweenInfo.new(Duration or .28, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Transparency = Target;})
			BorderTweens[Stroke] = Fade
			Fade:Play()
			tween(Gradient, Vector2.new(0, Base.Y), Duration or .28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		else
			local Fade = TweenService:Create(Stroke, TweenInfo.new(Duration or .24, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency = 1;})
			BorderTweens[Stroke] = Fade
			Fade.Completed:Once(function(State)
				if BorderTweens[Stroke] ~= Fade then return end
				BorderTweens[Stroke] = nil
				if State == Enum.PlaybackState.Completed and Gradient.Parent then Gradient.Offset = Base end
			end)
			Fade:Play()
			tween(Gradient, Vector2.new(1.15, Base.Y), Duration or .24, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		end
	end

	function Motion.ShineEnter(Object, Duration)
		for _, Gradient in ipairs(gradients(Object)) do
			local Overlay = shineOverlay(Gradient)
			if not Overlay then continue end
			local Base = baseOffset(Gradient)
			Overlay.Visible = true
			Gradient.Offset = Base
			tween(Gradient, Vector2.new(0, Base.Y), Duration or .28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		end
		borderShine(Object, true, Duration)
	end

	function Motion.ShineLeave(Object, Duration)
		for _, Gradient in ipairs(gradients(Object)) do
			local Overlay = shineOverlay(Gradient)
			if not Overlay then continue end
			local Base = baseOffset(Gradient)
			tween(Gradient, Vector2.new(1.15, Base.Y), Duration or .24, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, function()
				if Gradient.Parent and Overlay.Parent then
					Gradient.Offset = Base
					Overlay.Visible = false
				end
			end)
		end
		borderShine(Object, false, Duration)
	end

	function Motion.ShinePress(Object, Duration, IsHovered)
		for _, Gradient in ipairs(gradients(Object)) do
			local Overlay = shineOverlay(Gradient)
			if not Overlay then continue end
			local Base = baseOffset(Gradient)
			Overlay.Visible = true

			if IsHovered then
				tween(Gradient, Vector2.new(.4, Base.Y), Duration or .14, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, function()
					if Gradient.Parent then tween(Gradient, Vector2.new(0, Base.Y), .18, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut) end
				end)
			else
				Gradient.Offset = Base
				tween(Gradient, Vector2.new(1.15, Base.Y), Duration or .32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, function()
					if Gradient.Parent and Overlay.Parent then
						Gradient.Offset = Base
						Overlay.Visible = false
					end
				end)
			end
		end
	end

	function Motion.Shine(Object, Duration, ReturnDuration)
		Motion.ShinePress(Object, Duration or .32, false)
	end

	function Motion.Attach(Object, Config, Janitor)
		Config = Config or {}
		if Config.Enter then task.defer(function() if Object.Parent then Motion.Play(Object, Config.Enter, Config.EnterOptions) end end) end
		local Input = target(Object, Config.Target)
		if not Input or not Input:IsA('GuiObject') then return end
		local BaseScale = scale(Object).Scale
		local Hovered = false
		local function add(Connection) if Janitor then Janitor:Add(Connection) end end

		if Config.Hover or Config.ShineOnHover then
			add(Input.MouseEnter:Connect(function()
				Hovered = true
				if Config.Hover then Motion.Play(Object, Config.Hover, Config.HoverOptions) end
				if Config.ShineOnHover then Motion.ShineEnter(Object, Config.ShineDuration) end
			end))
			add(Input.MouseLeave:Connect(function()
				Hovered = false
				TweenService:Create(scale(Object), TweenInfo.new(.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = BaseScale;}):Play()
				if Config.ShineOnHover then Motion.ShineLeave(Object, Config.ShineLeaveDuration or Config.ShineReturnDuration) end
			end))
		end

		local function release()
			local Hover = Config.Hover and Motion.Get(Config.Hover)
			local HoverScale = Hover and Hover.ToScale or BaseScale
			TweenService:Create(scale(Object), TweenInfo.new(.11, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = HoverScale;}):Play()
			if Config.ShineOnPress then Motion.ShinePress(Object, Config.ShinePressDuration or Config.ShineDuration, Hovered) end
		end

		if Input:IsA('GuiButton') then
			if Config.Press then add(Input.MouseButton1Down:Connect(function() Motion.Play(Object, Config.Press, Config.PressOptions) end)) end
			add(Input.MouseButton1Up:Connect(release))
		elseif Config.Press or Config.ShineOnPress then
			add(Input.InputBegan:Connect(function(Event)
				if Event.UserInputType == Enum.UserInputType.MouseButton1 or Event.UserInputType == Enum.UserInputType.Touch then
					if Config.Press then Motion.Play(Object, Config.Press, Config.PressOptions) end
				end
			end))
			add(Input.InputEnded:Connect(function(Event)
				if Event.UserInputType == Enum.UserInputType.MouseButton1 or Event.UserInputType == Enum.UserInputType.Touch then release() end
			end))
		end
	end
end

return Motion;
