local queue = {}
environment.task = {spawn = function(callback) table.insert(queue, callback) end}
environment.Vector2 = {zero = {}}
modules.View = {}
playerService.LocalPlayer = first
local function flush()
	while #queue > 0 do table.remove(queue, 1)() end
end
