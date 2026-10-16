# Changelog

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
