-- Author -> lolokdev.
-- Last Edit -> September 14, 2026 6:05 PM CDT

local PseudoPlayer = {} do
	PseudoPlayer.__index = PseudoPlayer
	PseudoPlayer.ClassName = 'MatchmakingPseudoPlayer'

	-- new -> MatchmakingPseudoPlayer
	-- Creates one deterministic synthetic player used only by the isolated matchmaking simulator.
	-- @param UserId, number -> Synthetic negative user id.
	-- @param MMR, number -> Synthetic hidden matchmaking rating.
	function PseudoPlayer.new(UserId: number, MMR: number)
		local this = setmetatable({}, PseudoPlayer)
		this.UserId = UserId
		this.Name = 'Pseudo_' .. tostring(math.abs(UserId))
		this.DisplayName = this.Name
		this.MMR = MMR
		this.State = 'Idle'
		this.TicketId = nil
		this.Team = nil
		return this;
	end

	-- SetState -> nil
	-- Updates the synthetic lifecycle state and optional ticket/team metadata.
	-- @param State, string -> New synthetic state.
	-- @param TicketId, string? -> Current ticket id.
	-- @param Team, number? -> Assigned simulated team.
	function PseudoPlayer:SetState(State: string, TicketId: string?, Team: number?)
		self.State = State
		self.TicketId = TicketId
		self.Team = Team
	end
end

return PseudoPlayer;
