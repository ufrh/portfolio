-- Author -> lolokdev.
-- Last Edit -> September 15, 2026 1:55 PM CDT

local HttpService = game:GetService('HttpService')
local MemoryStoreService = game:GetService('MemoryStoreService')
local MessagingService = game:GetService('MessagingService')
local RunService = game:GetService('RunService')
local TeleportService = game:GetService('TeleportService')

local Config = require(script.Parent.Parent.Config)
local Queue = require(script.Parent.Parent.Queue)
local Rating = require(script.Parent.Parent.Rating)
local Rules = require(script.Parent.Parent.Rules)
local Sanitizer = require(script.Parent.Parent.Sanitizer)
local TestRuntime = require(script.Parent.Runtime)

local MockStorage = {} do
	MockStorage.__index = MockStorage
	MockStorage.ClassName = 'MatchmakingMockStorage'

	-- new -> MatchmakingMockStorage
	-- Creates an in-memory storage adapter implementing the production queue-allocation contract.
	function MockStorage.new()
		local this = setmetatable({}, MockStorage)
		this.Tickets = {}
		this.Assignments = {}
		this.Matches = {}
		this.Queue = {}
		this.Receipts = {}
		this.AssignmentWrites = 0
		this.FailAssignmentAt = nil
		return this;
	end

	-- SeedTicket -> nil
	-- Inserts one synthetic ticket into both ticket storage and the mock queue.
	-- @param Ticket, table -> Synthetic ticket payload.
	function MockStorage:SeedTicket(Ticket)
		self.Tickets[Ticket.Id] = Ticket
		table.insert(self.Queue, {TicketId = Ticket.Id; Receipt = 'receipt:' .. Ticket.Id; Read = false; Removed = false;})
	end

	-- ReadOne -> boolean, table?
	-- Reads one mock queue entry exactly once for the current worker cycle.
	function MockStorage:ReadOne()
		for _, Record in ipairs(self.Queue) do
			if not Record.Read and not Record.Removed then Record.Read = true; self.Receipts[Record.Receipt] = Record; return true, {TicketId = Record.TicketId; Receipt = Record.Receipt;} end
		end
		return true, nil;
	end

	-- GetTicket -> boolean, table?
	-- Reads one synthetic ticket by id.
	-- @param TicketId, string -> Ticket id.
	function MockStorage:GetTicket(TicketId: string)
		return true, self.Tickets[TicketId];
	end

	-- ClaimTicket -> boolean, string?
	-- Atomically transitions one synthetic queued ticket to matched for the expected match id.
	-- @param Ticket, table -> Ticket being claimed.
	-- @param MatchId, string -> Match id claiming the ticket.
	function MockStorage:ClaimTicket(Ticket, MatchId: string)
		local Current = self.Tickets[Ticket.Id]
		if not Current or Current.Status ~= 'Queued' then return false, 'ticket is no longer claimable' end
		Current.Status = 'Matched'
		Current.MatchId = MatchId
		return true;
	end

	-- RollbackTicket -> boolean
	-- Restores one failed synthetic match claim back to queued.
	-- @param Ticket, table -> Ticket being restored.
	-- @param MatchId, string -> Failed match id.
	function MockStorage:RollbackTicket(Ticket, MatchId: string)
		local Current = self.Tickets[Ticket.Id]
		if Current and Current.Status == 'Matched' and Current.MatchId == MatchId then Current.Status = 'Queued'; Current.MatchId = nil end
		return true;
	end

	-- SetMatch -> boolean
	-- Stores one synthetic match record.
	-- @param Match, table -> Match record.
	function MockStorage:SetMatch(Match)
		self.Matches[Match.Id] = table.clone(Match)
		return true;
	end

	-- GetMatch -> boolean, table?
	-- Reads one synthetic match record.
	-- @param MatchId, string -> Match id.
	function MockStorage:GetMatch(MatchId: string)
		return true, self.Matches[MatchId];
	end

	-- RemoveMatch -> boolean
	-- Removes one synthetic match record.
	-- @param MatchId, string -> Match id.
	function MockStorage:RemoveMatch(MatchId: string)
		self.Matches[MatchId] = nil
		return true;
	end

	-- SetAssignment -> boolean, string?
	-- Stores one synthetic assignment or intentionally fails at a configured write index.
	-- @param TicketId, string -> Ticket receiving the assignment.
	-- @param Assignment, table -> Match assignment.
	function MockStorage:SetAssignment(TicketId: string, Assignment)
		self.AssignmentWrites += 1
		if self.FailAssignmentAt and self.AssignmentWrites == self.FailAssignmentAt then return false, 'intentional assignment failure' end
		self.Assignments[TicketId] = Assignment
		return true;
	end

	-- GetAssignment -> boolean, table?
	-- Reads one synthetic assignment.
	-- @param TicketId, string -> Ticket id.
	function MockStorage:GetAssignment(TicketId: string)
		return true, self.Assignments[TicketId];
	end

	-- RemoveAssignment -> boolean
	-- Removes one synthetic assignment.
	-- @param TicketId, string -> Ticket id.
	function MockStorage:RemoveAssignment(TicketId: string)
		self.Assignments[TicketId] = nil
		return true;
	end

	-- RemoveReceipt -> boolean, string?
	-- Acknowledges one synthetic queue receipt.
	-- @param Receipt, string -> Queue receipt.
	function MockStorage:RemoveReceipt(Receipt: string)
		local Record = self.Receipts[Receipt]
		if not Record then return false, 'unknown receipt' end
		Record.Removed = true
		return true;
	end
end

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

local MockDispatcher = {} do
	MockDispatcher.__index = MockDispatcher
	MockDispatcher.ClassName = 'MatchmakingMockDispatcher'

	-- new -> MatchmakingMockDispatcher
	-- Creates an in-memory assignment-hint recorder.
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

local SelfTest = {} do
	-- makeCoordinator -> table
	-- Creates a no-op lease coordinator for deterministic in-memory Queue tests.
	local function makeCoordinator()
		local Coordinator = {}

		-- TryAcquire -> boolean
		-- Simulates successful worker-lease acquisition for deterministic tests.
		function Coordinator:TryAcquire() return true end

		-- HasLease -> boolean
		-- Reports an active synthetic worker lease.
		function Coordinator:HasLease() return true end

		-- Release -> nil
		-- Releases the no-op synthetic worker lease.
		function Coordinator:Release() end

		return Coordinator;
	end

	-- makeTicket -> table
	-- Creates one production-shaped deterministic stake/MMR ticket for automated invariant tests.
	-- @param Id, string -> Ticket id.
	-- @param Users, table -> Synthetic user ids.
	-- @param MMR, number -> Hidden ticket MMR.
	-- @param CreatedAt, number -> Synthetic creation timestamp.
	-- @param Stake, string? -> Optional stake name.
	-- @param Mode, string? -> Optional mode name.
	local function makeTicket(Id: string, Users, MMR: number, CreatedAt: number, Stake: string?, Mode: string?)
		local MMRs = {}
		for _, UserId in ipairs(Users) do MMRs[tostring(UserId)] = MMR end
		return {Id = Id; Queue = '__TEST__'; Stake = Stake or 'Standard'; Mode = Mode or 'FFA'; Users = Users; Size = #Users; MMR = MMR; MMRs = MMRs; Priority = 0; Data = {}; SourceJobId = 'TEST'; SourcePlaceId = game.PlaceId; CreatedAt = CreatedAt; UpdatedAt = CreatedAt; ExpiresAt = CreatedAt + 300; Status = 'Queued';};
	end

	-- makeRecord -> table
	-- Wraps one synthetic ticket in the production candidate record shape.
	-- @param Ticket, table -> Ticket payload.
	local function makeRecord(Ticket)
		return {Ticket = Ticket; Receipt = 'receipt:' .. Ticket.Id;};
	end

	-- definition -> table
	-- Creates a normalized test definition with the production stake whitelist.
	-- @param Source, table -> Test queue definition.
	local function definition(Source)
		Source.Stakes = {'Casual'; 'Standard'; 'Heated'; 'Ruckus'; 'AllIn';}
		Source.DefaultStake = 'Standard'
		Source.Modes = {'FFA'; 'BOUNTY'; 'HEIST';}
		Source.DefaultMode = 'FFA'
		return Queue.Normalize('__TEST__', Source, Config);
	end

	-- assertEqual -> nil
	-- Asserts strict equality with a concise diagnostic.
	-- @param Actual, any -> Actual value.
	-- @param Expected, any -> Expected value.
	-- @param Message, string -> Failure context.
	local function assertEqual(Actual, Expected, Message: string)
		assert(Actual == Expected, Message .. ' expected ' .. tostring(Expected) .. ', got ' .. tostring(Actual))
	end

	-- buildPipelineRuntime -> table, MatchmakingMockStorage, MatchmakingMockTeleport, MatchmakingMockDispatcher
	-- Creates Queue dependencies using in-memory storage and transport adapters.
	-- @param StorageValue, MatchmakingMockStorage -> Storage adapter.
	local function buildPipelineRuntime(StorageValue)
		local Teleport = MockTeleport.new()
		local Dispatcher = MockDispatcher.new()

		-- storageFactory -> MatchmakingMockStorage
		-- Returns the deterministic storage adapter injected into the production Queue.
		-- @param Name, string -> Requested logical queue name.
		-- @param RuntimeConfig, table -> Matchmaking configuration.
		local function storageFactory(Name, RuntimeConfig)
			return StorageValue;
		end

		-- coordinatorFactory -> table
		-- Returns a no-op deterministic queue-worker coordinator.
		-- @param StorageAdapter, table -> Injected storage adapter.
		-- @param Name, string -> Requested queue name.
		-- @param RuntimeConfig, table -> Matchmaking configuration.
		local function coordinatorFactory(StorageAdapter, Name, RuntimeConfig)
			return makeCoordinator();
		end

		return {Config = Config; Teleport = Teleport; Dispatcher = Dispatcher; StorageFactory = storageFactory; CoordinatorFactory = coordinatorFactory;}, StorageValue, Teleport, Dispatcher;
	end

	-- testExactMatch -> nil
	-- Verifies exact-target candidate selection.
	local function testExactMatch()
		local Definition = definition({Players = {Min = 8; Target = 8; Max = 8;}; Teams = {Count = 2; Size = 4;}; MMR = {Enabled = false;};})
		local Candidates = {}
		for Index = 1, 8 do table.insert(Candidates, makeRecord(makeTicket('E' .. tostring(Index), {-Index;}, 1000, 100))) end
		local Selected = Rules.Select(Candidates, Definition, 100)
		assert(Selected and #Selected == 8, 'exact 8-player match was not selected')
	end

	-- testPartyPreservation -> nil
	-- Verifies every user from one party ticket lands on the same team.
	local function testPartyPreservation()
		local Definition = definition({Players = {Min = 8; Target = 8; Max = 8;}; Teams = {Count = 2; Size = 4;}; MMR = {Enabled = false;};})
		local Selected = {makeRecord(makeTicket('P1', {-1; -2;}, 900, 100)), makeRecord(makeTicket('P2', {-3; -4;}, 1100, 100)), makeRecord(makeTicket('P3', {-5; -6;}, 950, 100)), makeRecord(makeTicket('P4', {-7; -8;}, 1050, 100));}
		local Teams = Rules.BalanceTeams(Selected, Definition)
		assert(Teams, 'team balancing returned nil')
		for _, Record in ipairs(Selected) do
			local Expected = Teams[tostring(Record.Ticket.Users[1])]
			for _, UserId in ipairs(Record.Ticket.Users) do assertEqual(Teams[tostring(UserId)], Expected, 'party split across teams') end
		end
	end

	-- testStakeIsolation -> nil
	-- Verifies different UI stake selections can never form one match together.
	local function testStakeIsolation()
		local Definition = definition({Players = {Min = 2; Target = 2; Max = 2;}; MMR = {Enabled = false;};})
		local Candidates = {makeRecord(makeTicket('A', {-1;}, 1000, 100, 'Casual')), makeRecord(makeTicket('B', {-2;}, 1000, 100, 'Heated'));}
		assert(Rules.Select(Candidates, Definition, 100) == nil, 'different stakes were incorrectly matched')
	end

	-- testModeIsolation -> nil
	-- Verifies different selected modes can never form one match together.
	local function testModeIsolation()
		local Definition = definition({Players = {Min = 2; Target = 2; Max = 2;}; MMR = {Enabled = false;};})
		local Candidates = {makeRecord(makeTicket('MF', {-1;}, 1000, 100, 'Standard', 'FFA')), makeRecord(makeTicket('MB', {-2;}, 1000, 100, 'Standard', 'BOUNTY'));}
		assert(Rules.Select(Candidates, Definition, 100) == nil, 'different modes were incorrectly matched')
	end

	-- testSoloSessionIsolation -> nil
	-- Verifies isolated one-client transport sessions can never consume each other's synthetic filler tickets.
	local function testSoloSessionIsolation()
		local Definition = definition({Players = {Min = 2; Target = 2; Max = 2;}; MMR = {Enabled = false;};})
		local First = makeTicket('SOLO_A', {-1001;}, 1000, 100, 'Standard', 'FFA')
		local Second = makeTicket('SOLO_B', {-1002;}, 1000, 100, 'Standard', 'FFA')
		First.Test = true
		First.TestType = 'SoloTransport'
		First.TestSessionId = 'SESSION_A'
		Second.Test = true
		Second.TestType = 'SoloTransport'
		Second.TestSessionId = 'SESSION_B'
		assert(Rules.Select({makeRecord(First), makeRecord(Second);}, Definition, 100) == nil, 'different solo transport sessions were incorrectly matched')
		Second.TestSessionId = 'SESSION_A'
		assert(Rules.Select({makeRecord(First), makeRecord(Second);}, Definition, 100) ~= nil, 'same solo transport session failed to match')
	end

	-- testMMRExpansion -> nil
	-- Verifies incompatible hidden MMR becomes compatible only after configured wait expansion.
	local function testMMRExpansion()
		local Definition = definition({Players = {Min = 2; Target = 2; Max = 2;}; MMR = {InitialRange = 50; ExpandPerSecond = 50; MaxRange = 600;};})
		local Candidates = {makeRecord(makeTicket('M1', {-1;}, 800, 100)), makeRecord(makeTicket('M2', {-2;}, 1200, 100));}
		assert(Rules.Select(Candidates, Definition, 100) == nil, 'MMR window accepted a 400-rating gap immediately')
		assert(Rules.Select(Candidates, Definition, 108) ~= nil, 'expanded MMR window failed to accept a valid delayed match')
	end

	-- testPriorityTieBreak -> nil
	-- Verifies explicit server priority wins when creation times are identical.
	local function testPriorityTieBreak()
		local Definition = definition({Players = {Min = 1; Target = 1; Max = 1;}; MMR = {Enabled = false;};})
		local Low = makeTicket('LOW', {-1;}, 1000, 100)
		local High = makeTicket('HIGH', {-2;}, 1000, 100)
		Low.Priority = 1
		High.Priority = 100
		local Selected = Rules.Select({makeRecord(Low), makeRecord(High);}, Definition, 100)
		assert(Selected and Selected[1].Ticket.Id == 'HIGH', 'higher priority ticket did not win equal-time tie')
	end

	-- testPartialMatch -> nil
	-- Verifies AllowPartial can start at Players.Min without exceeding Players.Target.
	local function testPartialMatch()
		local Definition = definition({Players = {Min = 12; Target = 16; Max = 16;}; AllowPartial = true; MMR = {Enabled = false;};})
		local Candidates = {}
		for Index = 1, 12 do table.insert(Candidates, makeRecord(makeTicket('F' .. tostring(Index), {-Index;}, 1000, 100))) end
		local Selected = Rules.Select(Candidates, Definition, 100)
		assert(Selected and #Selected == 12, 'partial match did not start at Players.Min')
	end

	-- testTeamBalance -> nil
	-- Verifies team balancing respects capacity and produces all assignments.
	local function testTeamBalance()
		local Definition = definition({Players = {Min = 8; Target = 8; Max = 8;}; Teams = {Count = 2; Size = 4;}; MMR = {Enabled = false;};})
		local Selected = {}
		for Index = 1, 8 do table.insert(Selected, makeRecord(makeTicket('T' .. tostring(Index), {-Index;}, 700 + Index * 100, 100))) end
		local Teams = Rules.BalanceTeams(Selected, Definition)
		assert(Teams, 'team balancing returned nil')
		local Counts = {}
		for _, Team in pairs(Teams) do Counts[Team] = (Counts[Team] or 0) + 1 end
		assertEqual(Counts[1], 4, 'team one capacity mismatch')
		assertEqual(Counts[2], 4, 'team two capacity mismatch')
	end

	-- testSanitizer -> nil
	-- Verifies cyclic gameplay data is rejected before MemoryStore persistence.
	local function testSanitizer()
		local Value = {}
		Value.Self = Value

		-- sanitize -> any
		-- Runs the expected failing cyclic metadata copy.
		local function sanitize()
			return Sanitizer.Copy(Value, Config);
		end

		local Success = pcall(sanitize)
		assert(not Success, 'cyclic matchmaking data was accepted')
	end

	-- testRating -> nil
	-- Verifies Elo helpers move winners upward and losers downward.
	local function testRating()
		local Winner = Rating.Elo(1000, 1000, 1)
		local Loser = Rating.Elo(1000, 1000, 0)
		assert(Winner > 1000 and Loser < 1000, 'Elo update direction is invalid')
	end

	-- testPublicTicketPrivacy -> nil
	-- Verifies queue status strips hidden MMR and private gameplay ticket data.
	local function testPublicTicketPrivacy()
		local Definition = definition({Players = {Min = 2; Target = 2; Max = 2;}; MMR = {Enabled = false;};})
		local StorageValue = MockStorage.new()
		local Runtime = buildPipelineRuntime(StorageValue)
		local Instance = Queue.new('__TEST__', Definition, Runtime)
		local Public = Instance:_PublicTicket(makeTicket('PRIVATE', {-1;}, 1875, 100, 'Ruckus'))
		assert(Public.MMR == nil and Public.MMRs == nil and Public.Data == nil, 'public ticket leaked hidden MMR/private data')
		assertEqual(Public.Stake, 'Ruckus', 'public ticket lost stake')
		Instance:Destroy()
	end

	-- testAllocationPipeline -> nil
	-- Runs the real Queue worker allocation path with stake, hidden MMR, destination and gameplay-data propagation.
	local function testAllocationPipeline()
		-- buildGameplayData -> table
		-- Produces deterministic server-only gameplay data for the allocation test.
		-- @param Context, table -> Match build context.
		local function buildGameplayData(Context)
			return {Stake = Context.Stake; AverageMMR = Context.MMR; Marker = 'GAMEPLAY';};
		end

		local Definition = definition({PlaceId = 987654; Players = {Min = 8; Target = 8; Max = 8;}; Teams = {Count = 2; Size = 4;}; MMR = {Enabled = false;}; BuildGameplayData = buildGameplayData;})
		local StorageValue = MockStorage.new()
		local Runtime, _, _, Dispatcher = buildPipelineRuntime(StorageValue)
		local Instance = Queue.new('__TEST__', Definition, Runtime)
		for Index = 1, 8 do StorageValue:SeedTicket(makeTicket('W' .. tostring(Index), {-Index;}, 1000 + Index, os.time(), 'Heated')) end
		Instance:_WorkerCycle()
		local MatchCount = 0
		local ReadyMatch = nil
		for _, Match in pairs(StorageValue.Matches) do MatchCount += 1; ReadyMatch = Match end
		assertEqual(MatchCount, 1, 'worker did not create exactly one match')
		assert(ReadyMatch and ReadyMatch.Status == 'Ready', 'created match never reached Ready')
		assertEqual(ReadyMatch.Stake, 'Heated', 'created match lost selected stake')
		assertEqual(ReadyMatch.PlaceId, 987654, 'created match used wrong gameplay place')
		assert(type(ReadyMatch.MMR) == 'number' and type(ReadyMatch.MMRs) == 'table', 'hidden MMR was not persisted server-side')
		assert(ReadyMatch.GameplayData and ReadyMatch.GameplayData.Marker == 'GAMEPLAY', 'gameplay data was not persisted')
		assertEqual(StorageValue.AssignmentWrites, 8, 'assignment writes were duplicated or missing')
		assertEqual(#Dispatcher.Messages, 1, 'assignment dispatch hint was not published once')
		assert(Dispatcher.Messages[1].AccessCode == nil, 'reserved-server access code leaked through dispatcher payload')
		Instance:Destroy()
	end

	-- testAllocationRollback -> nil
	-- Verifies partial assignment failure removes match artifacts and rolls every ticket back to queued.
	local function testAllocationRollback()
		local Definition = definition({Players = {Min = 4; Target = 4; Max = 4;}; Teams = {Count = 2; Size = 2;}; MMR = {Enabled = false;};})
		local StorageValue = MockStorage.new()
		StorageValue.FailAssignmentAt = 2
		local Runtime = buildPipelineRuntime(StorageValue)
		local Instance = Queue.new('__TEST__', Definition, Runtime)
		local Selected = {}
		for Index = 1, 4 do local TicketValue = makeTicket('R' .. tostring(Index), {-Index;}, 1000, os.time()); StorageValue:SeedTicket(TicketValue); table.insert(Selected, makeRecord(TicketValue)) end
		local Success = Instance:_CreateMatch(Selected)
		assert(not Success, 'intentional assignment failure unexpectedly succeeded')
		for _, TicketValue in pairs(StorageValue.Tickets) do assertEqual(TicketValue.Status, 'Queued', 'failed allocation left a ticket matched') end
		assert(next(StorageValue.Matches) == nil, 'failed allocation left a match record')
		assert(next(StorageValue.Assignments) == nil, 'failed allocation left assignment records')
		Instance:Destroy()
	end

	-- testReservationRollback -> nil
	-- Verifies reserved-server allocation failure restores all ticket claims and writes no match.
	local function testReservationRollback()
		local Definition = definition({Players = {Min = 4; Target = 4; Max = 4;}; Teams = {Count = 2; Size = 2;}; MMR = {Enabled = false;};})
		local StorageValue = MockStorage.new()
		local Runtime, _, Teleport = buildPipelineRuntime(StorageValue)
		Teleport.FailReserve = true
		local Instance = Queue.new('__TEST__', Definition, Runtime)
		local Selected = {}
		for Index = 1, 4 do local TicketValue = makeTicket('Q' .. tostring(Index), {-Index;}, 1000, os.time()); StorageValue:SeedTicket(TicketValue); table.insert(Selected, makeRecord(TicketValue)) end
		local Success = Instance:_CreateMatch(Selected)
		assert(not Success, 'intentional reservation failure unexpectedly succeeded')
		for _, TicketValue in pairs(StorageValue.Tickets) do assertEqual(TicketValue.Status, 'Queued', 'reservation failure left a ticket matched') end
		assert(next(StorageValue.Matches) == nil, 'reservation failure wrote a match record')
		Instance:Destroy()
	end

	-- testInjectedRuntimeParity -> nil
	-- Verifies the lab's injected clock/storage/teleport runtime drives the exact production Queue worker rather than a duplicate matcher.
	local function testInjectedRuntimeParity()
		local Definition = definition({Players = {Min = 2; Target = 2; Max = 2;}; Teams = {Count = 2; Size = 1;}; MMR = {InitialRange = 0; ExpandPerSecond = 50; MaxRange = 500;};})
		local RuntimeValue = TestRuntime.New(Config, Random.new(99), 100)
		local Instance = Queue.new('__TEST__', Definition, RuntimeValue.QueueRuntime)
		local StorageValue = RuntimeValue.GetStorage()
		StorageValue:SeedTicket(makeTicket('CLOCK_A', {-901;}, 1000, 100, 'Standard'))
		StorageValue:SeedTicket(makeTicket('CLOCK_B', {-902;}, 1200, 100, 'Standard'))
		Instance:_WorkerCycle()
		assert(next(StorageValue.Matches) == nil, 'injected clock matched outside the initial MMR window')
		RuntimeValue.Clock:Advance(5)
		Instance:_WorkerCycle()
		local MatchCount = 0
		for _ in pairs(StorageValue.Matches) do MatchCount += 1 end
		assertEqual(MatchCount, 1, 'production Queue worker did not honor injected clock MMR expansion')
		Instance:Destroy()
	end

	local Tests = {
		{'Exact target selection', testExactMatch},
		{'Party preservation', testPartyPreservation},
		{'Stake isolation', testStakeIsolation},
		{'Mode isolation', testModeIsolation},
		{'Solo test-session isolation', testSoloSessionIsolation},
		{'MMR expansion', testMMRExpansion},
		{'Priority tie-break', testPriorityTieBreak},
		{'Partial-match threshold', testPartialMatch},
		{'Team capacity balance', testTeamBalance},
		{'Gameplay-data sanitizer', testSanitizer},
		{'Elo rating', testRating},
		{'Hidden MMR privacy', testPublicTicketPrivacy},
		{'Queue allocation pipeline', testAllocationPipeline},
		{'Allocation rollback', testAllocationRollback},
		{'Reservation rollback', testReservationRollback},
		{'Injected runtime parity', testInjectedRuntimeParity};
	}

	-- probeResult -> table
	-- Creates one standardized external-service probe result.
	-- @param Name, string -> Probe name.
	-- @param Passed, boolean -> Whether the probe completed successfully.
	-- @param Status, string -> PASS, FAIL or UNAVAILABLE.
	-- @param Message, string -> Diagnostic detail.
	local function probeResult(Name: string, Passed: boolean, Status: string, Message: string)
		return {Name = Name; Passed = Passed; Status = Status; Message = Message;};
	end

	-- probeHashMap -> table
	-- Verifies MemoryStoreHashMap set/get/remove behavior using a unique disposable key.
	local function probeHashMap()
		local Map = MemoryStoreService:GetHashMap('__FORGE_MM_PROBE_HASH')
		local Key = HttpService:GenerateGUID(false)
		local Token = HttpService:GenerateGUID(false)

		-- operation -> nil
		-- Executes the disposable HashMap lifecycle probe.
		local function operation()
			Map:SetAsync(Key, {Token = Token;}, 20)
			local Value = Map:GetAsync(Key)
			Map:RemoveAsync(Key)
			assert(type(Value) == 'table' and Value.Token == Token, 'MemoryStoreHashMap returned unexpected data')
		end

		local Success, Reason = pcall(operation)
		return probeResult('MemoryStore HashMap', Success, Success and 'PASS' or 'UNAVAILABLE', Success and 'Set/Get/Remove succeeded.' or tostring(Reason));
	end

	-- probeQueue -> table
	-- Verifies MemoryStoreQueue add/read/remove receipt behavior using a unique disposable queue.
	local function probeQueue()
		local TestQueue = MemoryStoreService:GetQueue('__FORGE_MM_PROBE_QUEUE_' .. HttpService:GenerateGUID(false), 2)
		local Token = HttpService:GenerateGUID(false)

		-- operation -> nil
		-- Executes the disposable MemoryStoreQueue receipt probe.
		local function operation()
			TestQueue:AddAsync(Token, 20, 0)
			local Items, Receipt = TestQueue:ReadAsync(1, true, 1)
			assert(type(Items) == 'table' and Items[1] == Token and type(Receipt) == 'string', 'MemoryStoreQueue returned unexpected data')
			TestQueue:RemoveAsync(Receipt)
		end

		local Success, Reason = pcall(operation)
		return probeResult('MemoryStore Queue', Success, Success and 'PASS' or 'UNAVAILABLE', Success and 'Add/Read/Remove succeeded.' or tostring(Reason));
	end

	-- probeMessaging -> table
	-- Verifies one MessagingService publish can reach a matching temporary subscription.
	local function probeMessaging()
		local Topic = '__FORGE_MM_PROBE_' .. string.gsub(HttpService:GenerateGUID(false), '-', '')
		local Token = HttpService:GenerateGUID(false)
		local Received = false

		-- onMessage -> nil
		-- Marks the probe complete only when the expected token returns.
		-- @param Message, table -> MessagingService envelope.
		local function onMessage(Message)
			if type(Message) == 'table' and type(Message.Data) == 'table' and Message.Data.Token == Token then Received = true end
		end

		local Subscription = nil

		-- operation -> nil
		-- Executes the temporary MessagingService round-trip probe.
		local function operation()
			Subscription = MessagingService:SubscribeAsync(Topic, onMessage)
			MessagingService:PublishAsync(Topic, {Token = Token;})
			local Started = os.clock()
			while not Received and os.clock() - Started < 2 do task.wait(.05) end
			if Subscription then Subscription:Disconnect() end
			assert(Received, 'published message was not observed before timeout')
		end

		local Success, Reason = pcall(operation)
		if Subscription then pcall(Subscription.Disconnect, Subscription) end
		return probeResult('MessagingService', Success, Success and 'PASS' or 'UNAVAILABLE', Success and 'Publish/Subscribe succeeded.' or tostring(Reason));
	end

	-- probeReserveServer -> table
	-- Verifies reserved-server allocation when Roblox permits it in the current environment.
	local function probeReserveServer()
		if game.PlaceId <= 0 then return probeResult('ReserveServer', false, 'UNAVAILABLE', 'Publish the experience before probing reserved servers.') end

		-- operation -> nil
		-- Executes one reserved-server allocation probe without teleporting a player.
		local function operation()
			local AccessCode, PrivateServerId = TeleportService:ReserveServerAsync(game.PlaceId)
			assert(type(AccessCode) == 'string' and AccessCode ~= '', 'ReserveServerAsync returned no access code')
			assert(type(PrivateServerId) == 'string', 'ReserveServerAsync returned no private server id')
		end

		local Success, Reason = pcall(operation)
		local Status = Success and 'PASS' or (RunService:IsStudio() and 'UNAVAILABLE' or 'FAIL')
		return probeResult('ReserveServer', Success, Status, Success and 'Reservation succeeded.' or tostring(Reason));
	end

	-- Run -> table
	-- Executes every deterministic matchmaking invariant test and returns a UI-safe report.
	function SelfTest.Run()
		local Report = {Total = #Tests; Passed = 0; Failed = 0; Tests = {};}
		for _, Test in ipairs(Tests) do
			local Name = Test[1]
			local Callback = Test[2]
			local Success, Reason = pcall(Callback)
			if Success then Report.Passed += 1 else Report.Failed += 1 end
			table.insert(Report.Tests, {Name = Name; Passed = Success; Message = Success and 'PASS' or tostring(Reason);})
		end
		return Report;
	end

	-- Probe -> table
	-- Runs opt-in Roblox service integration probes without teleporting any real player.
	function SelfTest.Probe()
		local Results = {probeHashMap(), probeQueue(), probeMessaging(), probeReserveServer();}
		local Passed = 0
		local Failed = 0
		local Unavailable = 0
		for _, Item in ipairs(Results) do if Item.Status == 'PASS' then Passed += 1 elseif Item.Status == 'UNAVAILABLE' then Unavailable += 1 else Failed += 1 end end
		return {Passed = Passed; Failed = Failed; Unavailable = Unavailable; Total = #Results; Results = Results;};
	end
end

return SelfTest;
