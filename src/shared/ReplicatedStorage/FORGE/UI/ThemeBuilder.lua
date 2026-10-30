-- Author -> lolokdev.
-- Last Edit -> September 16, 2026 12:46 AM CDT

local ThemeBuilder = {} do
	ThemeBuilder.__index = ThemeBuilder

	local function opaque(Value)
		if type(Value) ~= 'table' then return true end
		if Value.__UIBinding == true or Value.__UIRef == true or Value.__UINode == true then return true end
		return getmetatable(Value) ~= nil;
	end

	local function copy(Value, Seen)
		if type(Value) ~= 'table' then return Value end
		if opaque(Value) then return Value end
		Seen = Seen or {}
		if Seen[Value] then return Seen[Value] end
		local Result = {}
		Seen[Value] = Result
		for Key, Child in pairs(Value) do Result[copy(Key, Seen)] = copy(Child, Seen) end
		return Result;
	end

	local function split(Path)
		local Result = {}
		for Part in string.gmatch(tostring(Path), '[^%.]+') do table.insert(Result, Part) end
		return Result;
	end

	local function merge(Target, Values, Seen)
		Seen = Seen or {}
		for Key, Value in pairs(Values or {}) do
			if type(Value) == 'table' and not opaque(Value) and type(Target[Key]) == 'table' and not opaque(Target[Key]) then
				merge(Target[Key], Value, Seen)
			else
				Target[Key] = copy(Value, Seen)
			end
		end
		return Target;
	end

	function ThemeBuilder.new(Base)
		local this = setmetatable({}, ThemeBuilder)
		this.Values = copy(Base or {})
		return this;
	end

	function ThemeBuilder:Set(Path, Value)
		local Parts = split(Path)
		local Current = self.Values
		for Index = 1, #Parts - 1 do
			local Key = Parts[Index]
			Current[Key] = Current[Key] or {}
			Current = Current[Key]
		end
		Current[Parts[#Parts]] = copy(Value)
		return self;
	end

	function ThemeBuilder:Merge(Path, Values)
		local Parts = split(Path)
		local Current = self.Values
		for _, Key in ipairs(Parts) do
			Current[Key] = Current[Key] or {}
			Current = Current[Key]
		end
		merge(Current, Values)
		return self;
	end

	function ThemeBuilder:Color(Name, Value) return self:Set('Colors.' .. Name, Value); end
	function ThemeBuilder:Spacing(Name, Value) return self:Set('Spacing.' .. Name, Value); end
	function ThemeBuilder:Radius(Name, Value) return self:Set('Radii.' .. Name, Value); end
	function ThemeBuilder:Typography(Name, Definition) return self:Set('Typography.' .. Name, Definition); end
	function ThemeBuilder:Surface(Name, Definition) return self:Set('Surfaces.' .. Name, Definition); end
	function ThemeBuilder:Component(Name, Definition) return self:Set('Components.' .. Name, Definition); end
	function ThemeBuilder:Motion(Name, Definition) return self:Set('Motion.' .. Name, Definition); end
	function ThemeBuilder:Build() return copy(self.Values); end
	function ThemeBuilder.Copy(Value) return copy(Value); end

	function ThemeBuilder.MergeTables(...)
		local Result = {}
		for _, Value in ipairs({...}) do merge(Result, Value or {}) end
		return Result;
	end

	function ThemeBuilder.Corner(Radius) return {Radius = Radius;}; end

	function ThemeBuilder.Stroke(Color, Thickness, Transparency, Gradient)
		return {Color = Color; Thickness = Thickness or 1; Transparency = Transparency or 0; Gradient = Gradient;};
	end

	function ThemeBuilder.Shadow(Color, Transparency, Offset, BlurRadius, Spread)
		return {
			Color = Color;
			Transparency = Transparency or 0;
			Offset = Offset or UDim2.fromOffset(0, 4);
			BlurRadius = BlurRadius or UDim.new(0, 12);
			Spread = Spread or UDim2.fromOffset(0, 0);
		};
	end

	function ThemeBuilder.Gradient(Color, Rotation, Transparency, Offset)
		return {Color = Color; Rotation = Rotation or 0; Transparency = Transparency; Offset = Offset;};
	end
end

return ThemeBuilder;
