-- Author -> lolokdev.
-- Last Edit -> September 15, 2026 1:10 PM CDT

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')

local Root = script
local TestRoot = Root:WaitForChild('Test')

local Arrival = require(Root.Arrival)
local Config = require(Root.Config)
local Dispatcher = require(Root.Dispatcher)
local Queue = require(Root.Queue)
local Rating = require(Root.Rating)
local Storage = require(Root.Storage)
local Stats = require(Root.Stats)
local Teleport = require(Root.Teleport)
local LiveTransport = require(TestRoot.LiveTransport)
local SelfTest = require(TestRoot.SelfTest)
local Simulator = require(TestRoot.Simulator)

local Matchmaking

local TestHarness = {} do
	TestHarness.__index = TestHarness
	TestHarness.ClassName = 'MatchmakingTestHarness'

	-- new -> MatchmakingTestHarness
	-- Creates the optional isolated matchmaking lab using only modules present in the current FORGE tree.
	-- @param RuntimeConfig, table -> Matchmaking configuration.
	-- @param GlobalStats, MatchmakingGlobalStats -> Persistent real-game telemetry provider.
	function TestHarness.new(RuntimeConfig, GlobalStats)
		local this = setmetatable({}, TestHarness)
		this.Config = RuntimeConfig
		this.Stats = GlobalStats
		this.Simulator = Simulator.new(RuntimeConfig)
		this.Folder = nil
		this.Command = nil
		this.Update = nil
		this.Connection = nil
		this.PlayerConnection = nil
		this.Running = false
		this.Accumulator = 0
		this.LastSelfTest = nil
		this.LastProbe = nil
		this.DestinationOnly = false
		return this;
	end

	-- IsAvailable -> boolean
	-- Keeps the diagnostics transport available in Studio and published servers while command authorization remains player-specific.
	function TestHarness:IsAvailable()
		local Ruckus = ReplicatedStorage:FindFirstChild('RUCKUS')
		local Manifest = Ruckus and Ruckus:FindFirstChild('PlaceManifest')
		if Manifest and Manifest:IsA('ModuleScript') then
			local Success, Value = pcall(require, Manifest)
			if Success and type(Value) == 'table' and Value.Role ~= 'MainMenu' then return false end
		end
		if RunService:IsStudio() then return self.Config.Test.EnabledInStudio == true end
		return self.Config.Test.EnablePublishedDiagnostics ~= false;
	end

	-- _ConfiguredTester -> boolean
	-- Resolves explicit public-server diagnostics testers from config or the runtime game attribute.
	-- @param Player, Player -> Requesting player.
	function TestHarness:_ConfiguredTester(Player: Player)
		local AttributeId = tonumber(game:GetAttribute('FORGEMatchmakingTesterUserId'))
		if AttributeId and AttributeId > 0 and Player.UserId == AttributeId then return true end
		for _, UserId in ipairs(self.Config.Test.AuthorizedUserIds or {}) do if Player.UserId == tonumber(UserId) then return true end end
		return false;
	end

	-- _Authorized -> boolean
	-- Restricts diagnostics and pseudo matchmaking to Studio, the experience creator, explicit testers, private-server ownership or authenticated solo-test arrivals.
	-- @param Player, Player -> Requesting player.
	function TestHarness:_Authorized(Player: Player)
		if not Player or not Player.Parent then return false end
		if RunService:IsStudio() then return true end
		if self.Config.Test.AllowCreatorInLive ~= false and game.CreatorType == Enum.CreatorType.User and Player.UserId == game.CreatorId then return true end
		if self:_ConfiguredTester(Player) then return true end
		if game.PrivateServerOwnerId > 0 and Player.UserId == game.PrivateServerOwnerId then return true end
		if game.PrivateServerOwnerId == 0 and game.PrivateServerId ~= '' then
			local ArrivalData = Arrival.Get(Player)
			if type(ArrivalData) == 'table' and ArrivalData.Test == true and ArrivalData.TestType == 'SoloTransport' then return true end
		end
		local Allowed = LiveTransport.IsAuthorized(Player)
		return Allowed == true;
	end

	-- _HasAuthorizedPlayer -> boolean
	-- Returns whether this server currently contains anyone allowed to open the diagnostics bridge.
	function TestHarness:_HasAuthorizedPlayer()
		for _, Player in ipairs(Players:GetPlayers()) do if self:_Authorized(Player) then return true end end
		return false;
	end

	-- _EnsureBridge -> nil
	-- Creates the replicated diagnostics bridge only after an authorized player is actually present.
	function TestHarness:_EnsureBridge()
		if self.Folder and self.Folder.Parent then return end
		if not self:_HasAuthorizedPlayer() then return end
		self:_CreateBridge()
	end

	-- _Snapshot -> table
	-- Builds one complete UI-safe diagnostics snapshot personalized with authoritative solo-transport status for the requesting real player.
	-- @param Player, Player? -> Optional requesting player.
	function TestHarness:_Snapshot(Player: Player?)
		local Snapshot = self.Simulator:Snapshot()
		Snapshot.SelfTest = self.LastSelfTest
		Snapshot.ServiceProbe = self.LastProbe
		Snapshot.Environment = RunService:IsStudio() and 'STUDIO' or (game.PrivateServerId == '' and 'PUBLIC SERVER' or (game.PrivateServerOwnerId > 0 and 'PRIVATE SERVER' or 'RESERVED SERVER'))
		Snapshot.Real = self.Stats:GetSnapshot()
		if Player then
			-- lookup -> table?
			-- Resolves the authoritative destination match for one requesting player.
			-- @param Target, Player -> Arriving player.
			local function lookup(Target)
				return Matchmaking and Matchmaking.GetCurrentMatch and Matchmaking.GetCurrentMatch(Target) or nil;
			end
			Snapshot.SoloTransport = LiveTransport.GetStatus(Player, lookup)
		end
		return Snapshot;
	end

	-- _Push -> nil
	-- Sends personalized diagnostics snapshots to authorized connected test clients.
	function TestHarness:_Push()
		if not self.Update then return end
		for _, Player in ipairs(Players:GetPlayers()) do if self:_Authorized(Player) then self.Update:FireClient(Player, self:_Snapshot(Player)) end end
	end

	-- _RunSelfTest -> table
	-- Runs deterministic production-rule and allocation-pipeline tests and stores the latest report.
	function TestHarness:_RunSelfTest()
		self.LastSelfTest = SelfTest.Run()
		self.Simulator.Metrics:Log('SELF TEST • ' .. tostring(self.LastSelfTest.Passed) .. '/' .. tostring(self.LastSelfTest.Total) .. ' passed')
		for _, Item in ipairs(self.LastSelfTest.Tests) do if not Item.Passed then self.Simulator.Metrics:Log('TEST FAIL • ' .. Item.Name .. ' • ' .. Item.Message) end end
		return self.LastSelfTest;
	end

	-- _RunProbe -> table
	-- Runs opt-in external Roblox service probes and stores the latest report.
	function TestHarness:_RunProbe()
		self.LastProbe = SelfTest.Probe()
		self.Simulator.Metrics:Log('SERVICE PROBE • ' .. tostring(self.LastProbe.Passed) .. ' passed • ' .. tostring(self.LastProbe.Unavailable) .. ' unavailable')
		for _, Item in ipairs(self.LastProbe.Results) do if Item.Status ~= 'PASS' then self.Simulator.Metrics:Log('PROBE ' .. Item.Status .. ' • ' .. Item.Name .. ' • ' .. Item.Message) end end
		return self.LastProbe;
	end

	-- _GetSoloQueue -> MatchmakingQueue?
	-- Creates one isolated MemoryStoreQueue namespace using the exact production Ruckus queue definition so live testing cannot consume or delay real production tickets.
	function TestHarness:_GetSoloQueue()
		if not Matchmaking or not Matchmaking.GetQueue then return nil end
		local Name = 'Ruckus__SoloTransport'
		local Existing = Matchmaking.GetQueue(Name)
		if Existing then return Existing end
		local Base = Matchmaking.GetQueue('Ruckus')
		if not Base then return nil end
		local Definition = Base.Definition
		local Raw = {Destination = {PlaceId = Definition.PlaceId;}; Players = {Min = Definition.Players.Min; Target = Definition.Players.Target; Max = Definition.Players.Max;}; Teams = Definition.Teams and {Count = Definition.Teams.Count; Size = Definition.Teams.Size;} or nil; AllowPartial = Definition.AllowPartial; Stakes = table.clone(Definition.Stakes.List); DefaultStake = Definition.Stakes.Default; Modes = table.clone(Definition.Modes.List); DefaultMode = Definition.Modes.Default; MMR = {Enabled = Definition.MMR.Enabled; Default = Definition.MMR.Default; InitialRange = Definition.MMR.InitialRange; ExpandPerSecond = Definition.MMR.ExpandPerSecond; MaxRange = Definition.MMR.MaxRange; Resolve = Definition.MMR.Resolve;}; TicketTTL = Definition.TicketTTL; Worker = true; CanMatch = Definition.CanMatch; BuildGameplayData = Definition.BuildGameplayData; BuildMatchMetadata = Definition.BuildMatchMetadata; ResolvePriority = Definition.ResolvePriority; TrackStats = false;}
		return Matchmaking.CreateQueue(Name, Raw);
	end

	-- _Command -> any
	-- Executes one validated diagnostics command from the Studio panel.
	-- @param Player, Player -> Requesting Studio player.
	-- @param Name, string -> Command name.
	-- @param Payload, table? -> Command payload.
	function TestHarness:_Command(Player: Player, Name: string, Payload)
		if not self:IsAvailable() then return {Ok = false; Error = 'matchmaking test harness is disabled';} end
		if not self:_Authorized(Player) then return {Ok = false; Error = 'matchmaking test harness is not authorized for this player';} end
		Payload = type(Payload) == 'table' and Payload or {}
		if Name == 'Snapshot' then return {Ok = true; Snapshot = self:_Snapshot(Player);} end
		if Name == 'Spawn' then return {Ok = true; Created = self.Simulator:SpawnSingles(math.clamp(tonumber(Payload.Count) or 1, 1, 100), Payload.Stake, Payload.Mode); Snapshot = self:_Snapshot(Player);} end
		if Name == 'Party' then return {Ok = true; Created = self.Simulator:SpawnParty(math.clamp(tonumber(Payload.Size) or 2, 1, self.Config.MaxPartySize), Payload.Stake, Payload.Mode); Snapshot = self:_Snapshot(Player);} end
		if Name == 'Stress' then return {Ok = true; Created = self.Simulator:SpawnStress(100); Snapshot = self:_Snapshot(Player);} end
		if Name == 'Cancel' then return {Ok = self.Simulator:CancelRandom(); Snapshot = self:_Snapshot(Player);} end
		if Name == 'Auto' then return {Ok = true; Enabled = self.Simulator:SetAuto(Payload.Enabled == true); Snapshot = self:_Snapshot(Player);} end
		if Name == 'FailureRate' then return {Ok = true; Value = self.Simulator:SetFailureRate(tonumber(Payload.Value) or 0); Snapshot = self:_Snapshot(Player);} end
		if Name == 'Profile' then return {Ok = self.Simulator:SetProfile(tostring(Payload.Name or '')); Snapshot = self:_Snapshot(Player);} end
		if Name == 'Stake' then return {Ok = self.Simulator:SetStake(tostring(Payload.Name or '')); Snapshot = self:_Snapshot(Player);} end
		if Name == 'Mode' then return {Ok = self.Simulator:SetMode(tostring(Payload.Name or '')); Snapshot = self:_Snapshot(Player);} end
		if Name == 'Clear' then self.Simulator:Reset(); return {Ok = true; Snapshot = self:_Snapshot(Player);} end
		if Name == 'SelfTest' then return {Ok = true; Report = self:_RunSelfTest(); Snapshot = self:_Snapshot(Player);} end
		if Name == 'Probe' then return {Ok = true; Report = self:_RunProbe(); Snapshot = self:_Snapshot(Player);} end
		if Name == 'RefreshReal' then self.Stats:Refresh(); return {Ok = true; Snapshot = self:_Snapshot(Player);} end
		if Name == 'SoloTransport' then
			local QueueObject = self:_GetSoloQueue()
			if not QueueObject then return {Ok = false; Error = 'Ruckus production queue is not available in this place'; Snapshot = self:_Snapshot(Player);} end
			local Success, Result = LiveTransport.Start(QueueObject, Player, tostring(Payload.Stake or 'Standard'), tostring(Payload.Mode or 'FFA'))
			return {Ok = Success; Error = Success and nil or tostring(Result); SoloTransport = Success and Result or nil; Snapshot = self:_Snapshot(Player);};
		end
		if Name == 'SoloCancel' then
			local QueueObject = self:_GetSoloQueue()
			if not QueueObject then return {Ok = false; Error = 'Ruckus production queue is not available in this place'; Snapshot = self:_Snapshot(Player);} end
			local Success, Result = LiveTransport.Cancel(QueueObject, Player)
			return {Ok = Success; Error = Success and nil or tostring(Result); Snapshot = self:_Snapshot(Player);};
		end
		return {Ok = false; Error = 'unknown matchmaking test command: ' .. tostring(Name);};
	end

	-- _CreateBridge -> nil
	-- Creates the authorization-gated RemoteFunction/RemoteEvent pair used by the draggable diagnostics panel.
	function TestHarness:_CreateBridge()
		local ForgeRoot = ReplicatedStorage:WaitForChild('FORGE')
		local Existing = ForgeRoot:FindFirstChild('__MatchmakingTest')
		if Existing then Existing:Destroy() end
		local Folder = Instance.new('Folder')
		Folder.Name = '__MatchmakingTest'
		Folder.Parent = ForgeRoot
		local Command = Instance.new('RemoteFunction')
		Command.Name = 'Command'
		Command.Parent = Folder
		local Update = Instance.new('RemoteEvent')
		Update.Name = 'Update'
		Update.Parent = Folder

		-- onInvoke -> any
		-- Forwards one test-panel request into the environment-gated harness command router.
		-- @param Player, Player -> Requesting player.
		-- @param Name, string -> Command name.
		-- @param Payload, table? -> Command payload.
		local function onInvoke(Player, Name, Payload)
			return self:_Command(Player, Name, Payload);
		end

		Command.OnServerInvoke = onInvoke
		self.Folder = Folder
		self.Command = Command
		self.Update = Update
	end

	-- _Heartbeat -> nil
	-- Advances the synthetic clock and emits throttled diagnostics snapshots.
	-- @param Delta, number -> Heartbeat delta time.
	function TestHarness:_Heartbeat(Delta: number)
		if not self.Running then return end
		if not self.DestinationOnly then self.Simulator:Step(math.min(Delta, .5)) end
		self.Accumulator += Delta
		if self.Accumulator < self.Config.Test.UpdateInterval then return end
		self.Accumulator = 0
		self:_Push()
	end

	-- Start -> boolean
	-- Starts the authorization-gated diagnostics transport; published public servers stay dormant until a trusted tester joins.
	function TestHarness:Start()
		if self.Running then return true end
		if not self:IsAvailable() then return false end
		self.Running = true
		self.Accumulator = 0
		self.DestinationOnly = false
		self:_EnsureBridge()

		if RunService:IsStudio() and self.Folder then
			self:_RunSelfTest()
			self.Simulator:SpawnSingles(self.Config.Test.InitialPseudoPlayers)
		end

		-- onPlayerAdded -> nil
		-- Lazily opens the replicated diagnostics bridge when a trusted live tester joins a published server.
		-- @param Player, Player -> Joining player.
		local function onPlayerAdded(Player)
			if not self:_Authorized(Player) then return end
			self:_EnsureBridge()
			if self.Update then task.defer(function() if Player.Parent and self:_Authorized(Player) then self.Update:FireClient(Player, self:_Snapshot(Player)) end end) end
		end

		-- onHeartbeat -> nil
		-- Forwards RunService heartbeat into the isolated simulator only while the trusted diagnostics bridge exists.
		-- @param Delta, number -> Heartbeat delta time.
		local function onHeartbeat(Delta)
			if not self.Folder then return end
			self:_Heartbeat(Delta)
		end

		self.PlayerConnection = Players.PlayerAdded:Connect(onPlayerAdded)
		self.Connection = RunService.Heartbeat:Connect(onHeartbeat)
		return true;
	end

	-- Stop -> nil
	-- Stops simulator updates and removes the Studio diagnostics transport.
	function TestHarness:Stop()
		if self.Connection then self.Connection:Disconnect(); self.Connection = nil end
		if self.PlayerConnection then self.PlayerConnection:Disconnect(); self.PlayerConnection = nil end
		if self.Folder then self.Folder:Destroy(); self.Folder = nil end
		self.Command = nil
		self.Update = nil
		self.Running = false
		self.DestinationOnly = false
	end

	-- Destroy -> nil
	-- Fully tears down the harness and clears synthetic state.
	function TestHarness:Destroy()
		self:Stop()
		self.Simulator:Reset()
	end
end

Matchmaking = {
	Config = Config,
	Rating = Rating,
	Arrival = Arrival,
	Queues = {};
} do
	local LookupStorage = Storage.new('__lookup', Config)

	local Runtime = {
		Config = Config,
		Dispatcher = Dispatcher.new(Config),
		Teleport = Teleport.new(Config);
	}

	local GlobalStats = Stats.new()
	local Test = TestHarness.new(Config, GlobalStats)
	Matchmaking.Stats = GlobalStats
	Matchmaking.Test = Test

	local Connections = {}
	local Started = false
	local Destroyed = false

	-- containsUser -> boolean
	-- Returns whether one stored match explicitly contains a Roblox user id.
	-- @param Match, table -> Stored match record.
	-- @param UserId, number -> User id being checked.
	local function containsUser(Match, UserId: number)
		if type(Match) ~= 'table' or type(Match.Users) ~= 'table' then return false end
		for _, Existing in ipairs(Match.Users) do if Existing == UserId then return true end end
		return false;
	end

	-- onDispatch -> nil
	-- Routes one cross-server assignment hint into the matching local queue.
	-- @param Payload, table -> Assignment hint.
	local function onDispatch(Payload)
		if type(Payload) ~= 'table' or type(Payload.Queue) ~= 'string' then return end
		local Existing = Matchmaking.Queues[Payload.Queue]
		if Existing then Existing:OnDispatch(Payload) end
	end

	-- onTeleportFailed -> nil
	-- Routes exhausted teleport retries back into the queue that owns the assignment.
	-- @param Player, Player -> Failed player.
	-- @param Result, any -> Roblox teleport result.
	-- @param Message, string -> Failure message.
	-- @param Assignment, table -> Failed assignment.
	local function onTeleportFailed(Player, Result, Message, Assignment)
		if type(Assignment) ~= 'table' or type(Assignment.Queue) ~= 'string' then return end
		local Existing = Matchmaking.Queues[Assignment.Queue]
		if Existing then Existing:OnTeleportFailed(Player, Result, Message, Assignment) end
	end

	-- CreateQueue -> MatchmakingQueue
	-- Creates a named global queue with party tickets, stake/mode isolation, hidden-MMR expansion and reserved-server allocation.
	-- @param Name, string -> Logical queue name.
	-- @param Definition, table -> Queue configuration.
	function Matchmaking.CreateQueue(Name: string, Definition)
		assert(type(Name) == 'string' and Name ~= '', 'FORGE.Matchmaking.CreateQueue requires a queue name.')
		assert(not Matchmaking.Queues[Name], 'FORGE matchmaking queue already exists: ' .. Name)
		local Normalized = Queue.Normalize(Name, Definition, Config)
		local Created = Queue.new(Name, Normalized, Runtime)
		Matchmaking.Queues[Name] = Created
		if Normalized.TrackStats ~= false then GlobalStats:TrackQueue(Name, Created) end
		if Started then Created:Start() end
		return Created;
	end

	-- GetQueue -> MatchmakingQueue?
	-- Returns one named queue.
	-- @param Name, string -> Queue name.
	function Matchmaking.GetQueue(Name: string)
		return Matchmaking.Queues[Name];
	end

	-- RemoveQueue -> boolean
	-- Destroys one named queue and removes it from the runtime registry.
	-- @param Name, string -> Queue name.
	function Matchmaking.RemoveQueue(Name: string)
		local Existing = Matchmaking.Queues[Name]
		if not Existing then return false end
		GlobalStats:UntrackQueue(Name)
		Existing:Destroy()
		Matchmaking.Queues[Name] = nil
		return true;
	end

	-- GetArrival -> table?
	-- Returns validated FORGE matchmaking teleport data for one arriving player.
	-- @param Player, Player -> Arriving player.
	function Matchmaking.GetArrival(Player: Player)
		return Arrival.Get(Player);
	end

	-- GetTeam -> number?
	-- Returns one arriving player's assigned team number.
	-- @param Player, Player -> Arriving player.
	function Matchmaking.GetTeam(Player: Player)
		return Arrival.Team(Player);
	end

	-- GetCurrentMatch -> table?
	-- Resolves the server-only shared match record for one player arriving from FORGE matchmaking.
	-- @param Player, Player -> Arriving player.
	function Matchmaking.GetCurrentMatch(Player: Player)
		local Data = Arrival.Get(Player)
		if not Data then return nil end
		local Success, Match = LookupStorage:GetMatch(Data.MatchId)
		if not Success or type(Match) ~= 'table' or Match.Status ~= 'Ready' or Match.Queue ~= Data.Queue then return nil end
		if Data.Stake ~= nil and Match.Stake ~= Data.Stake then return nil end
		if Data.Mode ~= nil and Match.Mode ~= Data.Mode then return nil end
		if not containsUser(Match, Player.UserId) then return nil end
		if type(Match.Teams) == 'table' and tonumber(Match.Teams[tostring(Player.UserId)]) ~= tonumber(Data.Teams and Data.Teams[tostring(Player.UserId)]) then return nil end
		return Match;
	end

	-- GetMatch -> table?
	-- Reads one server-only shared match record without requiring the destination place to recreate its source queue.
	-- @param MatchId, string -> Match id.
	function Matchmaking.GetMatch(MatchId: string)
		local Success, Match = LookupStorage:GetMatch(MatchId)
		return Success and type(Match) == 'table' and Match.Status == 'Ready' and Match or nil;
	end

	-- Start -> nil
	-- Starts global assignment delivery, teleport retry handling, diagnostics and all queues created before FORGE startup.
	function Matchmaking.Start()
		assert(not Destroyed, 'FORGE.Matchmaking has been destroyed.')
		if Started then return end
		Started = true
		GlobalStats:Start()
		Runtime.Dispatcher:Start()
		Runtime.Teleport:Start()
		table.insert(Connections, Runtime.Dispatcher.Received:Connect(onDispatch))
		table.insert(Connections, Runtime.Teleport.Failed:Connect(onTeleportFailed))
		for _, Existing in pairs(Matchmaking.Queues) do Existing:Start() end
		Test:Start()
	end

	-- Stop -> nil
	-- Stops queue workers, diagnostics and assignment delivery without deleting queue definitions.
	function Matchmaking.Stop()
		if not Started then return end
		Started = false
		for _, Existing in pairs(Matchmaking.Queues) do Existing:Stop() end
		for _, Connection in ipairs(Connections) do Connection:Disconnect() end
		Connections = {}
		Runtime.Dispatcher:Stop()
		Runtime.Teleport:Stop()
		Test:Stop()
		GlobalStats:Stop()
	end

	-- Destroy -> nil
	-- Fully tears down matchmaking queues, diagnostics, messaging, teleports and local signals.
	function Matchmaking.Destroy()
		if Destroyed then return end
		Matchmaking.Stop()
		local Names = {}
		for Name in pairs(Matchmaking.Queues) do table.insert(Names, Name) end
		for _, Name in ipairs(Names) do Matchmaking.RemoveQueue(Name) end
		Runtime.Dispatcher:Destroy()
		Runtime.Teleport:Destroy()
		Test:Destroy()
		LiveTransport.Destroy()
		GlobalStats:Destroy()
		Destroyed = true
	end
end

return Matchmaking;
