-- Author -> lolokdev.
-- Last Edit -> September 13, 2026 6:43 PM CDT

local Retry = require(script.Parent.Parent.Util.Retry)
local Id = require(script.Parent.Parent.Util.Id)

local SessionLock = {} do
	SessionLock.__index = SessionLock
	SessionLock.ClassName = 'SessionLock'

	-- new -> SessionLock
	-- Creates a session-lock helper around one store configuration.
	-- @param Config, table -> Store runtime configuration.
	function SessionLock.new(Config)
		local this = setmetatable({}, SessionLock)

		this.Config = Config

		return this;
	end

	-- IsStale -> boolean
	-- Returns whether a persisted session heartbeat can safely be reclaimed.
	-- @param Session, table? -> Persisted session record.
	function SessionLock:IsStale(Session)
		if type(Session) ~= 'table' then return true end
		if type(Session.heartbeat) ~= 'number' then return true end

		return os.time() - Session.heartbeat >= self.Config.SessionLockTimeout;
	end

	-- CreateSession -> table
	-- Creates the persisted ownership record for one profile load.
	-- @param Token, string -> Unique profile session token.
	function SessionLock:CreateSession(Token: string)
		local Now = os.time()

		return {
			token = Token,
			jobId = game.JobId,
			placeId = game.PlaceId,
			startedAt = Now,
			heartbeat = Now;
		};
	end

	-- Acquire -> boolean, table|string, string?
	-- Atomically claims one profile key while respecting active sessions in other servers.
	-- @param DataStore, GlobalDataStore -> Roblox datastore instance.
	-- @param Key, string -> Profile datastore key.
	-- @param CreateRecord, function -> Factory for a brand-new record.
	function SessionLock:Acquire(DataStore, Key: string, CreateRecord)
		local Deadline = os.clock() + self.Config.SessionLockLoadTimeout
		local Token = Id.Guid()
		local LastReason = 'session lock unavailable'

		while os.clock() < Deadline do
			local Blocked = false
			local Session = self:CreateSession(Token)

			-- transform -> table?
			-- Claims the record unless another fresh server session currently owns it.
			-- @param Old, table? -> Existing persisted record.
			local function transform(Old)
				local Record = Old or CreateRecord()
				local Existing = Record._session

				if Existing and Existing.token ~= Token and not self:IsStale(Existing) then
					Blocked = true

					return nil;
				end

				Record._session = Session

				return Record;
			end

			-- update -> table?
			-- Performs the atomic lock acquisition UpdateAsync.
			local function update()
				return DataStore:UpdateAsync(Key, transform);
			end

			local Success, Result = Retry.Call(Enum.DataStoreRequestType.UpdateAsync, self.Config.SaveAttempts, self.Config.BaseRetryDelay, self.Config.MaxRetryDelay, self.Config.BudgetWaitTimeout, update)

			if Success and Result then return true, Result, Token end

			if Blocked then
				LastReason = 'profile is active in another server'
				task.wait(self.Config.SessionLockPollInterval)
			else
				LastReason = tostring(Result)

				break
			end
		end

		return false, LastReason;
	end
end

return SessionLock;
