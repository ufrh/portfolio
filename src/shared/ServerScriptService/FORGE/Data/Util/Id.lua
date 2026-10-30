-- Author -> lolokdev.
-- Last Edit -> September 13, 2026 6:43 PM CDT

local HttpService = game:GetService('HttpService')

local Id = {}

-- Guid -> string
-- Generates a compact GUID suitable for session tokens and internal identifiers.
function Id.Guid()
	return string.gsub(HttpService:GenerateGUID(false), '%-', '');
end

-- PlayerKey -> string
-- Builds the canonical persistent player key.
-- @param Prefix, string -> Store key prefix.
-- @param UserId, number -> Roblox user id.
function Id.PlayerKey(Prefix: string, UserId: number)
	return Prefix .. tostring(UserId);
end

-- SafeName -> string
-- Restricts arbitrary names to datastore-safe alphanumeric separators.
-- @param Value, string -> Name being normalized.
function Id.SafeName(Value: string)
	local Result = string.gsub(Value, '[^%w_%-]', '_')

	if Result == '' then Result = 'unnamed' end

	return string.sub(Result, 1, 50);
end

return Id;
