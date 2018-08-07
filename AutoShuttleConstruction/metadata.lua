return PlaceObj('ModDef', {
	'title', "AutoShuttleConstruction",
	'description', "Automatically construct Shuttles at Shuttle Hubs if there are plenty of resources available (threshold configurable) and the hub is not maxed out already.\r\n\r\nBy default, new shuttles will be built if there are more than 5 times the base cost of building one.\r\n\r\nIf ModConfig is installed, the resource threshold can be edited as a multiplier of the base cost. Notifications can be disabled as well.",
	'image', "AutoShuttleConstruction.png",
	'last_changes', "Fix ModConfig compatibility/usage.",
	'id', "yzrZ1l2",
	'steam_id', "1345485647",
	'author', "akarnokd",
	'version', 12,
	'lua_revision', 233467,
	'code', {
		"Code/AutoShuttleConstructionScript.lua",
	},
	'saved', 1533626450,
})