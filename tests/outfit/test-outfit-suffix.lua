local Catalog, Description = modules.Catalog, modules.Description
local service = registry.OutfitService
local function player(id)
	local humanoid = {Health = 100, applied = newDescription()}
	function humanoid:GetAppliedDescription() return self.applied:Clone() end
	function humanoid:ApplyDescriptionAsync(description)
		if self.fail then self.fail = false; error("Apply failed") end
		if self.reenter then self.reenter(); self.reenter = nil end
		self.applied = description:Clone()
	end
	function humanoid:SetStateEnabled(state, enabled)
		self.states = self.states or {}
		self.states[state] = enabled
	end
	function humanoid:ChangeState(state) self.state = state end
	function humanoid:Move(value) self.moveDirection = value end
	function humanoid:IsA() return false end
	local root = {Name = "HumanoidRootPart", children = {}, IsA = function(_, class) return class == "BasePart" end}
	function root:FindFirstChild(name) return self.children[name] end
	local billboard = {Enabled = true, IsA = function(_, class) return class == "BillboardGui" end}
	local character = {Humanoid = humanoid, HumanoidRootPart = root, DescendantAdded = signal(), billboard = billboard}
	function character:FindFirstChildOfClass() return humanoid end
	function character:FindFirstChild(name) return self[name] end
	function character:WaitForChild(name) return self[name] end
	function character:GetDescendants() return {root, humanoid, billboard} end
	function character:PivotTo(pivot) self.pivot = pivot end
	return {UserId = id, Parent = true, Character = character, HasAppearanceLoaded = function() return true end}, humanoid
end
local first, humanoid = player(1)
humanoid.applied.Shirt = 81
humanoid.applied.Pants = 82
humanoid.applied.Face = 83
humanoid.applied.Head = 84
humanoid.applied.IdleAnimation = 85
humanoid.applied:SetAccessories({{AssetId = 86, AccessoryType = {Name = "Hair"}}})
humanoid.applied:SetEmotes({Wave = {87}})
local second = player(2)
local function call(owner, name, ...)
	local valid = modules.Validator.ValidateArguments(table.pack(...), service.options[name])
	if not valid then return {ok = false, message = "Invalid argument"} end
	return service.Client[name](owner, ...)
end
local function avatar(state) return jsonValues[state.avatarJSON] end
service:Init()
expect(call(first, "getState").revision == 0, "initial avatar revision")
local baseline = avatar(call(first, "getState"))
expect(baseline.properties.Shirt == 0 and baseline.properties.Pants == 0, "baseline removes classic clothing")
expect(baseline.properties.Face == 0 and baseline.properties.Head == 0, "baseline removes face and body packages")
expect(baseline.properties.IdleAnimation == 0, "baseline removes animations")
expect(#baseline.accessories == 0 and next(baseline.emotes) == nil, "baseline removes accessories and emotes")
expect(humanoid.applied.Shirt == 0 and #humanoid.applied:GetAccessories(true) == 0, "bare baseline applied to character")
service:Start()
service.playerConnections[first] = {}
service:prepareCharacter(first, first.Character)
local firstRoot = first.Character.HumanoidRootPart
expect(not firstRoot.Anchored and humanoid.WalkSpeed == 0, "root stays unanchored and walking is disabled")
expect(firstRoot:FindFirstChild("OutfitPosition").Attachment1 == hrpPosition, "AlignPosition targets Terrain.HRPPosition")
expect(firstRoot:FindFirstChild("OutfitOrientation").Attachment0 == firstRoot:FindFirstChild("OutfitRootAttachment"), "AlignOrientation drives root attachment")
expect(humanoid.JumpPower == 0 and humanoid.JumpHeight == 0 and humanoid.states.Jumping == false, "both jump modes disabled")
expect(humanoid.states.Freefall == false and humanoid.states.FallingDown == false, "falling states disabled")
expect(humanoid.state == "RunningNoPhysics", "mannequin uses stable non-falling state")
expect(humanoid.AutoRotate == false and humanoid.Jump == false, "turning and active jump disabled")
expect(humanoid.DisplayDistanceType == "None" and humanoid.HealthDisplayType == "AlwaysOff", "overhead name and health hidden")
expect(humanoid.NameDisplayDistance == 0 and humanoid.HealthDisplayDistance == 0, "overhead distances suppressed")
expect(not first.Character.billboard.Enabled, "custom character billboard hidden")
expect(first.Character.HumanoidRootPart.CanCollide == false, "character collisions disabled")
firstRoot.children.OutfitPosition = nil
service.heartbeat.callback()
expect(firstRoot:FindFirstChild("OutfitPosition") ~= nil and not firstRoot.Anchored, "missing position constraint is restored")
local replacementRoot = {Name = "HumanoidRootPart", IsA = function(_, class) return class == "BasePart" end}
modules.Character.preparePart(replacementRoot)
expect(not replacementRoot.Anchored, "replacement root remains physics-driven")
local fresh, freshHumanoid = player(3)
local loaded = fresh.Character
fresh.Character = nil
fresh.CharacterAdded, fresh.CharacterAppearanceLoaded = signal(), signal()
function fresh:LoadCharacterAsync()
	self.loads = (self.loads or 0) + 1
	self.Character = loaded
	loaded.HumanoidRootPart.Anchored = true
end
expect(not call(fresh, "getState").ok, "loading character returns retryable failure")
environment.task = {spawn = function(callback) callback() end}
service.added.callback(fresh)
expect(fresh.loads == 1 and fresh.Character == loaded, "player character is explicitly spawned once")
expect(not loaded.HumanoidRootPart.Anchored and loaded.HumanoidRootPart:FindFirstChild("OutfitPosition"), "LoadCharacter completion adds position constraint")
service.playerConnections[fresh][1].callback(loaded)
expect(not loaded.HumanoidRootPart.Anchored and freshHumanoid.WalkSpeed == 0, "spawned character is immediately constrained")
expect(call(fresh, "getState").ok, "character becomes available after spawning")
environment.task = nil
service:Stop()
expect(not call(first, "toggleItem", -1, "Asset").ok, "negative id rejected")
expect(not call(first, "toggleItem", 0/0, "Asset").ok, "NaN rejected")
expect(not call(first, "toggleItem", 100, "Fake").ok, "invalid kind rejected")
expect(not call(first, "toggleItem", 100, "Asset", "extra").ok, "extra arguments rejected")
expect(not call(first, "saveOutfit", string.char(255)).ok, "invalid UTF-8 name cannot corrupt session")
expect(Catalog.text("abc😭def", 5) == "abc", "truncation preserves UTF-8 boundary")
expect(Catalog.text("abc😭def", 7) == "abc😭", "complete Unicode character retained")
local state = call(first, "toggleItem", 100, "Asset")
expect(state.ok and avatar(state).properties.Shirt == 100, "shirt applied")
state = call(first, "toggleItem", 101, "Asset")
expect(state.ok and avatar(state).properties.Shirt == 101, "shirt replaced")
state = call(first, "toggleItem", 101, "Asset")
expect(state.ok and avatar(state).properties.Shirt == 0, "toggle removes shirt")
state = call(first, "toggleItem", 200, "Asset")
expect(state.ok and #avatar(state).accessories == 1, "accessory applied")
state = call(first, "removeItem", 200)
expect(state.ok and #avatar(state).accessories == 0, "accessory removed")
state = call(first, "toggleItem", 201, "Asset")
expect(state.ok and avatar(state).accessories[1].IsLayered, "layered accessory configured")
expect(not call(first, "toggleItem", 400, "Asset").ok, "gear rejected without changing avatar")
state = call(first, "toggleItem", 500, "Bundle")
expect(state.ok and avatar(state).properties.Shirt == 101 and avatar(state).properties.Pants == 102, "bundle assets applied")
local revision = state.revision
humanoid.fail = true
expect(not call(first, "toggleItem", 100, "Asset").ok, "failed character apply reported")
state = call(first, "getState")
expect(state.revision == revision and humanoid.applied.Shirt == 101, "failed apply rolls back appearance and session")
local originalDetails = editor.GetItemDetailsAsync
editor.GetItemDetailsAsync = function(self, ...)
	expect(not call(first, "reset").ok, "concurrent mutation rejected")
	return originalDetails(self, ...)
end
expect(call(first, "toggleItem", 888, "Asset").ok, "outer lookup completed")
editor.GetItemDetailsAsync = originalDetails
expect(call(first, "toggleItem", 100, "Asset").ok, "outer change completed")
expect(call(first, "saveOutfit", "Test outfit").ok, "outfit saved")
state = call(first, "reset")
expect(state.ok and avatar(state).properties.Shirt == 0, "bare creator baseline reset")
state = call(first, "applyOutfit", 1, "SavedOutfit")
expect(state.ok and avatar(state).properties.Shirt == 100, "saved outfit restored")
expect(not call(second, "applyOutfit", 1, "SavedOutfit").ok, "saved outfit belongs to owner")
expect(call(first, "deleteOutfit", 1).ok, "saved outfit deleted")
expect(not call(first, "applyOutfit", 1, "SavedOutfit").ok, "deleted outfit cannot be applied")
expect(not call(first, "saveOutfit", "   ").ok, "blank name rejected")
state = call(first, "applyOutfit", 1234, "RobloxOutfit")
expect(state.ok and avatar(state).properties.Pants == 1234, "platform outfit applied")
expect(not call(first, "toggleItem", 999, "Asset").ok, "catalog failure handled")
expect(call(first, "toggleFavorite", 100, "Asset").ok, "favorite added")
state = call(first, "toggleFavorite", 100, "Asset")
expect(#jsonValues[state.favoritesJSON] == 0, "favorite toggled off")
for id = 10000, 10023 do expect(call(first, "toggleFavorite", id, "Asset").ok, "favorite within cap") end
expect(not call(first, "toggleFavorite", 10024, "Asset").ok, "favorite cap enforced")
for id = 10000, 10024 do expect(call(first, "toggleItem", id, "Asset").ok, "recent item applied") end
state = call(first, "getState")
expect(#jsonValues[state.recentsJSON] == 20, "recents bounded")
expect(jsonValues[state.recentsJSON][1].id == 10024, "recents newest first")
local copy = Description.unpack(avatar(state))
expect(copy.Shirt == 10024, "description survives round trip")
Description.apply(copy, {id = 300, assetType = "EmoteAnimation"})
expect(copy:GetEmotes().Emote300[1] == 300, "emote added")
Description.remove(copy, 300)
expect(copy:GetEmotes().Emote300 == nil, "emote removed")
for _, category in {"Clothing", "Accessories", "Body", "Animations"} do
	for index in Catalog.subcategories[category] do
		local params = Catalog.searchParams(category, index, "test", 1)
		expect(#params.AssetTypes + #params.BundleTypes > 0, category .. " has valid filters")
		expect(({[10] = true, [28] = true, [30] = true, [60] = true, [120] = true})[params.Limit] and params.SearchKeyword == "test", "Roblox-supported search limit")
	end
end
expect(Catalog.categoryFor("Shirt") == "Clothing", "classic clothing classification")
expect(Catalog.categoryFor("HairAccessory") == "Body", "hair classification")
expect(Catalog.categoryFor(nil, "Animations") == "Animations", "bundle classification")
expect(#json(state) < 32768, "full library stays within transport limit")
for index = 1, 20 do expect(call(first, "saveOutfit", string.rep("N", 40)).ok, "outfit within cap") end
expect(not call(first, "saveOutfit", "Overflow").ok, "outfit cap enforced")
for id = 20000, 20019 do fixtures[id] = {AssetType = "Hat"}; expect(call(first, "toggleItem", id, "Asset").ok, "accessory within cap") end
expect(not call(first, "toggleItem", 201, "Asset").ok, "accessory cap enforced")
state = call(first, "getState")
local packed = modules.Serializer.EncodePacked(table.pack(state))
expect(#packed < 32768, "actual FORGE encoding stays within packet limit")
for _, value in {state.avatarJSON, state.equippedJSON, state.favoritesJSON, state.recentsJSON, state.outfitsJSON} do
	expect(#value <= 16384, "response section stays within string limit")
end
print("Worst-case tested FORGE packet: " .. #packed .. " bytes")
print("PASS: " .. checks .. " behavior checks; full response " .. #json(state) .. " bytes")
