return PlaceObj('ModDef', {
	'title', "AutoExplore",
	'description', "Idle RC Explorers automatically move to discovered anomalies and research them.\n\nSagan compatible. Note though that the Sagan update introduced Rover AI similar to this mod, but unlike this mod, it requires research to become available.\n\nThe Explorer's Info Panel features an \"Auto Explore\" section that can be toggled on. In addition, each rover can be limited to certain types of anomalies via toggle buttons.\n\nIf ModConfig (Old or Reborn) is installed, the status notifications can be disabled in the Mod Config Menu.\n\nThe rover doesn't try to get to unreachable anomalies anymore and contains some elaborate custom path management so that it uses tunnels to get to its destination across maps and zones.",
	'image', "AutoExplore.png",
	'last_changes', "Fix icons.",
	'id', "Gfsiaes",
	'steam_id', "1341019047",
	'author', "akarnokd",
	'version', 79,
	'lua_revision', 237920,
	'code', {"Code/AutoExploreScript.lua","Code/AutoPathFinding.lua"},
	'saved', 1542831473,
	'TagOther', true,
})