-- Author -> lolokdev.
-- Last Edit -> September 14, 2026 4:25 PM CDT

local DeepCopy = require(script.Parent.Parent.Util.DeepCopy)
local Path = require(script.Parent.Parent.Util.Path)
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local Signal = require(ReplicatedStorage.FORGE.Core.Signal)

local Profile = {} do
	Profile.__index = Profile
	Profile.ClassName = 'Profile'

	-- new -> Profile
	-- Creates one loaded in-memory profile bound to a store session token.
	-- @param Store, table -> Owning VAULT store.
	-- @param UserId, number -> Roblox user id.
	-- @param Key, string -> Persisted datastore key.
	-- @param Data, table -> Decoded profile data.
	-- @param Meta, table -> Persisted metadata snapshot.
	-- @param Token, string -> Session ownership token.
	-- @param Player, Player? -> Optional connected player.
	function Profile.new(Store, UserId: number, Key: string, Data, Meta, Token: string, Player: Player?)
		local this = setmetatable({}, Profile)

		this.Store = Store
		this.UserId = UserId
		this.Key = Key
		this.Player = Player

		this._Data = Data
		this._Meta = Meta
		this._Token = Token
		this._Receipts = Meta.Receipts or {}

		this._Dirty = false
		this._Released = false
		this._LockLost = false
		this._Saving = false
		this._SaveAgain = false

		this._LastSave = os.clock()
		this._NextAutosave = 0

		this._Audit = {}

		this.Changed = Signal.new()
		this.Released = Signal.new()

		return this;
	end

	-- _AssertActive -> nil
	-- Rejects mutations after a profile has released or lost ownership.
	function Profile:_AssertActive()
		assert(not self._Released, 'VAULT profile is released.')
		assert(not self._LockLost, 'VAULT profile no longer owns its session lock.')
	end

	-- _RecordAudit -> nil
	-- Appends one bounded in-memory mutation entry for debugging and telemetry.
	-- @param Action, string -> Mutation action.
	-- @param DataPath, string? -> Optional data path.
	-- @param OldValue, any -> Previous value.
	-- @param NewValue, any -> New value.
	function Profile:_RecordAudit(Action: string, DataPath: string?, OldValue, NewValue)
		local Limit = self.Store.Config.AuditTrailSize

		table.insert(self._Audit, {time = os.time(); action = Action; path = DataPath; old = DeepCopy.Copy(OldValue); new = DeepCopy.Copy(NewValue);})

		while #self._Audit > Limit do table.remove(self._Audit, 1) end
	end

	-- Get -> any
	-- Returns a deep-copied value from the profile.
	-- @param DataPath, string -> Dot-delimited data path.
	function Profile:Get(DataPath: string)
		self:_AssertActive()

		return DeepCopy.Copy(Path.Get(self._Data, DataPath));
	end

	-- Has -> boolean
	-- Returns whether a path currently contains a non-nil value.
	-- @param DataPath, string -> Dot-delimited data path.
	function Profile:Has(DataPath: string)
		self:_AssertActive()

		return Path.Get(self._Data, DataPath) ~= nil;
	end

	-- Snapshot -> table
	-- Returns a deep copy of the entire profile data tree.
	function Profile:Snapshot()
		self:_AssertActive()

		return DeepCopy.Copy(self._Data);
	end

	-- Metadata -> table
	-- Returns a safe copy of profile persistence metadata.
	function Profile:Metadata()
		return DeepCopy.Copy(self._Meta);
	end

	-- GetAuditTrail -> table
	-- Returns the bounded server-memory mutation journal.
	function Profile:GetAuditTrail()
		return DeepCopy.Copy(self._Audit);
	end

	-- IsDirty -> boolean
	-- Returns whether the profile contains unsaved changes.
	function Profile:IsDirty()
		return self._Dirty;
	end

	-- IsReleased -> boolean
	-- Returns whether this profile can no longer be mutated or saved.
	function Profile:IsReleased()
		return self._Released;
	end

	-- Set -> boolean, string?
	-- Validates and writes one profile value.
	-- @param DataPath, string -> Dot-delimited data path.
	-- @param Value, any -> Proposed server-authoritative value.
	function Profile:Set(DataPath: string, Value)
		self:_AssertActive()

		local Accepted, Reason = self.Store:_ValidatePathValue(DataPath, Value)

		if not Accepted then return false, Reason end

		local OldValue = Path.Get(self._Data, DataPath)
		local Written, WriteReason = Path.Set(self._Data, DataPath, DeepCopy.Copy(Value))

		if not Written then return false, WriteReason end

		self._Dirty = true

		self:_RecordAudit('Set', DataPath, OldValue, Value)
		self.Changed:Fire(DataPath, DeepCopy.Copy(Value), DeepCopy.Copy(OldValue))

		return true;
	end

	-- Increment -> boolean, number|string
	-- Atomically mutates one local numeric profile value after validation.
	-- @param DataPath, string -> Numeric data path.
	-- @param Delta, number -> Amount added to the current value.
	function Profile:Increment(DataPath: string, Delta: number)
		self:_AssertActive()

		if typeof(Delta) ~= 'number' then return false, 'increment delta must be a number' end

		local Current = Path.Get(self._Data, DataPath)

		if typeof(Current) ~= 'number' then return false, DataPath .. ' is not numeric' end

		local NewValue = Current + Delta
		local Success, Reason = self:Set(DataPath, NewValue)

		if not Success then return false, Reason end

		return true, NewValue;
	end

	-- Update -> boolean, any
	-- Applies a server callback to one path and validates its returned value.
	-- @param DataPath, string -> Data path being updated.
	-- @param Callback, function -> Pure server-side transformation callback.
	function Profile:Update(DataPath: string, Callback)
		self:_AssertActive()

		if type(Callback) ~= 'function' then return false, 'update callback must be a function' end

		local Current = DeepCopy.Copy(Path.Get(self._Data, DataPath))
		local Success, Result = pcall(Callback, Current)

		if not Success then return false, tostring(Result) end

		return self:Set(DataPath, Result);
	end

	-- Transaction -> boolean, string?
	-- Applies an all-or-nothing mutation to a deep-copied draft and validates the complete result.
	-- @param Callback, function -> Server-side draft mutation callback.
	function Profile:Transaction(Callback)
		self:_AssertActive()

		if type(Callback) ~= 'function' then return false, 'transaction callback must be a function' end

		local Draft = DeepCopy.Copy(self._Data)
		local Success, Result = pcall(Callback, Draft)

		if not Success then return false, tostring(Result) end
		if Result == false then return false, 'transaction aborted' end

		local Accepted, Reason = self.Store:_ValidateData(Draft)

		if not Accepted then return false, Reason end

		local OldData = self._Data

		self._Data = Draft
		self._Dirty = true

		self:_RecordAudit('Transaction', nil, OldData, Draft)
		self.Changed:Fire('*', DeepCopy.Copy(Draft), DeepCopy.Copy(OldData))

		return true;
	end

	-- HasReceipt -> boolean
	-- Returns whether an idempotent receipt id is already persisted in this profile session.
	-- @param ReceiptId, string|number -> Unique purchase or transaction id.
	function Profile:HasReceipt(ReceiptId)
		return self._Receipts[tostring(ReceiptId)] ~= nil;
	end

	-- ProcessReceipt -> boolean, string?
	-- Atomically applies an idempotent purchase mutation and records its receipt id in the same UpdateAsync.
	-- @param ReceiptId, string|number -> Unique purchase or transaction id.
	-- @param Callback, function -> Server-side data mutation callback.
	function Profile:ProcessReceipt(ReceiptId, Callback)
		self:_AssertActive()

		return self.Store:_CommitReceipt(self, tostring(ReceiptId), Callback);
	end

	-- Save -> boolean, string?
	-- Persists current data while keeping the session lock alive.
	function Profile:Save()
		self:_AssertActive()

		return self.Store:_SaveProfile(self, false);
	end

	-- Release -> boolean, string?
	-- Saves current data and atomically releases this server's session ownership.
	function Profile:Release()
		if self._Released then return true end
		if self._LockLost then self._Released = true; self.Released:Fire('lock lost'); return false, 'session lock lost' end

		return self.Store:_SaveProfile(self, true);
	end
end

return Profile;
