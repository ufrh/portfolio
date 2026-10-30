-- Author -> lolokdev.
-- Last Edit -> September 14, 2026 4:25 PM CDT

local Arrival = {} do
	-- Get -> table?
	-- Reads and validates FORGE match teleport metadata from one arriving player.
	-- @param Player, Player -> Player whose join data is inspected.
	function Arrival.Get(Player: Player)
		local JoinData = Player:GetJoinData()
		local TeleportData = JoinData and JoinData.TeleportData
		local MatchData = type(TeleportData) == 'table' and TeleportData.__FORGE_MATCH or nil

		if type(MatchData) ~= 'table' or type(MatchData.MatchId) ~= 'string' or type(MatchData.Queue) ~= 'string' or type(MatchData.TicketId) ~= 'string' then return nil end

		return MatchData;
	end

	-- Team -> number?
	-- Returns the assigned team index for one arriving player.
	-- @param Player, Player -> Arriving player.
	function Arrival.Team(Player: Player)
		local Data = Arrival.Get(Player)
		if not Data or type(Data.Teams) ~= 'table' then return nil end
		return tonumber(Data.Teams[tostring(Player.UserId)]);
	end

	-- IsReservedServer -> boolean
	-- Returns whether the current server is a Roblox reserved server.
	function Arrival.IsReservedServer()
		return game.PrivateServerId ~= '' and game.PrivateServerOwnerId == 0;
	end
end

return Arrival;
