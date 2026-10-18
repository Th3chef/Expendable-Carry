# Expendable Carry

![Expendable Carry](media/gallery.png)

*Carry your support weapon and an expendable, and swap between them with one key.*

**Download:** `Expendable-Carry-2.0.1.zip` from the [latest release](https://github.com/Th3chef/Expendable-Carry/releases/latest) (not the source code). Needs [Bingus Shared Loader](https://www.nexusmods.com/helldivers2/mods/16292) v19 or newer.

## What it does

In the base game you have one support weapon slot. Pick up an EAT, or any other expendable, and the game drops your Railgun, Autocannon or machine gun on the ground, and you have to go back for it.

With this mod you carry both. Your support weapon goes onto your back and the expendable goes in your hands. Press your support weapon key and the two swap: your weapon comes back to your hands and the expendable goes on your back. Press it again to swap back.

## How to use it

1. **Pick up an expendable** (EAT-17, EAT-700, EAT-411 Leveller, MGX-42 Bullet Storm, MLS-4X Commando, or the Solo Silo's targeting remote). Your support weapon goes onto your back, where the game holsters it, and the expendable is in your hands.
2. **Swap:** press your support weapon key (3 by default). Your weapon is back in your hands, with its own weapon-switch sound, and the expendable goes on your back. Press it again to swap back.
3. **Fire it.** When the expendable is used up, your support weapon goes back to your support slot. It stays on your back until you draw it, like any holstered weapon.

## Good to know

- **Two items at most:** your support weapon and one expendable, or two expendables if you don't carry a support weapon of your own (say you run the Solo Silo and EATs). Pick up another and one of them is set down: with your support weapon on your back, a new expendable replaces the one in your hands, as in the base game; with your support weapon in your hands, the expendable on your back is set down.
- **Picking up a support weapon:** pick one up with an expendable in your hands and the expendable goes on your back; your own support weapon there is set down. With two expendables, the one on your back stays and the one in your hands is dropped.
- **Switching weapons:** switch to your primary or secondary and the item in your hands is holstered too. Both sit side by side on your back, and your support weapon key draws them again.
- **Another weapon out:** an expendable you pick up with your primary or secondary out goes straight on your back; press your support weapon key to draw it.
- **Your own key:** the mod uses your support weapon key from the game's controls, so a key you changed works too. Typing it in the chat doesn't swap.
- **Controllers:** a controller has no support weapon button, so tap your switch weapon button (Y / Triangle by default). Holding it for the weapon wheel doesn't swap.
- **The Solo Silo's remote** goes on its own spot on your belt.
- **Any support weapon:** every weapon that sits in the support slot can be carried.
- **No range limit:** what you carry goes with you, and comes back wherever you are.
- **Safe while carried:** solo and when you host, nobody can pick up what's on your back, players without the mod included.
- **Light:** it sleeps on the ship, in the menus and whenever nothing is in your support slot (one quick look 4 times a second), and costs a few hundredths of a millisecond a frame while it works.

## Multiplayer

- **Solo and hosting:** everything above. Nobody else needs the mod.
- **Joined games (someone else hosts):** the host's game owns what you set down, so the item you swap away stays where it was set down instead of going on your back. Your support weapon key still asks the host for it back from wherever you are, with the game's pickup animation. The host doesn't need the mod. Other players see it on their minimap, and a squadmate could pick it up (the mod then lets it go).

## Options

**Expendable Carry (required)** is the mod itself: keep it ticked, and pick what your support weapon key does.

- **Swap, Don't Drop** (the default): the key swaps what's in your hands and what's on your back, as above.
- **Drop the Expendable** (the way the mod worked before 2.0): the key drops the expendable at your feet and brings your support weapon back, and switching to your primary, secondary, a grenade or a stratagem drops it too. An expendable picked up with another weapon out goes into your hands.

With CowboyBingus's Mod Options Menu installed, Swap, Don't Drop is also a toggle in the game's options (MODS tab, EXPENDABLE CARRY).

## Requirements

[Bingus Shared Loader](https://www.nexusmods.com/helldivers2/mods/16292) v19 or newer.

## Install / update

1. Install [Bingus Shared Loader](https://www.nexusmods.com/helldivers2/mods/16292) v19 or newer if you don't have it.
2. Mod manager (Arsenal / HD2 Mod Manager): add `Expendable-Carry-2.0.1.zip` and enable it. Tick **Expendable Carry (required)** and pick **Swap, Don't Drop** (or **Drop the Expendable**), then **Purge** and **Deploy**.
3. Updating from 1.2: the options changed, so check that **Expendable Carry (required)** is ticked and the pick you want is selected.

## Uninstall

Disable it in your mod manager, then Purge and Deploy. Its log files stay in the Bingus logs folder and can be deleted.

## Compatibility

- A Bingus Shared Loader script: it doesn't replace any game files, so it works alongside other mods.
- Patch-proof by design: it finds what it needs in the game's code by itself after a game update. If something can't be found, it turns itself off (or just that part, like the switch sound) and says so in its log, rather than guessing.
- Made and tested on the October 2026 game version.

## Known limitations

- The TX-41 Sterilizer has no weapon-switch sound in the game, so it comes back without one.

## How it works

A Bingus Shared Loader Lua addon.
- When you pick up an expendable, the game sets your support weapon down as usual. The mod locks it (its pickup does nothing for anyone, and its prompt is off) and has the game attach it to your helldiver's holster spot with the same attach the game uses for every holstered weapon.
- Your support weapon key: the item on your back is unlocked and the game's own routines put it back in your support slot and switch to it, the same calls the game makes when you pick a weapon up, minus the pickup itself. The game sets down the item that was in your hands, and the mod locks it and puts it on your back in its turn (with **Drop the Expendable**, it stays on the ground).
- With both on your back, the carried item sits beside the one the game holsters, on its own spot, shifted to the side.
- The Drop the Expendable pick only sets a flag the mod reads at start-up.
- Your key comes from the game's control settings file (Steam Cloud), read a few seconds after your helldiver appears and checked again every 15 seconds while you hold a support weapon, so a key you change in the game's options counts within about 15 seconds.
- The game's addresses are found by searching the game's code at start-up.

## Troubleshooting

- Your weapon doesn't go on your back: check Bingus Shared Loader v19 or newer is installed, the mod is enabled, and that you Purged and Deployed after installing.
- Attach the logs to a bug report: *ExpendableCarry.log*, *ExpendableCarry.research.log* and *BingusSharedLoader.log* in `%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs` (type %LOCALAPPDATA% into the File Explorer address bar and press Enter). ExpendableCarry.log shows whether it found what it needs in the game's code, your support weapon key, and every carry and swap.

## Building from source

See [src/BUILDING.md](src/BUILDING.md).

## Support

If you like my mods, you can support me on [Patreon](https://www.patreon.com/c/Chefboiardee).

## Credits

- **CowboyBingus**: Bingus Shared Loader.
- Fonts: Anton and Barlow Condensed (SIL Open Font License).

## License

All rights reserved. See [LICENSE](LICENSE).
