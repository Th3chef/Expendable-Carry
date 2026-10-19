# Changelog

## 2.0.2

- Fixed: in first person, the item on your back no longer gets in your view (the EAT on sharp turns, the Leveller and the Quasar right away). It's hidden while you're in first person, the same way the game hides its own holstered weapons, and aiming in third person doesn't hide it.

## 2.0.1

- Drop the Expendable: pulling out a grenade or calling a stratagem with the expendable in your hands now drops it, like switching to your primary or secondary. Before, the game holstered it on the same spot as your support weapon. Swap, Don't Drop is unchanged.

## 2.0.0

- Swap, Don't Drop is now the default: your support weapon key swaps what's in your hands and what's on your back. The old way is still there: pick Drop the Expendable under Expendable Carry (required) in your mod manager.
- With two items on your back, the carried one now sits beside the other instead of moving to a second spot, so they no longer stand upright or overlap.
- The mod manager options changed: when you update, check that Expendable Carry (required) is ticked and the pick you want is selected. The Mod Options Menu toggle starts at your pick.

## 1.2.0

- New option: Swap, Don't Drop (off unless you tick it). Your support weapon key swaps what's in your hands and what's on your back instead of dropping the expendable: your support weapon and one expendable, or two expendables. Switching to your primary or secondary keeps the expendable on your back, and an expendable picked up with another weapon out isn't drawn. A support weapon you pick up with an expendable in your hands puts the expendable on your back. In joined games the key asks the host for the other item back. Also a toggle in Mod Options Menu.
- The mod now has options in your mod manager: when you update, make sure Expendable Carry (required) is ticked.

## 1.1.2

- Lighter: the mod now sleeps on the ship, in the menus and whenever nothing is in your support slot (one quick look 4 times a second). While it works it reads less, and nothing heavy happens on the frame you pick something up.
- Fixed: if your helldiver wasn't fully set up the moment it appeared, the mod could stay inactive for that whole life.

## 1.1.1

- Switching to your primary or secondary with an expendable in hand now drops the expendable. Before, the game holstered it on your back next to your carried support weapon.

## 1.1.0

- New: with no support weapon of your own, a second expendable carries the first one (two EATs from one pod, an EAT and a Commando, the Solo Silo's remote and an EAT). It goes on your back, or the remote on its spot on your belt, and your support weapon key swaps back.
- A carried item the game removes (like the Solo Silo's remote when its silo is gone) is now let go cleanly.
- Joined games: a host that takes a few seconds to hand your weapon back is no longer logged as a failed swap.

## 1.0.1

- Fixed: when the game's control settings listed your support weapon action with no keyboard or mouse key (for example, only a controller button set for it), the mod had no key to swap with. It now uses the default, 3.

## 1.0.0

First release.

- Pick up an expendable (EAT-17, EAT-700, EAT-411 Leveller, MGX-42 Bullet Storm, MLS-4X Commando, the Solo Silo's targeting remote) and your own support weapon goes onto your back, on its own holster spot, with the game's own attach.
- Your support weapon key (read from the game's control settings, 3 by default) with the expendable in hand drops the expendable and brings your weapon back, with its weapon-switch sound. Typing the key in the chat doesn't swap.
- Controllers: a tap of the switch weapon button brings your weapon back (held for the weapon wheel, it doesn't).
- Used up: your weapon goes back to your support slot and stays on its sling until you draw it.
- An expendable picked up with your primary or secondary out is drawn into your hands.
- Solo and hosting: your carried weapon is locked (nobody can pick it up) and its pickup prompt is off. Joined games: the key asks the host's game for your weapon back from anywhere.
- No range limit. Finds what it needs in the game's code by itself (patch-proof).
