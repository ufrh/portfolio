-- Author -> lolokdev.
-- Last Edit -> September 14, 2026 4:25 PM CDT

local HttpService = game:GetService('HttpService')
local MemoryStoreService = game:GetService('MemoryStoreService')
local MessagingService = game:GetService('MessagingService')
local RunService = game:GetService('RunService')
local TeleportService = game:GetService('TeleportService')

local ServiceProbe = {} do
	-- result -> table
	-- Creates one standardized external-service probe result.
	-- @param Name, string -> Probe name.
	-- @param Passed, boolean -> Whether the probe completed successfully.
	-- @param Status, string -> PASS, FAIL or UNAVAILABLE.
	-- @param Message, string -> Diagnostic detail.
	local function result(Name: string, Passed: boolean, Status: string, Message: string)
		return {Name = Name; Passed = Passed; Status = Status; Message = Message;};
	end

	-- probeHashMap -> table
	-- Verifies MemoryStoreHashMap set/get/remove behavior using a unique disposable key.
	local function probeHashMap()
		local Map = MemoryStoreService:GetHashMap('__FORGE_MM_PROBE_HASH')
		local Key = HttpService:GenerateGUID(false)
		local Token = HttpService:GenerateGUID(false)

		-- operation -> nil
		-- Executes the disposable HashMap lifecycle probe.
		local function operation()
			Map:SetAsync(Key, {Token = Token;}, 20)
			local Value = Map:GetAsync(Key)
			Map:RemoveAsync(Key)
			assert(type(Value) == 'table' and Value.Token == Token, 'MemoryStoreHashMap returned unexpected data')
		end
		local Success, Reason = pcall(operation)
		return result('MemoryStore HashMap', Success, Success and 'PASS' or 'UNAVAILABLE', Success and 'Set/Get/Remove succeeded.' or tostring(Reason));
	end

	-- probeQueue -> table
	-- Verifies MemoryStoreQueue add/read/remove receipt behavior using a unique disposable queue.
	local function probeQueue()
		local Queue = MemoryStoreService:GetQueue('__FORGE_MM_PROBE_QUEUE_' .. HttpService:GenerateGUID(false), 2)
		local Token = HttpService:GenerateGUID(false)

		-- operation -> nil
		-- Executes the disposable MemoryStoreQueue receipt probe.
		local function operation()
			Queue:AddAsync(Token, 20, 0)
			local Items, Receipt = Queue:ReadAsync(1, true, 1)
			assert(type(Items) == 'table' and Items[1] == Token and type(Receipt) == 'string', 'MemoryStoreQueue returned unexpected data')
			Queue:RemoveAsync(Receipt)
		end
		local Success, Reason = pcall(operation)
		return result('MemoryStore Queue', Success, Success and 'PASS' or 'UNAVAILABLE', Success and 'Add/Read/Remove succeeded.' or tostring(Reason));
	end

	-- probeMessaging -> table
	-- Verifies one MessagingService publish can reach a matching temporary subscription.
	local function probeMessaging()
		local Topic = '__FORGE_MM_PROBE_' .. string.gsub(HttpService:GenerateGUID(false), '-', '')
		local Token = HttpService:GenerateGUID(false)
		local Received = false

		-- onMessage -> nil
		-- Marks the probe complete only when the expected token returns.
		-- @param Message, table -> MessagingService envelope.
		local function onMessage(Message)
			if type(Message) == 'table' and type(Message.Data) == 'table' and Message.Data.Token == Token then Received = true end
		end

		local Subscription = nil

		-- operation -> nil
		-- Executes the temporary MessagingService round-trip probe.
		local function operation()
			Subscription = MessagingService:SubscribeAsync(Topic, onMessage)
			MessagingService:PublishAsync(Topic, {Token = Token;})
			local Started = os.clock()
			while not Received and os.clock() - Started < 2 do task.wait(.05) end
			if Subscription then Subscription:Disconnect() end
			assert(Received, 'published message was not observed before timeout')
		end
		local Success, Reason = pcall(operation)
		if Subscription then pcall(Subscription.Disconnect, Subscription) end
		return result('MessagingService', Success, Success and 'PASS' or 'UNAVAILABLE', Success and 'Publish/Subscribe succeeded.' or tostring(Reason));
	end

	-- probeReserveServer -> table
	-- Verifies reserved-server allocation when Roblox permits it in the current environment.
	local function probeReserveServer()
		if game.PlaceId <= 0 then return result('ReserveServer', false, 'UNAVAILABLE', 'Publish the experience before probing reserved servers.') end

		-- operation -> nil
		-- Executes one reserved-server allocation probe without teleporting a player.
		local function operation()
			local AccessCode, PrivateServerId = TeleportService:ReserveServerAsync(game.PlaceId)
			assert(type(AccessCode) == 'string' and AccessCode ~= '', 'ReserveServerAsync returned no access code')
			assert(type(PrivateServerId) == 'string', 'ReserveServerAsync returned no private server id')
		end
		local Success, Reason = pcall(operation)
		local Status = Success and 'PASS' or (RunService:IsStudio() and 'UNAVAILABLE' or 'FAIL')
		return result('ReserveServer', Success, Status, Success and 'Reservation succeeded.' or tostring(Reason));
	end

	-- Run -> table
	-- Runs opt-in Roblox service integration probes without teleporting any real player.
	function ServiceProbe.Run()
		local Results = {probeHashMap(), probeQueue(), probeMessaging(), probeReserveServer();}
		local Passed = 0
		local Failed = 0
		local Unavailable = 0
		for _, Item in ipairs(Results) do if Item.Status == 'PASS' then Passed += 1 elseif Item.Status == 'UNAVAILABLE' then Unavailable += 1 else Failed += 1 end end
		return {Passed = Passed; Failed = Failed; Unavailable = Unavailable; Total = #Results; Results = Results;};
	end
end

return ServiceProbe;
