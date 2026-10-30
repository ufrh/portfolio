-- Author -> lolokdev.
-- Last Edit -> September 14, 2026 4:25 PM CDT

local Metrics = {} do
	Metrics.__index = Metrics
	Metrics.ClassName = 'MatchmakingTestMetrics'

	-- percentile -> number
	-- Returns a percentile from one numeric sample list without modifying the source list.
	-- @param Values, table -> Numeric samples.
	-- @param Fraction, number -> Percentile fraction from zero to one.
	local function percentile(Values, Fraction: number)
		if #Values == 0 then return 0 end
		local Sorted = table.clone(Values)
		table.sort(Sorted)
		local Index = math.clamp(math.ceil(#Sorted * Fraction), 1, #Sorted)
		return Sorted[Index];
	end

	-- average -> number
	-- Returns the arithmetic average of one numeric sample list.
	-- @param Values, table -> Numeric samples.
	local function average(Values)
		if #Values == 0 then return 0 end
		local Total = 0
		for _, Value in ipairs(Values) do Total += Value end
		return Total / #Values;
	end

	-- new -> MatchmakingTestMetrics
	-- Creates an empty metrics accumulator for one simulator session.
	-- @param RecentLimit, number -> Maximum recent log entries retained.
	function Metrics.new(RecentLimit: number)
		local this = setmetatable({}, Metrics)
		this.RecentLimit = RecentLimit
		this:Reset()
		return this;
	end

	-- Reset -> nil
	-- Clears every counter, timing sample and recent event.
	function Metrics:Reset()
		self.StartedAt = os.clock()
		self.PseudoCreated = 0
		self.TicketsCreated = 0
		self.MatchesCreated = 0
		self.Cancelled = 0
		self.TeleportSuccess = 0
		self.TeleportFailed = 0
		self.Errors = 0
		self.WaitSamples = {}
		self.TeamDeltaSamples = {}
		self.Recent = {}
	end

	-- Log -> nil
	-- Adds one newest-first human-readable simulator event.
	-- @param Message, string -> Event text.
	function Metrics:Log(Message: string)
		table.insert(self.Recent, 1, Message)
		while #self.Recent > self.RecentLimit do table.remove(self.Recent) end
	end

	-- RecordCreated -> nil
	-- Records new synthetic players and their containing ticket.
	-- @param PlayerCount, number -> Number of pseudo players created.
	function Metrics:RecordCreated(PlayerCount: number)
		self.PseudoCreated += PlayerCount
		self.TicketsCreated += 1
	end

	-- RecordMatch -> nil
	-- Records one successful synthetic match and its quality measurements.
	-- @param Wait, number -> Oldest ticket wait in seconds.
	-- @param TeamDelta, number -> Absolute team-average skill delta.
	function Metrics:RecordMatch(Wait: number, TeamDelta: number)
		self.MatchesCreated += 1
		table.insert(self.WaitSamples, Wait)
		table.insert(self.TeamDeltaSamples, TeamDelta)
	end

	-- RecordTeleport -> nil
	-- Records one simulated destination transport result.
	-- @param Success, boolean -> Whether the pseudo player transport succeeded.
	function Metrics:RecordTeleport(Success: boolean)
		if Success then self.TeleportSuccess += 1 else self.TeleportFailed += 1 end
	end

	-- RecordCancel -> nil
	-- Records one synthetic queued-ticket cancellation.
	function Metrics:RecordCancel()
		self.Cancelled += 1
	end

	-- RecordError -> nil
	-- Records and logs one synthetic simulation error.
	-- @param Message, string -> Error text.
	function Metrics:RecordError(Message: string)
		self.Errors += 1
		self:Log('ERROR • ' .. Message)
	end

	-- Snapshot -> table
	-- Builds immutable statistics suitable for the draggable client diagnostics panel.
	-- @param QueuedTickets, number -> Current queued ticket count.
	-- @param QueuedPlayers, number -> Current queued player count.
	function Metrics:Snapshot(QueuedTickets: number, QueuedPlayers: number)
		local Runtime = math.max(os.clock() - self.StartedAt, .001)
		local WorstDelta = 0
		for _, Value in ipairs(self.TeamDeltaSamples) do WorstDelta = math.max(WorstDelta, Value) end
		return {PseudoCreated = self.PseudoCreated; TicketsCreated = self.TicketsCreated; QueuedTickets = QueuedTickets; QueuedPlayers = QueuedPlayers; MatchesCreated = self.MatchesCreated; Cancelled = self.Cancelled; TeleportSuccess = self.TeleportSuccess; TeleportFailed = self.TeleportFailed; Errors = self.Errors; AverageWait = average(self.WaitSamples); P95Wait = percentile(self.WaitSamples, .95); AverageTeamDelta = average(self.TeamDeltaSamples); WorstTeamDelta = WorstDelta; MatchesPerMinute = self.MatchesCreated / Runtime * 60; Recent = table.clone(self.Recent);};
	end
end

return Metrics;
