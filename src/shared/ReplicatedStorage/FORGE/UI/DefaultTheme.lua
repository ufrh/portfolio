-- Author -> lolokdev.
-- Last Edit -> September 15, 2026 8:24 PM CDT

local ThemeBuilder = require(script.Parent.ThemeBuilder)

local Cream = Color3.fromRGB(255, 245, 211)
local CreamLight = Color3.fromRGB(255, 251, 229)
local CreamDark = Color3.fromRGB(225, 203, 145)
local Gold = Color3.fromRGB(255, 221, 102)
local GoldLight = Color3.fromRGB(255, 241, 175)
local GoldDark = Color3.fromRGB(194, 146, 37)
local Brown = Color3.fromRGB(121, 92, 43)
local BrownSoft = Color3.fromRGB(148, 112, 58)
local Dark = Color3.fromRGB(44, 42, 47)
local DarkSoft = Color3.fromRGB(64, 61, 69)
local White = Color3.fromRGB(255, 255, 255)
local Success = Color3.fromRGB(128, 211, 70)
local Danger = Color3.fromRGB(235, 89, 56)
local Blue = Color3.fromRGB(115, 168, 226)

local function TransientBorderShine(Light, Mid, Rotation)
	return {
		Name = 'ShineBorderGradient';
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Mid);
			ColorSequenceKeypoint.new(.42, Light);
			ColorSequenceKeypoint.new(.5, Color3.new(1, 1, 1));
			ColorSequenceKeypoint.new(.58, Light);
			ColorSequenceKeypoint.new(1, Mid);
		});
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1);
			NumberSequenceKeypoint.new(.34, 1);
			NumberSequenceKeypoint.new(.46, .3);
			NumberSequenceKeypoint.new(.5, .02);
			NumberSequenceKeypoint.new(.54, .3);
			NumberSequenceKeypoint.new(.66, 1);
			NumberSequenceKeypoint.new(1, 1);
		});
		Rotation = Rotation or 18;
		Offset = Vector2.new(-1.15, 0);
	};
end

local function PersistentBorderShine(Light, Mid, Dark, Rotation)
	return {
		Name = 'PersistentShineBorderGradient';
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Dark);
			ColorSequenceKeypoint.new(.2, Mid);
			ColorSequenceKeypoint.new(.43, Light);
			ColorSequenceKeypoint.new(.52, Color3.new(1, 1, 1));
			ColorSequenceKeypoint.new(.61, Light);
			ColorSequenceKeypoint.new(.8, Mid);
			ColorSequenceKeypoint.new(1, Dark);
		});
		Rotation = Rotation or 18;
		Offset = Vector2.new(-.2, 0);
	};
end

local function SurfaceDepthGradient(Top, Middle, Bottom, Rotation)
	return {
		Name = 'BaseSurfaceGradient';
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Top);
			ColorSequenceKeypoint.new(.48, Middle);
			ColorSequenceKeypoint.new(1, Bottom);
		});
		Transparency = NumberSequence.new(0);
		Rotation = Rotation or 90;
		Offset = Vector2.zero;
	};
end

local function TransientSurfaceShine(Base, Light, Peak, Rotation)
	return {
		Name = 'ShineSurfaceGradient';
		BackgroundColor3 = Color3.new(1, 1, 1);
		BackgroundTransparency = .94;
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Base);
			ColorSequenceKeypoint.new(.04, Base);
			ColorSequenceKeypoint.new(.14, Base:Lerp(Light, .18));
			ColorSequenceKeypoint.new(.26, Base:Lerp(Light, .5));
			ColorSequenceKeypoint.new(.36, Light);
			ColorSequenceKeypoint.new(.5, Peak);
			ColorSequenceKeypoint.new(.64, Light);
			ColorSequenceKeypoint.new(.74, Base:Lerp(Light, .5));
			ColorSequenceKeypoint.new(.86, Base:Lerp(Light, .18));
			ColorSequenceKeypoint.new(.96, Base);
			ColorSequenceKeypoint.new(1, Base);
		});
		Transparency = NumberSequence.new(.2);
		Rotation = Rotation or 108;
		Offset = Vector2.new(-1.15, 0);
	};
end

local GoldSurfaceGradient = {
	Name = 'GoldSurfaceGradient';
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 211, 72));
		ColorSequenceKeypoint.new(.25, Color3.fromRGB(255, 226, 118));
		ColorSequenceKeypoint.new(.48, Color3.fromRGB(255, 240, 170));
		ColorSequenceKeypoint.new(.58, Color3.fromRGB(255, 234, 145));
		ColorSequenceKeypoint.new(.78, Color3.fromRGB(255, 222, 101));
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 209, 67));
	});
	Rotation = 112;
	Offset = Vector2.zero;
};

local Builder = ThemeBuilder.new()

local ThemeBuilder = require(script.Parent.ThemeBuilder)

local function MetalGradient(Highlights, Mid, Dark, Rotation)
	return ThemeBuilder.Gradient(
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, Dark);
			ColorSequenceKeypoint.new(.18, Mid);
			ColorSequenceKeypoint.new(.38, Highlights);
			ColorSequenceKeypoint.new(.52, Mid);
			ColorSequenceKeypoint.new(.72, Highlights:Lerp(Mid, .55));
			ColorSequenceKeypoint.new(1, Dark);
		}),
		Rotation or 18
	);
end

local function MetalStroke(Light, Mid, Dark)
	return ThemeBuilder.Gradient(
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, Dark);
			ColorSequenceKeypoint.new(.28, Mid);
			ColorSequenceKeypoint.new(.48, Light);
			ColorSequenceKeypoint.new(.62, Mid);
			ColorSequenceKeypoint.new(1, Dark);
		}),
		-18
	);
end

local function MetalSurface(Name, Colors)
	Builder:Surface(Name, {
		BackgroundColor3 = Colors.Base;
		BackgroundTransparency = 0;

		Corner = ThemeBuilder.Corner(
			Colors.Radius or 18
		);

		Gradient = MetalGradient(
			Colors.Highlight,
			Colors.Mid,
			Colors.Dark,
			Colors.Rotation or 18
		);

		Stroke = ThemeBuilder.Stroke(
			Colors.StrokeBase or Colors.Mid,
			Colors.StrokeThickness or 2,
			Colors.StrokeTransparency or 0,
			MetalStroke(
				Colors.StrokeHighlight or Colors.Highlight,
				Colors.StrokeMid or Colors.Mid,
				Colors.StrokeDark or Colors.Dark
			)
		);

		Shadows = {
			ThemeBuilder.Shadow(
				Colors.Shadow or Colors.Dark,
				Colors.ShadowTransparency or .58,
				UDim2.fromOffset(0, 8),
				UDim.new(0, 14),
				UDim2.fromOffset(3, 3)
			);
		};

		PersistentShine = true;
		Metallic = true;
	})
end

MetalSurface('Silver', {
	Base = Color3.fromRGB(174, 181, 190);

	Highlight = Color3.fromRGB(245, 249, 255);
	Mid = Color3.fromRGB(185, 193, 204);
	Dark = Color3.fromRGB(92, 100, 112);

	StrokeHighlight = Color3.fromRGB(255, 255, 255);
	StrokeMid = Color3.fromRGB(205, 213, 223);
	StrokeDark = Color3.fromRGB(95, 102, 111);

	Shadow = Color3.fromRGB(38, 42, 49);
})

MetalSurface('Bronze', {
	Base = Color3.fromRGB(174, 102, 52);

	Highlight = Color3.fromRGB(255, 196, 122);
	Mid = Color3.fromRGB(187, 111, 58);
	Dark = Color3.fromRGB(83, 43, 24);

	StrokeHighlight = Color3.fromRGB(255, 214, 154);
	StrokeMid = Color3.fromRGB(195, 119, 66);
	StrokeDark = Color3.fromRGB(86, 46, 27);

	Shadow = Color3.fromRGB(50, 26, 15);
})

MetalSurface('Copper', {
	Base = Color3.fromRGB(183, 95, 58);

	Highlight = Color3.fromRGB(255, 188, 143);
	Mid = Color3.fromRGB(204, 112, 73);
	Dark = Color3.fromRGB(91, 43, 29);

	StrokeHighlight = Color3.fromRGB(255, 209, 177);
	StrokeMid = Color3.fromRGB(216, 125, 82);
	StrokeDark = Color3.fromRGB(97, 48, 31);

	Shadow = Color3.fromRGB(57, 27, 19);
})

MetalSurface('Platinum', {
	Base = Color3.fromRGB(197, 203, 214);

	Highlight = Color3.fromRGB(255, 255, 255);
	Mid = Color3.fromRGB(208, 214, 225);
	Dark = Color3.fromRGB(121, 128, 143);

	StrokeHighlight = Color3.fromRGB(255, 255, 255);
	StrokeMid = Color3.fromRGB(224, 230, 240);
	StrokeDark = Color3.fromRGB(127, 134, 147);

	Shadow = Color3.fromRGB(49, 54, 64);

	ShadowTransparency = .5;
})

MetalSurface('RoseGold', {
	Base = Color3.fromRGB(205, 142, 126);

	Highlight = Color3.fromRGB(255, 225, 213);
	Mid = Color3.fromRGB(216, 153, 136);
	Dark = Color3.fromRGB(114, 73, 66);

	StrokeHighlight = Color3.fromRGB(255, 235, 226);
	StrokeMid = Color3.fromRGB(226, 165, 148);
	StrokeDark = Color3.fromRGB(119, 77, 68);

	Shadow = Color3.fromRGB(70, 43, 39);
})

MetalSurface('Titanium', {
	Base = Color3.fromRGB(95, 105, 116);

	Highlight = Color3.fromRGB(190, 202, 214);
	Mid = Color3.fromRGB(112, 122, 134);
	Dark = Color3.fromRGB(43, 49, 56);

	StrokeHighlight = Color3.fromRGB(205, 216, 229);
	StrokeMid = Color3.fromRGB(122, 133, 145);
	StrokeDark = Color3.fromRGB(47, 53, 60);

	Shadow = Color3.fromRGB(20, 23, 27);

	ShadowTransparency = .46;
})

MetalSurface('Gunmetal', {
	Base = Color3.fromRGB(57, 63, 72);

	Highlight = Color3.fromRGB(136, 147, 160);
	Mid = Color3.fromRGB(69, 76, 86);
	Dark = Color3.fromRGB(23, 27, 32);

	StrokeHighlight = Color3.fromRGB(158, 170, 184);
	StrokeMid = Color3.fromRGB(77, 85, 96);
	StrokeDark = Color3.fromRGB(26, 29, 34);

	Shadow = Color3.fromRGB(8, 10, 12);

	ShadowTransparency = .38;
})

MetalSurface('ObsidianMetal', {
	Base = Color3.fromRGB(25, 26, 31);

	Highlight = Color3.fromRGB(94, 99, 113);
	Mid = Color3.fromRGB(39, 42, 50);
	Dark = Color3.fromRGB(8, 9, 12);

	StrokeHighlight = Color3.fromRGB(124, 130, 148);
	StrokeMid = Color3.fromRGB(48, 51, 61);
	StrokeDark = Color3.fromRGB(10, 11, 14);

	Shadow = Color3.fromRGB(0, 0, 0);

	ShadowTransparency = .28;
})

MetalSurface('BlueSteel', {
	Base = Color3.fromRGB(89, 113, 137);

	Highlight = Color3.fromRGB(190, 220, 246);
	Mid = Color3.fromRGB(103, 130, 157);
	Dark = Color3.fromRGB(39, 56, 72);

	StrokeHighlight = Color3.fromRGB(215, 235, 255);
	StrokeMid = Color3.fromRGB(116, 144, 172);
	StrokeDark = Color3.fromRGB(44, 61, 78);

	Shadow = Color3.fromRGB(20, 31, 42);
})

MetalSurface('EmeraldMetal', {
	Base = Color3.fromRGB(53, 130, 103);

	Highlight = Color3.fromRGB(164, 244, 207);
	Mid = Color3.fromRGB(62, 147, 117);
	Dark = Color3.fromRGB(21, 64, 50);

	StrokeHighlight = Color3.fromRGB(190, 255, 225);
	StrokeMid = Color3.fromRGB(75, 160, 130);
	StrokeDark = Color3.fromRGB(25, 71, 55);

	Shadow = Color3.fromRGB(13, 40, 31);
})

Builder
	:Set('ReferenceSize', Vector2.new(1920, 1080))
	:Set('Scale', {Mode = 'Fit'; Min = .45; Max = 1.35;})
	:Color('Cream', Cream)
	:Color('CreamLight', CreamLight)
	:Color('CreamDark', CreamDark)
	:Color('Gold', Gold)
	:Color('GoldLight', GoldLight)
	:Color('GoldDark', GoldDark)
	:Color('Brown', Brown)
	:Color('BrownSoft', BrownSoft)
	:Color('Dark', Dark)
	:Color('DarkSoft', DarkSoft)
	:Color('White', White)
	:Color('Success', Success)
	:Color('Danger', Danger)
	:Color('Blue', Blue)
	:Spacing('XS', 6)
	:Spacing('S', 10)
	:Spacing('M', 16)
	:Spacing('L', 24)
	:Spacing('XL', 32)
	:Spacing('XXL', 48)
	:Radius('Small', 10)
	:Radius('Medium', 16)
	:Radius('Large', 24)
	:Radius('Pill', 999)
	:Typography('Header', {FontFace = Font.fromEnum(Enum.Font.FredokaOne); TextSize = 28; TextColor3 = Brown; TextWrapped = true;})
	:Typography('Subtext', {FontFace = Font.fromEnum(Enum.Font.GothamMedium); TextSize = 17; TextColor3 = BrownSoft; TextWrapped = true;})
	:Typography('Body', {FontFace = Font.fromEnum(Enum.Font.GothamMedium); TextSize = 18; TextColor3 = Brown; TextWrapped = true;})
	:Typography('Button', {FontFace = Font.fromEnum(Enum.Font.FredokaOne); TextSize = 21; TextColor3 = Brown; TextWrapped = true;})
	:Typography('Caption', {FontFace = Font.fromEnum(Enum.Font.Gotham); TextSize = 14; TextColor3 = BrownSoft; TextWrapped = true;})
	:Typography('Hero', {FontFace = Font.fromEnum(Enum.Font.FredokaOne); TextSize = 52; TextColor3 = White; TextStrokeColor3 = Brown; TextStrokeTransparency = .1; TextWrapped = true;})
	:Surface('Clear', {BackgroundColor3 = White; BackgroundTransparency = 1;})
	:Surface('Cream', {
		BackgroundColor3 = Cream;
		BackgroundTransparency = 0;
		Corner = ThemeBuilder.Corner(18);
		Gradient = SurfaceDepthGradient(CreamLight, Cream, Cream:Lerp(CreamDark, .24), 90);
		ShineOverlay = TransientSurfaceShine(Cream, CreamLight, Color3.fromRGB(255, 255, 246), 108);
		Stroke = ThemeBuilder.Stroke(CreamDark, 2, .06, TransientBorderShine(Color3.fromRGB(255, 255, 242), Color3.fromRGB(240, 214, 151), 18));
		Shadows = {ThemeBuilder.Shadow(Color3.fromRGB(75, 57, 25), .72, UDim2.fromOffset(0, 8), UDim.new(0, 12), UDim2.fromOffset(4, 4));};
	})
	:Surface('CreamSoft', {
		BackgroundColor3 = CreamLight;
		BackgroundTransparency = .04;
		Corner = ThemeBuilder.Corner(16);
		Gradient = SurfaceDepthGradient(Color3.fromRGB(255, 253, 238), CreamLight, CreamLight:Lerp(CreamDark, .18), 90);
		ShineOverlay = TransientSurfaceShine(CreamLight, Color3.fromRGB(255, 253, 238), Color3.fromRGB(255, 255, 250), 108);
		Stroke = ThemeBuilder.Stroke(CreamDark, 1.5, .16, TransientBorderShine(Color3.fromRGB(255, 255, 246), Color3.fromRGB(236, 213, 158), 18));
		Shadows = {ThemeBuilder.Shadow(Color3.fromRGB(75, 57, 25), .82, UDim2.fromOffset(0, 5), UDim.new(0, 9), UDim2.fromOffset(2, 2));};
	})
	:Surface('Gold', {
		BackgroundColor3 = Gold;
		BackgroundTransparency = 0;
		Corner = ThemeBuilder.Corner(18);
		Gradient = GoldSurfaceGradient;
		ShineOverlay = TransientSurfaceShine(Gold, GoldLight, Color3.fromRGB(255, 255, 245), 108);
		Stroke = ThemeBuilder.Stroke(Color3.fromRGB(238, 184, 45), 2, .06, PersistentBorderShine(Color3.fromRGB(255, 255, 229), Color3.fromRGB(255, 225, 103), Color3.fromRGB(188, 128, 24), 18));
		Shadows = {
			ThemeBuilder.Shadow(Color3.fromRGB(255, 221, 102), .46, UDim2.fromOffset(0, 0), UDim.new(.32, 0), UDim2.fromOffset(16, 16));
			ThemeBuilder.Shadow(Color3.fromRGB(82, 58, 13), .76, UDim2.fromOffset(0, 8), UDim.new(0, 11), UDim2.fromOffset(4, 4));
		};
	})
	:Surface('Dark', {
		BackgroundColor3 = Dark;
		BackgroundTransparency = .08;
		Corner = ThemeBuilder.Corner(14);
		Gradient = SurfaceDepthGradient(DarkSoft, Dark, Dark:Lerp(Color3.new(0, 0, 0), .22), 90);
		ShineOverlay = TransientSurfaceShine(Dark, DarkSoft, Color3.fromRGB(105, 101, 112), 108);
		Stroke = ThemeBuilder.Stroke(White, 1.5, .5, TransientBorderShine(Color3.fromRGB(255, 255, 255), Color3.fromRGB(154, 151, 166), 18));
		Shadows = {ThemeBuilder.Shadow(Color3.new(0, 0, 0), .62, UDim2.fromOffset(0, 6), UDim.new(0, 12), UDim2.fromOffset(4, 4));};
	})
	:Surface('Success', {
		BackgroundColor3 = Success;
		BackgroundTransparency = 0;
		Corner = ThemeBuilder.Corner(18);
		Gradient = SurfaceDepthGradient(Color3.fromRGB(165, 231, 112), Success, Color3.fromRGB(103, 172, 61), 90);
		ShineOverlay = TransientSurfaceShine(Success, Color3.fromRGB(165, 231, 112), Color3.fromRGB(220, 255, 190), 108);
		Stroke = ThemeBuilder.Stroke(Color3.fromRGB(103, 172, 61), 2, .08, TransientBorderShine(Color3.fromRGB(244, 255, 230), Color3.fromRGB(178, 238, 127), 18));
		Shadows = {ThemeBuilder.Shadow(Color3.fromRGB(53, 96, 35), .72, UDim2.fromOffset(0, 7), UDim.new(0, 10), UDim2.fromOffset(3, 3));};
	})
	:Surface('Danger', {
		BackgroundColor3 = Danger;
		BackgroundTransparency = 0;
		Corner = ThemeBuilder.Corner(18);
		Gradient = SurfaceDepthGradient(Color3.fromRGB(247, 119, 88), Danger, Color3.fromRGB(183, 65, 39), 90);
		ShineOverlay = TransientSurfaceShine(Danger, Color3.fromRGB(247, 119, 88), Color3.fromRGB(255, 190, 168), 108);
		Stroke = ThemeBuilder.Stroke(Color3.fromRGB(183, 65, 39), 2, .07, TransientBorderShine(Color3.fromRGB(255, 229, 218), Color3.fromRGB(255, 137, 104), 18));
		Shadows = {ThemeBuilder.Shadow(Color3.fromRGB(99, 37, 20), .72, UDim2.fromOffset(0, 7), UDim.new(0, 10), UDim2.fromOffset(3, 3));};
	})
	:Component('Frame', {Surface = 'Clear';})
	:Component('Panel', {Surface = 'Cream'; Padding = {20;}; Gap = 12; Direction = 'Column'; Align = 'Start'; Justify = 'Start';})
	:Component('Card', {Surface = 'CreamSoft'; Padding = {16;}; Gap = 8; Direction = 'Column'; Align = 'Start'; Justify = 'Start';})
	:Component('PillButton', {Surface = 'Cream'; Width = 330; Height = 68; Padding = {12, 22;}; Gap = 10; Direction = 'Row'; Align = 'Center'; Justify = 'Center'; Motion = {Hover = 'Lift'; Press = 'Press'; ShineOnHover = true; ShineOnPress = true;};})
	:Component('PillSubtext', {Surface = 'Cream'; Width = 390; Height = 86; Padding = {12, 22;}; Gap = 12; Direction = 'Row'; Align = 'Center'; Justify = 'Center'; Motion = {Hover = 'Lift'; Press = 'Press'; ShineOnHover = true; ShineOnPress = true;};})
	:Component('IconButton', {Surface = 'Cream'; Width = 58; Height = 58; Padding = {10;}; Direction = 'Row'; Align = 'Center'; Justify = 'Center'; Motion = {Hover = 'Lift'; Press = 'Press'; ShineOnHover = true; ShineOnPress = true;};})
	:Component('Notification', {Surface = 'CreamSoft'; Width = 470; Height = 86; Padding = {12, 18;}; Gap = 12; Direction = 'Row'; Align = 'Center'; Justify = 'Center';})
	:Component('Achievement', {Surface = 'Gold'; Width = 470; Height = 94; Padding = {12, 18;}; Gap = 12; Direction = 'Row'; Align = 'Center'; Justify = 'Center';})
	:Component('ShinyText', {Surface = 'Gold'; Width = 500; Height = 84; Padding = {12, 22;};})
	:Component('Modal', {Surface = 'Cream'; Width = 560; Height = 'auto'; Padding = {24;}; Gap = 16; Direction = 'Column'; Align = 'Start'; Justify = 'Start';})
	:Component('ProgressBar', {Surface = 'CreamSoft'; FillSurface = 'Gold'; Width = 320; Height = 22; Padding = {0;};})
	:Component('Scroller', {Width = '100%'; Height = '100%'; Gap = 10; AutoCanvasPadding = 5; ScrollBarThickness = 5; ScrollBarMargin = 0; ScrollBarInset = 0; MinThumbSize = 24; ScrollBarTrackSurface = 'CreamSoft'; ScrollBarThumbSurface = 'Gold';})
	:Motion('FadeIn', {Duration = .2; FromTransparency = 1;})
	:Motion('PopIn', {Duration = .22; FromScale = .86; ToScale = 1; EasingStyle = Enum.EasingStyle.Back;})
	:Motion('ScaleIn', {Duration = .18; FromScale = .92; ToScale = 1;})
	:Motion('SlideUp', {Duration = .22; Offset = Vector2.new(0, 24);})
	:Motion('SlideDown', {Duration = .22; Offset = Vector2.new(0, -24);})
	:Motion('SlideLeft', {Duration = .22; Offset = Vector2.new(24, 0);})
	:Motion('SlideRight', {Duration = .22; Offset = Vector2.new(-24, 0);})
	:Motion('Lift', {Duration = .12; ToScale = 1.025;})
	:Motion('Press', {Duration = .08; ToScale = .96;})

return Builder:Build();
