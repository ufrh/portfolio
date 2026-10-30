local Catalog = require(script.Parent.Catalog)

local Description = {} do
	Description.properties = {
		"Shirt", "Pants", "GraphicTShirt", "Face", "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg",
		"IdleAnimation", "WalkAnimation", "RunAnimation", "JumpAnimation", "FallAnimation", "ClimbAnimation", "SwimAnimation",
		"HeightScale", "WidthScale", "DepthScale", "HeadScale", "BodyTypeScale", "ProportionScale"
	}
	local colors = {"HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor"}

	function Description.pack(description: HumanoidDescription)
		local data = {properties = {}, colors = {}, accessories = {}, emotes = description:GetEmotes()}
		for _, name in Description.properties do data.properties[name] = description[name] end
		for _, name in colors do
			local color = description[name]
			data.colors[name] = {color.R, color.G, color.B}
		end
		for _, accessory in description:GetAccessories(true) do
			table.insert(data.accessories, {
				AssetId = accessory.AssetId, AccessoryType = accessory.AccessoryType.Name,
				Order = accessory.Order, Puffiness = accessory.Puffiness, IsLayered = accessory.IsLayered
			})
		end
		return data;
	end

	function Description.unpack(data): HumanoidDescription
		local description = Instance.new("HumanoidDescription")
		for _, name in Description.properties do description[name] = data.properties[name] end
		for _, name in colors do description[name] = Color3.new(table.unpack(data.colors[name])) end
		local accessories = {}
		for _, accessory in data.accessories do
			local entry = table.clone(accessory)
			entry.AccessoryType = Enum.AccessoryType[entry.AccessoryType]
			table.insert(accessories, entry)
		end
		description:SetAccessories(accessories, true)
		description:SetEmotes(data.emotes or {})
		return description;
	end

	function Description.equipped(description: HumanoidDescription)
		local items, seen = {}, {}
		local function add(id, assetType)
			if (not id or id <= 0 or seen[id]) then return end
			seen[id] = true
			table.insert(items, {id = id, itemType = "Asset", assetType = assetType,
				name = assetType, creator = "", category = Catalog.categoryFor(assetType)})
		end
		for assetType, property in Catalog.properties do add(description[property], assetType) end
		for _, accessory in description:GetAccessories(true) do
			for assetType, name in Catalog.accessories do
				if (name == accessory.AccessoryType.Name) then add(accessory.AssetId, assetType); break end
			end
		end
		for _, ids in description:GetEmotes() do
			for _, id in ids do add(id, "EmoteAnimation") end
		end
		table.sort(items, function(a, b) return a.id < b.id end)
		return items;
	end

	function Description.remove(description: HumanoidDescription, id: number)
		for _, property in Catalog.properties do
			if (description[property] == id) then description[property] = 0 end
		end
		local accessories = description:GetAccessories(true)
		for index = #accessories, 1, -1 do
			if (accessories[index].AssetId == id) then table.remove(accessories, index) end
		end
		description:SetAccessories(accessories, true)
		local emotes = description:GetEmotes()
		for name, ids in emotes do
			if (table.find(ids, id)) then description:RemoveEmote(name) end
		end
	end

	function Description.apply(description: HumanoidDescription, item)
		local property = Catalog.properties[item.assetType]
		if (property) then description[property] = item.id; return true end
		local accessoryType = Catalog.accessories[item.assetType]
		if (accessoryType) then
			local accessories = description:GetAccessories(true)
			if (#accessories >= 20) then return false, "Remove an accessory first (20 max)." end
			local entry = {AssetId = item.id, AccessoryType = Enum.AccessoryType[accessoryType]}
			local asset = Enum.AvatarAssetType[item.assetType]
			if (asset.Value >= 64) then entry.IsLayered = true; entry.Order = #accessories + 1 end
			table.insert(accessories, entry)
			description:SetAccessories(accessories, true)
			return true;
		end
		if (item.assetType == "EmoteAnimation") then
			if (#Description.equipped(description) >= 48) then return false, "Remove an item first." end
			description:AddEmote("Emote" .. item.id, item.id)
			return true;
		end
		return false, "This item cannot be tried on. Gear is browse-only.";
	end
end return Description;
