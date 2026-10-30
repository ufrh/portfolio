local checks = 0
local function expect(value, message)
	checks += 1
	assert(value, message)
end

local function json(value)
	if type(value) == "string" then return string.format("%q", value) end
	if type(value) ~= "table" then return tostring(value) end
	local parts = {}
	if #value > 0 then
		for _, entry in value do table.insert(parts, json(entry)) end
		return "[" .. table.concat(parts, ",") .. "]"
	end
	for key, entry in value do table.insert(parts, json(tostring(key)) .. ":" .. json(entry)) end
	table.sort(parts)
	return "{" .. table.concat(parts, ",") .. "}"
end

local enumTypes = {}
local function enums(name, names)
	local result = {}
	for index, item in names do result[item] = {Name = item, Value = index, _enum = true} end
	function result:GetEnumItems()
		local items = {}
		for _, item in names do table.insert(items, self[item]) end
		return items
	end
	enumTypes[name] = result
	return result
end
local EnumMock = {
	HumanoidDisplayDistanceType = {None = "None"},
	HumanoidHealthDisplayType = {AlwaysOff = "AlwaysOff"},
	HumanoidStateType = {Jumping = "Jumping"},
	PositionAlignmentMode = {TwoAttachment = "TwoAttachment"},
	OrientationAlignmentMode = {OneAttachment = "OneAttachment"},
	UserInputType = {MouseButton1 = "MouseButton1", MouseMovement = "MouseMovement", Touch = "Touch"},
	AvatarAssetType = enums("AvatarAssetType", {"TShirt", "Hat", "Shirt", "Pants", "Head", "Face", "Gear", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "HairAccessory", "FaceAccessory", "NeckAccessory", "ShoulderAccessory", "FrontAccessory", "BackAccessory", "WaistAccessory", "IdleAnimation", "WalkAnimation", "RunAnimation", "JumpAnimation", "FallAnimation", "ClimbAnimation", "SwimAnimation", "EmoteAnimation", "TShirtAccessory", "ShirtAccessory", "PantsAccessory", "JacketAccessory", "SweaterAccessory", "ShortsAccessory", "LeftShoeAccessory", "RightShoeAccessory", "DressSkirtAccessory", "DynamicHead"}),
	AccessoryType = enums("AccessoryType", {"Hat", "Hair", "Face", "Neck", "Shoulder", "Front", "Back", "Waist", "TShirt", "Shirt", "Pants", "Jacket", "Sweater", "Shorts", "LeftShoe", "RightShoe", "DressSkirt"}),
	BundleType = enums("BundleType", {"BodyParts", "DynamicHead", "Shoes", "Animations"}),
	CatalogSortType = enums("CatalogSortType", {"Bestselling", "Relevance", "PriceLowToHigh", "PriceHighToLow", "MostFavorited", "RecentlyCreated"}),
	AvatarItemType = enums("AvatarItemType", {"Asset", "Bundle"})
}
for _, name in {"TShirtAccessory", "ShirtAccessory", "PantsAccessory", "JacketAccessory", "SweaterAccessory", "ShortsAccessory", "LeftShoeAccessory", "RightShoeAccessory", "DressSkirtAccessory"} do EnumMock.AvatarAssetType[name].Value = 65 end

local function deepCopy(value)
	if type(value) ~= "table" or value._enum then return value end
	local result = {}
	for key, entry in value do result[key] = deepCopy(entry) end
	return result
end
local DescriptionMock = {}
DescriptionMock.__index = DescriptionMock
local function newDescription()
	local self = setmetatable({_accessories = {}, _emotes = {}}, DescriptionMock)
	for _, name in {"Shirt", "Pants", "GraphicTShirt", "Face", "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "IdleAnimation", "WalkAnimation", "RunAnimation", "JumpAnimation", "FallAnimation", "ClimbAnimation", "SwimAnimation", "HeightScale", "WidthScale", "DepthScale", "HeadScale", "BodyTypeScale", "ProportionScale"} do self[name] = 0 end
	for _, name in {"HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor"} do self[name] = {R = .5, G = .6, B = .7} end
	return self
end
function DescriptionMock:Clone() return setmetatable(deepCopy(self), DescriptionMock) end
function DescriptionMock:Destroy() self.destroyed = true end
function DescriptionMock:GetAccessories() return deepCopy(self._accessories) end
function DescriptionMock:SetAccessories(value) self._accessories = deepCopy(value) end
function DescriptionMock:GetEmotes() return deepCopy(self._emotes) end
function DescriptionMock:SetEmotes(value) self._emotes = deepCopy(value) end
function DescriptionMock:AddEmote(name, id) self._emotes[name] = {id} end
function DescriptionMock:RemoveEmote(name) self._emotes[name] = nil end

local fixtures = {
	[100] = {AssetType = "Shirt"}, [101] = {AssetType = "Shirt"}, [102] = {AssetType = "Pants"},
	[200] = {AssetType = "Hat"}, [201] = {AssetType = "JacketAccessory"}, [300] = {AssetType = "EmoteAnimation"},
	[400] = {AssetType = "Gear"}, [500] = {ItemType = "Bundle", BundleType = "BodyParts"}
}
local jsonValues = {}
local HttpMock = {}
function HttpMock:JSONEncode(value)
	local encoded = json(value)
	jsonValues[encoded] = deepCopy(value)
	return encoded
end
local editor = {}
function editor:GetItemDetailsAsync(id, kind)
	if id == 999 then error("Catalog unavailable") end
	local value = table.clone(fixtures[id] or {AssetType = "Shirt"})
	value.Id = id
	value.ItemType = value.ItemType or kind.Name
	value.Name = string.rep("A", 90)
	value.CreatorName = string.rep("B", 40)
	value.Price = id
	return value
end
function editor:GetOutfitDetailsAsync(id) return {Name = "Platform outfit " .. id} end
local registry = {}
local ForgeMock = {}
function ForgeMock.Class(_, definition)
	local value = {Name = definition.Name, Client = {}, options = {}}
	function value:ConfigureEndpoint(name, options) self.options[name] = options end
	registry[definition.Name] = value
	return value
end
local function signal()
	return {Connect = function(_, callback) return {Disconnect = function() end, callback = callback} end}
end
local playerService = {PlayerRemoving = signal(), PlayerAdded = signal()}
function playerService:GetPlayers() return {} end
function playerService:GetHumanoidDescriptionFromUserIdAsync() return newDescription() end
function playerService:GetHumanoidDescriptionFromOutfitIdAsync(id)
	local value = newDescription()
	value.Pants = id
	return value
end
local sharedMock = {Catalog = "Catalog", Description = "Description", Character = "Character"}
local replicated = {}
function replicated:WaitForChild(name) return if name == "OutfitShared" then sharedMock else "FORGE" end
local services = {Players = playerService, ReplicatedStorage = replicated, AvatarEditorService = editor, HttpService = HttpMock,
	UserInputService = {}, RunService = {Heartbeat = signal()}, StarterGui = {}, ServerStorage = {},
	AssetService = {GetBundleDetailsAsync = function() return {Items = {{Type = "Asset", Id = 101}, {Type = "Asset", Id = 102}}} end}}
local modules = {FORGE = ForgeMock}
local function newInstance(name)
	if (name == "HumanoidDescription") then return newDescription() end
	local data = {ClassName = name, Name = name}
	local object
	object = setmetatable({}, {
		__index = data,
		__newindex = function(_, key, value)
			data[key] = value
			if (key == "Parent" and value) then
				value.children = value.children or {}
				value.children[data.Name] = object
			end
		end
	})
	data.IsA = function(_, class) return class == name end
	data.Destroy = function() data.destroyed = true end
	return object;
end
local rotation = {Rotation = 1}
local hrpPosition = {WorldCFrame = rotation, IsA = function(_, class) return class == "Attachment" end}
local terrain = {WaitForChild = function(_, name) assert(name == "HRPPosition"); return hrpPosition end}
local environment = setmetatable({
	Enum = EnumMock,
	CatalogSearchParams = {new = function() return {} end},
	Instance = {new = newInstance},
	Color3 = {new = function(r, g, b) return {R = r, G = g, B = b} end},
	Vector3 = {zero = {}},
	typeof = function(value) return if type(value) == "table" and value._enum then "EnumItem" else typeof(value) end,
	game = {GetService = function(_, name) assert(services[name], name); return services[name] end},
	workspace = {Terrain = terrain, WaitForChild = function(_, name)
		assert(name == "Rig")
		return {GetPivot = function() return 1 end, IsA = function(_, class) return class == "Model" end, FindFirstChildOfClass = function()
			return {GetAppliedDescription = function()
				local description = newDescription()
				description.Shirt = 77
				return description
			end}
		end}
	end},
	require = function(name) assert(modules[name], tostring(name)); return modules[name] end,
	warn = function() end,
}, {__index = getfenv()})
local function loadModule(name, source)
	local callback = assert(loadstring(source, name))
	environment.script = {Parent = {Catalog = "Catalog", Parent = {Config = "Config", Outfit = {View = "View", Gui = "Gui"}}}}
	setfenv(callback, environment)
	local result = callback()
	modules[name] = result
	return result
end
