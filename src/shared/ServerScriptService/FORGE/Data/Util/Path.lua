-- Author -> lolokdev.
-- Last Edit -> September 13, 2026 6:43 PM CDT

local Path = {}

-- Split -> {string}
-- Splits a dot-delimited data path into ordered keys.
-- @param Value, string|table -> Path string or already split key list.
function Path.Split(Value)
	if type(Value) == 'table' then return Value end
	if type(Value) ~= 'string' or Value == '' then return {} end

	local Result = {}

	for Key in string.gmatch(Value, '[^%.]+') do table.insert(Result, Key) end

	return Result;
end

-- Get -> any
-- Resolves a nested value from a root table.
-- @param Root, table -> Root data table.
-- @param Value, string|table -> Data path.
function Path.Get(Root, Value)
	local Current = Root

	for _, Key in ipairs(Path.Split(Value)) do
		if type(Current) ~= 'table' then return nil end
		Current = Current[Key]
	end

	return Current;
end

-- Set -> boolean, string?
-- Writes a nested value while requiring all parent containers to already exist.
-- @param Root, table -> Root data table.
-- @param Value, string|table -> Data path.
-- @param NewValue, any -> Value being written.
function Path.Set(Root, Value, NewValue)
	local Keys = Path.Split(Value)

	if #Keys == 0 then return false, 'path cannot be empty' end

	local Current = Root

	for Index = 1, #Keys - 1 do
		local Key = Keys[Index]

		if type(Current[Key]) ~= 'table' then return false, 'missing parent table at ' .. table.concat(Keys, '.', 1, Index) end

		Current = Current[Key]
	end

	Current[Keys[#Keys]] = NewValue

	return true;
end

-- Delete -> boolean, string?
-- Removes a nested value while requiring all parent containers to exist.
-- @param Root, table -> Root data table.
-- @param Value, string|table -> Data path.
function Path.Delete(Root, Value)
	local Keys = Path.Split(Value)

	if #Keys == 0 then return false, 'path cannot be empty' end

	local Current = Root

	for Index = 1, #Keys - 1 do
		local Key = Keys[Index]

		if type(Current[Key]) ~= 'table' then return false, 'missing parent table at ' .. table.concat(Keys, '.', 1, Index) end

		Current = Current[Key]
	end

	Current[Keys[#Keys]] = nil

	return true;
end

-- Join -> string
-- Joins path keys into the canonical dot-delimited form.
-- @param Keys, table -> Ordered path keys.
function Path.Join(Keys)
	return table.concat(Keys, '.');
end

return Path;
