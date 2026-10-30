-- Author -> lolokdev.
-- Last Edit -> September 13, 2026 6:43 PM CDT

local DeepCopy = {}

-- copyValue -> any
-- Recursively copies tables while preserving Roblox datatype values by reference/value semantics.
-- @param Value, any -> Value being copied.
-- @param Seen, table -> Cycle map used during recursive copies.
local function copyValue(Value, Seen)
	if type(Value) ~= 'table' then return Value end
	if Seen[Value] then return Seen[Value] end

	local Result = {}
	Seen[Value] = Result

	for Key, Item in pairs(Value) do Result[copyValue(Key, Seen)] = copyValue(Item, Seen) end

	return Result;
end

-- Copy -> any
-- Creates a deep copy of a value without mutating the source.
-- @param Value, any -> Value being copied.
function DeepCopy.Copy(Value)
	return copyValue(Value, {});
end

return DeepCopy;
