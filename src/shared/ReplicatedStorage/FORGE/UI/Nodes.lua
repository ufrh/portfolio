-- Author -> lolokdev.
-- Last Edit -> September 15, 2026 7:06 PM CDT

local Nodes = {} do
	local function node(Kind, Data)
		Data = Data or {}
		Data.__UINode = true
		Data.Kind = Kind
		return Data;
	end

	function Nodes.Element(ClassName, Props, Children)
		return node('Element', {ClassName = ClassName; Props = Props or {}; Children = Children or {};});
	end


	function Nodes.Page(ClassName, Props, Children)
		return node('Page', {ClassName = ClassName or 'Frame'; Props = Props or {}; Children = Children or {};});
	end

	function Nodes.Fragment(Children)
		return node('Fragment', {Children = Children or {};});
	end

	function Nodes.Zone(Name, Props, Children)
		return node('Zone', {Zone = Name; Props = Props or {}; Children = Children or {};});
	end

	function Nodes.Dynamic(StateObject, Callback, Name)
		return node('Dynamic', {State = StateObject; Render = Callback; Name = Name;});
	end

	function Nodes.Custom(Name, Props, Children)
		return node('Custom', {Component = Name; Props = Props or {}; Children = Children or {};});
	end
end

return Nodes;
