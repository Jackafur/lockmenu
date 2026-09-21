local ADDON, ns = ...

-- What the menu can show. Everything here is matched by name against your spellbook, and only spells you know are shown, so a
-- spell the beta does not have (or you have not learned yet) is skipped without any error. Rows appear top to bottom in this
-- order. A spell is shown once, in the first row that claims it. Which rows are shown is chosen in /lockmenu options
-- ("default = false" means a row starts switched off).
ns.Data = {
	spellGroups = {
		{
			label = "Demons",
			text = "Demons (summon your pet)",
			names = { "Summon Imp", "Summon Voidwalker", "Summon Succubus", "Summon Incubus", "Summon Felhunter", "Summon Felguard" },
			-- Any other "Summon ..." spell you know also lands here, except the mounts, which go to Utility.
			patterns = { "^Summon " },
			exclude = { ["Summon Felsteed"] = true, ["Summon Dreadsteed"] = true },
		},
		{
			label = "Buffs",
			text = "Buffs (armor, breath, invisibility)",
			names = { "Demon Skin", "Demon Armor", "Fel Armor", "Detect Invisibility", "Unending Breath", "Shadow Ward", "Soul Link" },
		},
		{
			label = "Utility",
			text = "Utility (summoning portal, rituals, mounts)",
			names = { "Ritual of Summoning", "Ritual of Souls", "Eye of Kilrogg", "Sense Demons", "Health Funnel", "Fel Domination",
				"Summon Felsteed", "Summon Dreadsteed" },
		},
		{
			label = "Stones",
			text = "Stones (make healthstone, soulstone and more)",
			names = { "Create Healthstone", "Create Soulstone", "Create Firestone", "Create Spellstone" },
		},
		{
			label = "Curses",
			text = "Curses and banes",
			default = false,
			names = {},
			-- Every "Curse of ..." and "Bane of ..." you know, so the beta's changed curses appear without being listed.
			patterns = { "^Curse of ", "^Bane of " },
		},
		{
			label = "Control",
			text = "Control (fear, banish, howl, death coil)",
			default = false,
			names = { "Fear", "Banish", "Howl of Terror", "Death Coil", "Enslave Demon" },
		},
	},

	-- Spells to add at the end of the menu, by exact name. (The options window has a box for this too.)
	extra = {},

	-- Stones and healthstones you carry are shown as buttons that use them (the best one you have), highest first.
	useItems = {
		{ label = "Healthstone", ids = { 22105, 22104, 22103, 19013, 19012, 9421, 19011, 19010, 5510, 19009, 19008, 5509, 19007, 19006, 5511, 19005, 19004, 5512 } },
		{ label = "Soulstone", ids = { 22116, 16896, 16895, 16893, 16892, 5232 } },
	},

	shardItem = 6265,
}
