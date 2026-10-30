-- Author -> lolokdev.
-- Last Edit -> September 15, 2026 6:02 PM CDT

local Theme = require(script.Parent.Theme)

local Typography = {} do
	local Properties = {'FontFace'; 'TextSize'; 'TextColor3'; 'TextTransparency'; 'TextStrokeColor3'; 'TextStrokeTransparency'; 'TextWrapped'; 'TextXAlignment'; 'TextYAlignment';}

	function Typography.Infer(Object)
		local Name = string.lower(Object.Name)
		if string.find(Name, 'header') then return 'Header' end
		if string.find(Name, 'subtext') then return 'Subtext' end
		if Object:IsA('TextButton') then return 'Button' end
		return nil;
	end

	function Typography.Apply(Object, ClassName, Overrides)
		if not Object or not (Object:IsA('TextLabel') or Object:IsA('TextButton') or Object:IsA('TextBox')) then return Object end
		local Definition = Theme.Get('Typography.' .. tostring(ClassName or Typography.Infer(Object) or 'Body')) or {}
		for _, Property in ipairs(Properties) do
			if Definition[Property] ~= nil then pcall(function() Object[Property] = Definition[Property] end) end
		end
		for Property, Value in pairs(Overrides or {}) do pcall(function() Object[Property] = Value end) end
		return Object;
	end

	function Typography.ApplyTree(Root, Mapping)
		local function apply(Object)
			local ClassName = Mapping and Mapping[Object.Name] or Typography.Infer(Object)
			if ClassName then Typography.Apply(Object, ClassName) end
		end
		apply(Root)
		for _, Object in ipairs(Root:GetDescendants()) do apply(Object) end
		return Root;
	end
end

return Typography;
