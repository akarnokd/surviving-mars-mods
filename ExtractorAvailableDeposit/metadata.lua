return PlaceObj('ModDef', {
	'title', "ExtractorAvailableDeposit",
	'description', "Display the available deposit under an Extractor building in the Info Panel.\r\n\r\nNotes:\r\n- The value is already visible in the rollover tooltip of the Production section in the vanilla game, this mod just makes sure it is shown in the Production section.\r\n- It mods the generic Mine-Panel and should work for custom mining buildings of other mods.",
	'image', "ExtractorAvailableDeposit.png",
	'last_changes', "Fix ModConfig compatibility/usage.",
	'id', "hnp4m1c",
	'steam_id', "1343197684",
	'author', "akarnokd",
	'version', 16,
	'lua_revision', 233467,
	'code', {
		"Code/ExtractorAvailableDepositScript.lua",
	},
	'saved', 1533626478,
	'TagBuildings', true,
	'TagInterface', true,
})