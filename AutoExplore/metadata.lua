return PlaceObj('ModDef', {
	'title', "AutoExplore",
	'description', "Idle RC Explorers automatically move to discovered anomalies and research them. In addition, when they get below 60% of battery and are also idle, they go to the nearest Power Cable to recharge, making sure there is plenty of power in case the next anomaly is a bit further away.\r\n\r\nThe Explorer's Info Panel features an \"Auto Explore\" section that can be toggled on. In addition, each rover can be limited to certain types of anomalies via toggle buttons.\r\n\r\nIf ModConfig is installed, the status notifications can be disabled in the Mod Config Menu.\r\n\r\nThe rover doesn't try to get to unreachable anomalies anymore and contains some elaborate custom path management so that it uses tunnels to get to its destination across maps and zones.",
	'image', "AutoExplore.png",
	'id', "Gfsiaes",
	'steam_id', "1341019047",
	'author', "akarnokd",
	'version', 56,
	'lua_revision', 228722,
	'code', {
		"Code/AutoExploreScript.lua",
		"Code/AutoPathFinding.lua",
	},
	'saved', 1524061579,
})