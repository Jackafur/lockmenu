# LockMenu

<img src="assets/icon-512.png" alt="LockMenu icon" width="128" align="right">

A warlock menu on one key for the WoW Forever beta (Classic+). Press a key and a menu opens at your mouse with the spells you would otherwise need keybinds for: your demons, buffs, stones and utility spells, plus the healthstone and soulstone you are carrying. Click one to cast it.

It reads your spellbook and only shows spells you know, so it works with the beta's own warlock spell list. There is no Felguard, Fel Armor or Ritual of Souls on the beta, but Incubus is there, and a spell the beta lacks is simply not shown.

## Install

1. Download the zip from the [releases page](https://github.com/Jackafur/lockmenu/releases) and extract the `LockMenu` folder into `World of Warcraft\_classic_beta_\Interface\AddOns`.
2. Restart the game once. A new addon and its key binding need a full restart.
3. Esc, Options, Keybindings, AddOns, LockMenu: bind "Show the warlock menu" to a key.

Press the key to open the menu. `/lockmenu` does the same.

## Options

Type `/lockmenu options`.

- **Hold to show:** the menu opens while you hold the key and closes when you let go, instead of toggling.
- **Cast on release:** with hold to show, letting go casts the spell the mouse is pointing at. This only works out of combat, because the game only lets a secure button change its spell out of combat. In combat, hold the key and click the spell instead.
- **Close after casting**, and whether it **opens at the mouse** or near the middle of the screen.
- **Which rows show:** Demons, Buffs, Utility, Stones, Curses and banes, Control (fear, banish, howl, death coil), the stones you carry, and extra spells. Curses and Control are off by default.
- **Button size, background opacity and menu opacity.**
- **Extra spells:** exact spell names, separated by commas, that appear in an Extra row.

Settings are kept in an account-wide macro named "LockMenu data", because the Forever beta does not read saved variables back. Please leave that macro alone.

## Commands

| Command | What it does |
|---|---|
| `/lockmenu` or `/lkm` | Open or close the menu |
| `/lockmenu options` | Open the options window |
| `/lockmenu scan` | Print what the addon found in your spellbook and how many buttons the menu has (send this with a bug report) |
| `/lockmenu rebuild` | Redraw the menu |

## Change what is shown

Edit `Data.lua`. The rows are matched by name against your spellbook, curses and banes are picked up by pattern, `extra` adds spells by exact name, and `useItems` lists the healthstone and soulstone item IDs.

## Limits

- The menu is an ordinary frame, so it opens and closes in combat. What it shows is only redrawn out of combat, and it opens at the mouse only out of combat (in combat it opens where it was).
- Cast on release does not work in combat (see above).
- It is early. It was built with AI assistance (Claude Code) and tested in game by the author on one setup, so expect rough edges. Bug reports are welcome under Issues.

## Credits

Inspired by WarlockTools by afrugalpenguin, a popup spell menu for TBC Anniversary. LockMenu is written from scratch for the Forever beta and shares no code with it. The healthstone and soulstone item ID lists are game data, which any item database has.

## License

MIT, see LICENSE.