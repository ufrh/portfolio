-- Author -> lolokdev.
-- Last Edit -> September 13, 2026 6:43 PM CDT

local RunService = game:GetService('RunService')

local Path = require(script.Parent.Parent.Util.Path)

local Guard = {}

-- finite -> boolean
-- Returns whether a number is safe for persistence and comparisons.
-- @param Value, number -> Number being checked.
local function finite(Value: number)
	return Value == Value and Value ~= math.huge and Value ~= -math.huge;
end

-- findTemplateValue -> any, boolean
-- Resolves a template value and reports whether the path is known.
-- @param Template, table -> Canonical template.
-- @param DataPath, string -> Data path being resolved.
local function findTemplateValue(Template, DataPath: string)
	local Keys = Path.Split(DataPath)
	local Current = Template

	for _, Key in ipairs(Keys) do
		if type(Current) ~= 'table' then return nil, false end
		if Current[Key] == nil then
			if next(Current) == nil then return nil, true end
			return nil, false
		end

		Current = Current[Key]
	end

	return Current, true;
end

-- validateRule -> boolean, string?
-- Applies one optional path rule to a runtime value.
-- @param DataPath, string -> Canonical data path.
-- @param Value, any -> Value being validated.
-- @param Rule, table? -> Optional rule definition.
local function validateRule(DataPath: string, Value, Rule)
	if not Rule then return true end

	local Kind = typeof(Value)

	if Rule.Type and Kind ~= Rule.Type then return false, DataPath .. ' must be ' .. Rule.Type .. ', received ' .. Kind end

	if Kind == 'number' then
		if not finite(Value) then return false, DataPath .. ' cannot be NaN or infinity' end
		if Rule.Integer and Value % 1 ~= 0 then return false, DataPath .. ' must be an integer' end
		if Rule.Min ~= nil and Value < Rule.Min then return false, DataPath .. ' is below minimum ' .. tostring(Rule.Min) end
		if Rule.Max ~= nil and Value > Rule.Max then return false, DataPath .. ' exceeds maximum ' .. tostring(Rule.Max) end
	end

	if Kind == 'string' then
		if Rule.MinLength and #Value < Rule.MinLength then return false, DataPath .. ' is shorter than the minimum length' end
		if Rule.MaxLength and #Value > Rule.MaxLength then return false, DataPath .. ' exceeds the maximum length' end
		if Rule.Pattern and not string.match(Value, Rule.Pattern) then return false, DataPath .. ' does not match its required pattern' end
	end

	if Rule.Values then
		local Found = false

		for _, Allowed in ipairs(Rule.Values) do
			if Value == Allowed then Found = true; break end
		end

		if not Found then return false, DataPath .. ' is not an allowed value' end
	end

	if Rule.Custom then
		local Success, Accepted, Reason = pcall(Rule.Custom, Value, DataPath)

		if not Success then return false, DataPath .. ' custom validator errored: ' .. tostring(Accepted) end
		if not Accepted then return false, Reason or DataPath .. ' custom validation failed' end
	end

	return true;
end

-- validateTree -> boolean, string?
-- Validates an entire runtime tree against the template and path rules.
-- @param Data, any -> Runtime subtree.
-- @param Template, any -> Template subtree.
-- @param Rules, table -> Path rule map.
-- @param Strict, boolean -> Whether unknown keys are rejected.
-- @param DataPath, string -> Current path.
local function validateTree(Data, Template, Rules, Strict: boolean, DataPath: string)
	if typeof(Data) ~= typeof(Template) then return false, (DataPath == '' and '<root>' or DataPath) .. ' has type ' .. typeof(Data) .. ', expected ' .. typeof(Template) end

	local Rule = Rules[DataPath]

	if Rule then
		local Accepted, Reason = validateRule(DataPath, Data, Rule)

		if not Accepted then return false, Reason end
	end

	if type(Data) ~= 'table' then
		if typeof(Data) == 'number' and not finite(Data) then return false, (DataPath == '' and '<root>' or DataPath) .. ' cannot be NaN or infinity' end

		return true;
	end

	local Dynamic = next(Template) == nil

	for Key, Value in pairs(Data) do
		local ChildPath = DataPath == '' and tostring(Key) or DataPath .. '.' .. tostring(Key)
		local Default = Template[Key]

		if Default == nil then
			if not Dynamic and Strict then return false, 'unknown data path ' .. ChildPath end

			local DynamicRule = Rules[ChildPath]

			if DynamicRule then
				local Accepted, Reason = validateRule(ChildPath, Value, DynamicRule)

				if not Accepted then return false, Reason end
			end
		else
			local Accepted, Reason = validateTree(Value, Default, Rules, Strict, ChildPath)

			if not Accepted then return false, Reason end
		end
	end

	return true;
end

-- AssertServer -> nil
-- Hard-fails when VAULT is required from a client environment.
function Guard.AssertServer()
	assert(RunService:IsServer(), 'VAULT is server-only and must never be required by a client.')
end

-- ValidateData -> boolean, string?
-- Validates a complete profile against its template and path rules.
-- @param Data, table -> Profile data being checked.
-- @param Template, table -> Canonical template.
-- @param Rules, table -> Path rule map.
-- @param Strict, boolean -> Whether unknown paths are rejected.
function Guard.ValidateData(Data, Template, Rules, Strict: boolean)
	if type(Data) ~= 'table' then return false, 'profile root must be a table' end

	return validateTree(Data, Template, Rules or {}, Strict, '');
end

-- ValidatePathValue -> boolean, string?
-- Validates a single write against the template and its exact path rule.
-- @param DataPath, string -> Data path being written.
-- @param Value, any -> Proposed value.
-- @param Template, table -> Canonical template.
-- @param Rules, table -> Path rule map.
-- @param Strict, boolean -> Whether unknown paths are rejected.
function Guard.ValidatePathValue(DataPath: string, Value, Template, Rules, Strict: boolean)
	local Default, Known = findTemplateValue(Template, DataPath)

	if not Known and Strict then return false, 'unknown data path ' .. DataPath end
	if Default ~= nil and typeof(Value) ~= typeof(Default) then return false, DataPath .. ' must remain ' .. typeof(Default) end
	if typeof(Value) == 'number' and not finite(Value) then return false, DataPath .. ' cannot be NaN or infinity' end

	return validateRule(DataPath, Value, (Rules or {})[DataPath]);
end

return Guard;
