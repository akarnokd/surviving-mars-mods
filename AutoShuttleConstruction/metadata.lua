return PlaceObj('ModDef', {
	'title', "AutoShuttleConstruction",
	'description', "Automatically construct Shuttles at Shuttle Hubs if there are plenty of resources available (threshold configurable) and the hub is not maxed out already.\n\nBy default, new shuttles will be built if there are more than 5 times the base cost of building one.\n\nIf ModConfig (Old or Reborn) is installed, the resource threshold can be edited as a multiplier of the base cost. Notifications can be disabled as well.",
	'image', "AutoShuttleConstruction.png",
	'last_changes', "Fix thread problems when loading a save without this mod.",
	'id', "yzrZ1l2",
	'steam_id', "1345485647",
	'pops_desktop_uuid', "130f823d-1b2f-46b5-a2dd-0c56def791e9",
	'pops_any_uuid', "63fefeab-3b81-402d-9921-c12da7e18ff2",
	'author', "akarnokd",
	'version', 25,
	'lua_revision', 1007000,
	'saved_with_revision', 1008033,
	'code', {
		"Code/AutoShuttleConstructionScript.lua",
	},
	'saved', 1632348469,
})