return PlaceObj('ModDef', {
	'title', "AutoScanMap",
	'description', "Automatically scan the map around the colony until all sectors have been scanned. Once deep scanning becomes available, it will do the scanning again.\n\nYou can still queue up sectors manually or cancel any active scan. The automatic scanning will only happen if there are no sectors queued up for scanning. There is only one sector scanned automatically at a time.\n\nIt ModConfig (Old or Reborn) is available, the scan mode can be specified: off, normal only, deep only, normal and deep. Normal only scans the map only if the deep scan research is not available. Default is Normal and Deep.",
	'image', "AutoScanMap.png",
	'last_changes', "Gagarin Update/ModConfig Rebord compatibility",
	'id', "LZx1sD",
	'steam_id', "1345983104",
	'pops_desktop_uuid', "ee28029d-9788-4bbb-95fb-c8c444efbb3d",
	'pops_any_uuid', "c8a4cae1-bbe8-4010-9319-0c64acd5bbff",
	'author', "akarnokd",
	'version', 21,
	'lua_revision', 233360,
	'saved_with_revision', 240905,
	'code', {"Code/AutoScanMapScript.lua"},
	'saved', 1551790387,
})