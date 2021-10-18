return PlaceObj('ModDef', {
	'title', "AutoGatherTransport",
	'description', "Idle RC Transports automatically gather Polymer, Metal or Waste Rocks deposited on the surface and brings them to the nearest storage location or custom location. It is recommended this location is serviced by drones. You can setup which transport should look for what resource.\n\nGathering waste rock requires a custom location to be set. The rover ignores waste rocks in a small radius around this location\n\nSupports ModConfig & ModConfig Reborn. There is a similar official auto-gathering option now, inspired by this mod with less features and locked behind research though.",
	'image', "AutoGatherTransport.png",
	'last_changes', "Handle possible invalid ModConfig configuration value.",
	'id', "Zq7BVyy",
	'steam_id', "1342196777",
	'pops_desktop_uuid', "925b3140-1bd4-4edf-a320-5e720f9471ac",
	'pops_any_uuid', "a7f0827a-a4af-46b1-a582-7ea56f639f63",
	'author', "akarnokd",
	'version', 81,
	'lua_revision', 1007000,
	'saved_with_revision', 1008298,
	'code', {
		"Code/AutoGatherTransportScript.lua",
		"Code/AutoPathFinding.lua",
	},
	'saved', 1634251246,
	'TagOther', true,
})