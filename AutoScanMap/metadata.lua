return PlaceObj('ModDef', {
	'title', "AutoScanMap",
	'description', "Automatically scan the map around the colony until all sectors have been scanned. Once deep scanning becomes available, it will do the scanning again.\n\nYou can still queue up sectors manually or cancel any active scan. The automatic scanning will only happen if there are no sectors queued up for scanning. There is only one sector scanned automatically at a time.\n\nIt ModConfig (Old or Reborn) is available, the scan mode can be specified: off, normal only, deep only, normal and deep. Normal only scans the map only if the deep scan research is not available. Default is Normal and Deep.",
	'image', "AutoScanMap.png",
	'last_changes', "Support Below and Beyond",
	'id', "LZx1sD",
	'steam_id', "1345983104",
	'pops_desktop_uuid', "eca54ead-8e13-4481-81f9-c93c9eacf1af",
	'pops_any_uuid', "916edcf7-030e-4eef-bf0d-97a05983e45e",
	'author', "akarnokd",
	'version', 27,
	'lua_revision', 1007000,
	'saved_with_revision', 1007783,
	'code', {
		"Code/AutoScanMapScript.lua",
	},
	'saved', 1631049030,
})