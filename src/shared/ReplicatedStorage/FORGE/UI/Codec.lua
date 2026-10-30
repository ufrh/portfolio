-- Author -> lolokdev.
-- Last Edit -> September 15, 2026 10:38 PM CDT

local HttpService = game:GetService('HttpService')

local Codec = {} do
	local function encode(Value, Seen)
		local Kind = typeof(Value)
		if Kind == 'Color3' then
			return {__type = 'Color3'; R = Value.R; G = Value.G; B = Value.B;};
		elseif Kind == 'Vector2' then
			return {__type = 'Vector2'; X = Value.X; Y = Value.Y;};
		elseif Kind == 'Vector3' then
			return {__type = 'Vector3'; X = Value.X; Y = Value.Y; Z = Value.Z;};
		elseif Kind == 'UDim' then
			return {__type = 'UDim'; Scale = Value.Scale; Offset = Value.Offset;};
		elseif Kind == 'UDim2' then
			return {
				__type = 'UDim2';
				XScale = Value.X.Scale; XOffset = Value.X.Offset;
				YScale = Value.Y.Scale; YOffset = Value.Y.Offset;
			};
		elseif Kind == 'EnumItem' then
			return {__type = 'EnumItem'; Enum = tostring(Value.EnumType); Name = Value.Name;};
		elseif Kind == 'ColorSequence' then
			local Points = {}
			for _, Point in ipairs(Value.Keypoints) do
				table.insert(Points, {Time = Point.Time; Value = encode(Point.Value, Seen);})
			end
			return {__type = 'ColorSequence'; Keypoints = Points;};
		elseif Kind == 'NumberSequence' then
			local Points = {}
			for _, Point in ipairs(Value.Keypoints) do
				table.insert(Points, {Time = Point.Time; Value = Point.Value; Envelope = Point.Envelope;})
			end
			return {__type = 'NumberSequence'; Keypoints = Points;};
		elseif Kind == 'Font' then
			return {
				__type = 'Font';
				Family = Value.Family;
				Weight = Value.Weight.Name;
				Style = Value.Style.Name;
			};
		end

		if type(Value) ~= 'table' then
			return Value;
		end

		Seen = Seen or {}
		if Seen[Value] then
			error('FORGE.UI documents cannot contain cyclic tables.')
		end
		Seen[Value] = true

		local Result = {}
		for Key, Child in pairs(Value) do
			Result[Key] = encode(Child, Seen)
		end

		Seen[Value] = nil
		return Result;
	end

	local function decode(Value)
		if type(Value) ~= 'table' then
			return Value;
		end

		local Type = Value.__type
		if Type == 'Color3' then
			return Color3.new(Value.R or 0, Value.G or 0, Value.B or 0);
		elseif Type == 'Vector2' then
			return Vector2.new(Value.X or 0, Value.Y or 0);
		elseif Type == 'Vector3' then
			return Vector3.new(Value.X or 0, Value.Y or 0, Value.Z or 0);
		elseif Type == 'UDim' then
			return UDim.new(Value.Scale or 0, Value.Offset or 0);
		elseif Type == 'UDim2' then
			return UDim2.new(Value.XScale or 0, Value.XOffset or 0, Value.YScale or 0, Value.YOffset or 0);
		elseif Type == 'EnumItem' then
			local EnumName = tostring(Value.Enum or ''):match('Enum%.(.+)') or tostring(Value.Enum or '')
			local EnumType = Enum[EnumName]
			return EnumType and EnumType[Value.Name] or nil;
		elseif Type == 'ColorSequence' then
			local Points = {}
			for _, Point in ipairs(Value.Keypoints or {}) do
				table.insert(Points, ColorSequenceKeypoint.new(Point.Time or 0, decode(Point.Value)))
			end
			return ColorSequence.new(Points);
		elseif Type == 'NumberSequence' then
			local Points = {}
			for _, Point in ipairs(Value.Keypoints or {}) do
				table.insert(Points, NumberSequenceKeypoint.new(Point.Time or 0, Point.Value or 0, Point.Envelope or 0))
			end
			return NumberSequence.new(Points);
		elseif Type == 'Font' then
			local Weight = Enum.FontWeight[Value.Weight] or Enum.FontWeight.Regular
			local Style = Enum.FontStyle[Value.Style] or Enum.FontStyle.Normal
			return Font.new(Value.Family or 'rbxasset://fonts/families/SourceSansPro.json', Weight, Style);
		end

		local Result = {}
		for Key, Child in pairs(Value) do
			Result[Key] = decode(Child)
		end
		return Result;
	end

	local function isArray(Value)
		local Count, Highest = 0, 0
		for Key in pairs(Value) do
			if type(Key) ~= 'number' or Key <= 0 or Key % 1 ~= 0 then return false end
			Count += 1
			Highest = math.max(Highest, Key)
		end
		return Count == Highest;
	end

	local function indent(Level)
		return string.rep('\t', Level);
	end

	local function quote(Value)
		return string.format('%q', Value);
	end

	local function keySource(Key)
		if type(Key) == 'string' and string.match(Key, '^[%a_][%w_]*$') then return Key end
		return '[' .. Codec.ToLua(Key, 0) .. ']';
	end

	function Codec.Encode(Value)
		return encode(Value, {});
	end

	function Codec.Decode(Value)
		return decode(Value);
	end

	function Codec.EncodeJSON(Value)
		return HttpService:JSONEncode(Codec.Encode(Value));
	end

	function Codec.DecodeJSON(Value)
		return Codec.Decode(HttpService:JSONDecode(Value));
	end

	function Codec.ToLua(Value, Level)
		Level = Level or 0
		local Kind = typeof(Value)
		if Kind == 'string' then return quote(Value) end
		if Kind == 'number' or Kind == 'boolean' then return tostring(Value) end
		if Value == nil then return 'nil' end
		if Kind == 'Color3' then return string.format('Color3.fromRGB(%d, %d, %d)', math.round(Value.R * 255), math.round(Value.G * 255), math.round(Value.B * 255)) end
		if Kind == 'Vector2' then return string.format('Vector2.new(%s, %s)', tostring(Value.X), tostring(Value.Y)) end
		if Kind == 'Vector3' then return string.format('Vector3.new(%s, %s, %s)', tostring(Value.X), tostring(Value.Y), tostring(Value.Z)) end
		if Kind == 'UDim' then return string.format('UDim.new(%s, %s)', tostring(Value.Scale), tostring(Value.Offset)) end
		if Kind == 'UDim2' then return string.format('UDim2.new(%s, %s, %s, %s)', tostring(Value.X.Scale), tostring(Value.X.Offset), tostring(Value.Y.Scale), tostring(Value.Y.Offset)) end
		if Kind == 'EnumItem' then return tostring(Value) end
		if Kind == 'Font' then return string.format('Font.new(%q, Enum.FontWeight.%s, Enum.FontStyle.%s)', Value.Family, Value.Weight.Name, Value.Style.Name) end
		if type(Value) ~= 'table' then return 'nil' end

		local Lines = {'{'}
		if isArray(Value) then
			for _, Child in ipairs(Value) do
				table.insert(Lines, indent(Level + 1) .. Codec.ToLua(Child, Level + 1) .. ';')
			end
		else
			local Keys = {}
			for Key in pairs(Value) do table.insert(Keys, Key) end
			table.sort(Keys, function(A, B) return tostring(A) < tostring(B) end)
			for _, Key in ipairs(Keys) do
				table.insert(Lines, indent(Level + 1) .. keySource(Key) .. ' = ' .. Codec.ToLua(Value[Key], Level + 1) .. ';')
			end
		end
		table.insert(Lines, indent(Level) .. '}')
		return table.concat(Lines, '\n');
	end
end

return Codec;
