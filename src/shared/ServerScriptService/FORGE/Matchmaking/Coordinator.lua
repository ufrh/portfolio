-- Author -> lolokdev.
-- Last Edit -> September 14, 2026 4:25 PM CDT

local HttpService = game:GetService('HttpService')

local Coordinator = {} do
	Coordinator.__index = Coordinator
	Coordinator.ClassName = 'MatchmakingCoordinator'

	-- new -> MatchmakingCoordinator
	-- Creates a failover lease coordinator so only one server actively consumes a logical queue at a time.
	-- @param Storage, MatchmakingStorage -> Queue storage.
	-- @param QueueName, string -> Logical queue name.
	-- @param Config, table -> Matchmaking configuration.
	function Coordinator.new(Storage, QueueName: string, Config)
		local this = setmetatable({}, Coordinator)

		this.Storage = Storage
		this.QueueName = QueueName
		this.Config = Config
		this.Token = (game.JobId ~= '' and game.JobId or 'studio') .. ':' .. HttpService:GenerateGUID(false)
		this.Owner = false
		this.ExpiresAt = 0

		return this;
	end

	-- _Acquire -> table?
	-- Attempts to acquire or renew the queue worker lease atomically.
	function Coordinator:_Acquire()
		local Now = os.time()
		local Desired = {Token = self.Token; JobId = game.JobId; ExpiresAt = Now + self.Config.LeaseTTL;}

		-- transform -> table
		-- Claims expired leases while preserving a live lease owned by another server.
		-- @param Current, table? -> Existing lease.
		local function transform(Current)
			if type(Current) == 'table' and Current.Token ~= self.Token and (Current.ExpiresAt or 0) > Now then return Current end
			return Desired;
		end

		return self.Storage.Leases:UpdateAsync(self.QueueName, transform, self.Config.LeaseTTL);
	end

	-- TryAcquire -> boolean
	-- Acquires or renews this server's queue-worker lease.
	function Coordinator:TryAcquire()
		local Success, Result = pcall(Coordinator._Acquire, self)
		self.Owner = Success and type(Result) == 'table' and Result.Token == self.Token
		self.ExpiresAt = self.Owner and (Result.ExpiresAt or 0) or 0
		return self.Owner;
	end

	-- HasLease -> boolean
	-- Returns whether this server still believes it owns a non-expired worker lease.
	function Coordinator:HasLease()
		return self.Owner and self.ExpiresAt > os.time();
	end

	-- _Release -> table?
	-- Releases the worker lease only when this server still owns it.
	function Coordinator:_Release()
		-- transform -> table?
		-- Expires only this coordinator's lease token without deleting a newer owner.
		-- @param Current, table? -> Existing lease.
		local function transform(Current)
			if type(Current) == 'table' and Current.Token == self.Token then Current.ExpiresAt = 0; Current.Released = true end
			return Current;
		end

		return self.Storage.Leases:UpdateAsync(self.QueueName, transform, 1);
	end

	-- Release -> nil
	-- Best-effort release of this server's queue worker lease.
	function Coordinator:Release()
		pcall(Coordinator._Release, self)
		self.Owner = false
		self.ExpiresAt = 0
	end
end

return Coordinator;
