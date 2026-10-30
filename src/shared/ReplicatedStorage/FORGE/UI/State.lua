-- Author -> lolokdev.
-- Last Edit -> September 15, 2026 6:02 PM CDT

local Signal = require(script.Parent.Parent.Core.Signal)

local State = {} do
	State.__index = State
	State.ClassName = 'UIState'

	function State.new(Value)
		local this = setmetatable({}, State)
		this._Value = Value
		this.Changed = Signal.new()
		return this;
	end

	function State:Is(Value)
		return getmetatable(Value) == State;
	end

	function State:Get()
		return self._Value;
	end

	function State:Set(Value)
		if self._Value == Value then return self._Value end
		local Previous = self._Value
		self._Value = Value
		self.Changed:Fire(Value, Previous)
		return Value;
	end

	function State:Update(Callback)
		return self:Set(Callback(self._Value));
	end

	function State:Subscribe(Callback, Immediate)
		local Connection = self.Changed:Connect(Callback)
		if Immediate ~= false then Callback(self._Value, nil) end
		return Connection;
	end

	function State:Map(Callback)
		return {__UIBinding = true; State = self; Transform = Callback;};
	end

	function State:Destroy()
		self.Changed:Destroy()
	end

	function State.Computed(Dependencies, Callback)
		local Values = {}
		local function read()
			for Index, Dependency in ipairs(Dependencies) do Values[Index] = Dependency:Get() end
			return Callback(table.unpack(Values));
		end
		local Result = State.new(read())
		Result._ComputedConnections = {}
		for _, Dependency in ipairs(Dependencies) do
			table.insert(Result._ComputedConnections, Dependency.Changed:Connect(function() Result:Set(read()) end))
		end
		local BaseDestroy = Result.Destroy
		function Result:Destroy()
			for _, Connection in ipairs(self._ComputedConnections) do Connection:Disconnect() end
			table.clear(self._ComputedConnections)
			BaseDestroy(self)
		end
		return Result;
	end
end

return State;
