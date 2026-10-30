-- Author -> lolokdev.
-- Last Edit -> September 14, 2026 8:45 PM CDT

local Rating = require(script.Parent.Rating)

local Rules = {} do
	-- getMMRConfig -> table
	-- Resolves the current hidden-MMR configuration while retaining legacy Skill compatibility.
	-- @param Definition, table -> Normalized queue definition.
	local function getMMRConfig(Definition)
		return Definition.MMR or Definition.Skill or {Enabled = false; InitialRange = 0; ExpandPerSecond = 0; MaxRange = math.huge;};
	end

	-- ticketMMR -> number
	-- Resolves one ticket's hidden MMR while retaining legacy Skill fields.
	-- @param Ticket, table -> Matchmaking ticket.
	local function ticketMMR(Ticket)
		return tonumber(Ticket.MMR or Ticket.Skill) or 0;
	end

	-- ticketStake -> string
	-- Resolves one ticket's canonical stake partition.
	-- @param Ticket, table -> Matchmaking ticket.
	local function ticketStake(Ticket)
		return tostring(Ticket.Stake or Ticket.Pool or 'default');
	end

	-- ticketMode -> string
	-- Resolves one ticket's canonical game-mode partition.
	-- @param Ticket, table -> Matchmaking ticket.
	local function ticketMode(Ticket)
		return tostring(Ticket.Mode or 'default');
	end

	-- getRange -> number
	-- Calculates the current allowed hidden-MMR delta for one ticket as wait time increases.
	-- @param Ticket, table -> Ticket being evaluated.
	-- @param MMR, table -> Normalized hidden-MMR configuration.
	-- @param Now, number -> Current unix time.
	local function getRange(Ticket, MMR, Now: number)
		if not MMR.Enabled then return math.huge end
		local Waited = math.max(Now - (tonumber(Ticket.CreatedAt) or Now), 0)
		return math.min(MMR.InitialRange + Waited * MMR.ExpandPerSecond, MMR.MaxRange);
	end

	-- compatible -> boolean
	-- Checks stake, mode, hidden MMR, party size and optional custom rules for one candidate ticket.
	-- @param Selected, table -> Already selected candidate records.
	-- @param Candidate, table -> Candidate record being considered.
	-- @param Definition, table -> Queue definition.
	-- @param Now, number -> Current unix time.
	local function compatible(Selected, Candidate, Definition, Now: number)
		local Ticket = Candidate.Ticket
		local Seed = Selected[1].Ticket
		local MMR = getMMRConfig(Definition)

		if ticketStake(Ticket) ~= ticketStake(Seed) then return false end
		if ticketMode(Ticket) ~= ticketMode(Seed) then return false end
		if Ticket.TestSessionId ~= Seed.TestSessionId then return false end
		if (Ticket.Test == true) ~= (Seed.Test == true) then return false end
		if Definition.Teams and Ticket.Size > Definition.Teams.Size then return false end

		if MMR.Enabled then
			local Items = {}
			for _, Record in ipairs(Selected) do table.insert(Items, {MMR = ticketMMR(Record.Ticket); Size = Record.Ticket.Size;}) end
			local Average = Rating.WeightedAverage(Items)
			local Difference = math.abs(ticketMMR(Ticket) - Average)
			local CandidateRange = getRange(Ticket, MMR, Now)
			local GroupRange = math.huge
			for _, Record in ipairs(Selected) do GroupRange = math.min(GroupRange, getRange(Record.Ticket, MMR, Now)) end
			if Difference > math.min(CandidateRange, GroupRange) then return false end
		end

		if Definition.CanMatch then
			local Snapshot = {}
			for _, Record in ipairs(Selected) do table.insert(Snapshot, Record.Ticket) end
			local Success, Allowed = pcall(Definition.CanMatch, Snapshot, Ticket)
			if not Success or Allowed ~= true then return false end
		end

		return true;
	end

	-- compareCandidates -> boolean
	-- Sorts candidates oldest-first, then by higher explicit priority.
	-- @param A, table -> First candidate record.
	-- @param B, table -> Second candidate record.
	local function compareCandidates(A, B)
		local CreatedA = tonumber(A.Ticket.CreatedAt) or 0
		local CreatedB = tonumber(B.Ticket.CreatedAt) or 0
		if CreatedA == CreatedB then return (tonumber(A.Ticket.Priority) or 0) > (tonumber(B.Ticket.Priority) or 0) end
		return CreatedA < CreatedB;
	end

	-- Select -> table?
	-- Finds one exact/partial same-stake same-mode hidden-MMR-compatible match without splitting party tickets.
	-- @param Candidates, table -> Queue candidate records.
	-- @param Definition, table -> Queue definition.
	-- @param Now, number? -> Optional deterministic clock used by the test harness.
	function Rules.Select(Candidates, Definition, Now: number?)
		if #Candidates == 0 then return nil end
		local Sorted = table.clone(Candidates)
		table.sort(Sorted, compareCandidates)
		Now = tonumber(Now) or os.time()

		for SeedIndex, Seed in ipairs(Sorted) do
			if Seed.Ticket.Size > Definition.Players.Max then continue end
			local Selected = {Seed;}
			local Count = Seed.Ticket.Size

			for CandidateIndex, Candidate in ipairs(Sorted) do
				if CandidateIndex == SeedIndex then continue end
				if Count >= Definition.Players.Target then break end
				if Count + Candidate.Ticket.Size > Definition.Players.Max then continue end
				if not compatible(Selected, Candidate, Definition, Now) then continue end
				table.insert(Selected, Candidate)
				Count += Candidate.Ticket.Size
			end

			local Exact = Count == Definition.Players.Target
			local Partial = Definition.AllowPartial and Count >= Definition.Players.Min
			if Exact or Partial then return Selected end
		end

		return nil;
	end

	-- BalanceTeams -> table?
	-- Greedily balances party-preserving tickets across configured team capacities using hidden MMR.
	-- @param Selected, table -> Selected candidate records.
	-- @param Definition, table -> Queue definition.
	function Rules.BalanceTeams(Selected, Definition)
		local Teams = Definition.Teams
		local Map = {}

		if not Teams then
			for _, Record in ipairs(Selected) do for _, UserId in ipairs(Record.Ticket.Users) do Map[tostring(UserId)] = 1 end end
			return Map;
		end

		local Tickets = table.clone(Selected)

		-- compareTickets -> boolean
		-- Sorts larger parties first and higher-MMR equal-size parties second for deterministic balancing.
		-- @param A, table -> First candidate record.
		-- @param B, table -> Second candidate record.
		local function compareTickets(A, B)
			if A.Ticket.Size == B.Ticket.Size then return ticketMMR(A.Ticket) > ticketMMR(B.Ticket) end
			return A.Ticket.Size > B.Ticket.Size;
		end

		table.sort(Tickets, compareTickets)
		local Buckets = {}
		for Index = 1, Teams.Count do Buckets[Index] = {Players = 0; MMR = 0;} end

		for _, Record in ipairs(Tickets) do
			local TicketValue = Record.Ticket
			local BestIndex = nil
			local BestScore = math.huge

			for Index, Team in ipairs(Buckets) do
				if Team.Players + TicketValue.Size > Teams.Size then continue end
				local Average = Team.Players > 0 and Team.MMR / Team.Players or 0
				local Score = Team.Players * 100000 + Average
				if Score < BestScore then BestScore = Score; BestIndex = Index end
			end

			if not BestIndex then return nil end
			local Team = Buckets[BestIndex]
			Team.Players += TicketValue.Size
			Team.MMR += ticketMMR(TicketValue) * TicketValue.Size
			for _, UserId in ipairs(TicketValue.Users) do Map[tostring(UserId)] = BestIndex end
		end

		return Map;
	end
end

return Rules;
