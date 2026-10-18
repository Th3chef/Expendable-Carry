"""Expendable Carry - build.

python build.py <out dir>              the release (Expendable-Carry-<ver>.zip)
  - 9ba626afa44a3aa3.patch_0: the addon (plain Lua, Bingus Shared Loader finds it by its first line)
  - manifest.json, icon.png (the Arsenal icon from artwork/icon.png); zip
"""
import json, os, re, shutil, struct, subprocess, sys, zipfile
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, HERE)
import patch_writer

VERSION = '2.0.0'
GUID_RELEASE = 'c8c1dd5a-ec87-4227-b67b-0ff28bc73feb'
LUA = 0xa14e8dfa2cd117e2
ADDON = 'mods/chef/expendable_carry'
DROP_ADDON = 'mods/chef/expendable_carry_drop'        # (2.0.0) the Drop the Expendable pick: only sets a flag
SWAP_ADDON = 'mods/chef/expendable_carry_swap'        # (2.0.0) the Swap, Don't Drop pick: only marks the pick
ANTON = os.path.join(HERE, 'fonts', 'anton-latin-400-normal.ttf')
ZIP_DATE = (2026, 10, 1, 0, 0, 0)       # every zip entry's date: the same sources give the same zip, byte for byte
# never in what ships (compared in lower case; a drive letter only at the start of a word, so 'record:\\n' is no hit),
# plus the patterns in personal_patterns.txt next to this file, one a line, when there is one (kept out of the repository)
PERSONAL = [re.compile(p) for p in (rb'c:\\+users', rb'(?<![a-z0-9_])d:\\', rb'/home/', rb'/mnt/', rb'steamlibrary')]
if os.path.exists(os.path.join(HERE, 'personal_patterns.txt')):
    PERSONAL += [re.compile(l.strip().encode()) for l in open(os.path.join(HERE, 'personal_patterns.txt'), encoding='utf-8')
                 if l.strip() and not l.startswith('#')]


def cycle_text(src):
    """(1.2.0) the Swap, Don't Drop option's description: the one copy is the Lua's CYCLE_TEXT line (the menu shows it too)"""
    m = re.search(r'^local CYCLE_TEXT = "([^"]+)"$', src, re.M)
    if not m:
        sys.exit('build.py: the Lua has no one-line CYCLE_TEXT')
    return m.group(1)


def resource_hash(name):
    """The game's 64-bit resource name hash (MurmurHash64A, seed 0)."""
    data = name.encode(); mask, mix = (1 << 64) - 1, 0xC6A4A7935BD1E995
    v = len(data) * mix & mask; end = len(data) // 8 * 8
    for (w,) in struct.iter_unpack('<Q', data[:end]):
        w = w * mix & mask; w ^= w >> 47; v = (v ^ (w * mix & mask)) * mix & mask
    if data[end:]: v = (v ^ int.from_bytes(data[end:], 'little')) * mix & mask
    v ^= v >> 47; v = v * mix & mask; v ^= v >> 47
    return v


assert resource_hash('lua') == LUA


def lua_resource(text):
    b = text.encode('utf-8')
    return struct.pack('<II', len(b), 2) + b


def icon(label):
    """A simple Arsenal icon: an expendable tube in front of a holstered support weapon (no hazard stripes)."""
    S = 1024
    img = Image.new('RGB', (S, S), (22, 24, 22))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((24, 24, S - 24, S - 24), 40, outline=(255, 231, 16), width=28)
    # the holstered support weapon (gray, diagonal behind)
    d.polygon([(190, 700), (760, 250), (820, 320), (250, 770)], fill=(110, 116, 106))
    d.rectangle((560, 380, 640, 470), fill=(90, 96, 86))
    # the expendable tube (yellow, in front)
    d.polygon([(200, 520), (820, 520), (820, 610), (200, 610)], fill=(255, 231, 16))
    d.rectangle((300, 610, 350, 700), fill=(255, 231, 16))
    d.rectangle((560, 610, 610, 680), fill=(255, 231, 16))
    font = ImageFont.truetype(ANTON, 120)
    t = 'CARRY'
    w = d.textlength(t, font=font)
    d.text(((S - w) / 2, 90), t, font=font, fill=(255, 231, 16), stroke_width=6, stroke_fill=(0, 0, 0))
    if label:
        f2 = ImageFont.truetype(ANTON, 110)
        w = d.textlength(label, font=f2)
        d.text(((S - w) / 2, 760), label, font=f2, fill=(255, 80, 60), stroke_width=6, stroke_fill=(0, 0, 0))
    return img.resize((512, 512), Image.LANCZOS)


def option_icons(pkg):
    """(1.2.0) Arsenal option pictures, 256x256: the core's is the mod's icon; the option's is the mod's art darkened
    behind a thick yellow frame with one glyph (two arrows around a tube: the swap; (2.0.0) a tube over a down arrow: the drop)."""
    import math
    os.makedirs(os.path.join(pkg, 'options'), exist_ok=True)
    S, Y = 1024, (255, 231, 16)
    art = os.path.join(HERE, 'artwork', 'icon.png')
    base = Image.open(art).convert('RGB') if os.path.exists(art) else icon('')
    base.resize((256, 256), Image.LANCZOS).save(os.path.join(pkg, 'options', 'core.png'), optimize=True)
    bg = base.resize((S, S), Image.LANCZOS).filter(ImageFilter.GaussianBlur(18)).point(lambda v: int(v * 0.35))
    d = ImageDraw.Draw(bg)
    d.rounded_rectangle((20, 20, S - 20, S - 20), 48, outline=Y, width=56)
    c, r, w = S // 2, 300, 70
    d.arc((c - r, c - r, c + r, c + r), 200, 340, fill=Y, width=w)
    d.arc((c - r, c - r, c + r, c + r), 20, 160, fill=Y, width=w)
    for ang in (340, 160):                    # an arrowhead at each arc's end, along the circle
        a = math.radians(ang)
        x, y = c + r * math.cos(a), c + r * math.sin(a)
        tx, ty, nx, ny = -math.sin(a), math.cos(a), math.cos(a), math.sin(a)
        d.polygon([(x + tx * 150, y + ty * 150), (x + nx * 110, y + ny * 110), (x - nx * 110, y - ny * 110)], fill=Y)
    d.rounded_rectangle((c - 190, c - 45, c + 190, c + 45), 20, fill=Y)
    d.rectangle((c - 120, c + 45, c - 80, c + 120), fill=Y)
    bg.resize((256, 256), Image.LANCZOS).save(os.path.join(pkg, 'options', 'cycle.png'), optimize=True)
    # (2.0.0) Drop the Expendable: the same frame, a tube and an arrow pointing down
    bg = base.resize((S, S), Image.LANCZOS).filter(ImageFilter.GaussianBlur(18)).point(lambda v: int(v * 0.35))
    d = ImageDraw.Draw(bg)
    d.rounded_rectangle((20, 20, S - 20, S - 20), 48, outline=Y, width=56)
    d.rounded_rectangle((c - 230, 250, c + 230, 340), 20, fill=Y)
    d.rectangle((c - 160, 340, c - 120, 410), fill=Y)
    d.rectangle((c - 45, 470, c + 45, 640), fill=Y)
    d.polygon([(c - 150, 630), (c + 150, 630), (c, 800)], fill=Y)
    bg.resize((256, 256), Image.LANCZOS).save(os.path.join(pkg, 'options', 'drop.png'), optimize=True)


def clean_out(out):
    """The output folder: never the source folder or one of its parents; only this build's own outputs are removed."""
    real = os.path.realpath(out)
    if real == HERE or HERE.startswith(real.rstrip(os.sep) + os.sep):
        sys.exit('build.py: %s is the source folder or one of its parents; use an output folder of its own' % out)
    os.makedirs(real, exist_ok=True)
    for f in os.listdir(real):
        p = os.path.join(real, f)
        if f == 'pkg' and os.path.isdir(p) and not os.path.islink(p): shutil.rmtree(p)
        elif f == 'addon.built.lua' or (f.startswith('Expendable-Carry-') and f.endswith('.zip')): os.remove(p)


def check_lua(path):
    """The built Lua compiles (luajit -bl), when luajit is on PATH."""
    lj = shutil.which('luajit')
    if not lj:
        print('luajit not on PATH: the compile check was skipped')
        return
    r = subprocess.run([lj, '-bl', path], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    if r.returncode != 0:
        sys.exit('build.py: the built Lua does not compile: ' + r.stderr.decode('utf-8', 'replace').strip())


def check_private(paths):
    """Nothing personal (a user folder, a drive or Steam path) in what ships."""
    for p in paths:
        data = open(p, 'rb').read().lower()
        for k in PERSONAL:
            m = k.search(data)
            if m:
                sys.exit('build.py: %s contains %r (personal); remove it before building' % (os.path.basename(p), m.group().decode()))


def main():
    out = sys.argv[1]
    full, guid, name = VERSION, GUID_RELEASE, 'Expendable-Carry-%s.zip' % VERSION
    clean_out(out)
    pkg = os.path.join(out, 'pkg'); os.makedirs(pkg)
    src = open(os.path.join(HERE, 'lua', 'expendable_carry.lua'), encoding='utf-8').read()
    head = '-- HD2-Addon: %s\n' % ADDON
    if not src.startswith(head):
        sys.exit('build.py: the Lua must start with %r (Bingus Shared Loader finds the addon by it)' % head.strip())
    reps = [("local VERSION = '%s'" % VERSION, "local VERSION = '%s'" % full)]
    for a, b in reps:
        assert src.count(a) == 1, a
        src = src.replace(a, b)
    built = os.path.join(out, 'addon.built.lua')
    open(built, 'w', encoding='utf-8', newline='\n').write(src)
    check_lua(built)
    # (2.0.0) mod manager option: the core (required, the option's own folder) with two picks, Swap, Don't Drop (the
    # default) and Drop the Expendable, each a flag addon in its own folder; the core swaps unless Drop is installed
    flags = []
    for f, a in (('swap.lua', SWAP_ADDON), ('drop.lua', DROP_ADDON)):
        t = open(os.path.join(HERE, 'lua', f), encoding='utf-8').read()
        if not t.startswith('-- HD2-Addon: %s\n' % a):
            sys.exit('build.py: lua/%s must start with -- HD2-Addon: %s' % (f, a))
        flags.append(t)
    patches = []
    for folder, addon, text in (('Core', ADDON, src), ('Swap', SWAP_ADDON, flags[0]), ('Drop', DROP_ADDON, flags[1])):
        toc, gpu, stream = patch_writer.write([(resource_hash(addon), LUA, lua_resource(text), b'', b'', 16)], [(LUA, 16)])
        patch_writer.check(toc, gpu, stream)
        os.makedirs(os.path.join(pkg, folder))
        base = os.path.join(pkg, folder, '9ba626afa44a3aa3.patch_0')
        open(base, 'wb').write(toc); open(base + '.gpu_resources', 'wb').write(gpu); open(base + '.stream', 'wb').write(stream)
        patches += [base, base + '.gpu_resources', base + '.stream']
    option_icons(pkg)
    art = os.path.join(HERE, 'artwork', 'icon.png')
    if os.path.exists(art):                   # the release art, 512x512 (Arsenal shows it small)
        Image.open(art).convert('RGB').resize((512, 512), Image.LANCZOS).save(os.path.join(pkg, 'icon.png'), optimize=True)
    else:
        icon('').save(os.path.join(pkg, 'icon.png'), optimize=True)
    man = {'Version': 1, 'Guid': guid, 'Name': 'Expendable Carry ' + full,
           'Description': ('Carry two: pick up an expendable (EAT-17, EAT-700, EAT-411, MGX-42, MLS-4X, the Solo Silo remote) and your own '
                           'support weapon goes onto your back. Your support weapon key (or a tap of switch weapon on a controller) swaps '
                           "what's in your hands with what's on your back: your support weapon and one expendable, or two expendables. Use "
                           'the expendable up and your weapon stays on your back. Joined games: the key asks the host for the other item '
                           'back. Pick Drop the Expendable for the classic way: the key drops the expendable and brings your weapon back. '
                           'Requires Bingus Shared Loader v19 or newer.'),
           'IconPath': 'icon.png',
           # (2.0.0) one option, the mod itself, with two picks: Swap, Don't Drop first (the default), Drop the Expendable
           'Options': [{'Name': 'Expendable Carry (required)', 'Image': 'options/core.png', 'Include': ['Core'],
                        'Description': 'The mod itself: keep this ticked, and pick what your support weapon key does.',
                        'SubOptions': [{'Name': "Swap, Don't Drop", 'Description': cycle_text(src) + ' The default.',
                                        'Image': 'options/cycle.png', 'Include': ['Swap']},
                                       {'Name': 'Drop the Expendable',
                                        'Description': 'Your support weapon key drops the expendable and brings your support weapon '
                                                       'back, and switching to your primary or secondary drops it too (the way the mod '
                                                       'worked before 2.0).',
                                        'Image': 'options/drop.png', 'Include': ['Drop']}]}]}
    open(os.path.join(pkg, 'manifest.json'), 'w', encoding='utf-8', newline='\n').write(json.dumps(man, indent=2))
    check_private(patches + [os.path.join(pkg, 'manifest.json')])
    z = os.path.join(out, name)
    files = []
    for dp, dn, fn in os.walk(pkg):
        dn.sort()
        for f in fn: files.append(os.path.relpath(os.path.join(dp, f), pkg).replace(os.sep, '/'))
    with zipfile.ZipFile(z, 'w', zipfile.ZIP_DEFLATED) as zf:
        for f in sorted(files):
            zi = zipfile.ZipInfo(f, ZIP_DATE)
            zi.compress_type, zi.create_system, zi.external_attr = zipfile.ZIP_DEFLATED, 0, 0o644 << 16
            zf.writestr(zi, open(os.path.join(pkg, f), 'rb').read())
    print(z, os.path.getsize(z))


if __name__ == '__main__':
    main()
