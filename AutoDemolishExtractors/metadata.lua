return PlaceObj('ModDef', {
	'title', "AutoDemolishExtractors",
	'description', "Automatically salvage and clear (demolish) all types of Extractors that have depleted their sources. If the respective research has been aquired, they will be cleared (decomissioned) as well.\r\n\r\nIf ModConfig is installed, the notification settings and the action to perform on each depleted extractor type can be specified (or disabled altogether). By default, notifications is on and action is Salvage and Clear.\r\n\r\nThis mod replaces my previous mod only for Concrete Extractors: AutoDemolishConcreteExtractor.",
	'image', "AutoDemolishExtractor.png",
	'last_changes', "Make mod not outdated by updating a lua_script number.",
	'id', "Wkku4ZW",
	'steam_id', "1347009783",
	'author', "akarnokd",
	'version', 12,
	'lua_revision', 233467,
	'code', {
		"Code/AutoDemolishExtractorsScript.lua",
	},
	'saved', 1533569817,
	'TagBuildings', true,
})