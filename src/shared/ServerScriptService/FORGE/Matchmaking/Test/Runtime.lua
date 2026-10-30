-- Author -> lolokdev.
-- Last Edit -> September 14, 2026 7:12 PM CDT

local Runtime = {}

local Clock = {} do
	Clock.__index = Clock
	Clock.ClassName = 'MatchmakingTestClock'

	-- new -> MatchmakingTestClock
	-- Creates one deterministic unix-style clock used by the production matchmaking engine during simulation.
	-- @param StartTime, number? -> Optional initial unix timestamp.
	function Clock.new(StartTime: number?)
		local this = setmetatable({}, Clock)
		this.Time = tonumber(StartTime) or os.time()
		return this;
	end

	-- Now -> number
	-- Returns the current deterministic simulation timestamp.
	function Clock:Now()
		return self.Time;
	end

	-- Advance -> number
	-- Advances deterministic simulation time without affecting production clocks.
	-- @param Delta, number -> Seconds to advance.
	function Clock:Advance(Delta: number)
		self.Time += math.max(tonumber(Delta) or 0, 0)
		return self.Time;
	end
end

local Id = {} do
	Id.__index = Id
	Id.ClassName = 'MatchmakingTestId'

	-- new -> MatchmakingTestId
	-- Creates deterministic synthetic identifiers for matches and queue receipts.
	function Id.new()
		local this = setmetatable({}, Id)
		this.Value = 0
		return this;
	end

	-- Next -> string
	-- Returns one unique deterministic identifier.
	-- @param Prefix, string? -> Identifier prefix.
	function Id:Next(Prefix: string?)
		self.Value += 1
		return tostring(Prefix or 'ID') .. '-' .. tostring(self.Value);
	end
end

local Storage = {} do
	Storage.__index = Storage
	Storage.ClassName = 'MatchmakingTestStorage'

	-- new -> MatchmakingTestStorage
	-- Creates an in-memory adapter implementing the production Queue storage contract with queue invisibility behavior.
	-- @param Name, string -> Logical queue name.
	-- @param Config, table -> Matchmaking configuration.
	-- @param ClockValue, MatchmakingTestClock -> Deterministic runtime clock.
	-- @param IdValue, MatchmakingTestId -> Deterministic id generator.
	function Storage.new(Name: string, Config, ClockValue, IdValue)
		local this = setmetatable({}, Storage)
		this.Name = Name
		this.Config = Config
		this.Clock = ClockValue
		this.Id = IdValue
		this.Tickets = {}
		this.Memberships = {}
		this.Assignments = {}
		this.Matches = {}
		this.Queue = {}
		this.Receipts = {}
		this.AssignmentWrites = 0
		this.FailAssignmentAt = nil
		return this;
	end

	-- SetTicket -> boolean
	-- Stores one synthetic production-shaped ticket.
	-- @param TicketValue, table -> Ticket payload.
	function Storage:SetTicket(TicketValue)
		self.Tickets[TicketValue.Id] = TicketValue
		return true;
	end

	-- RemoveTicket -> boolean
	-- Removes one synthetic ticket record.
	-- @param TicketId, string -> Ticket id.
	function Storage:RemoveTicket(TicketId: string)
		self.Tickets[TicketId] = nil
		return true;
	end

	-- Enqueue -> boolean
	-- Adds one ticket id to the simulated MemoryStore queue.
	-- @param TicketValue, table -> Ticket payload.
	function Storage:Enqueue(TicketValue)
		table.insert(self.Queue, {TicketId = TicketValue.Id; VisibleAt = self.Clock:Now(); Removed = false;})
		return true;
	end

	-- SeedTicket -> boolean
	-- Inserts one externally authored pseudo ticket through the same storage and queue surfaces production workers read.
	-- @param TicketValue, table -> Production-shaped pseudo ticket.
	function Storage:SeedTicket(TicketValue)
		self:SetTicket(TicketValue)
		self:Enqueue(TicketValue)
		return true;
	end

	-- ReadOne -> boolean, table?
	-- Simulates MemoryStoreQueue invisibility while returning one production-shaped receipt record.
	function Storage:ReadOne()
		local Now = self.Clock:Now()
		for _, Record in ipairs(self.Queue) do
			if Record.Removed or Record.VisibleAt > Now then continue end
			local Receipt = self.Id:Next('RECEIPT')
			Record.VisibleAt = Now + math.max(tonumber(self.Config.QueueInvisibility) or 1, .05)
			self.Receipts[Receipt] = Record
			return true, {TicketId = Record.TicketId; Receipt = Receipt;};
		end
		return true, nil;
	end

	-- RemoveReceipt -> boolean, string?
	-- Acknowledges one queue receipt and permanently removes that queue entry.
	-- @param Receipt, string -> Synthetic receipt id.
	function Storage:RemoveReceipt(Receipt: string)
		local Record = self.Receipts[Receipt]
		if not Record then return false, 'unknown synthetic queue receipt' end
		Record.Removed = true
		self.Receipts[Receipt] = nil
		return true;
	end

	-- GetQueueSize -> boolean, number
	-- Returns the number of non-acknowledged synthetic queue entries.
	function Storage:GetQueueSize()
		local Count = 0
		for _, Record in ipairs(self.Queue) do if not Record.Removed then Count += 1 end end
		return true, Count;
	end

	-- GetTicket -> boolean, table?
	-- Reads one synthetic ticket.
	-- @param TicketId, string -> Ticket id.
	function Storage:GetTicket(TicketId: string)
		return true, self.Tickets[TicketId];
	end

	-- ClaimMembership -> boolean, string?
	-- Claims one pseudo user against one ticket to mirror global duplicate-queue protection.
	-- @param UserId, number -> Pseudo user id.
	-- @param TicketValue, table -> Owning ticket.
	function Storage:ClaimMembership(UserId: number, TicketValue)
		local Existing = self.Memberships[UserId]
		if Existing and Existing.ExpiresAt > self.Clock:Now() and Existing.TicketId ~= TicketValue.Id then return false, 'player is already queued' end
		self.Memberships[UserId] = {Queue = TicketValue.Queue; TicketId = TicketValue.Id; ExpiresAt = TicketValue.ExpiresAt;}
		return true;
	end

	-- GetMembership -> boolean, table?
	-- Reads one pseudo-user queue membership.
	-- @param UserId, number -> Pseudo user id.
	function Storage:GetMembership(UserId: number)
		return true, self.Memberships[UserId];
	end

	-- ReleaseMembership -> boolean
	-- Releases one pseudo-user membership only when it belongs to the expected ticket.
	-- @param UserId, number -> Pseudo user id.
	-- @param TicketId, string -> Expected ticket id.
	function Storage:ReleaseMembership(UserId: number, TicketId: string)
		local Existing = self.Memberships[UserId]
		if Existing and Existing.TicketId == TicketId then self.Memberships[UserId] = nil end
		return true;
	end

	-- ClaimTicket -> boolean, string?
	-- Atomically transitions one active synthetic ticket from queued to matched.
	-- @param TicketValue, table -> Ticket being claimed.
	-- @param MatchId, string -> Match claiming the ticket.
	function Storage:ClaimTicket(TicketValue, MatchId: string)
		local Current = self.Tickets[TicketValue.Id]
		if not Current or Current.Status ~= 'Queued' or Current.ExpiresAt <= self.Clock:Now() then return false, 'ticket is no longer claimable' end
		Current.Status = 'Matched'
		Current.MatchId = MatchId
		Current.UpdatedAt = self.Clock:Now()
		return true;
	end

	-- RollbackTicket -> boolean
	-- Restores one failed synthetic match claim to queued state.
	-- @param TicketValue, table -> Ticket being restored.
	-- @param MatchId, string -> Match that owns the failed claim.
	function Storage:RollbackTicket(TicketValue, MatchId: string)
		local Current = self.Tickets[TicketValue.Id]
		if Current and Current.Status == 'Matched' and Current.MatchId == MatchId then Current.Status = 'Queued'; Current.MatchId = nil; Current.UpdatedAt = self.Clock:Now() end
		return true;
	end

	-- CancelTicket -> boolean, string?
	-- Cancels one queued synthetic ticket without modifying production state.
	-- @param TicketId, string -> Ticket id.
	-- @param Reason, string? -> Cancellation reason.
	function Storage:CancelTicket(TicketId: string, Reason: string?)
		local Current = self.Tickets[TicketId]
		if not Current or Current.Status ~= 'Queued' then return false, 'ticket cannot be cancelled' end
		Current.Status = 'Cancelled'
		Current.CancelReason = Reason or 'cancelled'
		Current.UpdatedAt = self.Clock:Now()
		return true;
	end

	-- SetAssignment -> boolean, string?
	-- Stores one synthetic assignment and supports deterministic failure injection.
	-- @param TicketId, string -> Ticket id.
	-- @param Assignment, table -> Match assignment.
	function Storage:SetAssignment(TicketId: string, Assignment)
		self.AssignmentWrites += 1
		if self.FailAssignmentAt and self.AssignmentWrites == self.FailAssignmentAt then return false, 'intentional assignment failure' end
		self.Assignments[TicketId] = Assignment
		return true;
	end

	-- GetAssignment -> boolean, table?
	-- Reads one synthetic assignment.
	-- @param TicketId, string -> Ticket id.
	function Storage:GetAssignment(TicketId: string)
		return true, self.Assignments[TicketId];
	end

	-- RemoveAssignment -> boolean
	-- Removes one synthetic assignment.
	-- @param TicketId, string -> Ticket id.
	function Storage:RemoveAssignment(TicketId: string)
		self.Assignments[TicketId] = nil
		return true;
	end

	-- SetMatch -> boolean
	-- Stores one synthetic match record.
	-- @param Match, table -> Match record.
	function Storage:SetMatch(Match)
		self.Matches[Match.Id] = table.clone(Match)
		return true;
	end

	-- GetMatch -> boolean, table?
	-- Reads one synthetic match record.
	-- @param MatchId, string -> Match id.
	function Storage:GetMatch(MatchId: string)
		return true, self.Matches[MatchId];
	end

	-- RemoveMatch -> boolean
	-- Removes one synthetic match record.
	-- @param MatchId, string -> Match id.
	function Storage:RemoveMatch(MatchId: string)
		self.Matches[MatchId] = nil
		return true;
	end

	-- ListQueued -> table
	-- Returns current queued ticket objects without exposing acknowledged or matched entries.
	function Storage:ListQueued()
		local Result = {}
		for _, TicketValue in pairs(self.Tickets) do if TicketValue.Status == 'Queued' and TicketValue.ExpiresAt > self.Clock:Now() then table.insert(Result, TicketValue) end end

		-- compareTickets -> boolean
		-- Sorts queued test tickets by creation time for deterministic diagnostics.
		-- @param A, table -> First ticket.
		-- @param B, table -> Second ticket.
		local function compareTickets(A, B)
			return A.CreatedAt < B.CreatedAt;
		end

		table.sort(Result, compareTickets)
		return Result;
	end
end

local Coordinator = {} do
	Coordinator.__index = Coordinator
	Coordinator.ClassName = 'MatchmakingTestCoordinator'

	-- new -> MatchmakingTestCoordinator
	-- Creates a deterministic always-owned worker lease used by the isolated lab.
	function Coordinator.new()
		return setmetatable({Owned = true;}, Coordinator);
	end

	-- TryAcquire -> boolean
	-- Acquires the synthetic worker lease.
	function Coordinator:TryAcquire()
		self.Owned = true
		return true;
	end

	-- HasLease -> boolean
	-- Returns whether the deterministic test worker owns its lease.
	function Coordinator:HasLease()
		return self.Owned;
	end

	-- Release -> nil
	-- Releases the deterministic test worker lease.
	function Coordinator:Release()
		self.Owned = false
	end
end

local Dispatcher = {} do
	Dispatcher.__index = Dispatcher
	Dispatcher.ClassName = 'MatchmakingTestDispatcher'

	-- new -> MatchmakingTestDispatcher
	-- Creates an in-memory assignment-hint transport.
	function Dispatcher.new()
		return setmetatable({Messages = {};}, Dispatcher);
	end

	-- Publish -> boolean
	-- Records one production dispatcher payload for deterministic delivery by the simulator.
	-- @param Payload, table -> Assignment hint payload.
	function Dispatcher:Publish(Payload)
		table.insert(self.Messages, Payload)
		return true;
	end

	-- Drain -> table
	-- Removes and returns all unpublished-to-local-simulator assignment hints.
	function Dispatcher:Drain()
		local Result = self.Messages
		self.Messages = {}
		return Result;
	end
end

local Teleport = {} do
	Teleport.__index = Teleport
	Teleport.ClassName = 'MatchmakingTestTeleport'

	-- new -> MatchmakingTestTeleport
	-- Creates a deterministic reserved-server and delayed pseudo-player transport adapter.
	-- @param ClockValue, MatchmakingTestClock -> Deterministic runtime clock.
	-- @param RandomValue, Random -> Seeded simulator random source.
	function Teleport.new(ClockValue, RandomValue)
		local this = setmetatable({}, Teleport)
		this.Clock = ClockValue
		this.Random = RandomValue
		this.Reservations = 0
		this.FailReserve = false
		this.FailureRate = 0
		this.Delay = 2.2
		this.Pending = {}
		this.OnComplete = nil
		return this;
	end

	-- Reserve -> boolean, string, string?
	-- Simulates one reserved gameplay instance allocation.
	-- @param PlaceId, number -> Destination place id.
	function Teleport:Reserve(PlaceId: number)
		if self.FailReserve then return false, 'intentional reservation failure' end
		self.Reservations += 1
		return true, 'TEST_ACCESS_' .. tostring(self.Reservations), 'TEST_PRIVATE_' .. tostring(PlaceId) .. '_' .. tostring(self.Reservations);
	end

	-- Send -> boolean, string?
	-- Accepts pseudo players through the exact production Queue dispatch call and schedules arrival outcomes.
	-- @param PlayersValue, table -> Pseudo-player objects owned by one source ticket.
	-- @param Assignment, table -> Production assignment object.
	function Teleport:Send(PlayersValue, Assignment)
		for _, PlayerValue in ipairs(PlayersValue) do
			local Success = self.Random:NextNumber() >= self.FailureRate
			table.insert(self.Pending, {Player = PlayerValue; Assignment = Assignment; Success = Success; CompleteAt = self.Clock:Now() + self.Delay;})
		end
		return true;
	end

	-- Step -> nil
	-- Completes delayed pseudo transports once their deterministic arrival time is reached.
	function Teleport:Step()
		local Now = self.Clock:Now()
		for Index = #self.Pending, 1, -1 do
			local Record = self.Pending[Index]
			if Record.CompleteAt > Now then continue end
			table.remove(self.Pending, Index)
			if self.OnComplete then self.OnComplete(Record.Player, Record.Assignment, Record.Success) end
		end
	end
end

-- New -> table
-- Creates a complete dependency-injected matchmaking runtime whose Queue engine is the same production Queue module used by live players.
-- @param Config, table -> Matchmaking configuration.
-- @param RandomValue, Random -> Seeded deterministic random source.
-- @param StartTime, number? -> Optional deterministic clock start.
function Runtime.New(Config, RandomValue, StartTime: number?)
	local ClockValue = Clock.new(StartTime)
	local IdValue = Id.new()
	local DispatcherValue = Dispatcher.new()
	local TeleportValue = Teleport.new(ClockValue, RandomValue)
	local StorageValue = nil

	-- storageFactory -> MatchmakingTestStorage
	-- Creates the single isolated storage adapter consumed by one production Queue instance.
	-- @param Name, string -> Logical queue name.
	-- @param RuntimeConfig, table -> Matchmaking configuration.
	local function storageFactory(Name, RuntimeConfig)
		StorageValue = Storage.new(Name, RuntimeConfig, ClockValue, IdValue)
		return StorageValue;
	end

	-- coordinatorFactory -> MatchmakingTestCoordinator
	-- Creates an always-owned deterministic coordinator for the production Queue worker.
	-- @param StorageAdapter, MatchmakingTestStorage -> Injected storage adapter.
	-- @param Name, string -> Logical queue name.
	-- @param RuntimeConfig, table -> Matchmaking configuration.
	local function coordinatorFactory(StorageAdapter, Name, RuntimeConfig)
		return Coordinator.new();
	end

	-- getStorage -> MatchmakingTestStorage?
	-- Returns the storage adapter created when Queue.new invokes the injected factory.
	local function getStorage()
		return StorageValue;
	end

	local QueueRuntime = {Config = Config; Clock = ClockValue; Id = IdValue; Dispatcher = DispatcherValue; Teleport = TeleportValue; StorageFactory = storageFactory; CoordinatorFactory = coordinatorFactory;}
	return {QueueRuntime = QueueRuntime; Clock = ClockValue; Id = IdValue; Dispatcher = DispatcherValue; Teleport = TeleportValue; GetStorage = getStorage;};
end

return Runtime;
