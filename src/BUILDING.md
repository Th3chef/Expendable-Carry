# Expendable Carry - source

A Bingus Shared Loader Lua mod: one addon, `lua/expendable_carry.lua`.

    lua/expendable_carry.lua
                    the addon (plain Lua; Bingus Shared Loader finds it by its first line)
    build.py        builds the mod zip (Python 3 + Pillow):
                      python3 build.py out              -> out/Expendable-Carry-<ver>.zip (the release)
    patch_writer.py writes the patch archive
    fonts/          Anton (SIL Open Font License), for the plain icon build.py draws when artwork/icon.png is missing
    artwork/        the release art:
                      hero.py         the scene, a flat illustration (Python 3 + NumPy, SciPy, Pillow)
                      cards.py        the thumbnail, gallery, GitHub social picture and AyakaMods cover: the scene from
                                      hero.py with the title and text as HTML rendered with Playwright Chromium
                                      (python3 cards.py <out dir> 1.0)
                      icon.png        the Arsenal icon build.py puts in the zip (the 1.0.0 art)
                      fonts/          Anton and Barlow Condensed (SIL Open Font License)

The scene uses the game's own HUD stratagem icons for the weapon silhouettes. They are the game's art and are not in
this repository: extract them from your game into `artwork/icons/` with Filediver (PNG) before running cards.py:

    0xcf20900c57479ca6                                                 -> icons/eat.png (the EAT-17's map icon)
    content/ui/shared/stratagem/icon_strat_hud_supportweapon_railgun   -> icons/railgun.png

Run them from this folder. The build is deterministic: the same sources give the same zip byte for byte (with the same
Python and zlib), and the files inside match the release. build.py only removes its own outputs from the output folder
and refuses the source folder or one of its parents.
