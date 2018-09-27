return PlaceObj('ModDef', {
	'title', "AutoDemolishExtractors",
	'description', "Automatically salvage and clear (demolish) all types of Extractors that have depleted their sources. If the respective research has been aquired, they will be cleared (decomissioned) as well.\r\n\r\nIf ModConfig is installed, the notification settings and the action to perform on each depleted extractor type can be specified (or disabled altogether). By default, notifications is on and action is Salvage and Clear.\r\n\r\nThis mod replaces my previous mod only for Concrete Extractors: AutoDemolishConcreteExtractor.",
	'image', "AutoDemolishExtractor.png",
	'last_changes', "Fix handler thread piling up on reloading a save and potentially causing peformance problems.",
	'id', "Wkku4ZW",
	'steam_id', "1347009783",
	'author', "akarnokd",
	'version', 16,
	'lua_revision', 234560,
	'code', {"Code/AutoDemolishExtractorsScript.lua"},
	'saved', 1538040324,
	'TagBuildings', true,
})