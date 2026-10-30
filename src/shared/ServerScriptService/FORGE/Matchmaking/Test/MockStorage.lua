-- Author -> lolokdev.
-- Last Edit -> September 14, 2026 4:25 PM CDT

local MockStorage = {} do
	MockStorage.__index = MockStorage
	MockStorage.ClassName = 'MatchmakingMockStorage'

	-- new -> MatchmakingMockStorage
	-- Creates an in-memory storage adapter implementing the production Queue allocation contract.
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
	-- Atomically transitions one synthetic queued ticket to Matched for the expected match id.
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
	-- Restores one failed synthetic match claim back to Queued.
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
		self.Matches[Match.Id] = Match
		return true;
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

return MockStorage;
