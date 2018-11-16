return PlaceObj('ModDef', {
	'title', "AutoShuttleConstruction",
	'description', "Automatically construct Shuttles at Shuttle Hubs if there are plenty of resources available (threshold configurable) and the hub is not maxed out already.\n\nBy default, new shuttles will be built if there are more than 5 times the base cost of building one.\n\nIf ModConfig (Old or Reborn) is installed, the resource threshold can be edited as a multiplier of the base cost. Notifications can be disabled as well.",
	'image', "AutoShuttleConstruction.png",
	'last_changes', "Gagarin Update/ModConfig Reborn compatibility.",
	'id', "yzrZ1l2",
	'steam_id', "1345485647",
	'author', "akarnokd",
	'version', 16,
	'lua_revision', 237920,
	'code', {"Code/AutoShuttleConstructionScript.lua"},
	'saved', 1542393560,
})