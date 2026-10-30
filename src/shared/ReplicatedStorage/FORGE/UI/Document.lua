-- Author -> lolokdev.
-- Last Edit -> September 16, 2026 12:46 AM CDT

local HttpService = game:GetService('HttpService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local Codec = require(script.Parent.Codec)
local Components = require(script.Parent.Components)
local Nodes = require(script.Parent.Nodes)
local Schema = require(script.Parent.Schema)

local Document = {} do
	Document.Version = 4
	Document.StoreName = 'FORGE_UI_Documents'
	Document.ValueName = '_DocumentJSON'

	local DefaultMeta = {
		AutoShow = false;
		Group = 'Default';
		DisplayOrder = 0;
		CloseOthers = false;
		KeepAlive = true;
		ResetOnSpawn = false;
		IgnoreGuiInset = false;
		ScaleMode = 'Fit';
		Margin = {0, 0, 0, 0;};
		ReferenceSize = Vector2.new(1920, 1080);
		MinScale = .35;
		MaxScale = 1.5;
		Controller = '';
	}

	local function id()
		return HttpService:GenerateGUID(false);
	end

	local function clone(Value, Seen)
		if type(Value) ~= 'table' then return Value end
		Seen = Seen or {}
		if Seen[Value] then return Seen[Value] end
		local Result = {}
		Seen[Value] = Result
		for Key, Child in pairs(Value) do Result[clone(Key, Seen)] = clone(Child, Seen) end
		return Result;
	end

	local function merge(Target, Source)
		for Key, Value in pairs(Source or {}) do
			if Target[Key] == nil then Target[Key] = clone(Value) end
		end
		return Target;
	end

	local function normalizeNode(Node)
		Node = Node or {}
		Node.Id = Node.Id or id()
		Node.Props = Node.Props or {}
		Node.Children = Node.Children or {}
		Node.Events = Node.Events or {}
		Node.Bindings = Node.Bindings or {}
		for _, Child in ipairs(Node.Children) do normalizeNode(Child) end
		return Node;
	end

	local function enumValue(Value, EnumType)
		if typeof(Value) == 'EnumItem' then return Value end
		if type(Value) == 'string' and EnumType and EnumType[Value] then return EnumType[Value] end
		return Value;
	end

	local function edge(Value)
		if type(Value) ~= 'string' then return Value end
		local Values = {}
		for Token in string.gmatch(Value, '[^,%s]+') do
			local Number = tonumber(Token)
			if Number then table.insert(Values, Number) end
		end
		if #Values == 0 then return Value end
		return Values;
	end

	local function size(Value)
		if type(Value) ~= 'string' then return Value end
		local Trimmed = string.gsub(Value, '^%s*(.-)%s*$', '%1')
		local Number = tonumber(Trimmed)
		return Number or Trimmed;
	end

	local function props(Node, Context)
		local Result = clone(Node.Props or {})
		for Key, Value in pairs(Result) do
			if Key == 'Margin' or Key == 'Padding' then Result[Key] = edge(Value) end
			if Key == 'Width' or Key == 'Height' then Result[Key] = size(Value) end
			if Key == 'TextXAlignment' then Result[Key] = enumValue(Value, Enum.TextXAlignment) end
			if Key == 'TextYAlignment' then Result[Key] = enumValue(Value, Enum.TextYAlignment) end
		end

		Result.Attributes = Result.Attributes or {}
		Result.Attributes.FORGEUIEditorId = Node.Id
		if type(Node.StatePair) == 'table' then
			Result.Attributes.FORGEUIStateRole = Node.StatePair.Role
			Result.Attributes.FORGEUIStateBeforeId = Node.StatePair.Role == 'Before' and Node.Id or Node.StatePair.BeforeId
			if Node.StatePair.Role == 'After' then Result.Visible = false end
		end

		for EventName, Action in pairs(Node.Events or {}) do
			if Action ~= nil and Action ~= '' then
				Result['On' .. EventName] = function(...)
					if Context and Context.Manager and Context.Manager.Execute then
						return Context.Manager.Execute(Action, Context, ...)
					end
					if type(Action) == 'string' then
						if Context and Context.Actions and type(Context.Actions[Action]) == 'function' then return Context.Actions[Action](...) end
						if Context and Context.Controller and type(Context.Controller[Action]) == 'function' then return Context.Controller[Action](Context.Controller, ...) end
					end
				end
			end
		end

		for Property, Definition in pairs(Node.Bindings or {}) do
			local StateName = type(Definition) == 'table' and Definition.State or Definition
			local StateObject = Context and Context.States and Context.States[StateName]
			if StateObject then
				local Format = type(Definition) == 'table' and Definition.Format or nil
				Result[Property] = {
					__UIBinding = true;
					State = StateObject;
					Transform = function(Value)
						if Format then return string.gsub(Format, '{value}', tostring(Value)) end
						return Value;
					end;
				}
			end
		end

		return Result;
	end

	local function compile(Node, Context)
		if not Node then return nil end
		local Children = {}
		for _, Child in ipairs(Node.Children or {}) do
			local Compiled = compile(Child, Context)
			if Compiled then table.insert(Children, Compiled) end
		end

		if Node.Kind == 'Zone' then
			local Properties = props(Node, Context)
			local ZoneName = Node.Zone or Properties.Zone or 'Center'
			Properties.Zone = nil
			return Nodes.Zone(ZoneName, Properties, Children);
		elseif Node.Kind == 'Fragment' then
			return Nodes.Fragment(Children);
		elseif Node.Kind == 'Element' then
			return Nodes.Element(Node.ClassName or 'Frame', props(Node, Context), Children);
		elseif Node.Kind == 'Component' then
			local Factory = Components[Node.Component]
			if not Factory then return nil end
			return Factory(props(Node, Context), Children);
		end
		return nil;
	end

	function Document.New(Name)
		Name = Name or 'Untitled'
		local Meta = clone(DefaultMeta)
		if Name == 'MainMenu' or Name == 'Lobby' or Name == 'Game' or Name == 'GameUI' then Meta.AutoShow = true end

		return Document.Normalize({
			Version = Document.Version;
			Name = Name;
			Meta = Meta;
			Root = {
				Kind = 'Component';
				Component = 'Page';
				Props = {Name = 'Page'; Surface = 'Clear'; Width = '100%'; Height = '100%'; FillViewport = true;};
				Children = {};
			};
		});
	end

	function Document.CreateNode(ComponentName)
		local Definition = Schema.Get(ComponentName) or {}
		if ComponentName == 'Zone' then
			return normalizeNode({Kind = 'Zone'; Zone = 'Center'; Props = clone(Definition.Defaults or {}); Children = {};});
		end
		return normalizeNode({Kind = 'Component'; Component = ComponentName; Props = clone(Definition.Defaults or {}); Children = {};});
	end

	function Document.Normalize(Data)
		if not Data then return Document.New('Untitled') end
		Data.Version = Document.Version
		Data.Name = tostring(Data.Name or 'Untitled')
		Data.Meta = merge(Data.Meta or {}, DefaultMeta)
		Data.Root = normalizeNode(Data.Root or {Kind = 'Component'; Component = 'Page'; Props = {}; Children = {};})
		return Data;
	end

	function Document.ToNode(Source, Context)
		local Data = Document.Read(Source)
		return compile(Data.Root, Context or {});
	end

	function Document.Store(Parent)
		Parent = Parent or ReplicatedStorage
		local Store = Parent:FindFirstChild(Document.StoreName)
		if Store and not Store:IsA('Folder') then Store:Destroy(); Store = nil end
		if not Store then
			Store = Instance.new('Folder')
			Store.Name = Document.StoreName
			Store.Parent = Parent
		end
		Store:SetAttribute('FORGEUIDocumentStore', true)
		Store:SetAttribute('FormatVersion', Document.Version)
		return Store;
	end

	function Document.Save(Data, Parent)
		Data = Document.Normalize(Data)
		assert(Data.Name ~= '', 'FORGE.UI document requires a non-empty name.')
		local Encoded = Codec.EncodeJSON(Data)
		local RoundTrip = Document.Normalize(Codec.DecodeJSON(Encoded))
		assert(RoundTrip.Name == Data.Name, 'FORGE.UI document failed serialization round-trip.')

		local Store = Document.Store(Parent)
		local Container = Store:FindFirstChild(Data.Name)
		if Container and not Container:IsA('Folder') then Container:Destroy(); Container = nil end
		if not Container then
			Container = Instance.new('Folder')
			Container.Name = Data.Name
			Container.Parent = Store
		end

		local Revision = (tonumber(Container:GetAttribute('Revision')) or 0) + 1
		Container:SetAttribute('FORGEUIDocument', true)
		Container:SetAttribute('Version', Data.Version)
		Container:SetAttribute('SchemaVersion', Schema.Version)
		Container:SetAttribute('Revision', Revision)
		Container:SetAttribute('SyncedAt', os.time())
		Container:SetAttribute('AutoShow', Data.Meta.AutoShow == true)
		Container:SetAttribute('Group', Data.Meta.Group or 'Default')
		Container:SetAttribute('DisplayOrder', tonumber(Data.Meta.DisplayOrder) or 0)
		Container:SetAttribute('CloseOthers', Data.Meta.CloseOthers == true)
		Container:SetAttribute('KeepAlive', Data.Meta.KeepAlive ~= false)

		local Value = Container:FindFirstChild(Document.ValueName)
		if Value and not Value:IsA('StringValue') then Value:Destroy(); Value = nil end
		if not Value then
			Value = Instance.new('StringValue')
			Value.Name = Document.ValueName
			Value.Parent = Container
		end
		Value.Value = Encoded
		return Container, #Encoded, Revision;
	end

	function Document.Delete(Name, Parent)
		local Store = (Parent or ReplicatedStorage):FindFirstChild(Document.StoreName)
		local Container = Store and Store:FindFirstChild(Name)
		if Container then Container:Destroy(); return true end
		return false;
	end

	function Document.List(Parent)
		local Store = (Parent or ReplicatedStorage):FindFirstChild(Document.StoreName)
		local Result = {}
		if not Store then return Result end
		for _, Child in ipairs(Store:GetChildren()) do
			if Child:IsA('Folder') and Child:FindFirstChild(Document.ValueName) then table.insert(Result, Child.Name) end
		end
		table.sort(Result)
		return Result;
	end

	function Document.Find(Name, Parent)
		local Store = (Parent or ReplicatedStorage):FindFirstChild(Document.StoreName)
		local Found = Store and Store:FindFirstChild(tostring(Name)) or nil
		if Found and Found:FindFirstChild(Document.ValueName) then return Found end
		return nil;
	end

	function Document.Read(Source)
		if type(Source) == 'table' then return Document.Normalize(clone(Source)) end
		if type(Source) == 'string' then return Document.Normalize(Codec.DecodeJSON(Source)) end
		if typeof(Source) ~= 'Instance' then error('Invalid FORGE.UI document source.') end
		if Source:IsA('ModuleScript') then return Document.Normalize(require(Source)) end
		if Source:IsA('StringValue') then return Document.Normalize(Codec.DecodeJSON(Source.Value)) end
		local Value = Source:FindFirstChild(Document.ValueName)
		assert(Value and Value:IsA('StringValue'), 'FORGE.UI document does not contain ' .. Document.ValueName)
		assert(Value.Value ~= '', 'FORGE.UI document JSON is empty: ' .. Source.Name)
		return Document.Normalize(Codec.DecodeJSON(Value.Value));
	end

	function Document.ToLua(Source)
		local Data = Document.Read(Source)
		return '-- Author -> lolokdev.\n-- Generated by FORGE UI Editor.\n\nreturn ' .. Codec.ToLua(Data, 0) .. ';\n';
	end

	function Document.FindNode(Data, Id)
		Data = Document.Normalize(Data)
		local function visit(Node, Parent, Index)
			if Node.Id == Id then return Node, Parent, Index end
			for ChildIndex, Child in ipairs(Node.Children or {}) do
				local Found, FoundParent, FoundIndex = visit(Child, Node, ChildIndex)
				if Found then return Found, FoundParent, FoundIndex end
			end
		end
		return visit(Data.Root, nil, nil);
	end

	function Document.CloneNode(Node)
		local Result = clone(Node)
		local Rekeyed = {}
		local function rekey(Current)
			local Original = Current.Id
			Current.Id = id()
			if Original then Rekeyed[Original] = Current.Id end
			for _, Child in ipairs(Current.Children or {}) do rekey(Child) end
		end
		local function remap(Current)
			local Pair = Current.StatePair
			if type(Pair) == 'table' then
				local Linked = Pair.Role == 'Before' and Pair.AfterId or Pair.BeforeId
				if Linked and Rekeyed[Linked] then
					if Pair.Role == 'Before' then Pair.AfterId = Rekeyed[Linked]
					else Pair.BeforeId = Rekeyed[Linked] end
				else
					Current.StatePair = nil
				end
			end
			for _, Child in ipairs(Current.Children or {}) do remap(Child) end
		end
		rekey(Result)
		remap(Result)
		return Result;
	end

end

return Document;
