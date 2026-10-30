-- Author -> lolokdev.
-- Last Edit -> September 14, 2026 8:45 PM CDT

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local TeleportService = game:GetService('TeleportService')

local Signal = require(ReplicatedStorage.FORGE.Core.Signal)

local Teleport = {} do
	Teleport.__index = Teleport
	Teleport.ClassName = 'MatchmakingTeleport'

	-- new -> MatchmakingTeleport
	-- Creates reserved-server allocation and retry handling for match assignments.
	-- @param Config, table -> Matchmaking configuration.
	function Teleport.new(Config)
		local this = setmetatable({}, Teleport)

		this.Config = Config
		this.Pending = {}
		this.Connections = {}
		this.Started = false
		this.Failed = Signal.new()

		return this;
	end

	-- Reserve -> boolean, string|any, string?
	-- Reserves one destination server and returns its secret access code plus private server id.
	-- @param PlaceId, number -> Destination place id.
	function Teleport:Reserve(PlaceId: number)
		local Success, AccessCode, PrivateServerId = pcall(TeleportService.ReserveServerAsync, TeleportService, PlaceId)
		if not Success then return false, tostring(AccessCode) end
		return true, AccessCode, PrivateServerId;
	end

	-- _Options -> TeleportOptions
	-- Builds teleport options for one reserved match without leaking the access code into teleport data.
	-- @param Assignment, table -> Server-only match assignment.
	function Teleport:_Options(Assignment)
		local Options = Instance.new('TeleportOptions')
		Options.ReservedServerAccessCode = Assignment.AccessCode
		Options:SetTeleportData({__FORGE_MATCH = {MatchId = Assignment.MatchId; Queue = Assignment.Queue; TicketId = Assignment.TicketId; Stake = Assignment.Stake; Mode = Assignment.Mode; Teams = Assignment.Teams; Test = Assignment.Test == true; TestType = Assignment.TestType; TestSessionId = Assignment.TestSessionId; IssuedAt = Assignment.CreatedAt;};})
		return Options;
	end

	-- _Send -> any
	-- Raw TeleportAsync callback used by pcall.
	-- @param PlaceId, number -> Destination place id.
	-- @param Targets, table -> Players being teleported.
	-- @param Options, TeleportOptions -> Destination options.
	function Teleport:_Send(PlaceId: number, Targets, Options)
		return TeleportService:TeleportAsync(PlaceId, Targets, Options);
	end

	-- Send -> boolean, string?
	-- Sends one same-server player group to the reserved server assigned by the cross-server matcher.
	-- @param Targets, table -> Players from one local ticket.
	-- @param Assignment, table -> Server-only assignment containing the reserved access code.
	function Teleport:Send(Targets, Assignment)
		local Valid = {}

		for _, Player in ipairs(Targets) do
			if typeof(Player) == 'Instance' and Player:IsA('Player') and Player.Parent == Players then table.insert(Valid, Player) end
		end

		if #Valid == 0 then return false, 'no connected players remain for this ticket' end

		local Options = self:_Options(Assignment)

		for _, Player in ipairs(Valid) do self.Pending[Player.UserId] = {Assignment = Assignment; Attempts = 1;} end

		local Success, Result = pcall(Teleport._Send, self, Assignment.PlaceId, Valid, Options)

		if not Success then
			for _, Player in ipairs(Valid) do self.Pending[Player.UserId] = nil end
			return false, tostring(Result);
		end

		return true;
	end

	-- _Retry -> nil
	-- Retries one TeleportInitFailed player using Roblox's exact returned destination options.
	-- @param Player, Player -> Player whose teleport failed.
	-- @param Options, TeleportOptions -> Retry-safe options returned by Roblox.
	function Teleport:_Retry(Player: Player, Options)
		local Context = self.Pending[Player.UserId]
		if not Context or not Player.Parent then return end

		local Success, Result = pcall(Teleport._Send, self, Context.Assignment.PlaceId, {Player;}, Options)

		if not Success then
			self.Pending[Player.UserId] = nil
			self.Failed:Fire(Player, 'TeleportFailure', tostring(Result), Context.Assignment)
		end
	end

	-- _OnTeleportFailed -> nil
	-- Retries Roblox teleport initialization failures before surfacing a final framework failure.
	-- @param Player, Player -> Failed player.
	-- @param Result, TeleportResult -> Roblox failure enum.
	-- @param Message, string -> Roblox failure message.
	-- @param PlaceId, number -> Failed destination place.
	-- @param Options, TeleportOptions -> Exact retry options supplied by Roblox.
	function Teleport:_OnTeleportFailed(Player, Result, Message, PlaceId, Options)
		local Context = self.Pending[Player.UserId]
		if not Context then return end

		if Context.Attempts >= self.Config.TeleportAttempts then
			self.Pending[Player.UserId] = nil
			self.Failed:Fire(Player, Result, Message, Context.Assignment)
			return
		end

		Context.Attempts += 1
		task.delay(self.Config.TeleportRetryDelay, Teleport._Retry, self, Player, Options)
	end

	-- _OnPlayerRemoving -> nil
	-- Clears retry state once a player leaves the source server, normally due to a successful teleport.
	-- @param Player, Player -> Departing player.
	function Teleport:_OnPlayerRemoving(Player: Player)
		self.Pending[Player.UserId] = nil
	end

	-- Start -> nil
	-- Starts teleport-failure retries and source-server cleanup.
	function Teleport:Start()
		if self.Started then return end
		self.Started = true

		-- onTeleportFailed -> nil
		-- Forwards Roblox teleport initialization failures into retry handling.
		-- @param Player, Player -> Failed player.
		-- @param Result, TeleportResult -> Roblox result.
		-- @param Message, string -> Roblox message.
		-- @param PlaceId, number -> Destination place id.
		-- @param Options, TeleportOptions -> Retry options.
		local function onTeleportFailed(Player, Result, Message, PlaceId, Options)
			self:_OnTeleportFailed(Player, Result, Message, PlaceId, Options)
		end

		-- onPlayerRemoving -> nil
		-- Clears successful/departing player retry state.
		-- @param Player, Player -> Departing player.
		local function onPlayerRemoving(Player)
			self:_OnPlayerRemoving(Player)
		end

		table.insert(self.Connections, TeleportService.TeleportInitFailed:Connect(onTeleportFailed))
		table.insert(self.Connections, Players.PlayerRemoving:Connect(onPlayerRemoving))
	end

	-- Stop -> nil
	-- Stops teleport listeners while preserving the transport object.
	function Teleport:Stop()
		for _, Connection in ipairs(self.Connections) do Connection:Disconnect() end
		self.Connections = {}
		self.Pending = {}
		self.Started = false
	end

	-- Destroy -> nil
	-- Stops teleport listeners and destroys signals.
	function Teleport:Destroy()
		self:Stop()
		self.Failed:Destroy()
	end
end

return Teleport;
