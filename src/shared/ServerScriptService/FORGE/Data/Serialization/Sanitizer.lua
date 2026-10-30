-- Author -> lolokdev.
-- Last Edit -> September 13, 2026 6:43 PM CDT

local HttpService = game:GetService('HttpService')

local Sanitizer = {}

-- EstimateBytes -> number
-- Estimates the JSON payload size that Roblox will persist for an encoded value.
-- @param Value, any -> Datastore-safe encoded value.
function Sanitizer.EstimateBytes(Value)
	local Success, Result = pcall(HttpService.JSONEncode, HttpService, Value)

	if not Success then error('VAULT could not JSON encode serialized data: ' .. tostring(Result)) end

	return #Result;
end

-- AssertSize -> number
-- Rejects encoded payloads that exceed the configured safety ceiling.
-- @param Value, any -> Datastore-safe encoded value.
-- @param Maximum, number -> Maximum accepted encoded byte count.
function Sanitizer.AssertSize(Value, Maximum: number)
	local Bytes = Sanitizer.EstimateBytes(Value)

	if Bytes > Maximum then error(string.format('VAULT payload is too large: %d bytes exceeds %d.', Bytes, Maximum)) end

	return Bytes;
end

return Sanitizer;
