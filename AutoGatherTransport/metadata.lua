return PlaceObj('ModDef', {
	'title', "AutoGatherTransport",
	'description', "Idle RC Transports automatically gather resources scattered around the surface and bring them back to the closest Universal Storage location. Such resources are Metal and Polymer surface deposits revealed by surface scanning. The transporter will not pick up other forms of resources dumped on the surface automatically.\r\n\r\nSagan compatible. Note though that the Sagan update introduced Rover AI similar to this mod, but unlike this mod, it requires research to become available.\r\n\r\nThe Transporter's Info Panel features an \"Auto Gather\" section that can be toggled on. Transporters will automatically use tunnels and should not get stuck on ledges/canyons anymore.\r\n\r\nIf ModConfig is installed, the status notifications can be disabled in the Mod Config Menu.\r\n\r\nNotes:\r\n- The Transports dump their gathered resources near the Universal Storage instead of into them because I wasn't able to prevent the popup of the \"Select resource to unload\" dialog.",
	'image', "AutoGatherTransport.png",
	'last_changes', "Fix handler thread piling up on reloading a save and potentially causing peformance problems.",
	'id', "Zq7BVyy",
	'steam_id', "1342196777",
	'author', "akarnokd",
	'version', 52,
	'lua_revision', 234560,
	'code', {"Code/AutoGatherTransportScript.lua","Code/AutoPathFinding.lua"},
	'saved', 1538040385,
	'TagOther', true,
})