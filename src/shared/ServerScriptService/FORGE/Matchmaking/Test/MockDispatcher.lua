-- Author -> lolokdev.
-- Last Edit -> September 14, 2026 4:25 PM CDT

local MockDispatcher = {} do
	MockDispatcher.__index = MockDispatcher
	MockDispatcher.ClassName = 'MatchmakingMockDispatcher'

	-- new -> MatchmakingMockDispatcher
	-- Creates an in-memory assignment hint recorder.
	function MockDispatcher.new()
		local this = setmetatable({}, MockDispatcher)
		this.Messages = {}
		return this;
	end

	-- Publish -> boolean
	-- Records one lightweight assignment hint for security and allocation assertions.
	-- @param Payload, table -> Published assignment hint.
	function MockDispatcher:Publish(Payload)
		table.insert(self.Messages, Payload)
		return true;
	end
end

return MockDispatcher;
