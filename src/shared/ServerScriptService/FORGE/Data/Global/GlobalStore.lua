-- Author -> lolokdev.
-- Last Edit -> September 13, 2026 6:43 PM CDT

local DataStoreService = game:GetService('DataStoreService')

local Config = require(script.Parent.Parent.Config)
local Codec = require(script.Parent.Parent.Serialization.Codec)
local Sanitizer = require(script.Parent.Parent.Serialization.Sanitizer)
local Retry = require(script.Parent.Parent.Util.Retry)
local DeepCopy = require(script.Parent.Parent.Util.DeepCopy)
local Id = require(script.Parent.Parent.Util.Id)
local Messaging = require(script.Parent.Messaging)

local GlobalStore = {} do
	GlobalStore.__index = GlobalStore
	GlobalStore.ClassName = 'GlobalStore'

	-- invalidate -> nil
	-- Removes one cached global key after another server reports a mutation.
	-- @param Self, GlobalStore -> Global store receiving the invalidation.
	-- @param Key, string -> Mutated key.
	local function invalidate(Self, Key: string)
		Self.Cache[Key] = nil
	end

	-- new -> GlobalStore
	-- Creates an atomic global key/value store with short-lived cache and cross-server invalidation.
	-- @param Name, string -> Parent store name.
	-- @param Scope, string -> Datastore scope.
	-- @param Limits, table -> Serialization limits.
	function GlobalStore.new(Name: string, Scope: string, Limits)
		local this = setmetatable({}, GlobalStore)

		this.Name = Name
		this.Scope = Scope
		this.Limits = Limits

		this.DataStore = DataStoreService:GetDataStore(Name .. '_Global', Scope)
		this.Cache = {}

		this.Bus = Messaging.new(Config.Global.MessagingTopicPrefix .. Id.SafeName(Name))

		-- onChanged -> nil
		-- Invalidates a local cache entry after a remote global mutation.
		-- @param Key, string -> Global key being invalidated.
		local function onChanged(Key)
			invalidate(this, Key)
		end

		this.Bus.Changed:Connect(onChanged)
		this.Bus:Start()

		return this;
	end

	-- _Encode -> any
	-- Serializes and size-checks one global value.
	-- @param Value, any -> Runtime global value.
	function GlobalStore:_Encode(Value)
		local Encoded = Codec.Encode(Value, self.Limits)

		Sanitizer.AssertSize(Encoded, self.Limits.MaxEncodedBytes)

		return Encoded;
	end

	-- _Decode -> any
	-- Decodes one persisted global value.
	-- @param Value, any -> Encoded global value.
	function GlobalStore:_Decode(Value)
		return Codec.Decode(Value, self.Limits);
	end

	-- Get -> boolean, any
	-- Reads one global value with a short-lived local cache.
	-- @param Key, string -> Global stat/key name.
	-- @param Default, any? -> Optional default returned for missing keys.
	function GlobalStore:Get(Key: string, Default)
		local Cached = self.Cache[Key]

		if Cached and os.clock() < Cached.expires then return true, DeepCopy.Copy(Cached.value) end

		-- read -> any
		-- Performs one global datastore GetAsync.
		local function read()
			return self.DataStore:GetAsync(Key);
		end

		local Success, Result = Retry.Call(Enum.DataStoreRequestType.GetAsync, Config.DataStore.SaveAttempts, Config.DataStore.BaseRetryDelay, Config.DataStore.MaxRetryDelay, Config.DataStore.BudgetWaitTimeout, read)

		if not Success then return false, Result end

		local Value = Default

		if Result ~= nil then
			local Decoded, DecodeResult = pcall(self._Decode, self, Result)

			if not Decoded then return false, DecodeResult end

			Value = DecodeResult
		end

		self.Cache[Key] = {value = DeepCopy.Copy(Value); expires = os.clock() + Config.Global.CacheTTL;}

		return true, DeepCopy.Copy(Value);
	end

	-- Set -> boolean, string?
	-- Replaces one global value and invalidates caches across servers.
	-- @param Key, string -> Global key.
	-- @param Value, any -> Runtime value.
	function GlobalStore:Set(Key: string, Value)
		local Encoded

		local Prepared, Result = pcall(self._Encode, self, Value)

		if not Prepared then return false, tostring(Result) end

		Encoded = Result

		-- write -> nil
		-- Performs one global SetAsync.
		local function write()
			self.DataStore:SetAsync(Key, Encoded)
		end

		local Success, Reason = Retry.Call(Enum.DataStoreRequestType.SetIncrementAsync, Config.DataStore.SaveAttempts, Config.DataStore.BaseRetryDelay, Config.DataStore.MaxRetryDelay, Config.DataStore.BudgetWaitTimeout, write)

		if not Success then return false, Reason end

		self.Cache[Key] = {value = DeepCopy.Copy(Value); expires = os.clock() + Config.Global.CacheTTL;}
		self.Bus:Publish(Key)

		return true;
	end

	-- Update -> boolean, any
	-- Atomically transforms one global value through UpdateAsync.
	-- @param Key, string -> Global key.
	-- @param Callback, function -> Pure server-side transformation callback.
	-- @param Default, any? -> Value used when the key does not exist.
	function GlobalStore:Update(Key: string, Callback, Default)
		if type(Callback) ~= 'function' then return false, 'global update callback must be a function' end

		local Updated
		local CallbackError

		-- transform -> any
		-- Decodes, transforms and re-encodes the current global value atomically.
		-- @param Old, any -> Existing encoded global value.
		local function transform(Old)
			local Current = Default

			if Old ~= nil then
				local Decoded, DecodeResult = pcall(self._Decode, self, Old)

				if not Decoded then CallbackError = tostring(DecodeResult); return nil end

				Current = DecodeResult
			end

			local Changed, NewValue = pcall(Callback, DeepCopy.Copy(Current))

			if not Changed then CallbackError = tostring(NewValue); return nil end

			local Encoded, EncodeResult = pcall(self._Encode, self, NewValue)

			if not Encoded then CallbackError = tostring(EncodeResult); return nil end

			Updated = DeepCopy.Copy(NewValue)

			return EncodeResult;
		end

		-- write -> any
		-- Performs the atomic global UpdateAsync.
		local function write()
			return self.DataStore:UpdateAsync(Key, transform);
		end

		local Success, Result = Retry.Call(Enum.DataStoreRequestType.UpdateAsync, Config.DataStore.SaveAttempts, Config.DataStore.BaseRetryDelay, Config.DataStore.MaxRetryDelay, Config.DataStore.BudgetWaitTimeout, write)

		if CallbackError then return false, CallbackError end
		if not Success then return false, Result end
		if Result == nil then return false, 'global update aborted' end

		self.Cache[Key] = {value = DeepCopy.Copy(Updated); expires = os.clock() + Config.Global.CacheTTL;}
		self.Bus:Publish(Key)

		return true, DeepCopy.Copy(Updated);
	end

	-- Increment -> boolean, number|string
	-- Atomically increments a numeric global stat.
	-- @param Key, string -> Global numeric stat key.
	-- @param Delta, number -> Increment amount.
	function GlobalStore:Increment(Key: string, Delta: number)
		if typeof(Delta) ~= 'number' then return false, 'global increment delta must be a number' end

		-- increment -> number
		-- Adds the requested delta to the current numeric value.
		-- @param Current, any -> Current global value.
		local function increment(Current)
			if Current == nil then Current = 0 end
			if typeof(Current) ~= 'number' then error('global value is not numeric') end

			return Current + Delta;
		end

		return self:Update(Key, increment, 0);
	end

	-- Delete -> boolean, string?
	-- Removes one global key.
	-- @param Key, string -> Global key being removed.
	function GlobalStore:Delete(Key: string)
		-- remove -> nil
		-- Performs one global RemoveAsync.
		local function remove()
			return self.DataStore:RemoveAsync(Key);
		end

		local Success, Result = Retry.Call(Enum.DataStoreRequestType.SetIncrementAsync, Config.DataStore.SaveAttempts, Config.DataStore.BaseRetryDelay, Config.DataStore.MaxRetryDelay, Config.DataStore.BudgetWaitTimeout, remove)

		if not Success then return false, Result end

		self.Cache[Key] = nil
		self.Bus:Publish(Key)

		return true;
	end

	-- Destroy -> nil
	-- Destroys the global cache invalidation bus.
	function GlobalStore:Destroy()
		self.Bus:Destroy()
		table.clear(self.Cache)
	end
end

return GlobalStore;
