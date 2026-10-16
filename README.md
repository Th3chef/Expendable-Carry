# Expendable Carry

![Expendable Carry](media/gallery.png)

*Pick up an EAT and keep your support weapon on your back.*

**Download:** `Expendable-Carry-1.1.0.zip` from the [latest release](https://github.com/Th3chef/Expendable-Carry/releases/latest) (not the source code). Needs [Bingus Shared Loader](https://www.nexusmods.com/helldivers2/mods/16292) v19 or newer.

In the base game you only have one support weapon slot: pick up an EAT and the game drops your Railgun, Autocannon or machine gun on the ground. With this mod your own support weapon goes onto your back instead, exactly where the game holsters it, while the expendable is in your hands. When you're done, press your support weapon key: the expendable drops at your feet and your weapon is back in your hands, with its weapon-switch sound. Use the expendable up and your weapon stays on its sling until you draw it, like a real sling.

## Features

- **Your weapon on your back:** the game's own attach puts it on its own holster spot, with its own position and angle, just as the game holsters it. No copies, no hiding: it's your real weapon.
- **One key back:** with the expendable in your hands, press your support weapon key. The expendable is dropped (you can pick it up again later) and your weapon is drawn, with its own weapon-switch sound.
- **Your own key:** the mod reads your support weapon key from the game's control settings (3 by default), so a rebound key works too. Typing it in the chat doesn't swap.
- **Controllers:** a controller has no support weapon button, so tap your switch weapon button (Y / Triangle by default) with the expendable in hand. Holding it for the weapon wheel doesn't swap.
- **Used up:** fire the last shot and your weapon goes back to your support slot, still on your back, until you draw it.
- **Two at once:** with no support weapon of your own, pick up a second expendable while you hold one (two EATs from one pod, an EAT and a Commando, the Solo Silo's remote and an EAT) and the first one is carried the same way: on your back, or the remote on its spot on your belt. Your support weapon key swaps back.
- **Drawn on pickup:** pick up an expendable with your primary or secondary out and the expendable goes into your hands.
- **No range limit:** your weapon goes wherever you go, and comes back wherever you are.
- **Safe while carried:** solo and when you host, nobody can pick your weapon up (players without the mod included), and its pickup prompt is off.
- **Light:** a few hundredths of a millisecond a frame.

## Expendables

EAT-17 Expendable Anti-Tank, EAT-700 Expendable Napalm, EAT-411 Leveller, MGX-42 Bullet Storm, MLS-4X Commando and the MS-11 Solo Silo's targeting remote. Every weapon that sits in the support slot can be carried, and with no support weapon of your own, so can an expendable when you pick up a second one.

## Options

None. It's on as soon as it's installed.

## Requirements

[Bingus Shared Loader](https://www.nexusmods.com/helldivers2/mods/16292) v19 or newer.

## Install / update

1. Install [Bingus Shared Loader](https://www.nexusmods.com/helldivers2/mods/16292) v19 or newer if you don't have it.
2. Mod manager (Arsenal / HD2 Mod Manager): add `Expendable-Carry-1.1.0.zip` and enable it, then **Purge** and **Deploy**.

## Uninstall

Disable it in your mod manager, then Purge and Deploy. Its log files stay in the Bingus logs folder and can be deleted.

## Compatibility

- A Bingus Shared Loader script: it doesn't replace any game files, so it works alongside other mods.
- Solo and hosting: everything above. Nobody else needs the mod.
- Joined games (someone else hosts): the host's game owns your weapon once it's set down, so it stays where it was set down. Your support weapon key asks the host's game for it back from wherever you are, with the game's pickup animation (the host doesn't need the mod).
- Patch-proof by design: it finds what it needs in the game's code by itself after a game update. If something can't be found, it turns itself off (or just that part, like the switch sound) and says so in its log, rather than guessing.
- Made and tested on the October 2026 game version.

## Known limitations

- Joined games: your weapon lies where it was set down for everyone, so it shows on the other players' minimaps, and a squadmate could pick it up (the mod then lets it go).
- Controllers: the switch weapon button brings your weapon back (there's no support weapon button on a controller).
- If you holster the expendable while carrying, the two can share one spot on your back.
- One item is carried at a time: with your own support weapon already on your back, a second expendable replaces the first, as in the base game.
- The TX-41 Sterilizer has no weapon-switch sound in the game, so it comes back without one.

## How it works

A Bingus Shared Loader Lua addon.
- When you pick up an expendable, the game sets your support weapon down as usual. The mod locks it (its pickup does nothing for anyone, and its prompt is off) and has the game attach it to your helldiver's holster spot with the same attach the game uses for every holstered weapon.
- Your support weapon key with the expendable in hand: the weapon is unlocked and the game's own routines put it back in your support slot (which drops the expendable) and switch to it, the same calls the game makes when you pick a weapon up, minus the pickup itself.
- Your key comes from the game's control settings file (Steam Cloud), read again every 15 seconds while you're not carrying an expendable, so a key you change in the game's options counts within about 15 seconds.
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
