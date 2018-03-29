return PlaceObj('ModDef', {
	'title', "AutoScanMap",
	'description', "Automatically scan the map around the colony until all sectors have been scanned. Once deep scanning becomes available, it will do the scanning again.\r\n\r\nIt ModConfig is available, the scan mode can be specified: off, normal only, deep only, normal and deep. Normal only scans the map only if the deep scan research is not available. Default is Normal and Deep.",
	'tags', "",
	'id', "LZx1sD",
	'author', "akarnokd",
	'version', 5,
	'lua_revision', 228184,
	'code', {
		"Code/AutoScanMapScript.lua",
	},
	'saved', 1522353868,
})