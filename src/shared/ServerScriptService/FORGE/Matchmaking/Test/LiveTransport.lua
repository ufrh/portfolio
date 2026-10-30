-- Author -> lolokdev.
-- Last Edit -> September 14, 2026 8:45 PM CDT

local HttpService = game:GetService('HttpService')
local RunService = game:GetService('RunService')

local LiveTransport = {} do
	LiveTransport.__index = LiveTransport
	LiveTransport.ClassName = 'MatchmakingLiveTransportTest'

	local Sessions = {}
	local SessionsById = {}
	local BoundQueues = {}

	-- copyArray -> table
	-- Creates a shallow array copy for UI-safe test status payloads.
	-- @param Source, table? -> Source array.
	local function copyArray(Source)
		local Result = {}
		for _, Value in ipairs(Source or {}) do table.insert(Result, Value) end
		return Result;
	end

	-- copyStatus -> table
	-- Creates a client-safe snapshot of one solo transport session without exposing hidden MMR or reserved-server credentials.
	-- @param Session, table -> Internal session record.
	local function copyStatus(Session)
		return {Enabled = true; Available = true; Active = Session.Active == true; SessionId = Session.SessionId; Stage = Session.Stage; Stake = Session.Stake; Mode = Session.Mode; TargetPlayers = Session.TargetPlayers; RealPlayers = Session.RealPlayers; SyntheticPlayers = Session.SyntheticPlayers; MatchId = Session.MatchId; DestinationPlaceId = Session.DestinationPlaceId; Reason = Session.Reason; CreatedAt = Session.CreatedAt; UpdatedAt = Session.UpdatedAt; SyntheticUsers = copyArray(Session.SyntheticUsers); Checks = {TicketCreated = Session.Checks.TicketCreated == true; SyntheticFilled = Session.Checks.SyntheticFilled == true; MatchCreated = Session.Checks.MatchCreated == true; MatchPersisted = Session.Checks.MatchPersisted == true; ReservedAllocated = Session.Checks.ReservedAllocated == true; AssignmentReceived = Session.Checks.AssignmentReceived == true; TeleportRequested = Session.Checks.TeleportRequested == true; DestinationJoined = Session.Checks.DestinationJoined == true; ArrivalAuthenticated = Session.Checks.ArrivalAuthenticated == true;};};
	end

	-- setStage -> nil
	-- Advances one solo transport session and records the latest reason/status text.
	-- @param Session, table -> Session being updated.
	-- @param Stage, string -> New stage name.
	-- @param Reason, string? -> Optional descriptive reason.
	local function setStage(Session, Stage: string, Reason: string?)
		Session.Stage = Stage
		Session.Reason = Reason
		Session.UpdatedAt = os.time()
	end

	-- syntheticBase -> number
	-- Produces one deterministic negative pseudo-user range from a session id.
	-- @param SessionId, string -> Unique test session id.
	local function syntheticBase(SessionId: string)
		local Hash = 2166136261
		for Index = 1, #SessionId do Hash = bit32.bxor(Hash, string.byte(SessionId, Index)); Hash = (Hash * 16777619) % 1000000000 end
		return -1000000000 - Hash * 100;
	end

	-- isCreator -> boolean
	-- Returns whether the requesting player is the direct user-owner of the experience.
	-- @param Player, Player -> Requesting player.
	local function isCreator(Player: Player)
		return game.CreatorType == Enum.CreatorType.User and Player.UserId == game.CreatorId;
	end

	-- isExplicitTester -> boolean
	-- Returns whether the requester matches the optional explicit test-user attribute.
	-- @param Player, Player -> Requesting player.
	local function isExplicitTester(Player: Player)
		local UserId = tonumber(game:GetAttribute('FORGESoloTransportTesterUserId'))
		return UserId ~= nil and UserId > 0 and Player.UserId == UserId;
	end

	-- isPrivateOwner -> boolean
	-- Returns whether the requester owns the current VIP/private server.
	-- @param Player, Player -> Requesting player.
	local function isPrivateOwner(Player: Player)
		return game.PrivateServerOwnerId > 0 and Player.UserId == game.PrivateServerOwnerId;
	end

	-- IsEnabled -> boolean
	-- Returns whether the explicit game-level solo transport switch is enabled.
	function LiveTransport.IsEnabled()
		return game:GetAttribute('FORGEAllowSoloTransportTest') == true;
	end

	-- IsAuthorized -> boolean, string?
	-- Validates that destructive live transport testing is explicitly enabled and limited to a trusted published private-server tester.
	-- @param Player, Player -> Requesting player.
	function LiveTransport.IsAuthorized(Player: Player)
		if not LiveTransport.IsEnabled() then return false, 'Set game attribute FORGEAllowSoloTransportTest = true first.' end
		if RunService:IsStudio() then return false, 'Solo live transport requires a published Roblox server; Studio cannot complete real teleports.' end
		if game.PrivateServerId == '' then return false, 'Solo live transport is restricted to private or reserved servers.' end
		if isPrivateOwner(Player) or isCreator(Player) or isExplicitTester(Player) then return true end
		return false, 'Only the private-server owner, experience creator, or FORGESoloTransportTesterUserId may run this test.';
	end

	-- _FindSessionByTicket -> table?
	-- Resolves a tracked solo test session from one marked ticket.
	-- @param TicketValue, table? -> Ticket associated with a queue event.
	function LiveTransport._FindSessionByTicket(TicketValue)
		if type(TicketValue) ~= 'table' or type(TicketValue.TestSessionId) ~= 'string' then return nil end
		return SessionsById[TicketValue.TestSessionId];
	end

	-- BindQueue -> nil
	-- Binds one production queue once so solo test progress follows the exact real matchmaking and teleport signals.
	-- @param QueueObject, MatchmakingQueue -> Production queue being tested.
	function LiveTransport.BindQueue(QueueObject)
		if BoundQueues[QueueObject] then return end
		local Connections = {}

		-- onMatchFound -> nil
		-- Marks allocation, persistence, reservation and assignment as verified when the real source ticket receives its assignment.
		-- @param TicketValue, table -> Local real ticket.
		-- @param Assignment, table -> Real reserved-server assignment.
		-- @param Match, table -> Authoritative stored match record.
		local function onMatchFound(TicketValue, Assignment, Match)
			local Session = LiveTransport._FindSessionByTicket(TicketValue)
			if not Session then return end
			Session.MatchId = Assignment.MatchId
			Session.Checks.MatchCreated = true
			Session.Checks.MatchPersisted = type(Match) == 'table' and Match.Id == Assignment.MatchId
			Session.Checks.ReservedAllocated = type(Assignment.AccessCode) == 'string' and Assignment.AccessCode ~= ''
			Session.Checks.AssignmentReceived = true
			setStage(Session, 'MatchFound', '12/12 test match allocated and assignment received.')
		end

		-- onTeleporting -> nil
		-- Marks the real Roblox TeleportAsync dispatch as requested for the real client.
		-- @param TicketValue, table -> Local real ticket.
		local function onTeleporting(TicketValue)
			local Session = LiveTransport._FindSessionByTicket(TicketValue)
			if not Session then return end
			Session.Checks.TeleportRequested = true
			setStage(Session, 'Teleporting', 'Real TeleportAsync request sent to the configured gameplay place.')
		end

		-- onTeleportFailed -> nil
		-- Records an exhausted real Roblox teleport failure for this test session.
		-- @param Player, Player -> Failed real player.
		-- @param Result, any -> Roblox teleport result.
		-- @param Message, string -> Failure text.
		-- @param Assignment, table -> Failed assignment.
		local function onTeleportFailed(Player, Result, Message, Assignment)
			if type(Assignment) ~= 'table' or type(Assignment.TestSessionId) ~= 'string' then return end
			local Session = SessionsById[Assignment.TestSessionId]
			if not Session then return end
			Session.Active = false
			setStage(Session, 'TeleportFailed', tostring(Message or Result))
		end

		-- onCancelled -> nil
		-- Marks a source-side test as cancelled when its real ticket leaves before matching.
		-- @param TicketValue, table -> Cancelled ticket.
		-- @param Reason, string -> Cancellation reason.
		local function onCancelled(TicketValue, Reason)
			local Session = LiveTransport._FindSessionByTicket(TicketValue)
			if not Session or TicketValue.Synthetic == true then return end
			Session.Active = false
			setStage(Session, 'Cancelled', tostring(Reason or 'cancelled'))
		end

		table.insert(Connections, QueueObject.MatchFound:Connect(onMatchFound))
		table.insert(Connections, QueueObject.Teleporting:Connect(onTeleporting))
		table.insert(Connections, QueueObject.TeleportFailed:Connect(onTeleportFailed))
		table.insert(Connections, QueueObject.Cancelled:Connect(onCancelled))
		BoundQueues[QueueObject] = Connections
	end

	-- Start -> boolean, table|string
	-- Queues one real player plus synthetic filler tickets through the production queue so one client can validate the full live Roblox transport boundary.
	-- @param QueueObject, MatchmakingQueue -> Real production queue.
	-- @param Player, Player -> Only real player in the test.
	-- @param Stake, string -> Selected stake partition.
	-- @param Mode, string -> Selected game-mode partition.
	function LiveTransport.Start(QueueObject, Player: Player, Stake: string, Mode: string)
		local Allowed, Reason = LiveTransport.IsAuthorized(Player)
		if not Allowed then return false, Reason end
		assert(QueueObject and QueueObject.ClassName == 'MatchmakingQueue', 'Solo live transport requires a production MatchmakingQueue.')
		LiveTransport.BindQueue(QueueObject)

		local Existing = QueueObject:GetStatus(Player)
		if Existing then return false, 'Leave the current matchmaking queue before starting a solo live transport test.' end

		local SessionId = HttpService:GenerateGUID(false)
		local TargetPlayers = QueueObject.Definition.Players.Target
		local Session = {SessionId = SessionId; Active = true; Stage = 'Preparing'; Stake = Stake; Mode = Mode; TargetPlayers = TargetPlayers; RealPlayers = 1; SyntheticPlayers = 0; SyntheticUsers = {}; SyntheticTicketIds = {}; MatchId = nil; DestinationPlaceId = QueueObject.Definition.PlaceId; Reason = nil; CreatedAt = os.time(); UpdatedAt = os.time(); Checks = {TicketCreated = false; SyntheticFilled = false; MatchCreated = false; MatchPersisted = false; ReservedAllocated = false; AssignmentReceived = false; TeleportRequested = false; DestinationJoined = false; ArrivalAuthenticated = false;};}
		Sessions[Player.UserId] = Session
		SessionsById[SessionId] = Session

		local Data = {__FORGESoloTransportTest = true; TestSessionId = SessionId; RealPlayerUserId = Player.UserId;}
		local Joined, RealTicket = QueueObject:Join(Player, {Stake = Stake; Mode = Mode; Data = Data; Test = true; TestType = 'SoloTransport'; TestSessionId = SessionId;})
		if not Joined then Session.Active = false; setStage(Session, 'Failed', tostring(RealTicket)); return false, tostring(RealTicket) end

		Session.RealTicketId = RealTicket.Id
		Session.Stake = RealTicket.Stake
		Session.Mode = RealTicket.Mode
		Session.Checks.TicketCreated = true
		setStage(Session, 'Filling', 'Real production ticket created; injecting isolated synthetic filler tickets.')

		local Needed = math.max(TargetPlayers - RealTicket.Size, 0)
		local Base = syntheticBase(SessionId)

		for Index = 1, Needed do
			local UserId = Base - Index
			local Created, SyntheticTicket = QueueObject:InjectSyntheticTestTicket(UserId, {Stake = RealTicket.Stake; Mode = RealTicket.Mode; MMR = RealTicket.MMR; TestSessionId = SessionId; Data = {__FORGESoloTransportTest = true; TestSessionId = SessionId; SyntheticIndex = Index;};})
			if not Created then
				for _, TicketId in ipairs(Session.SyntheticTicketIds) do QueueObject:Leave(TicketId, 'solo transport filler rollback') end
				QueueObject:Leave(RealTicket.Id, 'solo transport filler rollback')
				Session.Active = false
				setStage(Session, 'Failed', 'Synthetic filler creation failed: ' .. tostring(SyntheticTicket))
				return false, Session.Reason;
			end
			table.insert(Session.SyntheticUsers, UserId)
			table.insert(Session.SyntheticTicketIds, SyntheticTicket.Id)
		end

		Session.SyntheticPlayers = Needed
		Session.Checks.SyntheticFilled = Needed == 0 or #Session.SyntheticTicketIds == Needed
		setStage(Session, 'Searching', tostring(RealTicket.Size) .. ' real + ' .. tostring(Needed) .. ' synthetic participants queued through the production matcher.')
		return true, copyStatus(Session);
	end

	-- Cancel -> boolean, string?
	-- Cancels a still-searching source-side solo test and all synthetic filler tickets.
	-- @param QueueObject, MatchmakingQueue -> Production queue.
	-- @param Player, Player -> Test owner.
	function LiveTransport.Cancel(QueueObject, Player: Player)
		local Session = Sessions[Player.UserId]
		if not Session or not Session.Active then return false, 'No active solo transport test exists.' end
		if Session.RealTicketId then QueueObject:Leave(Session.RealTicketId, 'solo transport test cancelled') end
		for _, TicketId in ipairs(Session.SyntheticTicketIds or {}) do QueueObject:Leave(TicketId, 'solo transport test cancelled') end
		Session.Active = false
		setStage(Session, 'Cancelled', 'Solo transport test cancelled.')
		return true;
	end

	-- GetStatus -> table
	-- Returns source progress or authoritative destination-arrival verification for one player.
	-- @param Player, Player -> Requesting real player.
	-- @param MatchLookup, function? -> Optional authoritative GetCurrentMatch callback available in the destination place.
	function LiveTransport.GetStatus(Player: Player, MatchLookup)
		if type(MatchLookup) == 'function' then
			local Success, Match = pcall(MatchLookup, Player)
			if Success and type(Match) == 'table' and Match.Test == true and Match.TestType == 'SoloTransport' and type(Match.TestSessionId) == 'string' then
				local SyntheticUsers = type(Match.SyntheticUsers) == 'table' and Match.SyntheticUsers or {}
				return {Enabled = true; Available = true; Active = false; SessionId = Match.TestSessionId; Stage = 'ArrivalVerified'; Stake = Match.Stake; Mode = Match.Mode; TargetPlayers = #(Match.Users or {}); RealPlayers = type(Match.RealUsers) == 'table' and #Match.RealUsers or 1; SyntheticPlayers = #SyntheticUsers; SyntheticUsers = copyArray(SyntheticUsers); MatchId = Match.Id; DestinationPlaceId = Match.PlaceId; Reason = 'Authoritative destination match record verified for this real player.'; CreatedAt = Match.CreatedAt; UpdatedAt = os.time(); Checks = {TicketCreated = true; SyntheticFilled = true; MatchCreated = true; MatchPersisted = true; ReservedAllocated = true; AssignmentReceived = true; TeleportRequested = true; DestinationJoined = true; ArrivalAuthenticated = true;};}
			end
		end

		local Session = Sessions[Player.UserId]
		if Session then return copyStatus(Session) end
		local Allowed, Reason = LiveTransport.IsAuthorized(Player)
		return {Enabled = LiveTransport.IsEnabled(); Available = Allowed; Active = false; Stage = Allowed and 'Ready' or 'Unavailable'; Reason = Reason; Checks = {TicketCreated = false; SyntheticFilled = false; MatchCreated = false; MatchPersisted = false; ReservedAllocated = false; AssignmentReceived = false; TeleportRequested = false; DestinationJoined = false; ArrivalAuthenticated = false;};};
	end

	-- Destroy -> nil
	-- Disconnects bound queue listeners and clears in-memory source-side test sessions.
	function LiveTransport.Destroy()
		for QueueObject, Connections in pairs(BoundQueues) do
			for _, Connection in ipairs(Connections) do Connection:Disconnect() end
			BoundQueues[QueueObject] = nil
		end
		table.clear(Sessions)
		table.clear(SessionsById)
	end
end

return LiveTransport;
