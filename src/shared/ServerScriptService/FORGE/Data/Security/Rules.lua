-- Author -> lolokdev.
-- Last Edit -> September 13, 2026 6:43 PM CDT

local Rules = {}

-- Number -> table
-- Creates a numeric path rule.
-- @param Options, table? -> Min, Max and Integer constraints.
function Rules.Number(Options)
	local Rule = Options or {}

	Rule.Type = 'number'

	return Rule;
end

-- String -> table
-- Creates a string path rule.
-- @param Options, table? -> MinLength, MaxLength and Pattern constraints.
function Rules.String(Options)
	local Rule = Options or {}

	Rule.Type = 'string'

	return Rule;
end

-- Boolean -> table
-- Creates a boolean path rule.
function Rules.Boolean()
	return {Type = 'boolean';};
end

-- Values -> table
-- Creates an allowed-value rule for one path.
-- @param Values, table -> Accepted literal values.
-- @param TypeName, string? -> Optional required typeof result.
function Rules.Values(Values, TypeName: string?)
	return {Type = TypeName; Values = Values;};
end

-- Custom -> table
-- Creates a custom server-side validation rule.
-- @param Callback, function -> Validator returning accepted, optional reason.
-- @param TypeName, string? -> Optional required typeof result.
function Rules.Custom(Callback, TypeName: string?)
	assert(type(Callback) == 'function', 'VAULT custom rule requires a function.')

	return {Type = TypeName; Custom = Callback;};
end

return Rules;
