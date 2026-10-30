-- Author -> lolokdev.
-- Last Edit -> September 14, 2026 4:25 PM CDT

local Config = {
	DataStore = {
		Scope = 'production',
		KeyPrefix = 'Player_',

		AutosaveInterval = 60,
		AutosaveJitter = 10,

		SaveAttempts = 6,
		BaseRetryDelay = .75,
		MaxRetryDelay = 8,
		BudgetWaitTimeout = 30,

		SessionLockTimeout = 120,
		SessionLockLoadTimeout = 30,
		SessionLockPollInterval = 4,

		ShutdownTimeout = 25,

		KickOnLoadFailure = true,
		KickOnLockLoss = true,

		StrictSchema = true,
		PruneUnknown = true,
		RecoverCorruptData = false,

		MaxDepth = 32,
		MaxNodes = 20000,
		MaxStringLength = 200000,
		MaxEncodedBytes = 3500000,

		MaxReceiptIds = 250,
		AuditTrailSize = 100,

		AllowProductionWipes = false;
	},

	Global = {
		CacheTTL = 5,
		MessagingTopicPrefix = 'FORGE_DATA_GLOBAL_';
	},

	Leaderboard = {
		CacheTTL = 10,
		PageSize = 100;
	};
}

return table.freeze(Config);
