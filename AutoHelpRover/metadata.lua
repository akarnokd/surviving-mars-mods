return PlaceObj('ModDef', {
	'title', "AutoHelpRover",
	'description', "RC Rovers will automatically look for malfunctioning or out of battery rovers (such as Explorers, Transporters or other Rovers) and rescue them, while keeping themselves charged. If currently not rescuing, they are ordered back to the nearest Power Cable for recharging and/or safekeeping.\r\n\r\nThe Rover's Info Panel features an \"Auto Help\" section that can be toggled on.\r\n\r\nIf ModConfig is installed, the status notifications can be disabled in the Mod Config Menu.",
	'image', "AutoHelpRover.png",
	'last_changes', "Fix GUI elements apperaring multiple times (due to the script getting initialized multiple times in the latest patch for some reason).",
	'id', "iUvqqh",
	'steam_id', "1342675590",
	'author', "akarnokd",
	'version', 26,
	'lua_revision', 233467,
	'code', {
		"Code/AutoHelpRoverScript.lua",
	},
	'saved', 1534013529,
})