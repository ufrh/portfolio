-- Author -> lolokdev.
-- Last Edit -> September 16, 2026 12:46 AM CDT

local ReplicatedStorage = game:GetService('ReplicatedStorage')

local DefaultTheme = require(script.Parent.DefaultTheme)
local ThemeBuilder = require(script.Parent.ThemeBuilder)
local Codec = require(script.Parent.Codec)

local Theme = {} do
	Theme.OverrideName = 'FORGE_UI_ThemeOverrides'
	Theme.Overrides = {}
	Theme.Values = ThemeBuilder.Copy(DefaultTheme)

	local function split(Path)
		local Result = {}
		for Part in string.gmatch(tostring(Path), '[^%.]+') do table.insert(Result, Part) end
		return Result;
	end

	local function setPath(Target, Path, Value)
		local Parts = split(Path)
		local Current = Target
		for Index = 1, #Parts - 1 do
			local Key = Parts[Index]
			Current[Key] = Current[Key] or {}
			Current = Current[Key]
		end
		Current[Parts[#Parts]] = ThemeBuilder.Copy(Value)
	end

	local function getOverrideValue()
		local Value = ReplicatedStorage:FindFirstChild(Theme.OverrideName)
		if Value and Value:IsA('StringValue') and Value.Value ~= '' then
			local Success, Decoded = pcall(Codec.DecodeJSON, Value.Value)
			if Success and type(Decoded) == 'table' then return Decoded end
		end
		return {};
	end

	local function saveOverrides()
		local Value = ReplicatedStorage:FindFirstChild(Theme.OverrideName)
		if not Value then
			Value = Instance.new('StringValue')
			Value.Name = Theme.OverrideName
			Value.Parent = ReplicatedStorage
		end
		Value.Value = Codec.EncodeJSON(Theme.Overrides)
	end

	local function rebuild()
		Theme.Values = ThemeBuilder.MergeTables(DefaultTheme, Theme.Overrides)
		return Theme.Values;
	end

	Theme.Overrides = getOverrideValue()
	rebuild()

	function Theme.Get(Path)
		if not Path then return Theme.Values end
		local Current = Theme.Values
		for _, Key in ipairs(split(Path)) do
			if type(Current) ~= 'table' then return nil end
			Current = Current[Key]
		end
		return Current;
	end

	function Theme.Set(Path, Value)
		local Builder = ThemeBuilder.new(Theme.Values):Set(Path, Value)
		Theme.Values = Builder:Build()
		return Value;
	end

	function Theme.Merge(Path, Values)
		local Builder = ThemeBuilder.new(Theme.Values):Merge(Path, Values)
		Theme.Values = Builder:Build()
		return Theme.Get(Path);
	end

	function Theme.Replace(Values)
		Theme.Values = ThemeBuilder.Copy(Values)
		return Theme.Values;
	end

	function Theme.Reset()
		Theme.Values = ThemeBuilder.MergeTables(DefaultTheme, Theme.Overrides)
		return Theme.Values;
	end

	function Theme.Builder()
		return ThemeBuilder.new(Theme.Values);
	end

	function Theme.GetOverrides()
		return ThemeBuilder.Copy(Theme.Overrides);
	end

	function Theme.SetOverride(Path, Value)
		setPath(Theme.Overrides, Path, Value)
		saveOverrides()
		rebuild()
		return Theme.Get(Path);
	end

	function Theme.MergeOverride(Path, Values)
		local Current = ThemeBuilder.new(Theme.Overrides)
		Current:Merge(Path, Values)
		Theme.Overrides = Current:Build()
		saveOverrides()
		rebuild()
		return Theme.Get(Path);
	end

	function Theme.ClearOverrides()
		Theme.Overrides = {}
		local Value = ReplicatedStorage:FindFirstChild(Theme.OverrideName)
		if Value then Value:Destroy() end
		return rebuild();
	end
end

return Theme;
