-- Author -> lolokdev.
-- Last Edit -> September 14, 2026 4:25 PM CDT

local HttpService = game:GetService('HttpService')

local Sanitizer = {} do
	-- sanitizeValue -> any
	-- Converts matchmaking metadata into a bounded MemoryStore-safe value tree.
	-- @param Value, any -> Value being sanitized.
	-- @param Limits, table -> Metadata limits.
	-- @param Depth, number -> Current recursion depth.
	-- @param State, table -> Shared node counter and cycle tracker.
	local function sanitizeValue(Value, Limits, Depth, State)
		local Kind = typeof(Value)

		if Kind == 'nil' or Kind == 'boolean' then return Value end

		if Kind == 'number' then
			assert(Value == Value and Value ~= math.huge and Value ~= -math.huge, 'Matchmaking metadata cannot contain NaN or infinity.')
			return Value;
		end

		if Kind == 'string' then
			assert(#Value <= Limits.MaxStringLength, 'Matchmaking metadata string exceeded MaxStringLength.')
			return Value;
		end

		assert(Kind == 'table', 'Matchmaking metadata supports only nil, booleans, finite numbers, strings and tables.')
		assert(Depth < Limits.MaxMetadataDepth, 'Matchmaking metadata exceeded MaxMetadataDepth.')
		assert(not State.Seen[Value], 'Matchmaking metadata cannot contain cyclic tables.')

		State.Seen[Value] = true
		State.Nodes += 1

		assert(State.Nodes <= Limits.MaxMetadataNodes, 'Matchmaking metadata exceeded MaxMetadataNodes.')

		local Result = {}

		for Key, Item in pairs(Value) do
			local KeyKind = typeof(Key)
			assert(KeyKind == 'string' or KeyKind == 'number', 'Matchmaking metadata keys must be strings or numbers.')
			Result[Key] = sanitizeValue(Item, Limits, Depth + 1, State)
		end

		State.Seen[Value] = nil

		return Result;
	end

	-- Copy -> any
	-- Returns a sanitized deep copy suitable for MemoryStore or teleport payloads.
	-- @param Value, any -> Value being copied.
	-- @param Limits, table -> Matchmaking configuration limits.
	function Sanitizer.Copy(Value, Limits)
		local Result = sanitizeValue(Value, Limits, 0, {Nodes = 0; Seen = {};})
		local Success, Encoded = pcall(HttpService.JSONEncode, HttpService, Result)
		assert(Success, 'Matchmaking metadata could not be JSON encoded.')
		assert(#Encoded <= Limits.MaxMetadataBytes, 'Matchmaking metadata exceeded MaxMetadataBytes.')
		return Result;
	end

	-- QueueName -> string
	-- Converts a logical queue name into a compact MemoryStore-safe structure suffix.
	-- @param Name, string -> Logical queue name.
	function Sanitizer.QueueName(Name: string)
		assert(type(Name) == 'string' and Name ~= '', 'Matchmaking queue name must be a non-empty string.')
		local Clean = string.gsub(Name, '[^%w_%-]', '_')
		assert(#Clean <= 64, 'Matchmaking queue name exceeds 64 characters after normalization.')
		return Clean;
	end
end

return Sanitizer;
