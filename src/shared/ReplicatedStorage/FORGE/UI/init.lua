-- Author -> lolokdev.
-- Last Edit -> September 16, 2026 12:46 AM CDT

local RunService = game:GetService('RunService')

local State = require(script.State)
local Theme = require(script.Theme)
local ThemeBuilder = require(script.ThemeBuilder)
local Typography = require(script.Typography)
local Components = require(script.Components)
local Nodes = require(script.Nodes)
local Layout = require(script.Layout)
local Motion = require(script.Motion)
local Renderer = require(script.Renderer)
local Codec = require(script.Codec)
local Schema = require(script.Schema)
local Document = require(script.Document)
local ScreenManager = require(script.ScreenManager)

local UI = {} do
	UI.StateClass = State
	UI.Theme = Theme
	UI.ThemeBuilder = ThemeBuilder
	UI.Typography = Typography
	UI.Components = Components
	UI.Layout = Layout
	UI.Motion = Motion
	UI.Renderer = Renderer
	UI.Codec = Codec
	UI.Schema = Schema
	UI.Document = Document
	UI.Documents = ScreenManager
	UI.FORGE = nil

	function UI._AttachFORGE(FORGE)
		UI.FORGE = FORGE
		ScreenManager.AttachFORGE(FORGE)
	end

	function UI.State(Value)
		return State.new(Value);
	end

	function UI.Computed(Dependencies, Callback)
		return State.Computed(Dependencies, Callback);
	end

	function UI.Bind(StateObject, Transform)
		return {__UIBinding = true; State = StateObject; Transform = Transform or function(Value) return Value end;};
	end

	function UI.Ref()
		return {__UIRef = true; Current = nil;};
	end

	function UI.Element(ClassName, Props, Children)
		return Nodes.Element(ClassName, Props, Children);
	end

	function UI.Text(ClassName, Text, Props)
		Props = Props or {}
		Props.Text = Text
		Props.TextClass = ClassName
		Props.BackgroundTransparency = Props.BackgroundTransparency == nil and 1 or Props.BackgroundTransparency
		return Nodes.Element('TextLabel', Props);
	end

	function UI.Fragment(Children)
		return Nodes.Fragment(Children);
	end

	function UI.Zone(Name, Props, Children)
		return Nodes.Zone(Name, Props, Children);
	end

	function UI.Dynamic(StateObject, Callback, Name)
		return Nodes.Dynamic(StateObject, Callback, Name);
	end

	function UI.When(StateObject, Truthy, Falsy)
		return UI.Dynamic(StateObject, function(Value)
			if Value then return type(Truthy) == 'function' and Truthy(Value) or Truthy end
			return type(Falsy) == 'function' and Falsy(Value) or Falsy
		end, '_When');
	end

	function UI.Each(StateObject, Callback)
		return UI.Dynamic(StateObject, function(Values)
			local Children = {}
			for Index, Value in ipairs(Values or {}) do table.insert(Children, Callback(Value, Index)) end
			return UI.Fragment(Children)
		end, '_Each');
	end

	function UI.Component(Name, Props, Children)
		local Factory = Components[Name]
		if Factory then return Factory(Props or {}, Children or {}) end
		return Nodes.Custom(Name, Props, Children);
	end

	function UI.Use(Name, Props, Children)
		return UI.Component(Name, Props, Children);
	end

	function UI.Define(Name, Factory)
		Renderer.RegisterComponent(Name, Factory)
	end

	function UI.RegisterProperty(Name, Handler)
		Renderer.RegisterProperty(Name, Handler)
	end

	function UI.Edge(Top, Right, Bottom, Left)
		if Right == nil then return {Top = Top; Right = Top; Bottom = Top; Left = Top;} end
		if Bottom == nil then return {Top = Top; Right = Right; Bottom = Top; Left = Right;} end
		if Left == nil then return {Top = Top; Right = Right; Bottom = Bottom; Left = Right;} end
		return {Top = Top; Right = Right; Bottom = Bottom; Left = Left;};
	end

	function UI.SetTheme(Values)
		return Theme.Replace(Values);
	end

	function UI.Mount(Node, Options)
		assert(RunService:IsClient(), 'FORGE.UI can only mount interfaces on the client.')
		return Renderer.Mount(Node, Options);
	end

	function UI.Preview(Node, Parent, Options)
		return Renderer.Preview(Node, Parent, Options);
	end

	function UI.FromDocument(Source, Context)
		return Document.ToNode(Source, Context);
	end

	function UI.LoadDocument(Name, Context)
		local Source = Document.Find(Name)
		assert(Source, 'FORGE.UI document not found: ' .. tostring(Name))
		return Document.ToNode(Source, Context);
	end

	function UI.Show(Name, Context, Options)
		return ScreenManager.Show(Name, Context, Options);
	end

	function UI.Hide(Name, Options)
		return ScreenManager.Hide(Name, Options);
	end

	function UI.Toggle(Name, Context, Options)
		return ScreenManager.Toggle(Name, Context, Options);
	end

	function UI.SetState(DocumentName, BeforeIdentifier, NextState)
		return ScreenManager.SetState(DocumentName, BeforeIdentifier, NextState);
	end

	function UI.GetState(DocumentName, BeforeIdentifier)
		return ScreenManager.GetState(DocumentName, BeforeIdentifier);
	end

	function UI.Unmount(Name)
		return ScreenManager.Unmount(Name);
	end

	function UI.Refresh(Name)
		return ScreenManager.Refresh(Name);
	end

	function UI.ListOpen()
		return ScreenManager.ListOpen();
	end

	function UI.IsOpen(Name)
		return ScreenManager.IsOpen(Name);
	end

	function UI.HideGroup(Name, Except)
		return ScreenManager.HideGroup(Name, Except);
	end

	function UI.CloseAll(Except)
		return ScreenManager.CloseAll(Except);
	end

	function UI.RegisterAction(Name, Callback)
		return ScreenManager.RegisterAction(Name, Callback);
	end

	function UI.Start(Context)
		return ScreenManager.Start(Context);
	end

	function UI.GetService(Name)
		assert(UI.FORGE, 'FORGE.UI is not attached to FORGE.')
		return UI.FORGE.GetService(Name);
	end

	function UI.GetController(Name)
		assert(UI.FORGE, 'FORGE.UI is not attached to FORGE.')
		return UI.FORGE.GetController(Name);
	end
end

return UI;
