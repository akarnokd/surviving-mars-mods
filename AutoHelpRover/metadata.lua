return PlaceObj('ModDef', {
	'title', "AutoHelpRover",
	'description', "RC Rovers will automatically look for malfunctioning rovers (such as Explorers, Transporters or other Rovers) and rescue them. If currently not rescuing, they are ordered back to the nearest Power Cable for safekeeping.\r\n\r\nThe Rover's Info Panel features an \"Auto Help\" section that can be toggled on.\r\n\r\nIf ModConfig is installed, the status notifications can be disabled in the Mod Config Menu.",
	'image', "AutoHelpRover.png",
	'last_changes', "Fix handler thread piling up on reloading a save and potentially causing peformance problems.",
	'id', "iUvqqh",
	'steam_id', "1342675590",
	'author', "akarnokd",
	'version', 30,
	'lua_revision', 234560,
	'code', {"Code/AutoHelpRoverScript.lua"},
	'saved', 1538040409,
})