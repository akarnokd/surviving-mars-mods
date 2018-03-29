return PlaceObj('ModDef', {
	'title', "AutoScanMap",
	'description', "Automatically scan the map around the colony until all sectors have been scanned. Once deep scanning becomes available, it will do the scanning again.\r\n\r\nYou can still queue up sectors manually or cancel any active scan. The automatic scanning will only happen if there are no sectors queued up for scanning. There is only one sector scanned automatically at a time.\r\n\r\nIt ModConfig is available, the scan mode can be specified: off, normal only, deep only, normal and deep. Normal only scans the map only if the deep scan research is not available. Default is Normal and Deep.",
	'tags', "",
	'image', "AutoScanMap.png",
	'id', "LZx1sD",
	'steam_id', "1345983104",
	'author', "akarnokd",
	'version', 10,
	'lua_revision', 228184,
	'code', {
		"Code/AutoScanMapScript.lua",
	},
	'saved', 1522356809,
})