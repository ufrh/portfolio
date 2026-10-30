-- Author -> lolokdev.
-- Last Edit -> September 14, 2026 4:25 PM CDT

local MockTeleport = {} do
	MockTeleport.__index = MockTeleport
	MockTeleport.ClassName = 'MatchmakingMockTeleport'

	-- new -> MatchmakingMockTeleport
	-- Creates a deterministic reserved-server allocator for production Queue pipeline self-tests.
	function MockTeleport.new()
		local this = setmetatable({}, MockTeleport)
		this.Reservations = 0
		this.FailReserve = false
		return this;
	end

	-- Reserve -> boolean, string, string?
	-- Returns one fake secret access code/private-server id or an intentional reservation failure.
	-- @param PlaceId, number -> Simulated destination place id.
	function MockTeleport:Reserve(PlaceId: number)
		if self.FailReserve then return false, 'intentional reservation failure' end
		self.Reservations += 1
		return true, 'TEST_ACCESS_' .. tostring(self.Reservations), 'TEST_PRIVATE_' .. tostring(PlaceId) .. '_' .. tostring(self.Reservations);
	end
end

return MockTeleport;
