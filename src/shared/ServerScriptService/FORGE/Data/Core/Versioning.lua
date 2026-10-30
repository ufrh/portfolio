-- Author -> lolokdev.
-- Last Edit -> September 13, 2026 6:43 PM CDT

local Retry = require(script.Parent.Parent.Util.Retry)

local Versioning = {} do
	Versioning.__index = Versioning
	Versioning.ClassName = 'Versioning'

	-- new -> Versioning
	-- Creates a version-history helper for one datastore.
	-- @param DataStore, GlobalDataStore -> Roblox datastore instance.
	-- @param Config, table -> Store runtime configuration.
	function Versioning.new(DataStore, Config)
		local this = setmetatable({}, Versioning)

		this.DataStore = DataStore
		this.Config = Config

		return this;
	end

	-- List -> boolean, table|string
	-- Lists recent native datastore versions for one profile key.
	-- @param Key, string -> Datastore key.
	-- @param Limit, number? -> Maximum versions returned.
	function Versioning:List(Key: string, Limit: number?)
		local Maximum = math.clamp(math.floor(Limit or 25), 1, 100)

		-- requestPages -> DataStoreVersionPages
		-- Requests descending version history from Roblox.
		local function requestPages()
			return self.DataStore:ListVersionsAsync(Key, Enum.SortDirection.Descending, nil, nil, Maximum);
		end

		local Success, Pages = Retry.Call(nil, self.Config.SaveAttempts, self.Config.BaseRetryDelay, self.Config.MaxRetryDelay, self.Config.BudgetWaitTimeout, requestPages)

		if not Success then return false, Pages end

		local Result = {}

		for _, Entry in ipairs(Pages:GetCurrentPage()) do table.insert(Result, {version = Entry.Version; createdTime = Entry.CreatedTime; isDeleted = Entry.IsDeleted;}) end

		return true, Result;
	end

	-- Get -> boolean, table|string
	-- Reads one exact native datastore version.
	-- @param Key, string -> Datastore key.
	-- @param Version, string -> Roblox version identifier.
	function Versioning:Get(Key: string, Version: string)
		-- readVersion -> table?
		-- Fetches one exact datastore version.
		local function readVersion()
			return self.DataStore:GetVersionAsync(Key, Version);
		end

		return Retry.Call(Enum.DataStoreRequestType.GetAsync, self.Config.SaveAttempts, self.Config.BaseRetryDelay, self.Config.MaxRetryDelay, self.Config.BudgetWaitTimeout, readVersion);
	end
end

return Versioning;
