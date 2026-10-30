-- Author -> lolokdev.
-- Last Edit -> September 13, 2026 6:43 PM CDT

local Autosave = {} do
	Autosave.__index = Autosave
	Autosave.ClassName = 'Autosave'

	-- runLoop -> nil
	-- Drives staggered profile saves and session-heartbeat refreshes.
	-- @param Self, Autosave -> Active autosave runtime.
	local function runLoop(Self)
		while Self.Running do
			local Now = os.clock()

			for _, Profile in pairs(Self.Store._ProfilesByUserId) do
				if not Profile._Released and not Profile._LockLost and Now >= Profile._NextAutosave then
					Self.Store:_SaveProfile(Profile, false)
					Self:Schedule(Profile)
				end
			end

			task.wait(1)
		end
	end

	-- new -> Autosave
	-- Creates an autosave scheduler for one VAULT store.
	-- @param Store, table -> Owning store.
	function Autosave.new(Store)
		local this = setmetatable({}, Autosave)

		this.Store = Store
		this.Running = false

		return this;
	end

	-- Schedule -> nil
	-- Assigns the next staggered autosave deadline for one profile.
	-- @param Profile, Profile -> Loaded profile.
	function Autosave:Schedule(Profile)
		local Base = self.Store.Config.AutosaveInterval
		local Jitter = self.Store.Config.AutosaveJitter
		local Offset = Jitter > 0 and math.random() * Jitter or 0

		Profile._NextAutosave = os.clock() + Base + Offset
	end

	-- Start -> nil
	-- Starts the scheduler once.
	function Autosave:Start()
		if self.Running then return end

		self.Running = true

		task.spawn(runLoop, self)
	end

	-- Stop -> nil
	-- Stops future autosave scans.
	function Autosave:Stop()
		self.Running = false
	end
end

return Autosave;
