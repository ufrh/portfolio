-- Author -> lolokdev.
-- Last Edit -> September 15, 2026 1:10 PM CDT

local Root = script

local Guard = require(Root.Security.Guard)
local Store = require(Root.Core.Store)
local Definition = require(Root.Core.Definition)
local GlobalStore = require(Root.Global.GlobalStore)

local Data = {
	Stores = {},
	Globals = {},
	Config = require(Root.Config),
	Rules = require(Root.Security.Rules),
	Codec = require(Root.Serialization.Codec);
}

Guard.AssertServer()

-- compareModules -> boolean
-- Sorts datastore definition modules by name for deterministic startup.
-- @param A, ModuleScript -> First datastore module.
-- @param B, ModuleScript -> Second datastore module.
local function compareModules(A: ModuleScript, B: ModuleScript)
	return A.Name < B.Name;
end

-- defaultLimits -> table
-- Builds serialization limits for standalone global stores from FORGE.Data defaults.
local function defaultLimits()
	local Config = Data.Config.DataStore
	return {MaxDepth = Config.MaxDepth; MaxNodes = Config.MaxNodes; MaxStringLength = Config.MaxStringLength; MaxEncodedBytes = Config.MaxEncodedBytes;};
end

-- Store -> Store?
-- Creates a datastore from a clean definition or retrieves an existing store when no definition is supplied.
-- @param Name, string -> Logical FORGE.Data store name.
-- @param StoreDefinition, table? -> Clean datastore definition.
function Data.Store(Name: string, StoreDefinition)
	assert(type(Name) == 'string' and Name ~= '', 'FORGE.Data.Store requires a valid store name.')
	if StoreDefinition == nil then return Data.Stores[Name] end

	local Normalized = Definition.Normalize(Name, StoreDefinition)
	local Existing = Data.Stores[Normalized.Name]

	if Existing then
		if Normalized.AutoBind then Existing:BindPlayers() end
		return Existing;
	end

	local Created = Store.new(Normalized)
	Data.Stores[Normalized.Name] = Created
	if Normalized.AutoBind then Created:BindPlayers() end
	return Created;
end

-- CreateStore -> Store
-- Preserves the VAULT-compatible constructor while routing through the integrated FORGE.Data registry.
-- @param StoreDefinition, table -> Legacy or clean datastore definition.
function Data.CreateStore(StoreDefinition)
	assert(type(StoreDefinition) == 'table', 'FORGE.Data.CreateStore requires a definition table.')
	assert(type(StoreDefinition.Name) == 'string' and StoreDefinition.Name ~= '', 'FORGE.Data.CreateStore requires Definition.Name.')
	return Data.Store(StoreDefinition.Name, StoreDefinition);
end

-- Global -> GlobalStore
-- Creates or retrieves a standalone universe-wide atomic global store without requiring a player datastore.
-- @param Name, string -> Logical global store name.
-- @param Options, table? -> Optional Scope and serialization Limits overrides.
function Data.Global(Name: string, Options)
	assert(type(Name) == 'string' and Name ~= '', 'FORGE.Data.Global requires a valid global store name.')
	local Existing = Data.Globals[Name]
	if Existing then return Existing end
	Options = type(Options) == 'table' and Options or {}
	local Scope = type(Options.Scope) == 'string' and Options.Scope ~= '' and Options.Scope or Data.Config.DataStore.Scope
	local Limits = type(Options.Limits) == 'table' and Options.Limits or defaultLimits()
	local Created = GlobalStore.new(Name, Scope, Limits)
	Data.Globals[Name] = Created
	return Created;
end

-- GetGlobal -> GlobalStore?
-- Returns one already-created standalone global store.
-- @param Name, string -> Logical global store name.
function Data.GetGlobal(Name: string)
	return Data.Globals[Name];
end

-- DestroyGlobal -> boolean
-- Destroys one standalone global store and removes it from the registry.
-- @param Name, string -> Logical global store name.
function Data.DestroyGlobal(Name: string)
	local Existing = Data.Globals[Name]
	if not Existing then return false end
	Existing:Destroy()
	Data.Globals[Name] = nil
	return true;
end

-- Load -> table
-- Loads every datastore definition ModuleScript inside a folder and returns them by logical store name.
-- @param Folder, Instance -> Folder containing datastore definition modules.
function Data.Load(Folder: Instance)
	assert(typeof(Folder) == 'Instance', 'FORGE.Data.Load requires a Folder or Instance containing datastore modules.')

	local Modules = {}
	local Result = {}

	for _, Object in ipairs(Folder:GetChildren()) do if Object:IsA('ModuleScript') then table.insert(Modules, Object) end end
	table.sort(Modules, compareModules)

	for _, Module in ipairs(Modules) do
		local StoreDefinition = require(Module)
		assert(type(StoreDefinition) == 'table', 'FORGE.Data datastore module ' .. Module:GetFullName() .. ' must return a table.')
		if StoreDefinition.Enabled == false then continue end
		local Name = StoreDefinition.Name or Module.Name
		local Created = Data.Store(Name, StoreDefinition)
		Result[Name] = Created
	end

	return Result;
end

-- GetStore -> Store?
-- Returns an already-created datastore by logical name.
-- @param Name, string -> Store name.
function Data.GetStore(Name: string)
	return Data.Stores[Name];
end

-- DestroyStore -> boolean
-- Shuts down and removes one named datastore.
-- @param Name, string -> Store name.
function Data.DestroyStore(Name: string)
	local Existing = Data.Stores[Name]
	if not Existing then return false end
	Existing:Destroy()
	Data.Stores[Name] = nil
	return true;
end

-- DestroyAll -> nil
-- Shuts down every integrated player datastore and standalone global store registered in the current server.
function Data.DestroyAll()
	local StoreNames = {}
	local GlobalNames = {}
	for Name in pairs(Data.Stores) do table.insert(StoreNames, Name) end
	for Name in pairs(Data.Globals) do table.insert(GlobalNames, Name) end
	for _, Name in ipairs(StoreNames) do Data.DestroyStore(Name) end
	for _, Name in ipairs(GlobalNames) do Data.DestroyGlobal(Name) end
end

return Data;
