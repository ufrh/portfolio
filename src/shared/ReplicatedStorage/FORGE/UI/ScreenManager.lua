-- Author -> lolokdev.
-- Last Edit -> September 16, 2026 12:46 AM CDT

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')

local Signal = require(script.Parent.Parent.Core.Signal)
local Document = require(script.Parent.Document)
local Renderer = require(script.Parent.Renderer)

local ScreenManager = {} do
	ScreenManager.FORGE = nil
	ScreenManager.Started = false
	ScreenManager.Screens = {}
	ScreenManager.Actions = {}
	ScreenManager.Connections = {}
	ScreenManager.Changed = Signal.new()

	local function merge(...)
		local Result = {}
		for _, Source in ipairs({...}) do
			for Key, Value in pairs(Source or {}) do Result[Key] = Value end
		end
		return Result;
	end

	local function edge(Value)
		if type(Value) ~= 'table' then return Value end
		if Value.Top ~= nil then return Value end
		if #Value == 1 then return Value[1] end
		if #Value == 2 then return {Top = Value[1]; Right = Value[2]; Bottom = Value[1]; Left = Value[2];} end
		if #Value == 3 then return {Top = Value[1]; Right = Value[2]; Bottom = Value[3]; Left = Value[2];} end
		if #Value >= 4 then return {Top = Value[1]; Right = Value[2]; Bottom = Value[3]; Left = Value[4];} end
		return Value;
	end

	local function contextFor(Name, Data, Context)
		Context = merge(Context)
		Context.DocumentName = Name
		Context.Manager = ScreenManager
		Context.Actions = merge(ScreenManager.Actions, Context.Actions)
		Context.FORGE = ScreenManager.FORGE
		if not Context.Controller and Data.Meta and Data.Meta.Controller and Data.Meta.Controller ~= '' and ScreenManager.FORGE then
			local Success, Controller = pcall(ScreenManager.FORGE.GetController, Data.Meta.Controller)
			if Success then Context.Controller = Controller end
		end
		return Context;
	end

	local function optionsFor(Name, Data, Options)
		local Meta = Data.Meta or {}
		return merge({
			Name = 'FORGE_Document_' .. Name;
			DisplayOrder = tonumber(Meta.DisplayOrder) or 0;
			ResetOnSpawn = Meta.ResetOnSpawn == true;
			IgnoreGuiInset = Meta.IgnoreGuiInset == true;
			ScaleMode = Meta.ScaleMode or 'Fit';
			Margin = edge(Meta.Margin or 0);
			ReferenceSize = Meta.ReferenceSize or Vector2.new(1920, 1080);
			MinScale = tonumber(Meta.MinScale) or .35;
			MaxScale = tonumber(Meta.MaxScale) or 1.5;
		}, Options);
	end

	local function fire(Name, State)
		ScreenManager.Changed:Fire(Name, State, ScreenManager.Screens[Name])
	end

	local function revisionOf(Source)
		return Source and tonumber(Source:GetAttribute('Revision')) or 0;
	end

	function ScreenManager.AttachFORGE(FORGE)
		ScreenManager.FORGE = FORGE
	end

	function ScreenManager.RegisterAction(Name, Callback)
		assert(type(Name) == 'string' and Name ~= '', 'FORGE.UI document action requires a name.')
		assert(type(Callback) == 'function', 'FORGE.UI document action requires a callback.')
		ScreenManager.Actions[Name] = Callback
		return function()
			if ScreenManager.Actions[Name] == Callback then ScreenManager.Actions[Name] = nil end
		end;
	end

	function ScreenManager.Show(Name, Context, Options)
		assert(RunService:IsClient(), 'FORGE.UI.Show is client-only.')
		Name = tostring(Name)
		local Source = Document.Find(Name)
		assert(Source, 'FORGE.UI document not found: ' .. Name)
		local Data = Document.Read(Source)
		local Meta = Data.Meta or {}
		local Revision = revisionOf(Source)

		if Meta.CloseOthers == true then ScreenManager.HideGroup(Meta.Group or 'Default', Name) end

		local Existing = ScreenManager.Screens[Name]
		if Existing and Existing.Revision ~= Revision then
			local WasVisible = Existing.Visible
			local ExistingContext = Context or Existing.Context
			ScreenManager.Unmount(Name)
			if not WasVisible then return nil end
			return ScreenManager.Show(Name, ExistingContext, Options)
		end
		if Existing then
			if Context then Existing.Context = contextFor(Name, Data, Context) end
			local Screen = Existing.Handle and Existing.Handle.Root and Existing.Handle.Root.Screen
			if Screen then Screen.Enabled = true end
			Existing.Visible = true
			fire(Name, 'Shown')
			return Existing;
		end

		local RuntimeContext = contextFor(Name, Data, Context)
		local Node = Document.ToNode(Data, RuntimeContext)
		local Handle = Renderer.Mount(Node, optionsFor(Name, Data, Options))
		local Screen = Handle.Root and Handle.Root.Screen
		if Screen then
			Screen.Enabled = true
			Screen:SetAttribute('FORGEUIDocument', true)
			Screen:SetAttribute('FORGEUIDocumentName', Name)
			Screen:SetAttribute('FORGEUIGroup', Meta.Group or 'Default')
			Screen:SetAttribute('FORGEUIRevision', Revision)
		end

		local Entry = {
			Name = Name;
			Data = Data;
			Meta = Meta;
			Context = RuntimeContext;
			Handle = Handle;
			Visible = true;
			Revision = Revision;
		}
		ScreenManager.Screens[Name] = Entry
		fire(Name, 'Shown')
		return Entry;
	end

	function ScreenManager.Hide(Name, Options)
		Name = tostring(Name)
		local Entry = ScreenManager.Screens[Name]
		if not Entry then return false end
		Options = Options or {}
		local Destroy = Options.Destroy == true or Entry.Meta.KeepAlive == false
		if Destroy then
			Entry.Handle:Destroy()
			ScreenManager.Screens[Name] = nil
			fire(Name, 'Unmounted')
		else
			local Screen = Entry.Handle and Entry.Handle.Root and Entry.Handle.Root.Screen
			if Screen then Screen.Enabled = false end
			Entry.Visible = false
			fire(Name, 'Hidden')
		end
		return true;
	end

	function ScreenManager.Toggle(Name, Context, Options)
		if ScreenManager.IsOpen(Name) then ScreenManager.Hide(Name, Options); return false end
		ScreenManager.Show(Name, Context, Options)
		return true;
	end

	function ScreenManager.Unmount(Name)
		return ScreenManager.Hide(Name, {Destroy = true;});
	end

	function ScreenManager.IsOpen(Name)
		local Entry = ScreenManager.Screens[tostring(Name)]
		return Entry ~= nil and Entry.Visible == true;
	end

	function ScreenManager.Get(Name)
		return ScreenManager.Screens[tostring(Name)];
	end

	local function pairFor(Entry, BeforeIdentifier)
		local function visit(Node)
			local Pair = Node.StatePair
			if type(Pair) == 'table' and Pair.Role == 'Before' then
				local NodeName = Node.Props and Node.Props.Name
				if Node.Id == BeforeIdentifier or NodeName == BeforeIdentifier then
					return Node.Id, Pair.AfterId;
				end
			end
			for _, Child in ipairs(Node.Children or {}) do
				local A, B = visit(Child)
				if A then return A, B end
			end
		end
		return Entry and Entry.Data and visit(Entry.Data.Root);
	end

	function ScreenManager.SetState(DocumentName, BeforeIdentifier, NextState)
		local Entry = ScreenManager.Screens[tostring(DocumentName)]
		if not Entry or not Entry.Handle then return false end
		local BeforeId, AfterId = pairFor(Entry, BeforeIdentifier)
		if not BeforeId or not AfterId then return false end
		local ShowAfter = NextState == 'After' or NextState == true
		local Container = Entry.Handle.Root and Entry.Handle.Root.Viewport
		if not Container then return false end
		local Before, After
		for _, Object in ipairs(Container:GetDescendants()) do
			if Object:IsA('GuiObject') then
				local NodeId = Object:GetAttribute('FORGEUIEditorId')
				if NodeId == BeforeId then Before = Object end
				if NodeId == AfterId then After = Object end
			end
		end
		if not Before or not After then return false end
		Before.Visible = not ShowAfter
		After.Visible = ShowAfter
		Entry.StateValues = Entry.StateValues or {}
		Entry.StateValues[BeforeId] = ShowAfter and 'After' or 'Before'
		return true;
	end

	function ScreenManager.GetState(DocumentName, BeforeIdentifier)
		local Entry = ScreenManager.Screens[tostring(DocumentName)]
		local BeforeId = Entry and pairFor(Entry, BeforeIdentifier)
		return BeforeId and Entry.StateValues and Entry.StateValues[BeforeId] or (BeforeId and 'Before' or nil);
	end

	function ScreenManager.ListOpen()
		local Result = {}
		for Name, Entry in pairs(ScreenManager.Screens) do if Entry.Visible then table.insert(Result, Name) end end
		table.sort(Result)
		return Result;
	end

	function ScreenManager.HideGroup(Group, Except)
		Group = tostring(Group or 'Default')
		local Targets = {}
		for Name, Entry in pairs(ScreenManager.Screens) do
			if Name ~= Except and tostring(Entry.Meta.Group or 'Default') == Group then table.insert(Targets, Name) end
		end
		for _, Name in ipairs(Targets) do ScreenManager.Hide(Name) end
	end

	function ScreenManager.CloseAll(Except)
		local Targets = {}
		for Name in pairs(ScreenManager.Screens) do if Name ~= Except then table.insert(Targets, Name) end end
		for _, Name in ipairs(Targets) do ScreenManager.Hide(Name) end
	end

	function ScreenManager.Refresh(Name)
		Name = tostring(Name)
		local Entry = ScreenManager.Screens[Name]
		if not Entry then return false end
		local WasVisible, Context = Entry.Visible, Entry.Context
		ScreenManager.Unmount(Name)
		if WasVisible then ScreenManager.Show(Name, Context) end
		return true;
	end

	function ScreenManager.Execute(Action, Context, ...)
		if type(Action) == 'string' then
			local Callback = ScreenManager.Actions[Action]
			if Callback then return Callback(...) end
			if Context and Context.Controller and type(Context.Controller[Action]) == 'function' then return Context.Controller[Action](Context.Controller, ...) end
			return nil;
		end
		if type(Action) ~= 'table' then return nil end
		local Type = Action.Type or 'Controller'
		local Name = Action.Name or Action.Action
		local Target = Action.Target
		if Type == 'Document' then
			Target = Target == '$self' and Context and Context.DocumentName or Target
			if Name == 'Show' then return ScreenManager.Show(Target, Context) end
			if Name == 'Hide' then return ScreenManager.Hide(Target) end
			if Name == 'Toggle' then return ScreenManager.Toggle(Target, Context) end
			if Name == 'Unmount' then return ScreenManager.Unmount(Target) end
			if Name == 'CloseAll' then return ScreenManager.CloseAll(Target) end
			if Name == 'HideGroup' then return ScreenManager.HideGroup(Target or 'Default') end
		elseif Type == 'State' and Context and Context.States then
			local StateObject = Context.States[Target]
			if not StateObject then return nil end
			if Name == 'Toggle' then return StateObject:Update(function(Value) return not Value end) end
			if Name == 'Increment' then return StateObject:Update(function(Value) return (tonumber(Value) or 0) + (tonumber(Action.Value) or 1) end) end
			if Name == 'Set' then return StateObject:Set(Action.Value) end
		elseif Type == 'Action' then
			local Callback = ScreenManager.Actions[Target or Name]
			if Callback then return Callback(...) end
		elseif Type == 'Controller' then
			local Controller = Context and Context.Controller
			if Action.Controller and ScreenManager.FORGE then
				local Success, Found = pcall(ScreenManager.FORGE.GetController, Action.Controller)
				if Success then Controller = Found end
			end
			if Controller and type(Controller[Target or Name]) == 'function' then return Controller[Target or Name](Controller, ...) end
		end
	end

	local function watchStore()
		local function attach(Store)
			if not Store or not Store:IsA('Folder') then return end
			local function watchDocument(Container)
				if not Container:IsA('Folder') then return end
				local function syncDocument()
					local Entry = ScreenManager.Screens[Container.Name]
					if Entry and Entry.Visible then
						local Success, Error = pcall(ScreenManager.Refresh, Container.Name)
						if not Success then warn('[FORGE.UI Refresh]', Error) end
						return
					end

					local Success, Data = pcall(Document.Read, Container)
					if Success and Data.Meta and Data.Meta.AutoShow == true then
						local ShowSuccess, Error = pcall(ScreenManager.Show, Container.Name)
						if not ShowSuccess then warn('[FORGE.UI AutoShow]', Error) end
					end
				end

				local function attachValue(Value)
					if not Value or not Value:IsA('StringValue') or Value.Name ~= Document.ValueName then return end
					table.insert(ScreenManager.Connections, Value:GetPropertyChangedSignal('Value'):Connect(syncDocument))
					task.defer(syncDocument)
				end
				attachValue(Container:FindFirstChild(Document.ValueName))
				table.insert(ScreenManager.Connections, Container.ChildAdded:Connect(attachValue))
			end
			for _, Child in ipairs(Store:GetChildren()) do watchDocument(Child) end
			table.insert(ScreenManager.Connections, Store.ChildAdded:Connect(function(Child) task.defer(watchDocument, Child) end))
		end

		local Existing = ReplicatedStorage:FindFirstChild(Document.StoreName)
		if Existing then
			attach(Existing)
		else
			local Connection
			Connection = ReplicatedStorage.ChildAdded:Connect(function(Child)
				if Child.Name == Document.StoreName and Child:IsA('Folder') then
					Connection:Disconnect()
					attach(Child)
				end
			end)
			table.insert(ScreenManager.Connections, Connection)
		end
	end

	function ScreenManager.Start(Context)
		if not RunService:IsClient() or ScreenManager.Started then return end
		ScreenManager.Started = true
		watchStore()
		for _, Name in ipairs(Document.List()) do
			local Source = Document.Find(Name)
			local Success, Data = pcall(Document.Read, Source)
			if Success and Data.Meta and Data.Meta.AutoShow == true then
				local ShowSuccess, Error = pcall(ScreenManager.Show, Name, Context)
				if not ShowSuccess then warn('[FORGE.UI]', Error) end
			end
		end
	end

	function ScreenManager.Destroy()
		local Targets = {}
		for Name in pairs(ScreenManager.Screens) do table.insert(Targets, Name) end
		for _, Name in ipairs(Targets) do ScreenManager.Unmount(Name) end
		for _, Connection in ipairs(ScreenManager.Connections) do Connection:Disconnect() end
		ScreenManager.Connections = {}
		ScreenManager.Started = false
	end
end

return ScreenManager;
