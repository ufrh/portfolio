-- Author -> lolokdev.
-- Last Edit -> September 15, 2026 1:10 PM CDT

local HttpService = game:GetService('HttpService')
local RunService = game:GetService('RunService')

local DataRoot = script.Parent.Parent:WaitForChild('Data')
local Data = require(DataRoot)

local Stats = {} do
	Stats.__index = Stats
	Stats.ClassName = 'MatchmakingGlobalStats'

	local STORE_NAME = 'FORGE_MatchmakingTelemetry'
	local KEY_PREFIX = 'StatsV1_Shared_'
	local SHARD_COUNT = 8
	local FLUSH_INTERVAL = 12
	local REFRESH_INTERVAL = 8
	local STAKES = {'Casual'; 'Standard'; 'Heated'; 'Ruckus'; 'AllIn';}
	local METRICS = {'TicketsQueued'; 'PlayersQueued'; 'TicketsMatched'; 'PlayersMatched'; 'MatchesCreated'; 'CancelledTickets'; 'CancelledPlayers'; 'TeleportTickets'; 'TeleportPlayers'; 'TeleportFailedPlayers'; 'QueueErrors'; 'WaitTotal'; 'WaitSamples'; 'TeamDeltaTotal'; 'TeamDeltaSamples'; 'WorstTeamDelta'; 'MMRTotal'; 'MMRSamples';}

	-- zeroBucket -> table
	-- Creates one empty raw statistics bucket used for overall and per-stake aggregation.
	local function zeroBucket()
		local Result = {}
		for _, Key in ipairs(METRICS) do Result[Key] = 0 end
		return Result;
	end

	-- zeroDelta -> table
	-- Creates one empty local pending-delta structure.
	local function zeroDelta()
		local ByStake = {}
		for _, Stake in ipairs(STAKES) do ByStake[Stake] = zeroBucket() end
		return {Overall = zeroBucket(); ByStake = ByStake;};
	end

	-- zeroLive -> table
	-- Creates one ephemeral current-server live queue snapshot separate from cumulative persistent analytics.
	local function zeroLive()
		local ByStake = {}
		for _, Stake in ipairs(STAKES) do ByStake[Stake] = {Tickets = 0; Players = 0;} end
		return {Overall = {Tickets = 0; Players = 0;}; ByStake = ByStake;};
	end

	-- zeroRecord -> table
	-- Creates one persistent shard record with stable schema metadata.
	local function zeroRecord()
		local ByStake = {}
		for _, Stake in ipairs(STAKES) do ByStake[Stake] = zeroBucket() end
		return {Version = 1; FirstSeenAt = os.time(); UpdatedAt = 0; Overall = zeroBucket(); ByStake = ByStake;};
	end

	-- canonicalStake -> string
	-- Resolves arbitrary stake text into one stable global-statistics bucket name.
	-- @param Value, any -> Stake value supplied by a real matchmaking event.
	local function canonicalStake(Value)
		local Text = tostring(Value or 'Unknown')
		for _, Stake in ipairs(STAKES) do if string.lower(Stake) == string.lower(Text) then return Stake end end
		return Text ~= '' and Text or 'Unknown';
	end

	-- hashString -> number
	-- Produces a deterministic positive integer hash used to distribute server writes across shards.
	-- @param Value, string -> Server identity string.
	local function hashString(Value: string)
		local Hash = 5381
		for Index = 1, #Value do Hash = (Hash * 33 + string.byte(Value, Index)) % 2147483647 end
		return Hash;
	end

	-- average -> number
	-- Safely divides one cumulative total by its sample count.
	-- @param Total, number -> Cumulative metric total.
	-- @param Samples, number -> Number of observations.
	local function average(Total: number, Samples: number)
		if Samples <= 0 then return 0 end
		return Total / Samples;
	end

	-- ensureBucket -> table
	-- Reconciles one possibly stale persisted statistics bucket with the current metric schema.
	-- @param Source, table? -> Existing raw bucket.
	local function ensureBucket(Source)
		Source = type(Source) == 'table' and Source or {}
		for _, Key in ipairs(METRICS) do if type(Source[Key]) ~= 'number' then Source[Key] = 0 end end
		return Source;
	end

	-- ensureRecord -> table
	-- Reconciles one persisted shard record with current overall and per-stake structures.
	-- @param Source, table? -> Existing persisted shard value.
	local function ensureRecord(Source)
		Source = type(Source) == 'table' and Source or zeroRecord()
		Source.Version = 1
		Source.FirstSeenAt = tonumber(Source.FirstSeenAt) or os.time()
		Source.UpdatedAt = tonumber(Source.UpdatedAt) or 0
		Source.Overall = ensureBucket(Source.Overall)
		Source.ByStake = type(Source.ByStake) == 'table' and Source.ByStake or {}
		for _, Stake in ipairs(STAKES) do Source.ByStake[Stake] = ensureBucket(Source.ByStake[Stake]) end
		return Source;
	end

	-- copyDelta -> table
	-- Clones one pending delta before an asynchronous datastore flush takes ownership of it.
	-- @param Source, table -> Pending delta.
	local function copyDelta(Source)
		local Result = zeroDelta()
		for _, Key in ipairs(METRICS) do Result.Overall[Key] = tonumber(Source.Overall[Key]) or 0 end
		for Stake, Bucket in pairs(Source.ByStake or {}) do
			Result.ByStake[Stake] = Result.ByStake[Stake] or zeroBucket()
			for _, Key in ipairs(METRICS) do Result.ByStake[Stake][Key] = tonumber(Bucket[Key]) or 0 end
		end
		return Result;
	end

	-- hasDelta -> boolean
	-- Returns whether one pending delta contains any non-zero metric.
	-- @param Source, table -> Pending delta.
	local function hasDelta(Source)
		for _, Key in ipairs(METRICS) do if (tonumber(Source.Overall[Key]) or 0) ~= 0 then return true end end
		return false;
	end

	-- mergeBucket -> nil
	-- Adds additive metrics and preserves maxima while merging one statistics bucket into another.
	-- @param Target, table -> Destination raw bucket.
	-- @param Source, table -> Source raw bucket.
	local function mergeBucket(Target, Source)
		for _, Key in ipairs(METRICS) do
			local Value = tonumber(Source[Key]) or 0
			if Key == 'WorstTeamDelta' then Target[Key] = math.max(tonumber(Target[Key]) or 0, Value) else Target[Key] = (tonumber(Target[Key]) or 0) + Value end
		end
	end

	-- publicBucket -> table
	-- Converts raw cumulative counters into a UI-safe derived global-statistics bucket.
	-- @param Bucket, table -> Raw aggregate bucket.
	local function publicBucket(Bucket)
		Bucket = ensureBucket(Bucket)
		local TeleportAttempts = Bucket.TeleportPlayers
		local MatchConversionRate = Bucket.PlayersQueued > 0 and Bucket.PlayersMatched / Bucket.PlayersQueued or 0
		local CancellationRate = Bucket.PlayersQueued > 0 and Bucket.CancelledPlayers / Bucket.PlayersQueued or 0
		local DispatchRate = Bucket.PlayersMatched > 0 and Bucket.TeleportPlayers / Bucket.PlayersMatched or 0
		local AveragePartySize = Bucket.TicketsQueued > 0 and Bucket.PlayersQueued / Bucket.TicketsQueued or 0
		local PlayersPerMatch = Bucket.MatchesCreated > 0 and Bucket.PlayersMatched / Bucket.MatchesCreated or 0
		return {TicketsQueued = Bucket.TicketsQueued; PlayersQueued = Bucket.PlayersQueued; TicketsMatched = Bucket.TicketsMatched; PlayersMatched = Bucket.PlayersMatched; MatchesCreated = Bucket.MatchesCreated; CancelledTickets = Bucket.CancelledTickets; CancelledPlayers = Bucket.CancelledPlayers; TeleportTickets = Bucket.TeleportTickets; TeleportPlayers = Bucket.TeleportPlayers; TeleportFailedPlayers = Bucket.TeleportFailedPlayers; QueueErrors = Bucket.QueueErrors; AverageWait = average(Bucket.WaitTotal, Bucket.WaitSamples); AverageTeamDelta = average(Bucket.TeamDeltaTotal, Bucket.TeamDeltaSamples); WorstTeamDelta = Bucket.WorstTeamDelta; AverageQueuedMMR = average(Bucket.MMRTotal, Bucket.MMRSamples); TeleportFailureRate = TeleportAttempts > 0 and Bucket.TeleportFailedPlayers / TeleportAttempts or 0; MatchConversionRate = MatchConversionRate; CancellationRate = CancellationRate; DispatchRate = DispatchRate; AveragePartySize = AveragePartySize; PlayersPerMatch = PlayersPerMatch;};
	end

	-- isTestTicket -> boolean
	-- Returns whether one ticket belongs to framework-only solo transport validation and must stay out of production telemetry.
	-- @param TicketValue, table? -> Ticket being inspected.
	local function isTestTicket(TicketValue)
		if type(TicketValue) ~= 'table' then return false end
		if TicketValue.Test == true or TicketValue.Synthetic == true then return true end
		local Data = type(TicketValue.Data) == 'table' and TicketValue.Data or nil
		return Data ~= nil and Data.__FORGESoloTransportTest == true;
	end

	-- teamDelta -> number
	-- Calculates maximum team-average hidden-MMR difference for one completed real match.
	-- @param Context, table? -> Match build context containing MMRs and team assignments.
	local function teamDelta(Context)
		if type(Context) ~= 'table' or type(Context.Teams) ~= 'table' or type(Context.MMRs) ~= 'table' then return 0 end
		local Totals = {}
		local Counts = {}
		for UserId, Team in pairs(Context.Teams) do
			local MMR = tonumber(Context.MMRs[tostring(UserId)] or Context.MMRs[UserId])
			if MMR and Team ~= nil then Totals[Team] = (Totals[Team] or 0) + MMR; Counts[Team] = (Counts[Team] or 0) + 1 end
		end
		local Minimum = math.huge
		local Maximum = -math.huge
		local TeamCount = 0
		for Team, Total in pairs(Totals) do
			local Value = Total / math.max(Counts[Team] or 1, 1)
			Minimum = math.min(Minimum, Value)
			Maximum = math.max(Maximum, Value)
			TeamCount += 1
		end
		return TeamCount >= 2 and Maximum - Minimum or 0;
	end

	-- new -> MatchmakingGlobalStats
	-- Creates sharded universe-wide real matchmaking telemetry backed by FORGE.Data global storage.
	function Stats.new()
		local this = setmetatable({}, Stats)
		local Identity = game.JobId ~= '' and game.JobId or 'studio:' .. tostring(game.PlaceId) .. ':' .. HttpService:GenerateGUID(false)
		this.Global = Data.Global(STORE_NAME)
		this.RecordEnabled = not RunService:IsStudio() or game:GetAttribute('MatchmakingRecordStudioStats') == true
		this.Shard = hashString(Identity) % SHARD_COUNT + 1
		this.Pending = zeroDelta()
		this.Session = zeroDelta()
		this.Live = zeroLive()
		this.ActiveTickets = {}
		this.Aggregate = zeroRecord()
		this.Aggregate.FirstSeenAt = 0
		this.SessionStartedAt = os.time()
		this.LastEventAt = 0
		this.ReadAny = false
		this.QueueConnections = {}
		this.Running = false
		this.Flushing = false
		this.Refreshing = false
		this.LastRefreshClock = 0
		this.LastFlushError = nil
		this.LastRefreshError = nil
		return this;
	end

	-- _Key -> string
	-- Builds one persistent shard key.
	-- @param Shard, number -> One-based shard index.
	function Stats:_Key(Shard: number)
		return KEY_PREFIX .. tostring(Shard);
	end

	-- _Bucket -> table
	-- Returns or creates one per-stake metric bucket in the requested delta collection.
	-- @param Collection, table -> Delta collection containing ByStake.
	-- @param Stake, string -> Canonical stake.
	function Stats:_Bucket(Collection, Stake: string)
		Collection.ByStake[Stake] = Collection.ByStake[Stake] or zeroBucket()
		return Collection.ByStake[Stake];
	end

	-- _AddTo -> nil
	-- Adds one additive metric to both overall and per-stake buckets in a delta collection.
	-- @param Collection, table -> Delta collection being updated.
	-- @param Stake, string -> Canonical stake.
	-- @param Key, string -> Metric key.
	-- @param Value, number -> Additive metric value.
	function Stats:_AddTo(Collection, Stake: string, Key: string, Value: number)
		local Amount = tonumber(Value) or 0
		Collection.Overall[Key] = (tonumber(Collection.Overall[Key]) or 0) + Amount
		local Bucket = self:_Bucket(Collection, Stake)
		Bucket[Key] = (tonumber(Bucket[Key]) or 0) + Amount
	end

	-- _MaximumTo -> nil
	-- Updates one maximum metric in both overall and per-stake buckets in a delta collection.
	-- @param Collection, table -> Delta collection being updated.
	-- @param Stake, string -> Canonical stake.
	-- @param Key, string -> Maximum metric key.
	-- @param Value, number -> Candidate maximum.
	function Stats:_MaximumTo(Collection, Stake: string, Key: string, Value: number)
		local Amount = tonumber(Value) or 0
		Collection.Overall[Key] = math.max(tonumber(Collection.Overall[Key]) or 0, Amount)
		local Bucket = self:_Bucket(Collection, Stake)
		Bucket[Key] = math.max(tonumber(Bucket[Key]) or 0, Amount)
	end

	-- _Add -> nil
	-- Records one real matchmaking metric immediately for this server and queues it for global persistence when enabled.
	-- @param Stake, string -> Canonical stake.
	-- @param Key, string -> Metric key.
	-- @param Value, number -> Additive metric value.
	function Stats:_Add(Stake: string, Key: string, Value: number)
		self.LastEventAt = os.time()
		self:_AddTo(self.Session, Stake, Key, Value)
		if self.RecordEnabled then self:_AddTo(self.Pending, Stake, Key, Value) end
	end

	-- _SetMaximum -> nil
	-- Records one real maximum metric immediately for this server and queues it for global persistence when enabled.
	-- @param Stake, string -> Canonical stake.
	-- @param Key, string -> Maximum metric key.
	-- @param Value, number -> Candidate maximum.
	function Stats:_SetMaximum(Stake: string, Key: string, Value: number)
		self.LastEventAt = os.time()
		self:_MaximumTo(self.Session, Stake, Key, Value)
		if self.RecordEnabled then self:_MaximumTo(self.Pending, Stake, Key, Value) end
	end

	-- _SetLiveTicket -> nil
	-- Adds one locally originated queued ticket to current-server live analytics exactly once.
	-- @param TicketValue, table -> Queued production ticket.
	function Stats:_SetLiveTicket(TicketValue)
		if type(TicketValue) ~= 'table' or type(TicketValue.Id) ~= 'string' or self.ActiveTickets[TicketValue.Id] then return end
		local Stake = canonicalStake(TicketValue.Stake)
		local Players = tonumber(TicketValue.Size) or #(TicketValue.Users or {})
		self.ActiveTickets[TicketValue.Id] = {Stake = Stake; Players = Players;}
		self.Live.Overall.Tickets += 1
		self.Live.Overall.Players += Players
		self.Live.ByStake[Stake] = self.Live.ByStake[Stake] or {Tickets = 0; Players = 0;}
		self.Live.ByStake[Stake].Tickets += 1
		self.Live.ByStake[Stake].Players += Players
	end

	-- _RemoveLiveTicket -> nil
	-- Removes one locally originated ticket from current-server live queue analytics after cancel or match assignment.
	-- @param TicketValue, table -> Ticket leaving the live queue.
	function Stats:_RemoveLiveTicket(TicketValue)
		if type(TicketValue) ~= 'table' or type(TicketValue.Id) ~= 'string' then return end
		local Existing = self.ActiveTickets[TicketValue.Id]
		if not Existing then return end
		self.ActiveTickets[TicketValue.Id] = nil
		self.Live.Overall.Tickets = math.max(self.Live.Overall.Tickets - 1, 0)
		self.Live.Overall.Players = math.max(self.Live.Overall.Players - Existing.Players, 0)
		local Bucket = self.Live.ByStake[Existing.Stake]
		if Bucket then Bucket.Tickets = math.max(Bucket.Tickets - 1, 0); Bucket.Players = math.max(Bucket.Players - Existing.Players, 0) end
	end

	-- _MergeBack -> nil
	-- Restores one failed flush delta into current pending counters without losing newer events.
	-- @param Delta, table -> Failed flush delta.
	function Stats:_MergeBack(Delta)
		mergeBucket(self.Pending.Overall, Delta.Overall)
		for Stake, Bucket in pairs(Delta.ByStake or {}) do self.Pending.ByStake[Stake] = self.Pending.ByStake[Stake] or zeroBucket(); mergeBucket(self.Pending.ByStake[Stake], Bucket) end
	end

	-- _ApplyDelta -> table
	-- Atomically merges one local server delta into its persistent FORGE.Data statistics shard.
	-- @param Current, table? -> Existing shard record.
	-- @param Delta, table -> Local event delta being flushed.
	function Stats:_ApplyDelta(Current, Delta)
		Current = ensureRecord(Current)
		mergeBucket(Current.Overall, Delta.Overall)
		for Stake, Bucket in pairs(Delta.ByStake or {}) do Current.ByStake[Stake] = ensureBucket(Current.ByStake[Stake]); mergeBucket(Current.ByStake[Stake], Bucket) end
		Current.UpdatedAt = os.time()
		return Current;
	end

	-- _Flush -> boolean
	-- Flushes pending real-game matchmaking deltas to one sharded global datastore key.
	function Stats:_Flush()
		if not self.RecordEnabled or not hasDelta(self.Pending) then return true end
		if self.Flushing or self.Refreshing then return false end
		self.Flushing = true
		local Delta = copyDelta(self.Pending)
		self.Pending = zeroDelta()

		-- update -> table
		-- Merges the captured pending delta into the current persistent shard record.
		-- @param Current, table? -> Existing shard value.
		local function update(Current)
			return self:_ApplyDelta(Current, Delta);
		end

		local Success, Result = self.Global:Update(self:_Key(self.Shard), update, zeroRecord())
		if not Success then
			self:_MergeBack(Delta)
			self.LastFlushError = tostring(Result)
		else
			mergeBucket(self.Aggregate.Overall, Delta.Overall)
			for Stake, Bucket in pairs(Delta.ByStake or {}) do self.Aggregate.ByStake[Stake] = ensureBucket(self.Aggregate.ByStake[Stake]); mergeBucket(self.Aggregate.ByStake[Stake], Bucket) end
			self.Aggregate.FirstSeenAt = self.Aggregate.FirstSeenAt > 0 and self.Aggregate.FirstSeenAt or os.time()
			self.Aggregate.UpdatedAt = os.time()
			self.ReadAny = true
			self.LastFlushError = nil
		end
		self.Flushing = false
		return Success;
	end

	-- _Refresh -> boolean
	-- Reads every persistent shard and rebuilds one universe-wide aggregate snapshot for diagnostics.
	function Stats:_Refresh()
		if self.Refreshing or self.Flushing then return false end
		self.Refreshing = true
		local Aggregate = zeroRecord()
		Aggregate.FirstSeenAt = math.huge
		Aggregate.UpdatedAt = 0
		local ReadAny = false
		local ErrorMessage = nil

		for Shard = 1, SHARD_COUNT do
			local Success, Record = self.Global:Get(self:_Key(Shard), nil)
			if Success and type(Record) == 'table' then
				Record = ensureRecord(Record)
				mergeBucket(Aggregate.Overall, Record.Overall)
				for Stake, Bucket in pairs(Record.ByStake or {}) do Aggregate.ByStake[Stake] = ensureBucket(Aggregate.ByStake[Stake]); mergeBucket(Aggregate.ByStake[Stake], Bucket) end
				Aggregate.FirstSeenAt = math.min(Aggregate.FirstSeenAt, Record.FirstSeenAt)
				Aggregate.UpdatedAt = math.max(Aggregate.UpdatedAt, Record.UpdatedAt)
				ReadAny = true
			elseif not Success then
				ErrorMessage = tostring(Record)
			end
		end

		if Aggregate.FirstSeenAt == math.huge then Aggregate.FirstSeenAt = 0 end
		self.Aggregate = Aggregate
		self.ReadAny = ReadAny
		self.LastRefreshClock = os.clock()
		self.LastRefreshError = ErrorMessage
		self.Refreshing = false
		return ReadAny;
	end

	-- Refresh -> table
	-- Forces a datastore refresh and returns the newest cached global real-game snapshot.
	function Stats:Refresh()
		self:_Flush()
		self:_Refresh()
		return self:GetSnapshot();
	end

	-- GetSnapshot -> table
	-- Returns immediate current-server real telemetry plus a projected universe-wide snapshot with unflushed production events included.
	function Stats:GetSnapshot()
		if not self.Refreshing and not self.Flushing and os.clock() - self.LastRefreshClock >= REFRESH_INTERVAL then task.spawn(Stats._Refresh, self) end

		local Visible = zeroRecord()
		Visible.FirstSeenAt = self.Aggregate.FirstSeenAt
		Visible.UpdatedAt = self.Aggregate.UpdatedAt
		mergeBucket(Visible.Overall, self.Aggregate.Overall)
		for Stake, Bucket in pairs(self.Aggregate.ByStake or {}) do Visible.ByStake[Stake] = ensureBucket(Visible.ByStake[Stake]); mergeBucket(Visible.ByStake[Stake], Bucket) end

		if self.RecordEnabled then
			mergeBucket(Visible.Overall, self.Pending.Overall)
			for Stake, Bucket in pairs(self.Pending.ByStake or {}) do Visible.ByStake[Stake] = ensureBucket(Visible.ByStake[Stake]); mergeBucket(Visible.ByStake[Stake], Bucket) end
			if hasDelta(self.Pending) then Visible.UpdatedAt = math.max(Visible.UpdatedAt, self.LastEventAt) end
		end

		local ByStake = {}
		local SessionByStake = {}
		for _, Stake in ipairs(STAKES) do ByStake[Stake] = publicBucket(Visible.ByStake[Stake] or zeroBucket()); SessionByStake[Stake] = publicBucket(self.Session.ByStake[Stake] or zeroBucket()) end

		local LiveByStake = {}
		for _, Stake in ipairs(STAKES) do local Bucket = self.Live.ByStake[Stake] or {Tickets = 0; Players = 0;}; LiveByStake[Stake] = {Tickets = Bucket.Tickets; Players = Bucket.Players;} end
		local SessionDuration = math.max(os.time() - self.SessionStartedAt, 0)
		return {Version = 2; GeneratedAt = os.time(); FirstSeenAt = Visible.FirstSeenAt; UpdatedAt = Visible.UpdatedAt; Shards = SHARD_COUNT; Overall = publicBucket(Visible.Overall); ByStake = ByStake; ReadAny = self.ReadAny or (self.RecordEnabled and hasDelta(self.Pending)); Recording = self.RecordEnabled; Studio = RunService:IsStudio(); FlushError = self.LastFlushError; RefreshError = self.LastRefreshError; Live = {Overall = {Tickets = self.Live.Overall.Tickets; Players = self.Live.Overall.Players;}; ByStake = LiveByStake;}; Session = {StartedAt = self.SessionStartedAt; LastEventAt = self.LastEventAt; Duration = SessionDuration; MatchesPerMinute = SessionDuration > 0 and self.Session.Overall.MatchesCreated / SessionDuration * 60 or 0; Overall = publicBucket(self.Session.Overall); ByStake = SessionByStake;};};
	end

	-- TrackQueue -> nil
	-- Attaches persistent global telemetry to one production queue without touching isolated simulator queues.
	-- @param QueueName, string -> Runtime queue name.
	-- @param QueueObject, MatchmakingQueue -> Production queue instance.
	function Stats:TrackQueue(QueueName: string, QueueObject)
		if self.QueueConnections[QueueName] then return end
		local Connections = {}

		-- onQueued -> nil
		-- Records one real ticket entering global matchmaking.
		-- @param TicketValue, table -> Newly queued real ticket.
		local function onQueued(TicketValue)
			if isTestTicket(TicketValue) then return end
			local Stake = canonicalStake(TicketValue.Stake)
			self:_SetLiveTicket(TicketValue)
			self:_Add(Stake, 'TicketsQueued', 1)
			self:_Add(Stake, 'PlayersQueued', tonumber(TicketValue.Size) or #(TicketValue.Users or {}))
			self:_Add(Stake, 'MMRTotal', tonumber(TicketValue.MMR) or 0)
			self:_Add(Stake, 'MMRSamples', 1)
		end

		-- onCancelled -> nil
		-- Records one real ticket cancellation and affected player count.
		-- @param TicketValue, table -> Cancelled real ticket.
		local function onCancelled(TicketValue)
			if isTestTicket(TicketValue) then return end
			local Stake = canonicalStake(TicketValue.Stake)
			self:_RemoveLiveTicket(TicketValue)
			self:_Add(Stake, 'CancelledTickets', 1)
			self:_Add(Stake, 'CancelledPlayers', tonumber(TicketValue.Size) or #(TicketValue.Users or {}))
		end

		-- onMatchFound -> nil
		-- Removes one locally originated ticket from current-server live queue analytics when any worker assigns its match.
		-- @param TicketValue, table -> Locally owned matched ticket.
		local function onMatchFound(TicketValue)
			if isTestTicket(TicketValue) then return end
			self:_RemoveLiveTicket(TicketValue)
		end

		-- onMatchCreated -> nil
		-- Records one globally allocated real match exactly once on its worker server.
		-- @param Match, table -> Completed match record.
		-- @param Context, table -> Server-only match context.
		-- @param Selected, table -> Claimed candidate records included in the match.
		local function onMatchCreated(Match, Context, Selected)
			if type(Match) == 'table' and Match.Test == true then return end
			local Stake = canonicalStake(Match.Stake)
			local Tickets = type(Selected) == 'table' and #Selected or #(Match.Tickets or {})
			local Players = #(Match.Users or {})
			self:_Add(Stake, 'MatchesCreated', 1)
			self:_Add(Stake, 'TicketsMatched', Tickets)
			self:_Add(Stake, 'PlayersMatched', Players)
			if type(Selected) == 'table' then
				for _, Record in ipairs(Selected) do
					local CreatedAt = type(Record.Ticket) == 'table' and tonumber(Record.Ticket.CreatedAt) or nil
					if CreatedAt then self:_Add(Stake, 'WaitTotal', math.max(os.time() - CreatedAt, 0)); self:_Add(Stake, 'WaitSamples', 1) end
				end
			end
			local Delta = teamDelta(Context)
			self:_Add(Stake, 'TeamDeltaTotal', Delta)
			self:_Add(Stake, 'TeamDeltaSamples', 1)
			self:_SetMaximum(Stake, 'WorstTeamDelta', Delta)
		end

		-- onTeleporting -> nil
		-- Records one real ticket dispatched toward its reserved gameplay instance.
		-- @param TicketValue, table -> Source-server ticket.
		local function onTeleporting(TicketValue)
			if isTestTicket(TicketValue) then return end
			local Stake = canonicalStake(TicketValue.Stake)
			self:_Add(Stake, 'TeleportTickets', 1)
			self:_Add(Stake, 'TeleportPlayers', tonumber(TicketValue.Size) or #(TicketValue.Users or {}))
		end

		-- onTeleportFailed -> nil
		-- Records one real player whose reserved-server teleport exhausted retries.
		-- @param Player, Player -> Failed real player.
		-- @param Result, any -> Roblox failure result.
		-- @param Message, string -> Roblox failure message.
		-- @param Assignment, table -> Match assignment containing stake.
		local function onTeleportFailed(Player, Result, Message, Assignment)
			if type(Assignment) == 'table' and Assignment.Test == true then return end
			local Stake = canonicalStake(type(Assignment) == 'table' and Assignment.Stake or 'Unknown')
			self:_Add(Stake, 'TeleportFailedPlayers', 1)
		end

		-- onError -> nil
		-- Records one production queue error for global operational visibility.
		-- @param Message, string -> Queue error category.
		local function onError(Message, Detail, Context)
			if type(Context) == 'table' and Context.Test == true then return end
			self:_Add('Unknown', 'QueueErrors', 1)
		end

		table.insert(Connections, QueueObject.Queued:Connect(onQueued))
		table.insert(Connections, QueueObject.Cancelled:Connect(onCancelled))
		table.insert(Connections, QueueObject.MatchFound:Connect(onMatchFound))
		table.insert(Connections, QueueObject.MatchCreated:Connect(onMatchCreated))
		table.insert(Connections, QueueObject.Teleporting:Connect(onTeleporting))
		table.insert(Connections, QueueObject.TeleportFailed:Connect(onTeleportFailed))
		table.insert(Connections, QueueObject.Error:Connect(onError))
		self.QueueConnections[QueueName] = Connections
	end

	-- UntrackQueue -> nil
	-- Disconnects persistent telemetry listeners for one production queue.
	-- @param QueueName, string -> Runtime queue name.
	function Stats:UntrackQueue(QueueName: string)
		local Connections = self.QueueConnections[QueueName]
		if not Connections then return end
		for _, Connection in ipairs(Connections) do Connection:Disconnect() end
		self.QueueConnections[QueueName] = nil
	end

	-- _Loop -> nil
	-- Periodically batches local production events into sharded FORGE.Data global storage.
	function Stats:_Loop()
		while self.Running do task.wait(FLUSH_INTERVAL); if self.Running then self:_Flush() end end
	end

	-- Start -> nil
	-- Starts background batched persistence for real-game matchmaking telemetry.
	function Stats:Start()
		if self.Running then return end
		self.Running = true
		task.spawn(Stats._Loop, self)
	end

	-- Stop -> nil
	-- Stops background persistence and synchronously flushes remaining real-game deltas.
	function Stats:Stop()
		if not self.Running then self:_Flush(); return end
		self.Running = false
		self:_Flush()
	end

	-- Destroy -> nil
	-- Flushes pending metrics and disconnects all production queue telemetry listeners.
	function Stats:Destroy()
		self:Stop()
		local Names = {}
		for Name in pairs(self.QueueConnections) do table.insert(Names, Name) end
		for _, Name in ipairs(Names) do self:UntrackQueue(Name) end
	end
end

return Stats;
