-- Author -> lolokdev.
-- Last Edit -> September 13, 2026 6:43 PM CDT

local Codec = {}

local TAG = '__vault_type'

-- finite -> boolean
-- Returns whether a number is safe for persistent storage.
-- @param Value, number -> Number being checked.
local function finite(Value: number)
	return Value == Value and Value ~= math.huge and Value ~= -math.huge;
end

-- encodeKey -> any
-- Encodes supported persistent table keys into tagged primitive records.
-- @param Value, any -> Table key being encoded.
local function encodeKey(Value)
	local Kind = type(Value)

	if Kind == 'string' or Kind == 'boolean' then return Value end
	if Kind == 'number' and finite(Value) then return Value end

	error('VAULT serializer only supports string, boolean and finite number table keys.')
end

-- encodeValue -> any
-- Recursively converts Roblox datatypes and tables into datastore-safe tagged values.
-- @param Value, any -> Runtime value being encoded.
-- @param State, table -> Recursive encoding state.
-- @param Depth, number -> Current recursion depth.
local function encodeValue(Value, State, Depth: number)
	if Depth > State.MaxDepth then error('VAULT serializer exceeded maximum depth.') end

	State.Nodes += 1

	if State.Nodes > State.MaxNodes then error('VAULT serializer exceeded maximum node count.') end

	local Kind = typeof(Value)

	if Value == nil or Kind == 'boolean' then return Value end
	if Kind == 'number' then
		if not finite(Value) then error('VAULT serializer rejected NaN or infinity.') end
		return Value
	end
	if Kind == 'string' then
		if #Value > State.MaxStringLength then error('VAULT serializer rejected an oversized string.') end
		return Value
	end

	if Kind == 'table' then
		if State.Seen[Value] then error('VAULT serializer rejected a cyclic table.') end

		State.Seen[Value] = true

		local Entries = {}

		for Key, Item in pairs(Value) do table.insert(Entries, {k = encodeKey(Key); v = encodeValue(Item, State, Depth + 1);}) end

		State.Seen[Value] = nil

		return {[TAG] = 'Table'; entries = Entries;};
	end

	if Kind == 'Vector2' then return {[TAG] = 'Vector2'; v = {Value.X, Value.Y;};} end
	if Kind == 'Vector3' then return {[TAG] = 'Vector3'; v = {Value.X, Value.Y, Value.Z;};} end
	if Kind == 'Color3' then return {[TAG] = 'Color3'; v = {Value.R, Value.G, Value.B;};} end
	if Kind == 'CFrame' then return {[TAG] = 'CFrame'; v = {Value:GetComponents()};} end
	if Kind == 'UDim' then return {[TAG] = 'UDim'; v = {Value.Scale, Value.Offset;};} end
	if Kind == 'UDim2' then return {[TAG] = 'UDim2'; v = {Value.X.Scale, Value.X.Offset, Value.Y.Scale, Value.Y.Offset;};} end
	if Kind == 'Rect' then return {[TAG] = 'Rect'; v = {Value.Min.X, Value.Min.Y, Value.Max.X, Value.Max.Y;};} end
	if Kind == 'NumberRange' then return {[TAG] = 'NumberRange'; v = {Value.Min, Value.Max;};} end
	if Kind == 'BrickColor' then return {[TAG] = 'BrickColor'; v = Value.Number;} end
	if Kind == 'DateTime' then return {[TAG] = 'DateTime'; v = Value.UnixTimestampMillis;} end

	if Kind == 'EnumItem' then
		local EnumType = string.match(tostring(Value.EnumType), '^Enum%.(.+)$')

		return {[TAG] = 'EnumItem'; enum = EnumType; name = Value.Name;};
	end

	if Kind == 'NumberSequence' then
		local Points = {}

		for _, Point in ipairs(Value.Keypoints) do table.insert(Points, {Point.Time, Point.Value, Point.Envelope;}) end

		return {[TAG] = 'NumberSequence'; v = Points;};
	end

	if Kind == 'ColorSequence' then
		local Points = {}

		for _, Point in ipairs(Value.Keypoints) do table.insert(Points, {Point.Time, Point.Value.R, Point.Value.G, Point.Value.B;}) end

		return {[TAG] = 'ColorSequence'; v = Points;};
	end

	error('VAULT serializer does not support datatype ' .. Kind .. '.')
end

-- decodeValue -> any
-- Reconstructs runtime Roblox datatypes and tables from datastore-safe tagged values.
-- @param Value, any -> Encoded value being decoded.
-- @param Depth, number -> Current recursion depth.
-- @param MaxDepth, number -> Maximum allowed recursion depth.
local function decodeValue(Value, Depth: number, MaxDepth: number)
	if Depth > MaxDepth then error('VAULT decoder exceeded maximum depth.') end
	if type(Value) ~= 'table' then return Value end

	local Kind = Value[TAG]

	if Kind == 'Table' then
		local Result = {}

		for _, Entry in ipairs(Value.entries or {}) do Result[Entry.k] = decodeValue(Entry.v, Depth + 1, MaxDepth) end

		return Result;
	end

	if Kind == 'Vector2' then return Vector2.new(Value.v[1], Value.v[2]) end
	if Kind == 'Vector3' then return Vector3.new(Value.v[1], Value.v[2], Value.v[3]) end
	if Kind == 'Color3' then return Color3.new(Value.v[1], Value.v[2], Value.v[3]) end
	if Kind == 'CFrame' then return CFrame.new(table.unpack(Value.v)) end
	if Kind == 'UDim' then return UDim.new(Value.v[1], Value.v[2]) end
	if Kind == 'UDim2' then return UDim2.new(Value.v[1], Value.v[2], Value.v[3], Value.v[4]) end
	if Kind == 'Rect' then return Rect.new(Value.v[1], Value.v[2], Value.v[3], Value.v[4]) end
	if Kind == 'NumberRange' then return NumberRange.new(Value.v[1], Value.v[2]) end
	if Kind == 'BrickColor' then return BrickColor.new(Value.v) end
	if Kind == 'DateTime' then return DateTime.fromUnixTimestampMillis(Value.v) end
	if Kind == 'EnumItem' then
		local EnumType = Enum[Value.enum]

		if not EnumType then error('VAULT decoder could not resolve enum ' .. tostring(Value.enum) .. '.') end

		local Item = EnumType[Value.name]

		if not Item then error('VAULT decoder could not resolve enum item ' .. tostring(Value.name) .. '.') end

		return Item;
	end
	if Kind == 'NumberSequence' then
		local Points = {}

		for _, Point in ipairs(Value.v or {}) do table.insert(Points, NumberSequenceKeypoint.new(Point[1], Point[2], Point[3])) end

		return NumberSequence.new(Points);
	end
	if Kind == 'ColorSequence' then
		local Points = {}

		for _, Point in ipairs(Value.v or {}) do table.insert(Points, ColorSequenceKeypoint.new(Point[1], Color3.new(Point[2], Point[3], Point[4]))) end

		return ColorSequence.new(Points);
	end

	error('VAULT decoder encountered an unknown serialized tag.')
end

-- Encode -> any
-- Converts runtime data into a datastore-safe representation.
-- @param Value, any -> Runtime value being serialized.
-- @param Limits, table -> Serializer limits.
function Codec.Encode(Value, Limits)
	local State = {MaxDepth = Limits.MaxDepth; MaxNodes = Limits.MaxNodes; MaxStringLength = Limits.MaxStringLength; Nodes = 0; Seen = {};}

	return encodeValue(Value, State, 0);
end

-- Decode -> any
-- Reconstructs runtime data from a VAULT encoded value.
-- @param Value, any -> Encoded value.
-- @param Limits, table -> Serializer limits.
function Codec.Decode(Value, Limits)
	return decodeValue(Value, 0, Limits.MaxDepth);
end

return Codec;
