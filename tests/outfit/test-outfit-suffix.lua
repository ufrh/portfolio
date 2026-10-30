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
	return {UserId = id, Parent = true}, humanoid
end
local first, humanoid = player(1)
local second = player(2)
local function call(owner, name, ...)
	local valid = modules.Validator.ValidateArguments(table.pack(...), service.options[name])
	if not valid then return {ok = false, message = "Invalid argument"} end
	return service.Client[name](owner, ...)
end
local function avatar(state) return jsonValues[state.avatarJSON] end
expect(call(first, "getState").revision == 0, "initial avatar revision")
expect(first.Character == nil and call(first, "getState").ok, "creator initializes without a player character")
expect(avatar(call(first, "getState")).properties.Shirt == 77, "baseline comes from Workspace.Rig")
service:Start()
expect(playerService.CharacterAutoLoads == false, "service disables character spawning")
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
expect(state.ok and avatar(state).properties.Shirt == 77, "authored rig baseline reset")
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
		expect(params.Limit == 24 and params.SearchKeyword == "test", "search params")
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
