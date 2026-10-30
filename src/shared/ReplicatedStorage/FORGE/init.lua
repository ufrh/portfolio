local RunService = game:GetService('RunService')
local ServerScriptService = game:GetService('ServerScriptService')

local Root = script

local Config = require(Root.Config)
local State = require(Root.Core.State)
local Class = require(Root.Core.Class)
local Registry = require(Root.Core.Registry)
local Loader = require(Root.Core.Loader)
local DependencyGraph = require(Root.Core.DependencyGraph)
local Lifecycle = require(Root.Core.Lifecycle)
local Logger = require(Root.Core.Logger)
local Signal = require(Root.Core.Signal)
local Janitor = require(Root.Core.Janitor)
local Types = require(Root.Shared.Types)
local ClientBridge = require(Root.Network.ClientBridge)
local Avatar = require(Root.Avatar)
local Progression = require(Root.Progression)
local UI = RunService:IsClient() and require(Root.UI) or nil

local FORGE = {} do
	FORGE.Version = Config.Version
	FORGE.Config = Config
	FORGE.Types = Types
	FORGE.Signal = Signal
	FORGE.Janitor = Janitor
	FORGE.Avatar = Avatar
	FORGE.Progression = Progression
	FORGE.UI = UI
	FORGE.Data = nil
	FORGE.Matchmaking = nil

	if UI then
		UI._AttachFORGE(FORGE)
	end

	local ServerSubsystemsLoaded = false

	local function LoadServerSubsystems()
		if not RunService:IsServer() or ServerSubsystemsLoaded then return end

		local ServerRoot = ServerScriptService:FindFirstChild('FORGE') or ServerScriptService:WaitForChild('FORGE', 3)
		assert(ServerRoot, 'FORGE server folder is missing from ServerScriptService.')

		local DataRoot = ServerRoot:FindFirstChild('Data') or ServerRoot:WaitForChild('Data', 3)
		local MatchmakingRoot = ServerRoot:FindFirstChild('Matchmaking') or ServerRoot:WaitForChild('Matchmaking', 3)

		assert(DataRoot, 'FORGE.Data is missing from ServerScriptService.FORGE.')
		assert(MatchmakingRoot, 'FORGE.Matchmaking is missing from ServerScriptService.FORGE.')

		FORGE.Data = require(DataRoot)
		FORGE.Matchmaking = require(MatchmakingRoot)
		ServerSubsystemsLoaded = true
	end

	function FORGE.Class(Kind, Definition)
		return Class.Create(Kind, Definition);
	end

	function FORGE.Get(Name)
		return Registry.Get(Name);
	end

	function FORGE.GetService(Name)
		if RunService:IsServer() then return Registry.GetService(Name) end
		assert(State.Bridge, 'FORGE is not started.')
		return State.Bridge:GetService(Name);
	end

	function FORGE.GetController(Name)
		return Registry.GetController(Name);
	end

	function FORGE.GetData()
		assert(RunService:IsServer(), 'FORGE.Data is server-only.')
		LoadServerSubsystems()
		return FORGE.Data;
	end

	function FORGE.GetMatchmaking()
		assert(RunService:IsServer(), 'FORGE.Matchmaking is server-only.')
		LoadServerSubsystems()
		return FORGE.Matchmaking;
	end

	local function StartMatchmakingIfNeeded()
		if not RunService:IsServer() or not FORGE.Matchmaking then return end
		if next(FORGE.Matchmaking.Queues) ~= nil then
			FORGE.Matchmaking.Start()
		end
	end

	local function Rebuild()
		local Kind = RunService:IsServer() and 'Service' or 'Controller'
		local Ordered = DependencyGraph.Resolve(Registry.List(Kind))

		Lifecycle.Init(Ordered)

		if RunService:IsServer() and State.Bridge and State.Bridge.RebuildRoutes then
			State.Bridge:RebuildRoutes()
			StartMatchmakingIfNeeded()
		end

		Lifecycle.Start(Ordered)
		State.Ordered = Ordered
	end

	function FORGE.Start(Options)
		Options = Options or {}
		if State.Started then return State.BootReport end
		if State.Starting then error('FORGE is already starting.') end

		State.Starting = true
		State.Roots = Options.Roots or {}

		local Success, Result = xpcall(function()
			if RunService:IsClient() then
				State.Bridge = Options.Bridge or ClientBridge.new()
				State.Bridge:Start()
			elseif Options.Bridge then
				State.Bridge = Options.Bridge
				State.Bridge:Start()
			else
				error('FORGE server startup requires a ServerBridge instance.')
			end

			Loader.Load(State.Roots)

			if RunService:IsServer() and State.Bridge.RebuildRoutes then
				State.Bridge:RebuildRoutes()
				LoadServerSubsystems()
			end

			local Kind = RunService:IsServer() and 'Service' or 'Controller'
			local Ordered = DependencyGraph.Resolve(Registry.List(Kind))
			Lifecycle.Init(Ordered)

			if RunService:IsServer() then
				State.Bridge:RebuildRoutes()
				StartMatchmakingIfNeeded()
			end

			Lifecycle.Start(Ordered)
			State.Ordered = Ordered

			if RunService:IsServer() and State.Bridge.SetReady then
				State.Bridge:SetReady(true)
			end

			for _, RuntimeRoot in ipairs(State.Roots) do
				local Connection = Loader.Watch(RuntimeRoot, Rebuild)
				if Connection then table.insert(State.Connections, Connection) end
			end

			State.Started = true
			Logger.Info('Runtime', string.format('FORGE %s started in %s mode.', Config.Version, State.Environment))
			return State.BootReport
		end, debug.traceback)

		State.Starting = false

		if not Success then
			State.Started = false

			if RunService:IsServer() and State.Bridge and State.Bridge.SetBootError then
				State.Bridge:SetBootError(Result)
			end

			error(Result)
		end

		return Result;
	end

	function FORGE.RegisterMiddleware(Name, Callback)
		assert(RunService:IsServer(), 'RegisterMiddleware is server-only.')
		assert(State.Bridge and State.Bridge.RegisterMiddleware, 'FORGE server bridge is not active.')
		State.Bridge:RegisterMiddleware(Name, Callback)
	end

	function FORGE.UseMiddleware(Callback)
		assert(RunService:IsServer(), 'UseMiddleware is server-only.')
		assert(State.Bridge and State.Bridge.Use, 'FORGE server bridge is not active.')
		State.Bridge:Use(Callback)
	end

	function FORGE.Stop()
		if not State.Started then return end
		Lifecycle.Stop(State.Ordered or {})
		if RunService:IsServer() and FORGE.Matchmaking then FORGE.Matchmaking.Stop() end
		State.Started = false
	end

	function FORGE.Destroy()
		Lifecycle.Stop(State.Ordered or {})
		Lifecycle.Destroy(State.Ordered or {})

		for _, Connection in ipairs(State.Connections) do
			Connection:Disconnect()
		end

		State.Connections = {}

		if RunService:IsServer() then
			if FORGE.Matchmaking then FORGE.Matchmaking.Destroy() end
			if FORGE.Data then FORGE.Data.DestroyAll() end
		end

		if State.Bridge and State.Bridge.Destroy then
			State.Bridge:Destroy()
		end

		State.Bridge = nil
		State.Started = false
		State.Starting = false
	end

	function FORGE.GetBootReport()
		return State.BootReport;
	end
end

return FORGE;
