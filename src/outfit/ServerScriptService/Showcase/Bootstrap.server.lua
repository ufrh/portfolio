local Players = game:GetService("Players")

Players.CharacterAutoLoads = false

local catalog = game:GetService("StarterGui"):FindFirstChild("Catalog")
if (catalog) then catalog.ResetOnSpawn = false end
