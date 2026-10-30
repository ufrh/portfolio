local Catalog = {} do
	Catalog.pageSize = 28
	Catalog.categories = {"Clothing", "Accessories", "Body", "Animations", "Outfits", "Starred", "Recents"}
	Catalog.sorts = {
		{label = "MOST SALES", value = "Bestselling"},
		{label = "RELEVANCE", value = "Relevance"},
		{label = "LOWEST PRICE", value = "PriceLowToHigh"},
		{label = "HIGHEST PRICE", value = "PriceHighToLow"},
		{label = "MOST FAVORITED", value = "MostFavorited"},
		{label = "NEWEST", value = "RecentlyCreated"}
	}

	Catalog.subcategories = {
		Clothing = {
			{name = "All"},
			{name = "Classic Shirts", assets = {"Shirt"}},
			{name = "Classic T-Shirts", assets = {"TShirt"}},
			{name = "Classic Pants", assets = {"Pants"}},
			{name = "Shirts", assets = {"ShirtAccessory"}},
			{name = "T-Shirts", assets = {"TShirtAccessory"}},
			{name = "Pants", assets = {"PantsAccessory"}},
			{name = "Jackets", assets = {"JacketAccessory"}},
			{name = "Sweaters", assets = {"SweaterAccessory"}},
			{name = "Shorts", assets = {"ShortsAccessory"}},
			{name = "Dresses & Skirts", assets = {"DressSkirtAccessory"}},
			{name = "Shoes", assets = {"LeftShoeAccessory", "RightShoeAccessory"}, bundles = {"Shoes"}}
		},
		Accessories = {
			{name = "All"}, {name = "Hats", assets = {"Hat"}},
			{name = "Face", assets = {"FaceAccessory"}}, {name = "Neck", assets = {"NeckAccessory"}},
			{name = "Shoulder", assets = {"ShoulderAccessory"}}, {name = "Front", assets = {"FrontAccessory"}},
			{name = "Back", assets = {"BackAccessory"}}, {name = "Waist", assets = {"WaistAccessory"}},
			{name = "Gear", assets = {"Gear"}}
		},
		Body = {
			{name = "All"}, {name = "Hair", assets = {"HairAccessory"}}, {name = "Faces", assets = {"Face"}},
			{name = "Heads", assets = {"Head", "DynamicHead"}, bundles = {"DynamicHead"}},
			{name = "Torsos", assets = {"Torso"}}, {name = "Arms", assets = {"LeftArm", "RightArm"}},
			{name = "Legs", assets = {"LeftLeg", "RightLeg"}}, {name = "Body Bundles", bundles = {"BodyParts"}}
		},
		Animations = {
			{name = "Bundles", bundles = {"Animations"}}, {name = "Idle", assets = {"IdleAnimation"}},
			{name = "Walk", assets = {"WalkAnimation"}}, {name = "Run", assets = {"RunAnimation"}},
			{name = "Jump", assets = {"JumpAnimation"}}, {name = "Fall", assets = {"FallAnimation"}},
			{name = "Climb", assets = {"ClimbAnimation"}}, {name = "Swim", assets = {"SwimAnimation"}},
			{name = "Emotes", assets = {"EmoteAnimation"}}
		},
		Outfits = {{name = "My Outfits"}, {name = "Roblox Outfits"}},
		Starred = {}, Recents = {}
	}
	for _, category in {"Starred", "Recents"} do
		for _, name in {"All", "Clothing", "Accessories", "Body", "Animations", "Outfits"} do
			table.insert(Catalog.subcategories[category], {name = name})
		end
	end

	Catalog.properties = {
		TShirt = "GraphicTShirt", Shirt = "Shirt", Pants = "Pants", Face = "Face", Head = "Head",
		DynamicHead = "Head", Torso = "Torso", LeftArm = "LeftArm", RightArm = "RightArm",
		LeftLeg = "LeftLeg", RightLeg = "RightLeg", IdleAnimation = "IdleAnimation",
		WalkAnimation = "WalkAnimation", RunAnimation = "RunAnimation", JumpAnimation = "JumpAnimation",
		FallAnimation = "FallAnimation", ClimbAnimation = "ClimbAnimation", SwimAnimation = "SwimAnimation"
	}
	Catalog.accessories = {
		Hat = "Hat", HairAccessory = "Hair", FaceAccessory = "Face", NeckAccessory = "Neck",
		ShoulderAccessory = "Shoulder", FrontAccessory = "Front", BackAccessory = "Back", WaistAccessory = "Waist",
		TShirtAccessory = "TShirt", ShirtAccessory = "Shirt", PantsAccessory = "Pants", JacketAccessory = "Jacket",
		SweaterAccessory = "Sweater", ShortsAccessory = "Shorts", LeftShoeAccessory = "LeftShoe",
		RightShoeAccessory = "RightShoe", DressSkirtAccessory = "DressSkirt"
	}
	function Catalog.assetName(value): string?
		if (typeof(value) == "EnumItem") then return value.Name end
		if (type(value) == "string") then return value end
		for _, item in Enum.AvatarAssetType:GetEnumItems() do
			if (item.Value == value) then return item.Name end
		end
		return nil;
	end

	function Catalog.text(value, limit: number): string
		local text = tostring(value)
		if (#text <= limit) then return text end
		local boundary = utf8.offset(text, 0, limit + 1)
		return string.sub(text, 1, boundary - 1);
	end

	function Catalog.categoryFor(assetType: string?, bundleType: string?): string
		if (bundleType) then
			return if (bundleType == "Animations") then "Animations" elseif (bundleType == "Shoes") then "Clothing" else "Body";
		end
		for _, category in {"Clothing", "Accessories", "Body", "Animations"} do
			for _, entry in Catalog.subcategories[category] do
				if (entry.assets and table.find(entry.assets, assetType)) then return category end
			end
		end
		return "Body";
	end

	function Catalog.normalize(raw)
		local assetType = Catalog.assetName(raw.AssetType)
		local itemType = if (typeof(raw.ItemType) == "EnumItem") then raw.ItemType.Name else raw.ItemType or "Asset"
		local bundleType = if (typeof(raw.BundleType) == "EnumItem") then raw.BundleType.Name else raw.BundleType
		return {
			id = raw.Id, itemType = itemType, assetType = assetType, bundleType = bundleType,
			name = Catalog.text(raw.Name or "Unnamed item", 64), creator = Catalog.text(raw.CreatorName or "Roblox", 32),
			price = raw.Price or raw.LowestPrice, category = Catalog.categoryFor(assetType, bundleType)
		};
	end

	function Catalog.key(item): string
		return item.itemType .. ":" .. tostring(item.id);
	end

	function Catalog.searchParams(category: string, subcategory: number, query: string, sort: number)
		local entry = Catalog.subcategories[category][subcategory]
		local assets, bundles = {}, {}
		local entries = if (entry.name == "All") then Catalog.subcategories[category] else {entry}
		for _, option in entries do
			for _, name in option.assets or {} do
				if (not table.find(assets, Enum.AvatarAssetType[name])) then table.insert(assets, Enum.AvatarAssetType[name]) end
			end
			for _, name in option.bundles or {} do
				if (not table.find(bundles, Enum.BundleType[name])) then table.insert(bundles, Enum.BundleType[name]) end
			end
		end
		local params = CatalogSearchParams.new() do
			params.AssetTypes    = assets
			params.BundleTypes   = bundles
			params.SearchKeyword = query
			params.SortType      = Enum.CatalogSortType[Catalog.sorts[sort].value]
			params.Limit         = Catalog.pageSize
		end
		return params;
	end
end return Catalog;
