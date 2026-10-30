local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AvatarEditorService = game:GetService("AvatarEditorService")
local AssetService = game:GetService("AssetService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local FORGE = require(ReplicatedStorage:WaitForChild("FORGE"))
local Shared = ReplicatedStorage:WaitForChild("OutfitShared")
local Catalog = require(Shared.Catalog)
local Description = require(Shared.Description)
local Character = require(Shared.Character)

local OutfitService = FORGE.Class("Service", {Name = "OutfitService"}) do
	local sessions, details = {}, {}
	local detailCount = 0

	local function getDetails(id: number, itemType: string)
		local key = itemType .. ":" .. id
		if (details[key]) then return details[key] end
		local raw = AvatarEditorService:GetItemDetailsAsync(id, Enum.AvatarItemType[itemType])
		local item = Catalog.normalize(raw)
		assert(item.id == id, "Catalog returned a different item.")
		if (detailCount >= 300) then table.clear(details); detailCount = 0 end
		details[key] = item
		detailCount += 1
		return item;
	end

	local function getSession(player: Player)
		if (sessions[player]) then return sessions[player] end
		local humanoid = OutfitService.creatorRig:FindFirstChildOfClass("Humanoid")
		assert(humanoid, "Workspace.Rig has no Humanoid.")
		local loaded = humanoid:GetAppliedDescription()
		local description = Description.bare(loaded)
		loaded:Destroy()
		local success, reason = pcall(function() humanoid:ApplyDescriptionAsync(description) end)
		if (not success) then description:Destroy(); error(reason) end
		Character.constrain(OutfitService.creatorRig, OutfitService.creatorPosition)
		local root = OutfitService.creatorRig:FindFirstChild("HumanoidRootPart")
		if (root) then pcall(function() root:SetNetworkOwner(player) end) end
		local session = {
			description = description, baseline = description:Clone(), favorites = {}, recents = {},
			outfits = {}, nextOutfit = 0, selected = nil, revision = 0
		}
		if (not player.Parent) then
			session.description:Destroy()
			session.baseline:Destroy()
			error("Player left.")
		end
		sessions[player] = session
		return session;
	end

	local function snapshot(session)
		local outfits = {}
		for _, outfit in session.outfits do
			table.insert(outfits, {id = outfit.id, itemType = "SavedOutfit", name = outfit.name,
				creator = "Saved this session", category = "Outfits"})
		end
		local items = Description.equipped(session.description)
		for index, item in items do
			items[index] = details[Catalog.key(item)] or item
		end
		return {ok = true, avatarJSON = HttpService:JSONEncode(Description.pack(session.description)),
			equippedJSON = HttpService:JSONEncode(items), favoritesJSON = HttpService:JSONEncode(session.favorites),
			recentsJSON = HttpService:JSONEncode(session.recents), outfitsJSON = HttpService:JSONEncode(outfits),
			selected = session.selected, revision = session.revision};
	end

	local function apply(player, session, description, selected)
		if (not player.Parent) then description:Destroy(); error("Player left.") end
		local humanoid = OutfitService.creatorRig:FindFirstChildOfClass("Humanoid")
		if (not humanoid) then description:Destroy(); error("Workspace.Rig has no Humanoid.") end
		local success, reason = pcall(function() humanoid:ApplyDescriptionAsync(description) end)
		if (not success) then
			description:Destroy()
			pcall(function() humanoid:ApplyDescriptionAsync(session.description) end)
			Character.constrain(OutfitService.creatorRig, OutfitService.creatorPosition)
			error(reason)
		end
		Character.constrain(OutfitService.creatorRig, OutfitService.creatorPosition)
		session.description:Destroy()
		session.description = description
		session.selected = selected
		session.revision += 1
	end

	local function recent(session, item)
		local key = Catalog.key(item)
		for index = #session.recents, 1, -1 do
			if (Catalog.key(session.recents[index]) == key) then table.remove(session.recents, index) end
		end
		table.insert(session.recents, 1, item)
		if (#session.recents > 20) then table.remove(session.recents) end
	end

	-- One change at a time.
	local busy = {}
	local function endpoint(name, schema, callback)
		OutfitService.Client[name] = function(player, ...)
			if (busy[player]) then return {ok = false, message = "Your previous change is still loading."} end
			busy[player] = true
			local success, result = pcall(callback, player, ...)
			busy[player] = nil
			if (not success) then
				warn("[Outfit] " .. tostring(result))
				return {ok = false, message = "Couldn't finish that request. Try again in a moment."};
			end
			return result;
		end
		OutfitService:ConfigureEndpoint(name, {Schema = schema, Rate = {Capacity = 8, Refill = 2}})
	end
	local idType = FORGE.Types.Number({Min = 1, Max = 9007199254740991, Integer = true})
	local kindType = FORGE.Types.String({MaxLength = 16})

	endpoint("getState", {}, function(player)
		return snapshot(getSession(player));
	end)

	endpoint("toggleItem", {idType, kindType}, function(player, id, itemType)
		assert(itemType == "Asset" or itemType == "Bundle", "Invalid item type.")
		local session = getSession(player)
		local item = getDetails(id, itemType)
		local description = session.description:Clone()
		local selected = Catalog.key(item)
		if (itemType == "Asset") then
			local worn = false
			for _, equipped in Description.equipped(description) do
				if (equipped.id == id) then worn = true; break end
			end
			if (worn) then
				Description.remove(description, id)
			else
				local success, reason = Description.apply(description, item)
				if (not success) then description:Destroy(); return {ok = false, message = reason} end
			end
			selected = nil
		else
			local bundle = AssetService:GetBundleDetailsAsync(id)
			local applied = 0
			for _, entry in bundle.Items or {} do
				if (entry.Type == "Asset") then
					local asset = getDetails(entry.Id, "Asset")
					Description.remove(description, entry.Id)
					if (Description.apply(description, asset)) then applied += 1 end
				end
			end
			if (applied == 0) then description:Destroy(); return {ok = false, message = "This bundle has no supported avatar items."} end
		end
		apply(player, session, description, selected)
		recent(session, item)
		return snapshot(session);
	end)

	endpoint("removeItem", {idType}, function(player, id)
		local session = getSession(player)
		local description = session.description:Clone()
		Description.remove(description, id)
		apply(player, session, description)
		return snapshot(session);
	end)

	endpoint("reset", {}, function(player)
		local session = getSession(player)
		apply(player, session, session.baseline:Clone())
		return snapshot(session);
	end)

	endpoint("toggleFavorite", {idType, kindType}, function(player, id, itemType)
		assert(itemType == "Asset" or itemType == "Bundle" or itemType == "RobloxOutfit", "Invalid favorite type.")
		local session = getSession(player)
		local key = itemType .. ":" .. id
		for index, item in session.favorites do
			if (Catalog.key(item) == key) then table.remove(session.favorites, index); return snapshot(session) end
		end
		if (#session.favorites >= 24) then return {ok = false, message = "You can star up to 24 items per session."} end
		local item
		if (itemType == "RobloxOutfit") then
			local raw = AvatarEditorService:GetOutfitDetailsAsync(id)
			item = {id = id, itemType = itemType, name = Catalog.text(raw.Name or "Roblox outfit", 64), creator = "Roblox outfit", category = "Outfits"}
		else item = getDetails(id, itemType) end
		table.insert(session.favorites, item)
		return snapshot(session);
	end)

	endpoint("saveOutfit", {FORGE.Types.String({MinLength = 1, MaxLength = 40})}, function(player, name)
		local session = getSession(player)
		if (#session.outfits >= 20) then return {ok = false, message = "Delete a saved outfit first (20 max)."} end
		name = string.match(name, "^%s*(.-)%s*$")
		if (not utf8.len(name)) then return {ok = false, message = "That name contains invalid text."} end
		if (name == "") then return {ok = false, message = "Give your outfit a name."} end
		session.nextOutfit += 1
		table.insert(session.outfits, {id = session.nextOutfit, name = name, description = session.description:Clone()})
		return snapshot(session);
	end)

	endpoint("applyOutfit", {idType, kindType}, function(player, id, itemType)
		local session = getSession(player)
		local description, item
		if (itemType == "SavedOutfit") then
			for _, outfit in session.outfits do
				if (outfit.id == id) then
					description = outfit.description:Clone()
					item = {id = id, itemType = itemType, name = outfit.name, creator = "Saved this session", category = "Outfits"}
					break
				end
			end
		elseif (itemType == "RobloxOutfit") then
			description = Players:GetHumanoidDescriptionFromOutfitIdAsync(id)
			local raw = AvatarEditorService:GetOutfitDetailsAsync(id)
			item = {id = id, itemType = itemType, name = Catalog.text(raw.Name or "Roblox outfit", 64), creator = "Roblox outfit", category = "Outfits"}
		end
		if (not description) then return {ok = false, message = "That outfit is no longer available."} end
		apply(player, session, description, Catalog.key(item))
		recent(session, item)
		return snapshot(session);
	end)

	endpoint("deleteOutfit", {idType}, function(player, id)
		local session = getSession(player)
		for index, outfit in session.outfits do
			if (outfit.id == id) then outfit.description:Destroy(); table.remove(session.outfits, index); break end
		end
		for index = #session.recents, 1, -1 do
			local item = session.recents[index]
			if (item.itemType == "SavedOutfit" and item.id == id) then table.remove(session.recents, index) end
		end
		return snapshot(session);
	end)

	function OutfitService:Init()
		Players.CharacterAutoLoads = false
		local position = workspace.Terrain:WaitForChild("HRPPosition", 10)
		assert(position and position:IsA("Attachment"), "Terrain.HRPPosition must be an Attachment.")
		self.creatorPosition = position
		local rig = workspace:WaitForChild("Rig", 10)
		assert(rig and rig:IsA("Model"), "Workspace.Rig is missing.")
		self.creatorRig = rig
	end

	function OutfitService:prepareRig()
		local humanoid = self.creatorRig:WaitForChild("Humanoid", 15)
		local root = self.creatorRig:WaitForChild("HumanoidRootPart", 15)
		if (not humanoid or not root) then return end
		Character.constrain(self.creatorRig, self.creatorPosition)
		if (self.partConnection) then self.partConnection:Disconnect() end
		self.partConnection = self.creatorRig.DescendantAdded:Connect(Character.preparePart)
	end

	function OutfitService:Start()
		self:prepareRig()
		self.heartbeat = RunService.Heartbeat:Connect(function()
			local root = self.creatorRig:FindFirstChild("HumanoidRootPart")
			if (root and (root.Anchored or not root:FindFirstChild("OutfitPosition")
				or not root:FindFirstChild("OutfitOrientation"))) then Character.constrain(self.creatorRig, self.creatorPosition) end
		end)
		self.removing = Players.PlayerRemoving:Connect(function(player)
			local session = sessions[player]
			if (not session) then return end
			sessions[player] = nil
			session.description:Destroy()
			session.baseline:Destroy()
			for _, outfit in session.outfits do outfit.description:Destroy() end
		end)
	end

	function OutfitService:Stop()
		if (self.removing) then self.removing:Disconnect() end
		if (self.heartbeat) then self.heartbeat:Disconnect() end
		if (self.partConnection) then self.partConnection:Disconnect() end
	end
end return OutfitService;
