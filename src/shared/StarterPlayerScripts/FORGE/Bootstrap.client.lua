-- Author -> lolokdev.
-- Last Edit -> September 15, 2026 11:56 PM CDT

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local Player = Players.LocalPlayer
local PlayerScripts = Player:WaitForChild('PlayerScripts')

local ForgeFolder = ReplicatedStorage:WaitForChild('FORGE')
local FORGE = require(ForgeFolder)

local Roots = {}
local Controllers = PlayerScripts:FindFirstChild(FORGE.Config.Paths.ClientControllers)
if Controllers then table.insert(Roots, Controllers) end

FORGE.Start({Roots = Roots;})

if FORGE.UI then
	FORGE.UI.Start()
end
