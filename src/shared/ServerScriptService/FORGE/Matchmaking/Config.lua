-- Author -> lolokdev.
-- Last Edit -> September 14, 2026 9:30 PM CDT

local Config = {
	Namespace = 'FORGE_MM_V1',

	TicketTTL = 180,
	AssignmentTTL = 90,
	MatchTTL = 300,

	QueueInvisibility = 5,
	PollInterval = .8,
	AssignmentPollInterval = 1.5,
	ReadBatch = 16,

	LeaseTTL = 15,
	LeaseHeartbeat = 5,

	RetryAttempts = 4,
	RetryDelay = .2,
	RetryMaxDelay = 2,

	TeleportAttempts = 3,
	TeleportRetryDelay = 2,

	MaxPartySize = 12,
	MaxMetadataDepth = 8,
	MaxMetadataNodes = 600,
	MaxStringLength = 2048,
	MaxMetadataBytes = 12000,

	Debug = false,

	Test = {
		EnabledInStudio = true,
		EnablePublishedDiagnostics = true,
		AllowCreatorInLive = true,
		AuthorizedUserIds = {},
		AllowLive = false,

		InitialPseudoPlayers = 24,
		MaxPseudoPlayers = 500,
		UpdateInterval = .35,
		StepInterval = .1,
		AutoSpawnRate = 4,
		RecentMatches = 10,

		DefaultProfile = '4v4',
		Seed = 1337,
		TeleportFailureRate = .02;
	};
}

return table.freeze(Config);
