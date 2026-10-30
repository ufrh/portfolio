-- Author -> lolokdev.
-- Last Edit -> September 14, 2026 4:25 PM CDT

local MemoryStoreService = game:GetService('MemoryStoreService')

local Sanitizer = require(script.Parent.Sanitizer)

local Storage = {} do
	Storage.__index = Storage
	Storage.ClassName = 'MatchmakingStorage'

	-- retry -> boolean, ...any
	-- Retries transient MemoryStore operations with bounded exponential backoff.
	-- @param Attempts, number -> Maximum attempts.
	-- @param BaseDelay, number -> Initial delay.
	-- @param MaxDelay, number -> Maximum delay.
	-- @param Callback, function -> Operation callback.
	-- @param ..., any -> Callback arguments.
	local function retry(Attempts: number, BaseDelay: number, MaxDelay: number, Callback, ...)
		local Arguments = table.pack(...)
		local LastError = 'unknown MemoryStore error'

		for Attempt = 1, Attempts do
			local Result = table.pack(pcall(Callback, table.unpack(Arguments, 1, Arguments.n)))
			if Result[1] then return true, table.unpack(Result, 2, Result.n) end
			LastError = tostring(Result[2])
			if Attempt < Attempts then task.wait(math.min(BaseDelay * 2 ^ (Attempt - 1), MaxDelay)) end
		end

		return false, LastError;
	end

	-- new -> MatchmakingStorage
	-- Creates shared ticket maps plus one MemoryStoreQueue for a logical matchmaking queue.
	-- @param QueueName, string -> Logical queue name.
	-- @param Config, table -> Matchmaking configuration.
	function Storage.new(QueueName: string, Config)
		local this = setmetatable({}, Storage)
		local Name = Sanitizer.QueueName(QueueName)
		local Prefix = Config.Namespace

		this.Name = QueueName
		this.Config = Config
		this.Queue = MemoryStoreService:GetQueue(Prefix .. ':queue:' .. Name, Config.QueueInvisibility)
		this.Tickets = MemoryStoreService:GetHashMap(Prefix .. ':tickets')
		this.Memberships = MemoryStoreService:GetHashMap(Prefix .. ':memberships')
		this.Assignments = MemoryStoreService:GetHashMap(Prefix .. ':assignments')
		this.Matches = MemoryStoreService:GetHashMap(Prefix .. ':matches')
		this.Leases = MemoryStoreService:GetHashMap(Prefix .. ':leases')

		return this;
	end

	-- _GetTicket -> any
	-- Raw MemoryStore ticket lookup callback.
	-- @param Key, string -> Ticket id.
	function Storage:_GetTicket(Key: string)
		return self.Tickets:GetAsync(Key);
	end

	-- GetTicket -> boolean, table?
	-- Reads one ticket by id.
	-- @param TicketId, string -> Ticket id.
	function Storage:GetTicket(TicketId: string)
		return retry(self.Config.RetryAttempts, self.Config.RetryDelay, self.Config.RetryMaxDelay, Storage._GetTicket, self, TicketId);
	end

	-- _SetTicket -> boolean
	-- Raw ticket persistence callback.
	-- @param Key, string -> Ticket id.
	-- @param Value, table -> Ticket payload.
	-- @param TTL, number -> Expiration seconds.
	function Storage:_SetTicket(Key: string, Value, TTL: number)
		return self.Tickets:SetAsync(Key, Value, TTL);
	end

	-- SetTicket -> boolean, any
	-- Writes one ticket with bounded expiration.
	-- @param TicketValue, table -> Ticket payload.
	function Storage:SetTicket(TicketValue)
		local TTL = math.max(TicketValue.ExpiresAt - os.time(), 1)
		return retry(self.Config.RetryAttempts, self.Config.RetryDelay, self.Config.RetryMaxDelay, Storage._SetTicket, self, TicketValue.Id, TicketValue, TTL);
	end

	-- _RemoveTicket -> nil
	-- Raw ticket removal callback.
	-- @param Key, string -> Ticket id.
	function Storage:_RemoveTicket(Key: string)
		return self.Tickets:RemoveAsync(Key);
	end

	-- RemoveTicket -> boolean, any
	-- Removes one ticket from shared storage.
	-- @param TicketId, string -> Ticket id.
	function Storage:RemoveTicket(TicketId: string)
		return retry(self.Config.RetryAttempts, self.Config.RetryDelay, self.Config.RetryMaxDelay, Storage._RemoveTicket, self, TicketId);
	end

	-- _Enqueue -> nil
	-- Raw queue insertion callback.
	-- @param TicketId, string -> Ticket id.
	-- @param TTL, number -> Expiration seconds.
	-- @param Priority, number -> Queue priority.
	function Storage:_Enqueue(TicketId: string, TTL: number, Priority: number)
		return self.Queue:AddAsync(TicketId, TTL, Priority);
	end

	-- Enqueue -> boolean, any
	-- Adds one ticket id to the global queue.
	-- @param TicketValue, table -> Ticket being queued.
	function Storage:Enqueue(TicketValue)
		local TTL = math.max(TicketValue.ExpiresAt - os.time(), 1)
		return retry(self.Config.RetryAttempts, self.Config.RetryDelay, self.Config.RetryMaxDelay, Storage._Enqueue, self, TicketValue.Id, TTL, TicketValue.Priority or 0);
	end

	-- _ReadOne -> table, string?
	-- Raw single-item queue read callback.
	function Storage:_ReadOne()
		return self.Queue:ReadAsync(1, false, 0);
	end

	-- ReadOne -> boolean, table?
	-- Reads one invisible queue item and returns its ticket id plus receipt id.
	function Storage:ReadOne()
		local Success, Items, Receipt = retry(self.Config.RetryAttempts, self.Config.RetryDelay, self.Config.RetryMaxDelay, Storage._ReadOne, self)
		if not Success then return false, Items end
		if type(Items) ~= 'table' or #Items == 0 then return true, nil end
		return true, {TicketId = Items[1]; Receipt = Receipt;};
	end

	-- _RemoveReceipt -> nil
	-- Raw queue acknowledgement callback.
	-- @param Receipt, string -> Read receipt id.
	function Storage:_RemoveReceipt(Receipt: string)
		return self.Queue:RemoveAsync(Receipt);
	end

	-- RemoveReceipt -> boolean, any
	-- Permanently acknowledges one previously read queue item.
	-- @param Receipt, string -> Read receipt id.
	function Storage:RemoveReceipt(Receipt: string)
		if type(Receipt) ~= 'string' or Receipt == '' then return false, 'invalid queue receipt' end
		return retry(self.Config.RetryAttempts, self.Config.RetryDelay, self.Config.RetryMaxDelay, Storage._RemoveReceipt, self, Receipt);
	end

	-- _QueueSize -> number
	-- Raw queue-size callback.
	function Storage:_QueueSize()
		return self.Queue:GetSizeAsync(false);
	end

	-- GetQueueSize -> boolean, number|string
	-- Returns the approximate visible and invisible ticket count.
	function Storage:GetQueueSize()
		return retry(self.Config.RetryAttempts, self.Config.RetryDelay, self.Config.RetryMaxDelay, Storage._QueueSize, self);
	end

	-- _GetMembership -> any
	-- Raw membership lookup callback.
	-- @param Key, string -> User key.
	function Storage:_GetMembership(Key: string)
		return self.Memberships:GetAsync(Key);
	end

	-- GetMembership -> boolean, table?
	-- Reads one user's current global matchmaking membership.
	-- @param UserId, number -> Roblox user id.
	function Storage:GetMembership(UserId: number)
		return retry(self.Config.RetryAttempts, self.Config.RetryDelay, self.Config.RetryMaxDelay, Storage._GetMembership, self, tostring(UserId));
	end

	-- _ClaimMembership -> any
	-- Atomically claims one user's global matchmaking membership if free or expired.
	-- @param Key, string -> User key.
	-- @param Value, table -> New membership.
	-- @param TTL, number -> Expiration seconds.
	function Storage:_ClaimMembership(Key: string, Value, TTL: number)
		-- transform -> table
		-- Keeps a live membership or replaces an expired one atomically.
		-- @param Current, table? -> Existing membership.
		local function transform(Current)
			if type(Current) == 'table' and type(Current.ExpiresAt) == 'number' and Current.ExpiresAt > os.time() then return Current end
			return Value;
		end

		return self.Memberships:UpdateAsync(Key, transform, TTL);
	end

	-- ClaimMembership -> boolean, string?
	-- Claims one user for a ticket, preventing simultaneous queue membership across FORGE queues.
	-- @param UserId, number -> Roblox user id.
	-- @param TicketValue, table -> Ticket claiming the user.
	function Storage:ClaimMembership(UserId: number, TicketValue)
		local TTL = math.max(TicketValue.ExpiresAt - os.time(), 1)
		local Value = {Queue = TicketValue.Queue; TicketId = TicketValue.Id; ExpiresAt = TicketValue.ExpiresAt;}
		local Success, Result = retry(self.Config.RetryAttempts, self.Config.RetryDelay, self.Config.RetryMaxDelay, Storage._ClaimMembership, self, tostring(UserId), Value, TTL)
		if not Success then return false, tostring(Result) end
		if type(Result) ~= 'table' or Result.TicketId ~= TicketValue.Id or Result.Queue ~= TicketValue.Queue then return false, 'player is already queued' end
		return true;
	end

	-- _ReleaseMembership -> any
	-- Atomically expires one membership only when it still belongs to the expected ticket.
	-- @param Key, string -> User key.
	-- @param TicketId, string -> Expected ticket id.
	function Storage:_ReleaseMembership(Key: string, TicketId: string)
		-- transform -> table?
		-- Expires only the matching ticket membership without deleting a newer owner's value.
		-- @param Current, table? -> Existing membership.
		local function transform(Current)
			if type(Current) == 'table' and Current.TicketId == TicketId then Current.ExpiresAt = 0; Current.Released = true end
			return Current;
		end

		return self.Memberships:UpdateAsync(Key, transform, 1);
	end

	-- ReleaseMembership -> boolean, any
	-- Releases one user's ticket membership.
	-- @param UserId, number -> Roblox user id.
	-- @param TicketId, string -> Expected ticket id.
	function Storage:ReleaseMembership(UserId: number, TicketId: string)
		return retry(self.Config.RetryAttempts, self.Config.RetryDelay, self.Config.RetryMaxDelay, Storage._ReleaseMembership, self, tostring(UserId), TicketId);
	end

	-- _ClaimTicket -> any
	-- Atomically transitions a queued ticket into one match claim.
	-- @param TicketId, string -> Ticket id.
	-- @param MatchId, string -> Match claiming it.
	-- @param TTL, number -> Remaining ticket TTL.
	function Storage:_ClaimTicket(TicketId: string, MatchId: string, TTL: number)
		-- transform -> table?
		-- Claims only an active queued ticket.
		-- @param Current, table? -> Existing ticket.
		local function transform(Current)
			if type(Current) ~= 'table' or Current.Queue ~= self.Name or Current.Status ~= 'Queued' or (Current.ExpiresAt or 0) <= os.time() then return Current end
			Current.Status = 'Matched'
			Current.MatchId = MatchId
			Current.UpdatedAt = os.time()
			return Current;
		end

		return self.Tickets:UpdateAsync(TicketId, transform, TTL);
	end

	-- ClaimTicket -> boolean, string?
	-- Claims one active queued ticket for a match id.
	-- @param TicketValue, table -> Ticket being claimed.
	-- @param MatchId, string -> Match id.
	function Storage:ClaimTicket(TicketValue, MatchId: string)
		local TTL = math.max(TicketValue.ExpiresAt - os.time(), 1)
		local Success, Result = retry(self.Config.RetryAttempts, self.Config.RetryDelay, self.Config.RetryMaxDelay, Storage._ClaimTicket, self, TicketValue.Id, MatchId, TTL)
		if not Success then return false, tostring(Result) end
		if type(Result) ~= 'table' or Result.Status ~= 'Matched' or Result.MatchId ~= MatchId then return false, 'ticket is no longer claimable' end
		return true;
	end

	-- _RollbackTicket -> any
	-- Rolls one failed match claim back to queued only when the same match owns it.
	-- @param TicketId, string -> Ticket id.
	-- @param MatchId, string -> Failed match id.
	-- @param TTL, number -> Remaining ticket TTL.
	function Storage:_RollbackTicket(TicketId: string, MatchId: string, TTL: number)
		-- transform -> table?
		-- Restores the expected failed claim.
		-- @param Current, table? -> Existing ticket.
		local function transform(Current)
			if type(Current) ~= 'table' or Current.Status ~= 'Matched' or Current.MatchId ~= MatchId then return Current end
			Current.Status = 'Queued'
			Current.MatchId = nil
			Current.UpdatedAt = os.time()
			return Current;
		end

		return self.Tickets:UpdateAsync(TicketId, transform, TTL);
	end

	-- RollbackTicket -> boolean, any
	-- Restores one claimed ticket after allocation failure.
	-- @param TicketValue, table -> Ticket being restored.
	-- @param MatchId, string -> Failed match id.
	function Storage:RollbackTicket(TicketValue, MatchId: string)
		local TTL = math.max(TicketValue.ExpiresAt - os.time(), 1)
		return retry(self.Config.RetryAttempts, self.Config.RetryDelay, self.Config.RetryMaxDelay, Storage._RollbackTicket, self, TicketValue.Id, MatchId, TTL);
	end

	-- _CancelTicket -> any
	-- Atomically marks a queued ticket cancelled.
	-- @param TicketId, string -> Ticket id.
	-- @param Reason, string -> Cancellation reason.
	function Storage:_CancelTicket(TicketId: string, Reason: string)
		-- transform -> table?
		-- Cancels only queued tickets, preserving already-matched assignments.
		-- @param Current, table? -> Existing ticket.
		local function transform(Current)
			if type(Current) ~= 'table' or Current.Status ~= 'Queued' then return Current end
			Current.Status = 'Cancelled'
			Current.CancelReason = Reason
			Current.UpdatedAt = os.time()
			return Current;
		end

		return self.Tickets:UpdateAsync(TicketId, transform, self.Config.TicketTTL);
	end

	-- CancelTicket -> boolean, string?
	-- Cancels one queued ticket.
	-- @param TicketId, string -> Ticket id.
	-- @param Reason, string? -> Cancellation reason.
	function Storage:CancelTicket(TicketId: string, Reason: string?)
		local FinalReason = Reason or 'cancelled'
		local Success, Result = retry(self.Config.RetryAttempts, self.Config.RetryDelay, self.Config.RetryMaxDelay, Storage._CancelTicket, self, TicketId, FinalReason)
		if not Success then return false, tostring(Result) end
		if type(Result) ~= 'table' or Result.Status ~= 'Cancelled' then return false, 'ticket is not queued' end
		return true;
	end

	-- _SetAssignment -> boolean
	-- Raw assignment persistence callback.
	-- @param TicketId, string -> Ticket id.
	-- @param Assignment, table -> Assignment payload.
	function Storage:_SetAssignment(TicketId: string, Assignment)
		return self.Assignments:SetAsync(TicketId, Assignment, self.Config.AssignmentTTL);
	end

	-- SetAssignment -> boolean, any
	-- Stores one server-only teleport assignment.
	-- @param TicketId, string -> Ticket id.
	-- @param Assignment, table -> Assignment payload.
	function Storage:SetAssignment(TicketId: string, Assignment)
		return retry(self.Config.RetryAttempts, self.Config.RetryDelay, self.Config.RetryMaxDelay, Storage._SetAssignment, self, TicketId, Assignment);
	end

	-- _GetAssignment -> any
	-- Raw assignment lookup callback.
	-- @param TicketId, string -> Ticket id.
	function Storage:_GetAssignment(TicketId: string)
		return self.Assignments:GetAsync(TicketId);
	end

	-- GetAssignment -> boolean, table?
	-- Reads one ticket assignment.
	-- @param TicketId, string -> Ticket id.
	function Storage:GetAssignment(TicketId: string)
		return retry(self.Config.RetryAttempts, self.Config.RetryDelay, self.Config.RetryMaxDelay, Storage._GetAssignment, self, TicketId);
	end

	-- _RemoveAssignment -> nil
	-- Raw assignment removal callback.
	-- @param TicketId, string -> Ticket id.
	function Storage:_RemoveAssignment(TicketId: string)
		return self.Assignments:RemoveAsync(TicketId);
	end

	-- RemoveAssignment -> boolean, any
	-- Removes one assignment.
	-- @param TicketId, string -> Ticket id.
	function Storage:RemoveAssignment(TicketId: string)
		return retry(self.Config.RetryAttempts, self.Config.RetryDelay, self.Config.RetryMaxDelay, Storage._RemoveAssignment, self, TicketId);
	end

	-- _SetMatch -> boolean
	-- Raw match-record persistence callback.
	-- @param MatchId, string -> Match id.
	-- @param Match, table -> Match payload.
	function Storage:_SetMatch(MatchId: string, Match)
		return self.Matches:SetAsync(MatchId, Match, self.Config.MatchTTL);
	end

	-- SetMatch -> boolean, any
	-- Stores one server-only match record.
	-- @param Match, table -> Match payload.
	function Storage:SetMatch(Match)
		return retry(self.Config.RetryAttempts, self.Config.RetryDelay, self.Config.RetryMaxDelay, Storage._SetMatch, self, Match.Id, Match);
	end

	-- _GetMatch -> any
	-- Raw match-record lookup callback.
	-- @param MatchId, string -> Match id.
	function Storage:_GetMatch(MatchId: string)
		return self.Matches:GetAsync(MatchId);
	end

	-- GetMatch -> boolean, table?
	-- Reads one match record by id.
	-- @param MatchId, string -> Match id.
	function Storage:GetMatch(MatchId: string)
		return retry(self.Config.RetryAttempts, self.Config.RetryDelay, self.Config.RetryMaxDelay, Storage._GetMatch, self, MatchId);
	end

	-- _RemoveMatch -> nil
	-- Raw match-record removal callback.
	-- @param MatchId, string -> Match id.
	function Storage:_RemoveMatch(MatchId: string)
		return self.Matches:RemoveAsync(MatchId);
	end

	-- RemoveMatch -> boolean, any
	-- Removes one match record.
	-- @param MatchId, string -> Match id.
	function Storage:RemoveMatch(MatchId: string)
		return retry(self.Config.RetryAttempts, self.Config.RetryDelay, self.Config.RetryMaxDelay, Storage._RemoveMatch, self, MatchId);
	end
end

return Storage;
