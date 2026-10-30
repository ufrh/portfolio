-- Author -> lolokdev.
-- Last Edit -> September 13, 2026 6:43 PM CDT

local DataStoreService = game:GetService('DataStoreService')

local Config = require(script.Parent.Parent.Config)
local Retry = require(script.Parent.Parent.Util.Retry)
local Id = require(script.Parent.Parent.Util.Id)
local DeepCopy = require(script.Parent.Parent.Util.DeepCopy)

local Leaderboard = {} do
	Leaderboard.__index = Leaderboard
	Leaderboard.ClassName = 'Leaderboard'

	-- finite -> boolean
	-- Returns whether an ordered-datastore score is valid.
	-- @param Value, number -> Score being checked.
	local function finite(Value: number)
		return Value == Value and Value ~= math.huge and Value ~= -math.huge;
	end

	-- new -> Leaderboard
	-- Creates a named ordered-datastore manager for one VAULT store.
	-- @param StoreName, string -> Parent VAULT store name.
	-- @param Scope, string -> Datastore scope.
	function Leaderboard.new(StoreName: string, Scope: string)
		local this = setmetatable({}, Leaderboard)

		this.StoreName = StoreName
		this.Scope = Scope

		this.Stores = {}
		this.Cache = {}

		return this;
	end

	-- _GetStore -> OrderedDataStore
	-- Resolves and caches one named ordered datastore.
	-- @param Name, string -> Leaderboard name.
	function Leaderboard:_GetStore(Name: string)
		local Existing = self.Stores[Name]

		if Existing then return Existing end

		local Store = DataStoreService:GetOrderedDataStore(self.StoreName .. '_LB_' .. Id.SafeName(Name), self.Scope)

		self.Stores[Name] = Store

		return Store;
	end

	-- Set -> boolean, string?
	-- Writes one numeric score for a user/key.
	-- @param Name, string -> Leaderboard name.
	-- @param Key, string|number -> Entry key.
	-- @param Score, number -> Numeric score.
	function Leaderboard:Set(Name: string, Key, Score: number)
		if typeof(Score) ~= 'number' or not finite(Score) then return false, 'leaderboard score must be a finite number' end

		local Store = self:_GetStore(Name)

		-- write -> nil
		-- Performs one ordered datastore SetAsync.
		local function write()
			Store:SetAsync(tostring(Key), Score)
		end

		local Success, Result = Retry.Call(Enum.DataStoreRequestType.SetIncrementSortedAsync, Config.DataStore.SaveAttempts, Config.DataStore.BaseRetryDelay, Config.DataStore.MaxRetryDelay, Config.DataStore.BudgetWaitTimeout, write)

		if not Success then return false, Result end

		self.Cache[Name] = nil

		return true;
	end

	-- Increment -> boolean, number|string
	-- Atomically increments one leaderboard entry.
	-- @param Name, string -> Leaderboard name.
	-- @param Key, string|number -> Entry key.
	-- @param Delta, number -> Score delta.
	function Leaderboard:Increment(Name: string, Key, Delta: number)
		if typeof(Delta) ~= 'number' or not finite(Delta) then return false, 'leaderboard delta must be a finite number' end

		local Store = self:_GetStore(Name)

		-- increment -> number
		-- Performs one ordered datastore IncrementAsync.
		local function increment()
			return Store:IncrementAsync(tostring(Key), Delta);
		end

		local Success, Result = Retry.Call(Enum.DataStoreRequestType.SetIncrementSortedAsync, Config.DataStore.SaveAttempts, Config.DataStore.BaseRetryDelay, Config.DataStore.MaxRetryDelay, Config.DataStore.BudgetWaitTimeout, increment)

		if not Success then return false, Result end

		self.Cache[Name] = nil

		return true, Result;
	end

	-- Remove -> boolean, string?
	-- Removes one leaderboard entry.
	-- @param Name, string -> Leaderboard name.
	-- @param Key, string|number -> Entry key.
	function Leaderboard:Remove(Name: string, Key)
		local Store = self:_GetStore(Name)

		-- remove -> nil
		-- Performs one ordered datastore RemoveAsync.
		local function remove()
			return Store:RemoveAsync(tostring(Key));
		end

		local Success, Result = Retry.Call(Enum.DataStoreRequestType.SetIncrementSortedAsync, Config.DataStore.SaveAttempts, Config.DataStore.BaseRetryDelay, Config.DataStore.MaxRetryDelay, Config.DataStore.BudgetWaitTimeout, remove)

		if not Success then return false, Result end

		self.Cache[Name] = nil

		return true;
	end

	-- GetTop -> boolean, table|string
	-- Returns ordered entries with short-lived query caching.
	-- @param Name, string -> Leaderboard name.
	-- @param Limit, number? -> Number of entries requested.
	-- @param Ascending, boolean? -> Whether lowest scores should come first.
	function Leaderboard:GetTop(Name: string, Limit: number?, Ascending: boolean?)
		local Count = math.clamp(math.floor(Limit or Config.Leaderboard.PageSize), 1, 100)
		local Direction = Ascending == true
		local CacheKey = Name .. ':' .. tostring(Count) .. ':' .. tostring(Direction)
		local Cached = self.Cache[CacheKey]

		if Cached and os.clock() < Cached.expires then return true, DeepCopy.Copy(Cached.value) end

		local Store = self:_GetStore(Name)

		-- read -> DataStorePages
		-- Requests the current ordered leaderboard page.
		local function read()
			return Store:GetSortedAsync(Direction, Count);
		end

		local Success, Pages = Retry.Call(Enum.DataStoreRequestType.GetSortedAsync, Config.DataStore.SaveAttempts, Config.DataStore.BaseRetryDelay, Config.DataStore.MaxRetryDelay, Config.DataStore.BudgetWaitTimeout, read)

		if not Success then return false, Pages end

		local Entries = Pages:GetCurrentPage()
		local Result = {}

		for Rank, Entry in ipairs(Entries) do table.insert(Result, {rank = Rank; key = Entry.key; value = Entry.value;}) end

		self.Cache[CacheKey] = {value = DeepCopy.Copy(Result); expires = os.clock() + Config.Leaderboard.CacheTTL;}

		return true, Result;
	end

	-- Destroy -> nil
	-- Clears local ordered-store references and query caches.
	function Leaderboard:Destroy()
		table.clear(self.Stores)
		table.clear(self.Cache)
	end
end

return Leaderboard;
