-- Author -> lolokdev.
-- Last Edit -> September 13, 2026 7:07 PM CDT

local DeepCopy = require(script.Parent.Parent.Util.DeepCopy)

local Definition = {}

-- normalizeVersion -> number
-- Validates and resolves the clean Version alias into VAULT's internal schema version.
-- @param Source, table -> Raw datastore definition.
local function normalizeVersion(Source)
	local Version = Source.Version or Source.SchemaVersion or 1

	assert(type(Version) == 'number', 'VAULT datastore Version must be a number.')
	assert(Version >= 1 and Version % 1 == 0, 'VAULT datastore Version must be a positive integer.')

	return Version;
end

-- normalizeData -> table
-- Resolves the clean Data alias into VAULT's internal template.
-- @param Source, table -> Raw datastore definition.
local function normalizeData(Source)
	local Data = Source.Data or Source.Template

	assert(type(Data) == 'table', 'VAULT datastore definition requires a Data table.')

	return DeepCopy.Copy(Data);
end

-- Normalize -> table
-- Converts a clean game-facing datastore definition into the complete internal VAULT definition.
-- @param Name, string -> Logical store name.
-- @param Source, table -> Raw clean or legacy datastore definition.
function Definition.Normalize(Name: string, Source)
	assert(type(Name) == 'string' and Name ~= '', 'VAULT datastore requires a valid name.')
	assert(type(Source) == 'table', 'VAULT datastore definition must be a table.')

	local Result = DeepCopy.Copy(Source)

	Result.Name = Name
	Result.DataStoreName = Source.DataStore or Source.DataStoreName or Name
	Result.SchemaVersion = normalizeVersion(Source)
	Result.Template = normalizeData(Source)
	Result.Rules = DeepCopy.Copy(Source.Rules or {})
	Result.Migrations = DeepCopy.Copy(Source.Migrations or {})
	Result.Config = DeepCopy.Copy(Source.Config or {})
	Result.Scope = Source.Scope
	Result.KeyPrefix = Source.Prefix or Source.KeyPrefix
	Result.AutoBind = Source.Players == true or Source.BindPlayers == true

	return Result;
end

return Definition;
