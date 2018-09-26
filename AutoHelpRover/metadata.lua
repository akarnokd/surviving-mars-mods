return PlaceObj('ModDef', {
	'title', "AutoHelpRover",
	'description', "RC Rovers will automatically look for malfunctioning rovers (such as Explorers, Transporters or other Rovers) and rescue them. If currently not rescuing, they are ordered back to the nearest Power Cable for safekeeping.\r\n\r\nThe Rover's Info Panel features an \"Auto Help\" section that can be toggled on.\r\n\r\nIf ModConfig is installed, the status notifications can be disabled in the Mod Config Menu.",
	'image', "AutoHelpRover.png",
	'last_changes', "Remove battery related logic as the Sagan update has removed batteries from rovers entirely.",
	'id', "iUvqqh",
	'steam_id', "1342675590",
	'author', "akarnokd",
	'version', 28,
	'lua_revision', 234560,
	'code', {"Code/AutoHelpRoverScript.lua"},
	'saved', 1537994224,
})