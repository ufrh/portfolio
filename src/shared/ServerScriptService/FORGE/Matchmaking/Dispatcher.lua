-- Author -> lolokdev.
-- Last Edit -> September 14, 2026 4:25 PM CDT

local MessagingService = game:GetService('MessagingService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local Signal = require(ReplicatedStorage.FORGE.Core.Signal)

local Dispatcher = {} do
	Dispatcher.__index = Dispatcher
	Dispatcher.ClassName = 'MatchmakingDispatcher'

	-- new -> MatchmakingDispatcher
	-- Creates the cross-server assignment notification transport with polling-safe fallback behavior.
	-- @param Config, table -> Matchmaking configuration.
	function Dispatcher.new(Config)
		local this = setmetatable({}, Dispatcher)

		this.Config = Config
		this.Topic = Config.Namespace .. ':assignments'
		this.Started = false
		this.Subscription = nil
		this.Received = Signal.new()

		return this;
	end

	-- _OnMessage -> nil
	-- Converts one MessagingService envelope into a dispatcher signal.
	-- @param Message, table -> MessagingService message envelope.
	function Dispatcher:_OnMessage(Message)
		if type(Message) ~= 'table' or type(Message.Data) ~= 'table' then return end
		self.Received:Fire(Message.Data)
	end

	-- Start -> nil
	-- Starts cross-server assignment notifications; queue polling remains a fallback if subscription fails.
	function Dispatcher:Start()
		if self.Started then return end
		self.Started = true

		local Success, Result = pcall(MessagingService.SubscribeAsync, MessagingService, self.Topic, function(Message) self:_OnMessage(Message) end)
		if Success then self.Subscription = Result elseif self.Config.Debug then warn('[FORGE Matchmaking] Messaging subscription unavailable: ' .. tostring(Result)) end
	end

	-- Publish -> boolean, string?
	-- Publishes a lightweight assignment hint without exposing reserved-server access codes.
	-- @param Payload, table -> Queue and ticket identifiers.
	function Dispatcher:Publish(Payload)
		local Success, Result = pcall(MessagingService.PublishAsync, MessagingService, self.Topic, Payload)
		if not Success and self.Config.Debug then warn('[FORGE Matchmaking] Assignment publish failed: ' .. tostring(Result)) end
		return Success, Success and nil or tostring(Result);
	end

	-- Stop -> nil
	-- Stops assignment notifications while preserving the dispatcher object.
	function Dispatcher:Stop()
		if self.Subscription then self.Subscription:Disconnect(); self.Subscription = nil end
		self.Started = false
	end

	-- Destroy -> nil
	-- Stops messaging and destroys dispatcher signals.
	function Dispatcher:Destroy()
		self:Stop()
		self.Received:Destroy()
	end
end

return Dispatcher;
