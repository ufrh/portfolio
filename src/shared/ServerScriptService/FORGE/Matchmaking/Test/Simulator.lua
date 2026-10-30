-- Author -> lolokdev.
-- Last Edit -> September 15, 2026 1:55 PM CDT

local Rating = require(script.Parent.Parent.Rating)
local Queue = require(script.Parent.Parent.Queue)
local PseudoPlayer = require(script.Parent.PseudoPlayer)
local TestRuntime = require(script.Parent.Runtime)

local STAKES = {'Casual'; 'Standard'; 'Heated'; 'Ruckus'; 'AllIn';}
local MODES = {'FFA'; 'BOUNTY'; 'HEIST';}
local VISUAL_QUEUE_PER_STAKE = 24
local VISUAL_TRANSIT_LIMIT = 160
local VISUAL_TRANSIT_LIFETIME = 6
local HISTORY_LIMIT = 60
local HISTOGRAM = {{Label = '<700'; Min = -math.huge; Max = 699;}; {Label = '700-899'; Min = 700; Max = 899;}; {Label = '900-1099'; Min = 900; Max = 1099;}; {Label = '1100-1299'; Min = 1100; Max = 1299;}; {Label = '1300+'; Min = 1300; Max = math.huge;};}

local Metrics = {} do
	Metrics.__index = Metrics
	Metrics.ClassName = 'MatchmakingSimulationMetrics'

	-- average -> number
	-- Calculates a safe arithmetic mean for one numeric sample array.
	-- @param Values, table -> Numeric samples.
	local function average(Values)
		if #Values == 0 then return 0 end
		local Total = 0
		for _, Value in ipairs(Values) do Total += Value end
		return Total / #Values;
	end

	-- percentile -> number
	-- Calculates one nearest-rank percentile from numeric samples.
	-- @param Values, table -> Numeric samples.
	-- @param Percentile, number -> Zero-to-one percentile.
	local function percentile(Values, Percentile: number)
		if #Values == 0 then return 0 end
		local Sorted = table.clone(Values)
		table.sort(Sorted)
		return Sorted[math.clamp(math.ceil(#Sorted * Percentile), 1, #Sorted)];
	end

	-- newBucket -> table
	-- Creates one empty per-stake metrics bucket.
	local function newBucket()
		return {PseudoCreated = 0; TicketsCreated = 0; MatchesCreated = 0; MatchedPlayers = 0; Cancelled = 0; TeleportSuccess = 0; TeleportFailed = 0; WaitSamples = {}; TeamDeltaSamples = {};};
	end

	-- new -> MatchmakingSimulationMetrics
	-- Creates isolated simulation metrics that never write production global statistics.
	-- @param RecentLimit, number -> Maximum recent event log entries.
	function Metrics.new(RecentLimit: number)
		local this = setmetatable({}, Metrics)
		this.RecentLimit = RecentLimit
		this:Reset()
		return this;
	end

	-- Reset -> nil
	-- Clears every simulation-only aggregate while preserving the configured event-log limit.
	function Metrics:Reset()
		self.StartedAt = os.clock()
		self.PseudoCreated = 0
		self.TicketsCreated = 0
		self.MatchesCreated = 0
		self.MatchedPlayers = 0
		self.Cancelled = 0
		self.TeleportSuccess = 0
		self.TeleportFailed = 0
		self.Errors = 0
		self.WaitSamples = {}
		self.TeamDeltaSamples = {}
		self.Recent = {}
		self.ByStake = {}
		for _, Stake in ipairs(STAKES) do self.ByStake[Stake] = newBucket() end
	end

	-- _Stake -> table
	-- Returns one existing or lazily created per-stake metrics bucket.
	-- @param Stake, string -> Canonical stake name.
	function Metrics:_Stake(Stake: string)
		if not self.ByStake[Stake] then self.ByStake[Stake] = newBucket() end
		return self.ByStake[Stake];
	end

	-- Log -> nil
	-- Adds one newest-first human-readable simulator event.
	-- @param Message, string -> Event text.
	function Metrics:Log(Message: string)
		table.insert(self.Recent, 1, Message)
		while #self.Recent > self.RecentLimit do table.remove(self.Recent) end
	end

	-- RecordCreated -> nil
	-- Records pseudo-player and ticket creation globally and for one stake.
	-- @param PlayerCount, number -> Number of pseudo players created.
	-- @param Stake, string -> Ticket stake.
	function Metrics:RecordCreated(PlayerCount: number, Stake: string)
		self.PseudoCreated += PlayerCount
		self.TicketsCreated += 1
		local Bucket = self:_Stake(Stake)
		Bucket.PseudoCreated += PlayerCount
		Bucket.TicketsCreated += 1
	end

	-- RecordMatch -> nil
	-- Records one match produced by the production Queue worker and its quality measurements.
	-- @param Wait, number -> Oldest included ticket wait in seconds.
	-- @param TeamDelta, number -> Maximum team-average hidden-MMR delta.
	-- @param Stake, string -> Match stake.
	-- @param Players, number -> Players included in the match.
	function Metrics:RecordMatch(Wait: number, TeamDelta: number, Stake: string, Players: number)
		self.MatchesCreated += 1
		self.MatchedPlayers += Players
		table.insert(self.WaitSamples, Wait)
		table.insert(self.TeamDeltaSamples, TeamDelta)
		local Bucket = self:_Stake(Stake)
		Bucket.MatchesCreated += 1
		Bucket.MatchedPlayers += Players
		table.insert(Bucket.WaitSamples, Wait)
		table.insert(Bucket.TeamDeltaSamples, TeamDelta)
	end

	-- RecordTeleport -> nil
	-- Records one simulated transport completion globally and for one stake.
	-- @param Success, boolean -> Whether the pseudo player arrived successfully.
	-- @param Stake, string -> Match stake.
	function Metrics:RecordTeleport(Success: boolean, Stake: string)
		local Bucket = self:_Stake(Stake)
		if Success then self.TeleportSuccess += 1; Bucket.TeleportSuccess += 1 else self.TeleportFailed += 1; Bucket.TeleportFailed += 1 end
	end

	-- RecordCancel -> nil
	-- Records one queued synthetic-ticket cancellation.
	-- @param Stake, string -> Cancelled ticket stake.
	function Metrics:RecordCancel(Stake: string)
		self.Cancelled += 1
		self:_Stake(Stake).Cancelled += 1
	end

	-- RecordError -> nil
	-- Records one production-engine error observed by the isolated runtime.
	-- @param Message, string -> Error text.
	function Metrics:RecordError(Message: string)
		self.Errors += 1
		self:Log('ERROR • ' .. Message)
	end

	-- _BucketSnapshot -> table
	-- Converts one stake metrics bucket into UI-safe derived values.
	-- @param Bucket, table -> Stake metrics bucket.
	-- @param RuntimeSeconds, number -> Simulator runtime seconds.
	-- @param Live, table -> Current live queue metrics for the stake.
	function Metrics:_BucketSnapshot(Bucket, RuntimeSeconds: number, Live)
		local WorstDelta = 0
		for _, Value in ipairs(Bucket.TeamDeltaSamples) do WorstDelta = math.max(WorstDelta, Value) end
		local Attempts = Bucket.TeleportSuccess + Bucket.TeleportFailed
		return {PseudoCreated = Bucket.PseudoCreated; TicketsCreated = Bucket.TicketsCreated; QueuedTickets = Live.QueuedTickets or 0; QueuedPlayers = Live.QueuedPlayers or 0; AverageQueuedMMR = Live.AverageQueuedMMR or 0; OldestWait = Live.OldestWait or 0; MatchesCreated = Bucket.MatchesCreated; MatchedPlayers = Bucket.MatchedPlayers; Cancelled = Bucket.Cancelled; TeleportSuccess = Bucket.TeleportSuccess; TeleportFailed = Bucket.TeleportFailed; TeleportFailureRate = Attempts > 0 and Bucket.TeleportFailed / Attempts or 0; AverageWait = average(Bucket.WaitSamples); P95Wait = percentile(Bucket.WaitSamples, .95); AverageTeamDelta = average(Bucket.TeamDeltaSamples); WorstTeamDelta = WorstDelta; MatchesPerMinute = Bucket.MatchesCreated / RuntimeSeconds * 60;};
	end

	-- Snapshot -> table
	-- Builds immutable aggregate and per-stake simulation metrics.
	-- @param QueuedTickets, number -> Current queued ticket count.
	-- @param QueuedPlayers, number -> Current queued player count.
	-- @param LiveByStake, table -> Current live queue metrics by stake.
	function Metrics:Snapshot(QueuedTickets: number, QueuedPlayers: number, LiveByStake)
		local RuntimeSeconds = math.max(os.clock() - self.StartedAt, .001)
		local WorstDelta = 0
		for _, Value in ipairs(self.TeamDeltaSamples) do WorstDelta = math.max(WorstDelta, Value) end
		local ByStake = {}
		for _, Stake in ipairs(STAKES) do ByStake[Stake] = self:_BucketSnapshot(self:_Stake(Stake), RuntimeSeconds, LiveByStake[Stake] or {}) end
		local Attempts = self.TeleportSuccess + self.TeleportFailed
		return {PseudoCreated = self.PseudoCreated; TicketsCreated = self.TicketsCreated; QueuedTickets = QueuedTickets; QueuedPlayers = QueuedPlayers; MatchesCreated = self.MatchesCreated; MatchedPlayers = self.MatchedPlayers; Cancelled = self.Cancelled; TeleportSuccess = self.TeleportSuccess; TeleportFailed = self.TeleportFailed; TeleportFailureRate = Attempts > 0 and self.TeleportFailed / Attempts or 0; Errors = self.Errors; AverageWait = average(self.WaitSamples); P95Wait = percentile(self.WaitSamples, .95); AverageTeamDelta = average(self.TeamDeltaSamples); WorstTeamDelta = WorstDelta; MatchesPerMinute = self.MatchesCreated / RuntimeSeconds * 60; Recent = table.clone(self.Recent); ByStake = ByStake;};
	end
end

local Simulator = {} do
	Simulator.__index = Simulator
	Simulator.ClassName = 'MatchmakingSimulator'

	local Profiles = {Ruckus12 = {Players = {Min = 12; Target = 12; Max = 12;}; MMR = {InitialRange = 125; ExpandPerSecond = 10; MaxRange = 900;};};}

	-- sortedProfileNames -> table
	-- Returns deterministic profile names for the diagnostics UI.
	local function sortedProfileNames()
		local Result = {}
		for Name in pairs(Profiles) do table.insert(Result, Name) end
		table.sort(Result)
		return Result;
	end

	-- validStake -> string?
	-- Resolves a case-insensitive stake name into its canonical diagnostics value.
	-- @param Name, string? -> Requested stake.
	local function validStake(Name: string?)
		if type(Name) ~= 'string' then return nil end
		for _, Stake in ipairs(STAKES) do if string.lower(Stake) == string.lower(Name) then return Stake end end
		return nil;
	end

	-- validMode -> string?
	-- Resolves a case-insensitive mode name into its canonical diagnostics value.
	-- @param Name, string? -> Requested mode.
	local function validMode(Name: string?)
		if type(Name) ~= 'string' then return nil end
		for _, Mode in ipairs(MODES) do if string.lower(Mode) == string.lower(Name) then return Mode end end
		return nil;
	end

	-- teamDelta -> number
	-- Calculates maximum average hidden-MMR difference between teams from the production match context.
	-- @param Context, table -> Production Queue match context.
	local function teamDelta(Context)
		if type(Context) ~= 'table' or type(Context.Teams) ~= 'table' or type(Context.MMRs) ~= 'table' then return 0 end
		local Totals = {}
		local Counts = {}
		for UserId, Team in pairs(Context.Teams) do
			local MMR = tonumber(Context.MMRs[tostring(UserId)] or Context.MMRs[UserId])
			if MMR then Totals[Team] = (Totals[Team] or 0) + MMR; Counts[Team] = (Counts[Team] or 0) + 1 end
		end
		local Minimum = math.huge
		local Maximum = -math.huge
		local Count = 0
		for Team, Total in pairs(Totals) do local Average = Total / math.max(Counts[Team] or 1, 1); Minimum = math.min(Minimum, Average); Maximum = math.max(Maximum, Average); Count += 1 end
		return Count > 1 and Maximum - Minimum or 0;
	end

	-- makeDefinition -> table
	-- Builds the active production-shaped simulator definition for one profile.
	-- @param Name, string -> Profile name.
	-- @param Config, table -> Matchmaking configuration.
	local function makeDefinition(Name: string, Config)
		local Definition = table.clone(Profiles[Name])
		Definition.Stakes = STAKES
		Definition.DefaultStake = 'Standard'
		Definition.Modes = MODES
		Definition.DefaultMode = 'FFA'
		return Queue.Normalize('__FORGE_TEST__', Definition, Config);
	end

	-- new -> MatchmakingSimulator
	-- Creates an isolated lab that injects fake Roblox infrastructure into the exact production Queue engine.
	-- @param Config, table -> Matchmaking configuration.
	function Simulator.new(Config)
		local this = setmetatable({}, Simulator)
		this.Config = Config
		this.Random = Random.new(Config.Test.Seed)
		this.Metrics = Metrics.new(Config.Test.RecentMatches)
		this.Profile = Profiles[Config.Test.DefaultProfile] and Config.Test.DefaultProfile or 'Ruckus12'
		this.SelectedStake = 'Standard'
		this.SelectedMode = 'FFA'
		this.TeleportFailureRate = Config.Test.TeleportFailureRate
		this.NextUserId = -1
		this.Players = {}
		this.Matches = {}
		this.VisualTransits = {}
		this.History = {}
		this.LastHistoryTime = 0
		this.Auto = false
		this.AutoAccumulator = 0
		this.Connections = {}
		this:_InitializeEngine()
		return this;
	end

	-- _DisconnectEngine -> nil
	-- Tears down the current isolated Queue engine before a profile/reset rebuild.
	function Simulator:_DisconnectEngine()
		for _, Connection in ipairs(self.Connections) do Connection:Disconnect() end
		self.Connections = {}
		if self.Engine then self.Engine:Destroy(); self.Engine = nil end
	end

	-- _InitializeEngine -> nil
	-- Injects deterministic storage, coordinator, dispatcher, clock and teleport adapters into the real production Queue module.
	function Simulator:_InitializeEngine()
		self:_DisconnectEngine()
		self.Definition = makeDefinition(self.Profile, self.Config)
		self.RuntimeAdapter = TestRuntime.New(self.Config, self.Random, os.time())
		self.Engine = Queue.new('__FORGE_TEST__', self.Definition, self.RuntimeAdapter.QueueRuntime)
		self.Storage = self.RuntimeAdapter.GetStorage()
		self.RuntimeAdapter.Teleport.FailureRate = self.TeleportFailureRate

		-- onMatchCreated -> nil
		-- Forwards production Queue match creation into simulation-only analytics and visuals.
		-- @param Match, table -> Production match record.
		-- @param Context, table -> Production hidden-MMR match context.
		-- @param Selected, table -> Production selected ticket records.
		local function onMatchCreated(Match, Context, Selected)
			self:_OnMatchCreated(Match, Context, Selected)
		end

		-- onTeleporting -> nil
		-- Marks pseudo players as being dispatched after production Queue assignment handling calls the injected transport adapter.
		-- @param TicketValue, table -> Dispatched ticket.
		-- @param Assignment, table -> Production assignment.
		local function onTeleporting(TicketValue, Assignment)
			self:_OnTeleporting(TicketValue, Assignment)
		end

		-- onTeleportFailed -> nil
		-- Records the same Queue teleport-failure signal game code receives in production.
		-- @param PlayerValue, table -> Pseudo player.
		-- @param Result, any -> Synthetic result.
		-- @param Message, string -> Synthetic failure message.
		-- @param Assignment, table -> Production assignment.
		local function onTeleportFailed(PlayerValue, Result, Message, Assignment)
			self.Metrics:Log('TELEPORT FAIL • ' .. tostring(Assignment.Stake) .. ' • P' .. tostring(math.abs(PlayerValue.UserId)))
		end

		-- onError -> nil
		-- Records production Queue errors without contaminating real-game telemetry.
		-- @param Message, string -> Queue error category.
		-- @param Detail, any -> Queue error detail.
		local function onError(Message, Detail)
			self.Metrics:RecordError(tostring(Message) .. ' • ' .. tostring(Detail or ''))
		end

		-- onTransportComplete -> nil
		-- Completes one fake transport and routes failures back through the production Queue failure surface.
		-- @param PlayerValue, table -> Pseudo player.
		-- @param Assignment, table -> Production assignment.
		-- @param Success, boolean -> Synthetic transport outcome.
		local function onTransportComplete(PlayerValue, Assignment, Success)
			self:_OnTransportComplete(PlayerValue, Assignment, Success)
		end

		self.RuntimeAdapter.Teleport.OnComplete = onTransportComplete
		table.insert(self.Connections, self.Engine.MatchCreated:Connect(onMatchCreated))
		table.insert(self.Connections, self.Engine.Teleporting:Connect(onTeleporting))
		table.insert(self.Connections, self.Engine.TeleportFailed:Connect(onTeleportFailed))
		table.insert(self.Connections, self.Engine.Error:Connect(onError))
	end

	-- _MMR -> number
	-- Produces a bounded pseudo hidden MMR centered around 1000 with a broad stress-test spread.
	function Simulator:_MMR()
		return math.clamp(1000 + self.Random:NextInteger(-450, 450), 0, 3000);
	end

	-- _CreatePlayer -> MatchmakingPseudoPlayer
	-- Allocates one unique synthetic player identity.
	-- @param MMR, number? -> Optional explicit hidden rating.
	function Simulator:_CreatePlayer(MMR: number?)
		local UserId = self.NextUserId
		self.NextUserId -= 1
		local PlayerValue = PseudoPlayer.new(UserId, MMR or self:_MMR())
		self.Players[UserId] = PlayerValue
		return PlayerValue;
	end

	-- _CreateTicket -> table
	-- Creates one production-shaped pseudo ticket and inserts it into the adapter read by Queue:_WorkerCycle.
	-- @param Party, table -> Pseudo players queued together.
	-- @param Stake, string? -> Optional matchmaking stake.
	-- @param Mode, string? -> Optional matchmaking mode.
	function Simulator:_CreateTicket(Party, Stake: string?, Mode: string?)
		local ResolvedStake = validStake(Stake) or self.SelectedStake
		local ResolvedMode = validMode(Mode) or self.SelectedMode
		local MMRs = {}
		local Users = {}
		local ByUser = {}
		for _, PlayerValue in ipairs(Party) do table.insert(MMRs, PlayerValue.MMR); table.insert(Users, PlayerValue.UserId); ByUser[tostring(PlayerValue.UserId)] = PlayerValue.MMR end
		local Now = self.RuntimeAdapter.Clock:Now()
		local TicketId = self.RuntimeAdapter.Id:Next('TICKET')
		local TicketValue = {Id = TicketId; Queue = '__FORGE_TEST__'; Stake = ResolvedStake; Mode = ResolvedMode; Users = Users; Size = #Users; MMR = Rating.Average(MMRs); MMRs = ByUser; Priority = 0; Data = {Synthetic = true;}; SourceJobId = 'SIMULATOR'; SourcePlaceId = game.PlaceId; CreatedAt = Now; UpdatedAt = Now; ExpiresAt = Now + self.Definition.TicketTTL; Status = 'Queued';}
		for _, PlayerValue in ipairs(Party) do PlayerValue:SetState('Queued', TicketId, nil); self.Storage:ClaimMembership(PlayerValue.UserId, TicketValue) end
		self.Storage:SeedTicket(TicketValue)
		self.Engine.LocalTickets[TicketId] = {Ticket = TicketValue; Players = Party; Assigned = false; Dispatched = false;}
		self.Metrics:RecordCreated(#Party, ResolvedStake)
		self.Metrics:Log('QUEUED • ' .. ResolvedMode .. ' • ' .. ResolvedStake .. ' • ' .. tostring(#Party) .. 'P @ ' .. tostring(math.floor(TicketValue.MMR)))
		return TicketValue;
	end

	-- SpawnSingles -> number
	-- Creates independent synthetic players and queues each as one production-shaped ticket.
	-- @param Count, number -> Number of pseudo players to create.
	-- @param Stake, string? -> Optional stake override.
	-- @param Mode, string? -> Optional mode override.
	function Simulator:SpawnSingles(Count: number, Stake: string?, Mode: string?)
		local Created = 0
		local Limit = math.max(self.Config.Test.MaxPseudoPlayers - self.Metrics.PseudoCreated, 0)
		local ResolvedStake = validStake(Stake) or self.SelectedStake
		local ResolvedMode = validMode(Mode) or self.SelectedMode
		for _ = 1, math.min(math.max(math.floor(Count), 0), Limit) do self:_CreateTicket({self:_CreatePlayer();}, ResolvedStake, ResolvedMode); Created += 1 end
		return Created;
	end

	-- SpawnParty -> number
	-- Creates one inseparable pseudo party respecting the active production team capacity.
	-- @param Size, number -> Requested party size.
	-- @param Stake, string? -> Optional stake override.
	-- @param Mode, string? -> Optional mode override.
	function Simulator:SpawnParty(Size: number, Stake: string?, Mode: string?)
		local Maximum = self.Definition.Teams and self.Definition.Teams.Size or self.Config.MaxPartySize
		local Count = math.clamp(math.floor(Size), 1, Maximum)
		if self.Metrics.PseudoCreated + Count > self.Config.Test.MaxPseudoPlayers then return 0 end
		local Party = {}
		for _ = 1, Count do table.insert(Party, self:_CreatePlayer()) end
		self:_CreateTicket(Party, validStake(Stake) or self.SelectedStake, validMode(Mode) or self.SelectedMode)
		return Count;
	end

	-- SpawnStress -> number
	-- Distributes synthetic players across every stake and mode partition so isolation and starvation are visible under production behavior.
	-- @param Count, number -> Total pseudo players requested.
	function Simulator:SpawnStress(Count: number)
		local Created = 0
		for Index = 1, math.max(math.floor(Count), 0) do
			local Stake = STAKES[((Index - 1) % #STAKES) + 1]
			local Mode = MODES[(math.floor((Index - 1) / #STAKES) % #MODES) + 1]
			Created += self:SpawnSingles(1, Stake, Mode)
			if self.Metrics.PseudoCreated >= self.Config.Test.MaxPseudoPlayers then break end
		end
		return Created;
	end

	-- _OnMatchCreated -> nil
	-- Records one exact production Queue match and initializes its visual transit records.
	-- @param Match, table -> Production match record.
	-- @param Context, table -> Production hidden-MMR context.
	-- @param Selected, table -> Selected production candidate records.
	function Simulator:_OnMatchCreated(Match, Context, Selected)
		local Oldest = self.RuntimeAdapter.Clock:Now()
		local PartySizes = {}
		for _, Record in ipairs(Selected) do Oldest = math.min(Oldest, Record.Ticket.CreatedAt); for _, UserId in ipairs(Record.Ticket.Users) do PartySizes[UserId] = Record.Ticket.Size end end
		local Wait = self.RuntimeAdapter.Clock:Now() - Oldest
		local Delta = teamDelta(Context)
		local Stake = Match.Stake
		local Mode = Match.Mode
		local Summary = {Id = Match.Id; Stake = Stake; Mode = Mode; Users = table.clone(Match.Users); Teams = table.clone(Match.Teams); CreatedAt = Match.CreatedAt; Wait = Wait; TeamDelta = Delta; Status = Match.Status;}
		table.insert(self.Matches, 1, Summary)
		while #self.Matches > self.Config.Test.RecentMatches do table.remove(self.Matches) end
		self.Metrics:RecordMatch(Wait, Delta, Stake, #Match.Users)
		self.Metrics:Log('MATCH • ' .. tostring(Mode) .. ' • ' .. Stake .. ' • ' .. tostring(#Match.Users) .. 'P • ' .. string.format('%.1fs', Wait) .. ' • Δ ' .. tostring(math.floor(Delta)))
		for _, UserId in ipairs(Match.Users) do
			local PlayerValue = self.Players[UserId]
			local Team = tonumber(Match.Teams[tostring(UserId)])
			if PlayerValue then PlayerValue:SetState('Matched', nil, Team) end
			table.insert(self.VisualTransits, 1, {UserId = UserId; Stake = Stake; Mode = Mode; MMR = PlayerValue and PlayerValue.MMR or 0; Team = Team; PartySize = PartySizes[UserId] or 1; MatchId = Match.Id; Success = nil; StartedAt = self.RuntimeAdapter.Clock:Now();})
			while #self.VisualTransits > VISUAL_TRANSIT_LIMIT do table.remove(self.VisualTransits) end
		end
	end

	-- _OnTeleporting -> nil
	-- Mirrors the production Teleporting signal into pseudo-player state after assignment validation and Send invocation succeed.
	-- @param TicketValue, table -> Production ticket.
	-- @param Assignment, table -> Production assignment.
	function Simulator:_OnTeleporting(TicketValue, Assignment)
		for _, UserId in ipairs(TicketValue.Users) do local PlayerValue = self.Players[UserId]; if PlayerValue then PlayerValue:SetState('Teleporting', nil, tonumber(Assignment.Teams[tostring(UserId)])) end end
	end

	-- _OnTransportComplete -> nil
	-- Completes one adapter-driven pseudo transport and forwards failures into Queue:OnTeleportFailed.
	-- @param PlayerValue, MatchmakingPseudoPlayer -> Pseudo player.
	-- @param Assignment, table -> Production assignment.
	-- @param Success, boolean -> Synthetic outcome.
	function Simulator:_OnTransportComplete(PlayerValue, Assignment, Success: boolean)
		local Team = tonumber(Assignment.Teams[tostring(PlayerValue.UserId)])
		PlayerValue:SetState(Success and 'Teleported' or 'TeleportFailed', nil, Team)
		self.Metrics:RecordTeleport(Success, Assignment.Stake)
		for _, Transit in ipairs(self.VisualTransits) do if Transit.UserId == PlayerValue.UserId and Transit.MatchId == Assignment.MatchId then Transit.Success = Success; Transit.CompletedAt = self.RuntimeAdapter.Clock:Now(); break end end
		if not Success then self.Engine:OnTeleportFailed(PlayerValue, 'SyntheticFailure', 'Injected pseudo-player teleport failure.', Assignment) end
	end

	-- _DrainDispatches -> nil
	-- Delivers dispatcher hints into the exact production Queue assignment handler without MessagingService.
	function Simulator:_DrainDispatches()
		for _, Payload in ipairs(self.RuntimeAdapter.Dispatcher:Drain()) do
			if type(Payload.TicketIds) ~= 'table' then continue end
			for _, TicketId in ipairs(Payload.TicketIds) do self.Engine:_HandleAssignment(TicketId) end
		end
	end

	-- _MatchAvailable -> boolean
	-- Runs one exact Queue:_WorkerCycle and reports whether it created a match.
	function Simulator:_MatchAvailable()
		local Before = self.Metrics.MatchesCreated
		self.Engine:_WorkerCycle()
		self:_DrainDispatches()
		return self.Metrics.MatchesCreated > Before;
	end

	-- _CaptureHistory -> nil
	-- Captures bounded one-second analytics samples for sparklines and trend panels.
	function Simulator:_CaptureHistory()
		local Now = self.RuntimeAdapter.Clock:Now()
		if Now - self.LastHistoryTime < 1 then return end
		self.LastHistoryTime = Now
		local Live = self:_LiveByStake()
		local QueuedPlayers = 0
		for _, Stake in ipairs(STAKES) do QueuedPlayers += Live[Stake].QueuedPlayers end
		table.insert(self.History, {Time = Now; QueuedPlayers = QueuedPlayers; Matches = self.Metrics.MatchesCreated; MatchesPerMinute = self.Metrics:Snapshot(0, 0, Live).MatchesPerMinute; AverageWait = self.Metrics:Snapshot(0, 0, Live).AverageWait; TeleportFailures = self.Metrics.TeleportFailed;})
		while #self.History > HISTORY_LIMIT do table.remove(self.History, 1) end
	end

	-- Step -> nil
	-- Advances deterministic infrastructure adapters and repeatedly runs the exact production Queue worker while matches are available.
	-- @param Delta, number -> Simulation seconds elapsed.
	function Simulator:Step(Delta: number)
		local SafeDelta = math.max(tonumber(Delta) or 0, 0)
		self.RuntimeAdapter.Clock:Advance(SafeDelta)
		if self.Auto then
			self.AutoAccumulator += SafeDelta * self.Config.Test.AutoSpawnRate
			local Spawn = math.floor(self.AutoAccumulator)
			if Spawn > 0 then self.AutoAccumulator -= Spawn; self:SpawnSingles(Spawn, self.SelectedStake, self.SelectedMode) end
		end
		self.RuntimeAdapter.Teleport:Step()
		local Cycles = 0
		while Cycles < 64 and self:_MatchAvailable() do Cycles += 1 end
		self.RuntimeAdapter.Teleport:Step()
		self:_CaptureHistory()
	end

	-- CancelRandom -> boolean
	-- Cancels one random queued synthetic ticket through the storage contract production Queue workers observe.
	function Simulator:CancelRandom()
		local Tickets = self.Storage:ListQueued()
		if #Tickets == 0 then return false end
		local TicketValue = Tickets[self.Random:NextInteger(1, #Tickets)]
		local Success = self.Storage:CancelTicket(TicketValue.Id, 'simulation cancellation')
		if not Success then return false end
		for _, UserId in ipairs(TicketValue.Users) do local PlayerValue = self.Players[UserId]; if PlayerValue then PlayerValue:SetState('Cancelled', nil, nil) end; self.Storage:ReleaseMembership(UserId, TicketValue.Id) end
		self.Engine.LocalTickets[TicketValue.Id] = nil
		self.Metrics:RecordCancel(TicketValue.Stake)
		self.Metrics:Log('CANCELLED • ' .. tostring(TicketValue.Mode) .. ' • ' .. TicketValue.Stake .. ' • ' .. tostring(TicketValue.Size) .. 'P')
		return true;
	end

	-- SetAuto -> boolean
	-- Enables or disables continuous pseudo-player generation for the currently selected stake and mode.
	-- @param Enabled, boolean -> Requested auto-spawn state.
	function Simulator:SetAuto(Enabled: boolean)
		self.Auto = Enabled == true
		self.AutoAccumulator = 0
		return self.Auto;
	end

	-- SetFailureRate -> number
	-- Changes injected pseudo transport failure probability without changing production Queue logic.
	-- @param Value, number -> Failure probability from zero to one.
	function Simulator:SetFailureRate(Value: number)
		self.TeleportFailureRate = math.clamp(tonumber(Value) or 0, 0, 1)
		self.RuntimeAdapter.Teleport.FailureRate = self.TeleportFailureRate
		return self.TeleportFailureRate;
	end

	-- SetProfile -> boolean
	-- Switches production queue definition and resets isolated adapter state.
	-- @param Name, string -> Profile name.
	function Simulator:SetProfile(Name: string)
		if not Profiles[Name] then return false end
		self.Profile = Name
		self:Reset()
		return true;
	end

	-- SetStake -> boolean
	-- Changes the stake used by manual and automatic pseudo-player creation.
	-- @param Name, string -> Stake name.
	function Simulator:SetStake(Name: string)
		local Stake = validStake(Name)
		if not Stake then return false end
		self.SelectedStake = Stake
		return true;
	end

	-- SetMode -> boolean
	-- Changes the mode used by manual and automatic pseudo-player creation.
	-- @param Name, string -> Mode name.
	function Simulator:SetMode(Name: string)
		local Mode = validMode(Name)
		if not Mode then return false end
		self.SelectedMode = Mode
		return true;
	end

	-- Reset -> nil
	-- Clears synthetic state and rebuilds fresh adapters around the exact production Queue module.
	function Simulator:Reset()
		self.NextUserId = -1
		self.Players = {}
		self.Matches = {}
		self.VisualTransits = {}
		self.History = {}
		self.LastHistoryTime = 0
		self.Auto = false
		self.AutoAccumulator = 0
		self.Metrics:Reset()
		self:_InitializeEngine()
		self.RuntimeAdapter.Teleport.FailureRate = self.TeleportFailureRate
	end

	-- _LiveByStake -> table
	-- Calculates current queued players, tickets, average MMR and oldest wait for each stake from the injected storage adapter.
	function Simulator:_LiveByStake()
		local Result = {}
		for _, Stake in ipairs(STAKES) do Result[Stake] = {QueuedTickets = 0; QueuedPlayers = 0; MMRTotal = 0; MMRWeight = 0; AverageQueuedMMR = 0; OldestWait = 0;} end
		local Now = self.RuntimeAdapter.Clock:Now()
		for _, TicketValue in ipairs(self.Storage:ListQueued()) do
			local Bucket = Result[TicketValue.Stake]
			if not Bucket then continue end
			Bucket.QueuedTickets += 1
			Bucket.QueuedPlayers += TicketValue.Size
			Bucket.MMRTotal += TicketValue.MMR * TicketValue.Size
			Bucket.MMRWeight += TicketValue.Size
			Bucket.OldestWait = math.max(Bucket.OldestWait, Now - TicketValue.CreatedAt)
		end
		for _, Stake in ipairs(STAKES) do local Bucket = Result[Stake]; Bucket.AverageQueuedMMR = Bucket.MMRWeight > 0 and Bucket.MMRTotal / Bucket.MMRWeight or 0; Bucket.MMRTotal = nil; Bucket.MMRWeight = nil end
		return Result;
	end

	-- _Histogram -> table, table
	-- Builds overall and per-stake hidden-MMR distributions for currently queued pseudo players.
	function Simulator:_Histogram()
		local Overall = {}
		local ByStake = {}
		for Index, Bin in ipairs(HISTOGRAM) do Overall[Index] = {Label = Bin.Label; Count = 0;} end
		for _, Stake in ipairs(STAKES) do ByStake[Stake] = {}; for Index, Bin in ipairs(HISTOGRAM) do ByStake[Stake][Index] = {Label = Bin.Label; Count = 0;} end end
		for _, TicketValue in ipairs(self.Storage:ListQueued()) do
			for _, UserId in ipairs(TicketValue.Users) do
				local PlayerValue = self.Players[UserId]
				local MMR = PlayerValue and PlayerValue.MMR or TicketValue.MMR
				for Index, Bin in ipairs(HISTOGRAM) do if MMR >= Bin.Min and MMR <= Bin.Max then Overall[Index].Count += 1; ByStake[TicketValue.Stake][Index].Count += 1; break end end
			end
		end
		return Overall, ByStake;
	end

	-- _StateCounts -> table
	-- Counts pseudo players by current lifecycle state for compact flow analytics.
	function Simulator:_StateCounts()
		local Result = {Queued = 0; Matched = 0; Teleporting = 0; Teleported = 0; TeleportFailed = 0; Cancelled = 0;}
		for _, PlayerValue in pairs(self.Players) do if Result[PlayerValue.State] ~= nil then Result[PlayerValue.State] += 1 end end
		return Result;
	end

	-- _Visualization -> table
	-- Builds bounded visual queue markers plus recent production-match transit records.
	function Simulator:_Visualization()
		local PlayersValue = {}
		local ShownByStake = {}
		local QueuedTotal = 0
		local QueuedShown = 0
		for _, Stake in ipairs(STAKES) do ShownByStake[Stake] = 0 end
		for _, TicketValue in ipairs(self.Storage:ListQueued()) do
			for _, UserId in ipairs(TicketValue.Users) do
				QueuedTotal += 1
				local Shown = ShownByStake[TicketValue.Stake] or 0
				if Shown >= VISUAL_QUEUE_PER_STAKE then continue end
				Shown += 1
				ShownByStake[TicketValue.Stake] = Shown
				QueuedShown += 1
				local PlayerValue = self.Players[UserId]
				table.insert(PlayersValue, {UserId = UserId; Stake = TicketValue.Stake; Mode = TicketValue.Mode; State = 'Queued'; MMR = PlayerValue and PlayerValue.MMR or TicketValue.MMR; TicketId = TicketValue.Id; PartySize = TicketValue.Size; Slot = Shown;})
			end
		end
		local Now = self.RuntimeAdapter.Clock:Now()
		for Index = #self.VisualTransits, 1, -1 do
			local Transit = self.VisualTransits[Index]
			local Age = math.max(Now - Transit.StartedAt, 0)
			if Age > VISUAL_TRANSIT_LIFETIME then table.remove(self.VisualTransits, Index); continue end
			local State = Age < .65 and 'Matched' or (Transit.Success == nil and 'Teleporting' or (Transit.Success and 'Teleported' or 'TeleportFailed'))
			table.insert(PlayersValue, {UserId = Transit.UserId; Stake = Transit.Stake; Mode = Transit.Mode; State = State; MMR = Transit.MMR; Team = Transit.Team; PartySize = Transit.PartySize; MatchId = Transit.MatchId; Age = Age; Success = Transit.Success;})
		end
		return {Players = PlayersValue; HiddenQueued = math.max(QueuedTotal - QueuedShown, 0); QueuePerStakeLimit = VISUAL_QUEUE_PER_STAKE; TransitLifetime = VISUAL_TRANSIT_LIFETIME;};
	end

	-- Snapshot -> table
	-- Builds the complete pseudo-player state, exact-engine parity metadata and visual analytics consumed by the draggable lab.
	function Simulator:Snapshot()
		local LiveByStake = self:_LiveByStake()
		local QueuedTickets = 0
		local QueuedPlayers = 0
		for _, Stake in ipairs(STAKES) do QueuedTickets += LiveByStake[Stake].QueuedTickets; QueuedPlayers += LiveByStake[Stake].QueuedPlayers end
		local Snapshot = self.Metrics:Snapshot(QueuedTickets, QueuedPlayers, LiveByStake)
		local OverallHistogram, ByStakeHistogram = self:_Histogram()
		Snapshot.Profile = self.Profile
		Snapshot.Profiles = sortedProfileNames()
		Snapshot.Stakes = table.clone(STAKES)
		Snapshot.SelectedStake = self.SelectedStake
		Snapshot.Modes = table.clone(MODES)
		Snapshot.SelectedMode = self.SelectedMode
		Snapshot.Auto = self.Auto
		Snapshot.FailureRate = self.TeleportFailureRate
		Snapshot.VirtualTime = self.RuntimeAdapter.Clock:Now()
		Snapshot.TargetPlayers = self.Definition.Players.Target
		Snapshot.TeamCount = self.Definition.Teams and self.Definition.Teams.Count or 1
		Snapshot.TeamSize = self.Definition.Teams and self.Definition.Teams.Size or self.Definition.Players.Target
		Snapshot.Visualization = self:_Visualization()
		Snapshot.Analytics = {Engine = 'PRODUCTION QUEUE'; Infrastructure = 'IN-MEMORY ADAPTERS'; ExactMatcher = true; StateCounts = self:_StateCounts(); MMRHistogram = OverallHistogram; MMRByStake = ByStakeHistogram; Timeline = table.clone(self.History);}
		return Snapshot;
	end
end

return Simulator;
