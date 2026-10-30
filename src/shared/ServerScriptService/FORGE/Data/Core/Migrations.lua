-- Author -> lolokdev.
-- Last Edit -> September 13, 2026 6:43 PM CDT

local DeepCopy = require(script.Parent.Parent.Util.DeepCopy)

local Migrations = {}

-- Apply -> table, boolean
-- Applies ordered schema migrations from the stored version to the current version.
-- @param Data, table -> Decoded profile data.
-- @param StoredVersion, number -> Version currently stored.
-- @param CurrentVersion, number -> Store schema version.
-- @param Steps, table -> Migration functions keyed by destination version.
function Migrations.Apply(Data, StoredVersion: number, CurrentVersion: number, Steps)
	if StoredVersion > CurrentVersion then error('VAULT cannot load data from a newer schema version.') end

	local Working = DeepCopy.Copy(Data)
	local Changed = false

	for Version = StoredVersion + 1, CurrentVersion do
		local Migration = Steps and Steps[Version]

		if Migration then
			local Success, Result = pcall(Migration, Working)

			if not Success then error('VAULT migration to version ' .. tostring(Version) .. ' failed: ' .. tostring(Result)) end
			if Result ~= nil then Working = Result end

			Changed = true
		end
	end

	return Working, Changed;
end

return Migrations;
