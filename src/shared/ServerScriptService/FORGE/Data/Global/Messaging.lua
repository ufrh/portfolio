-- Author -> lolokdev.
-- Last Edit -> September 14, 2026 4:25 PM CDT

local MessagingService = game:GetService('MessagingService')

local ReplicatedStorage = game:GetService('ReplicatedStorage')

local Signal = require(ReplicatedStorage.FORGE.Core.Signal)

local Messaging = {} do
	Messaging.__index = Messaging
	Messaging.ClassName = 'Messaging'

	-- onMessage -> nil
	-- Routes a MessagingService payload into the local invalidation signal.
	-- @param Self, Messaging -> Messaging instance receiving the payload.
	-- @param Message, table -> Roblox MessagingService wrapper.
	local function onMessage(Self, Message)
		if type(Message.Data) ~= 'table' then return end

		Self.Changed:Fire(Message.Data.key, Message.Data.stamp)
	end

	-- new -> Messaging
	-- Creates a lightweight cross-server invalidation bus.
	-- @param Topic, string -> MessagingService topic.
	function Messaging.new(Topic: string)
		local this = setmetatable({}, Messaging)

		this.Topic = Topic
		this.Changed = Signal.new()
		this.Subscription = nil

		return this;
	end

	-- Start -> boolean, string?
	-- Subscribes to cross-server invalidation events.
	function Messaging:Start()
		if self.Subscription then return true end

		-- receive -> nil
		-- Forwards one Roblox message into this bus.
		-- @param Message, table -> MessagingService message wrapper.
		local function receive(Message)
			onMessage(self, Message)
		end

		local Success, Result = pcall(MessagingService.SubscribeAsync, MessagingService, self.Topic, receive)

		if not Success then return false, tostring(Result) end

		self.Subscription = Result

		return true;
	end

	-- Publish -> boolean, string?
	-- Publishes a tiny invalidation notice without shipping the full persisted payload.
	-- @param Key, string -> Global data key that changed.
	function Messaging:Publish(Key: string)
		local Payload = {key = Key; stamp = os.time();}
		local Success, Result = pcall(MessagingService.PublishAsync, MessagingService, self.Topic, Payload)

		if not Success then return false, tostring(Result) end

		return true;
	end

	-- Destroy -> nil
	-- Stops cross-server invalidation and destroys local listeners.
	function Messaging:Destroy()
		if self.Subscription then self.Subscription:Disconnect(); self.Subscription = nil end

		self.Changed:Destroy()
	end
end

return Messaging;
