-- Author -> lolokdev.
-- Last Edit -> September 14, 2026 8:45 PM CDT

local HttpService = game:GetService('HttpService')

local Sanitizer = require(script.Parent.Sanitizer)

local Ticket = {} do
	-- collectUsers -> table
	-- Converts a same-server player group into unique user ids for cross-server persistence.
	-- @param Players, table -> Players entering matchmaking together.
	local function collectUsers(Players)
		local Result = {}
		local Seen = {}

		for _, Player in ipairs(Players) do
			assert(typeof(Player) == 'Instance' and Player:IsA('Player'), 'Matchmaking tickets can only contain Player instances.')
			assert(Player.Parent ~= nil, 'Matchmaking cannot queue a disconnected Player.')
			assert(not Seen[Player.UserId], 'Matchmaking ticket contains the same player more than once.')
			Seen[Player.UserId] = true
			table.insert(Result, Player.UserId)
		end

		return Result;
	end

	-- Create -> table
	-- Creates a compact server-authored stake/mode/MMR ticket safe for cross-server MemoryStore transport.
	-- @param QueueName, string -> Owning queue name.
	-- @param Players, table -> Same-server players queued as one inseparable group.
	-- @param Options, table -> Server-resolved stake, MMR, data, priority and TTL.
	-- @param Definition, table -> Normalized queue definition.
	-- @param Limits, table -> Matchmaking metadata limits.
	function Ticket.Create(QueueName: string, Players, Options, Definition, Limits)
		local UserIds = collectUsers(Players)
		local Now = os.time()
		local TTL = Options.TTL or Definition.TicketTTL

		return {
			Id = HttpService:GenerateGUID(false),
			Queue = QueueName,
			Stake = Options.Stake,
			Mode = Options.Mode,
			Users = UserIds,
			Size = #UserIds,
			MMR = tonumber(Options.MMR) or Definition.MMR.Default,
			MMRs = Sanitizer.Copy(Options.MMRs or {}, Limits),
			Priority = tonumber(Options.Priority) or 0,
			Data = Sanitizer.Copy(Options.Data or {}, Limits),
			Test = Options.Test == true,
			TestType = Options.TestType,
			TestSessionId = Options.TestSessionId,
			Synthetic = false,
			SourceJobId = game.JobId,
			SourcePlaceId = game.PlaceId,
			CreatedAt = Now,
			UpdatedAt = Now,
			ExpiresAt = Now + TTL,
			Status = 'Queued';
		};
	end

	-- CreateSynthetic -> table
	-- Creates one isolated server-authored pseudo-user ticket for the live solo transport test without manufacturing a Roblox Player instance.
	-- @param QueueName, string -> Owning production queue name.
	-- @param UserId, number -> Negative synthetic user id.
	-- @param Options, table -> Test stake, mode, MMR, data and session fields.
	-- @param Definition, table -> Normalized queue definition.
	-- @param Limits, table -> Matchmaking metadata limits.
	function Ticket.CreateSynthetic(QueueName: string, UserId: number, Options, Definition, Limits)
		assert(type(UserId) == 'number' and UserId < 0 and UserId % 1 == 0, 'Synthetic matchmaking user ids must be negative integers.')
		assert(type(Options) == 'table' and type(Options.TestSessionId) == 'string' and Options.TestSessionId ~= '', 'Synthetic matchmaking tickets require a test session id.')
		local Now = os.time()
		local TTL = Options.TTL or Definition.TicketTTL
		local MMR = tonumber(Options.MMR) or Definition.MMR.Default

		return {Id = HttpService:GenerateGUID(false); Queue = QueueName; Stake = Options.Stake; Mode = Options.Mode; Users = {UserId;}; Size = 1; MMR = MMR; MMRs = {[tostring(UserId)] = MMR;}; Priority = tonumber(Options.Priority) or 0; Data = Sanitizer.Copy(Options.Data or {}, Limits); Test = true; TestType = 'SoloTransport'; TestSessionId = Options.TestSessionId; Synthetic = true; SourceJobId = game.JobId; SourcePlaceId = game.PlaceId; CreatedAt = Now; UpdatedAt = Now; ExpiresAt = Now + TTL; Status = 'Queued';};
	end

	-- Contains -> boolean
	-- Returns whether one ticket contains a user id.
	-- @param Value, table -> Ticket being searched.
	-- @param UserId, number -> User id being searched.
	function Ticket.Contains(Value, UserId: number)
		if type(Value) ~= 'table' or type(Value.Users) ~= 'table' then return false end
		for _, Existing in ipairs(Value.Users) do if Existing == UserId then return true end end
		return false;
	end

	-- IsActive -> boolean
	-- Returns whether a stored ticket is still eligible for matchmaking using the production clock or one injected by the deterministic lab.
	-- @param Value, table -> Stored ticket.
	-- @param QueueName, string -> Expected queue name.
	-- @param Now, number? -> Optional deterministic unix timestamp.
	function Ticket.IsActive(Value, QueueName: string, Now: number?)
		local Timestamp = tonumber(Now) or os.time()
		return type(Value) == 'table' and Value.Queue == QueueName and Value.Status == 'Queued' and type(Value.ExpiresAt) == 'number' and Value.ExpiresAt > Timestamp;
	end
end

return Ticket;
