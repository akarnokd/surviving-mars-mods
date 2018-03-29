return PlaceObj('ModDef', {
	'title', "ModManagerShowTGA",
	'description', 'The Mod Manager allows only a single image per mod. For Steam, this has to be a PNG, for the game, this has to be a TGA image. \r\n\r\nThis mod changes the logic that picks the image on the Mod Manager screen to try and use the "image.tga" when the definition has "image.png". That means a mod should both have a PNG and a TGA file with the same name. Use the PNG in the definition so Steam displays it properly.\r\n\r\nNotes:\r\n- It was promised this image problem will be officially resolved, until then...',
	'tags', "",
	'id', "w4zmxwV",
	'author', "akarnokd",
	'version', 4,
	'lua_revision', 228184,
	'code', {
		"Code/ModManagerShowTGAScript.lua",
	},
	'saved', 1522311555,
})