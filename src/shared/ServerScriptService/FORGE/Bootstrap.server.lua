local ReplicatedStorage, ServerScriptService =
	game:GetService('ReplicatedStorage'), game:GetService('ServerScriptService')

local ForgeFolder = ReplicatedStorage:WaitForChild('FORGE')
local NetworkRoot = script.Parent:WaitForChild('Network')
local ServerBridge = require(NetworkRoot:WaitForChild('ServerBridge'))

local Bridge = ServerBridge.new()
Bridge:Start()

local Loaded, FORGE = xpcall(function()
	return require(ForgeFolder)
end, debug.traceback)

if not Loaded then
	warn('[FORGE] Failed to load the server runtime:\n' .. tostring(FORGE))
	error(FORGE)
end

local Roots = {}
local Services = ServerScriptService:FindFirstChild(FORGE.Config.Paths.ServerServices)
local Closing = false

if Services then
	table.insert(Roots, Services)
end

local Started, StartError = xpcall(function()
	FORGE.Start({Roots = Roots; Bridge = Bridge;})
end, debug.traceback)

if not Started then
	warn('[FORGE] Server startup failed:\n' .. tostring(StartError))
	error(StartError)
end

local function Close()
	if Closing then return end
	Closing = true
	FORGE.Destroy()
end

game:BindToClose(Close)
