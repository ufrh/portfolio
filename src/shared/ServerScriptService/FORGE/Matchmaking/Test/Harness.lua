-- Author -> lolokdev.
-- Last Edit -> September 14, 2026 4:25 PM CDT

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')

local SelfTest = require(script.Parent.SelfTest)
local ServiceProbe = require(script.Parent.ServiceProbe)
local Simulator = require(script.Parent.Simulator)

local Harness = {} do
	Harness.__index = Harness
	Harness.ClassName = 'MatchmakingTestHarness'

	-- new -> MatchmakingTestHarness
	-- Creates the optional isolated matchmaking lab used by Studio pseudo-player diagnostics.
	-- @param Config, table -> Matchmaking configuration.
	function Harness.new(Config)
		local this = setmetatable({}, Harness)
		this.Config = Config
		this.Simulator = Simulator.new(Config)
		this.Folder = nil
		this.Command = nil
		this.Update = nil
		this.Connection = nil
		this.Running = false
		this.Accumulator = 0
		this.LastSelfTest = nil
		this.LastProbe = nil
		return this;
	end

	-- IsAvailable -> boolean
	-- Returns whether the diagnostics harness is allowed in the current server environment.
	function Harness:IsAvailable()
		if RunService:IsStudio() then return self.Config.Test.EnabledInStudio == true end
		return self.Config.Test.AllowLive == true and game.PrivateServerId ~= '';
	end

	-- _Snapshot -> table
	-- Builds one complete UI-safe diagnostics snapshot.
	function Harness:_Snapshot()
		local Snapshot = self.Simulator:Snapshot()
		Snapshot.SelfTest = self.LastSelfTest
		Snapshot.ServiceProbe = self.LastProbe
		Snapshot.Environment = RunService:IsStudio() and 'STUDIO' or 'PRIVATE SERVER'
		return Snapshot;
	end

	-- _Push -> nil
	-- Broadcasts one current diagnostics snapshot to connected test clients.
	function Harness:_Push()
		if self.Update then self.Update:FireAllClients(self:_Snapshot()) end
	end

	-- _RunSelfTest -> table
	-- Runs deterministic production-rule and allocation-pipeline tests and stores the latest report.
	function Harness:_RunSelfTest()
		self.LastSelfTest = SelfTest.Run()
		self.Simulator.Metrics:Log('SELF TEST • ' .. tostring(self.LastSelfTest.Passed) .. '/' .. tostring(self.LastSelfTest.Total) .. ' passed')
		for _, Item in ipairs(self.LastSelfTest.Tests) do if not Item.Passed then self.Simulator.Metrics:Log('TEST FAIL • ' .. Item.Name .. ' • ' .. Item.Message) end end
		return self.LastSelfTest;
	end

	-- _RunProbe -> table
	-- Runs opt-in external Roblox service probes and stores the latest report.
	function Harness:_RunProbe()
		self.LastProbe = ServiceProbe.Run()
		self.Simulator.Metrics:Log('SERVICE PROBE • ' .. tostring(self.LastProbe.Passed) .. ' passed • ' .. tostring(self.LastProbe.Unavailable) .. ' unavailable')
		for _, Item in ipairs(self.LastProbe.Results) do if Item.Status ~= 'PASS' then self.Simulator.Metrics:Log('PROBE ' .. Item.Status .. ' • ' .. Item.Name .. ' • ' .. Item.Message) end end
		return self.LastProbe;
	end

	-- _Command -> any
	-- Executes one validated diagnostics command from the Studio panel.
	-- @param Player, Player -> Requesting Studio player.
	-- @param Name, string -> Command name.
	-- @param Payload, table? -> Command payload.
	function Harness:_Command(Player: Player, Name: string, Payload)
		if not self:IsAvailable() then return {Ok = false; Error = 'matchmaking test harness is disabled';} end
		Payload = type(Payload) == 'table' and Payload or {}
		if Name == 'Snapshot' then return {Ok = true; Snapshot = self:_Snapshot();} end
		if Name == 'Spawn' then return {Ok = true; Created = self.Simulator:SpawnSingles(math.clamp(tonumber(Payload.Count) or 1, 1, 100)); Snapshot = self:_Snapshot();} end
		if Name == 'Party' then return {Ok = true; Created = self.Simulator:SpawnParty(math.clamp(tonumber(Payload.Size) or 2, 1, self.Config.MaxPartySize)); Snapshot = self:_Snapshot();} end
		if Name == 'Stress' then return {Ok = true; Created = self.Simulator:SpawnSingles(100); Snapshot = self:_Snapshot();} end
		if Name == 'Cancel' then return {Ok = self.Simulator:CancelRandom(); Snapshot = self:_Snapshot();} end
		if Name == 'Auto' then return {Ok = true; Enabled = self.Simulator:SetAuto(Payload.Enabled == true); Snapshot = self:_Snapshot();} end
		if Name == 'FailureRate' then return {Ok = true; Value = self.Simulator:SetFailureRate(tonumber(Payload.Value) or 0); Snapshot = self:_Snapshot();} end
		if Name == 'Profile' then return {Ok = self.Simulator:SetProfile(tostring(Payload.Name or '')); Snapshot = self:_Snapshot();} end
		if Name == 'Clear' then self.Simulator:Reset(); return {Ok = true; Snapshot = self:_Snapshot();} end
		if Name == 'SelfTest' then return {Ok = true; Report = self:_RunSelfTest(); Snapshot = self:_Snapshot();} end
		if Name == 'Probe' then return {Ok = true; Report = self:_RunProbe(); Snapshot = self:_Snapshot();} end
		return {Ok = false; Error = 'unknown matchmaking test command: ' .. tostring(Name);};
	end

	-- _CreateBridge -> nil
	-- Creates the Studio-only RemoteFunction/RemoteEvent pair used by the draggable diagnostics panel.
	function Harness:_CreateBridge()
		local Root = ReplicatedStorage:WaitForChild('FORGE')
		local Existing = Root:FindFirstChild('__MatchmakingTest')
		if Existing then Existing:Destroy() end
		local Folder = Instance.new('Folder')
		Folder.Name = '__MatchmakingTest'
		Folder.Parent = Root
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
	function Harness:_Heartbeat(Delta: number)
		if not self.Running then return end
		self.Simulator:Step(math.min(Delta, .5))
		self.Accumulator += Delta
		if self.Accumulator < self.Config.Test.UpdateInterval then return end
		self.Accumulator = 0
		self:_Push()
	end

	-- Start -> boolean
	-- Starts the Studio/private-server harness, initial pseudo population and automated self-test report.
	function Harness:Start()
		if self.Running then return true end
		if not self:IsAvailable() then return false end
		self.Running = true
		self.Accumulator = 0
		self:_CreateBridge()
		self:_RunSelfTest()
		self.Simulator:SpawnSingles(self.Config.Test.InitialPseudoPlayers)

		-- onHeartbeat -> nil
		-- Forwards RunService heartbeat into the isolated simulator.
		-- @param Delta, number -> Heartbeat delta time.
		local function onHeartbeat(Delta)
			self:_Heartbeat(Delta)
		end

		self.Connection = RunService.Heartbeat:Connect(onHeartbeat)
		return true;
	end

	-- Stop -> nil
	-- Stops simulator updates and removes the Studio diagnostics transport.
	function Harness:Stop()
		if self.Connection then self.Connection:Disconnect(); self.Connection = nil end
		if self.Folder then self.Folder:Destroy(); self.Folder = nil end
		self.Command = nil
		self.Update = nil
		self.Running = false
	end

	-- Destroy -> nil
	-- Fully tears down the harness and clears synthetic state.
	function Harness:Destroy()
		self:Stop()
		self.Simulator:Reset()
	end
end

return Harness;
