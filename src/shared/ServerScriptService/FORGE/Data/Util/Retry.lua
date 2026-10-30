-- Author -> lolokdev.
-- Last Edit -> September 14, 2026 7:26 PM CDT

local DataStoreService = game:GetService('DataStoreService')

local Retry = {}

-- getBudget -> number?
-- Safely reads the current Roblox request budget without allowing Studio/API availability to crash the retry layer.
-- @param RequestType, Enum.DataStoreRequestType -> Request budget category.
local function getBudget(RequestType)
	local Success, Result = pcall(DataStoreService.GetRequestBudgetForRequestType, DataStoreService, RequestType)
	if not Success then return nil end
	return tonumber(Result);
end

-- waitForBudget -> boolean
-- Waits for one datastore request token while respecting a hard timeout.
-- @param RequestType, Enum.DataStoreRequestType? -> Roblox datastore request budget category.
-- @param Timeout, number -> Maximum wait duration in seconds.
local function waitForBudget(RequestType, Timeout: number)
	if not RequestType then return true end

	local Started = os.clock()
	local Limit = math.max(tonumber(Timeout) or 0, 0)

	while true do
		local Budget = getBudget(RequestType)
		if Budget == nil or Budget >= 1 then return true end
		if os.clock() - Started >= Limit then return false end
		task.wait(.1)
	end
end

-- Call -> boolean, ...any
-- Runs one datastore operation with budget awareness, protected execution and exponential backoff.
-- @param RequestType, Enum.DataStoreRequestType? -> Request budget category.
-- @param Attempts, number -> Maximum operation attempts.
-- @param BaseDelay, number -> Initial retry delay.
-- @param MaxDelay, number -> Maximum retry delay.
-- @param BudgetTimeout, number -> Maximum wait for each budget token.
-- @param Callback, function -> Operation callback.
function Retry.Call(RequestType, Attempts: number, BaseDelay: number, MaxDelay: number, BudgetTimeout: number, Callback)
	assert(type(Callback) == 'function', 'Retry callback must be a function.')

	local AttemptCount = math.max(math.floor(tonumber(Attempts) or 1), 1)
	local InitialDelay = math.max(tonumber(BaseDelay) or 0, 0)
	local DelayLimit = math.max(tonumber(MaxDelay) or InitialDelay, InitialDelay)
	local LastError = 'operation failed'

	for Attempt = 1, AttemptCount do
		if not waitForBudget(RequestType, BudgetTimeout) then
			LastError = 'datastore request budget timeout'
		else
			local Packed = table.pack(pcall(Callback))
			if Packed[1] then return true, table.unpack(Packed, 2, Packed.n) end
			LastError = tostring(Packed[2])
		end

		if Attempt < AttemptCount then
			local Delay = math.min(InitialDelay * (2 ^ (Attempt - 1)), DelayLimit)
			local Jitter = Delay > 0 and math.random() * math.min(Delay * .2, .5) or 0
			if Delay + Jitter > 0 then task.wait(Delay + Jitter) end
		end
	end

	return false, LastError;
end

-- Run -> boolean, ...any
-- Preserves compatibility with older FORGE.Data builds that referenced Retry.Run.
-- @param RequestType, Enum.DataStoreRequestType? -> Request budget category.
-- @param Attempts, number -> Maximum operation attempts.
-- @param BaseDelay, number -> Initial retry delay.
-- @param MaxDelay, number -> Maximum retry delay.
-- @param BudgetTimeout, number -> Maximum wait for each budget token.
-- @param Callback, function -> Operation callback.
function Retry.Run(RequestType, Attempts: number, BaseDelay: number, MaxDelay: number, BudgetTimeout: number, Callback)
	return Retry.Call(RequestType, Attempts, BaseDelay, MaxDelay, BudgetTimeout, Callback);
end

return Retry;
