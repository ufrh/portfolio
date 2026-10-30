-- Author -> lolokdev.
-- Last Edit -> September 13, 2026 6:43 PM CDT

local DeepCopy = require(script.Parent.Parent.Util.DeepCopy)

local Reconcile = {}

-- reconcileValue -> boolean
-- Recursively fills missing template values and repairs incompatible types.
-- @param Data, table -> Runtime data table.
-- @param Template, table -> Canonical template table.
-- @param PruneUnknown, boolean -> Whether unknown keys should be removed.
-- @param Path, string -> Current debug path.
local function reconcileValue(Data, Template, PruneUnknown: boolean, Path: string)
	local Changed = false

	for Key, Default in pairs(Template) do
		local Current = Data[Key]
		local CurrentPath = Path == '' and tostring(Key) or Path .. '.' .. tostring(Key)

		if Current == nil then
			Data[Key] = DeepCopy.Copy(Default)
			Changed = true
		elseif typeof(Current) ~= typeof(Default) then
			Data[Key] = DeepCopy.Copy(Default)
			Changed = true
		elseif type(Default) == 'table' and next(Default) ~= nil then
			if reconcileValue(Current, Default, PruneUnknown, CurrentPath) then Changed = true end
		end
	end

	if PruneUnknown and next(Template) ~= nil then
		for Key in pairs(Data) do
			if Template[Key] == nil then
				Data[Key] = nil
				Changed = true
			end
		end
	end

	return Changed;
end

-- Apply -> boolean
-- Reconciles runtime data against the configured template.
-- @param Data, table -> Runtime data table.
-- @param Template, table -> Canonical template.
-- @param PruneUnknown, boolean -> Whether unknown keys are removed.
function Reconcile.Apply(Data, Template, PruneUnknown: boolean)
	assert(type(Data) == 'table', 'VAULT reconciliation requires table data.')
	assert(type(Template) == 'table', 'VAULT reconciliation requires a table template.')

	return reconcileValue(Data, Template, PruneUnknown, '');
end

return Reconcile;
