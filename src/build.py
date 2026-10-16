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

VERSION = '1.1.1'
GUID_RELEASE = 'c8c1dd5a-ec87-4227-b67b-0ff28bc73feb'
LUA = 0xa14e8dfa2cd117e2
ADDON = 'mods/chef/expendable_carry'
ANTON = os.path.join(HERE, 'fonts', 'anton-latin-400-normal.ttf')
ZIP_DATE = (2026, 10, 1, 0, 0, 0)       # every zip entry's date: the same sources give the same zip, byte for byte
# never in what ships (compared in lower case; a drive letter only at the start of a word, so 'record:\\n' is no hit),
# plus the patterns in personal_patterns.txt next to this file, one a line, when there is one (kept out of the repository)
PERSONAL = [re.compile(p) for p in (rb'c:\\+users', rb'(?<![a-z0-9_])d:\\', rb'/home/', rb'/mnt/', rb'steamlibrary')]
if os.path.exists(os.path.join(HERE, 'personal_patterns.txt')):
    PERSONAL += [re.compile(l.strip().encode()) for l in open(os.path.join(HERE, 'personal_patterns.txt'), encoding='utf-8')
                 if l.strip() and not l.startswith('#')]


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
    toc, gpu, stream = patch_writer.write([(resource_hash(ADDON), LUA, lua_resource(src), b'', b'', 16)], [(LUA, 16)])
    patch_writer.check(toc, gpu, stream)
    base = os.path.join(pkg, '9ba626afa44a3aa3.patch_0')
    open(base, 'wb').write(toc); open(base + '.gpu_resources', 'wb').write(gpu); open(base + '.stream', 'wb').write(stream)
    art = os.path.join(HERE, 'artwork', 'icon.png')
    if os.path.exists(art):                   # the release art, 512x512 (Arsenal shows it small)
        Image.open(art).convert('RGB').resize((512, 512), Image.LANCZOS).save(os.path.join(pkg, 'icon.png'), optimize=True)
    else:
        icon('').save(os.path.join(pkg, 'icon.png'), optimize=True)
    man = {'Version': 1, 'Guid': guid, 'Name': 'Expendable Carry ' + full,
           'Description': ('Pick up an expendable support weapon (EAT-17, EAT-700, EAT-411, MGX-42, MLS-4X) or the Solo Silo targeting remote and keep '
                           'your own: your support weapon goes onto your back. Press your support weapon key (3, or the key you set in the game) with '
                           'the expendable in hand and your weapon is back in your hands (the expendable is dropped); '
                           'use the expendable up and your weapon stays on your back until you draw it. On a controller, '
                           'tap the switch weapon button. Switching to your primary or secondary drops the expendable. With no support weapon of your own, picking up a second expendable carries the first one the same way. In a joined game the key asks the host for your weapon back from '
                           'wherever it was set down. Requires Bingus Shared Loader v19 or newer.'),
           'IconPath': 'icon.png'}
    open(os.path.join(pkg, 'manifest.json'), 'w', encoding='utf-8', newline='\n').write(json.dumps(man, indent=2))
    check_private([base, base + '.gpu_resources', base + '.stream', os.path.join(pkg, 'manifest.json')])
    z = os.path.join(out, name)
    with zipfile.ZipFile(z, 'w', zipfile.ZIP_DEFLATED) as zf:
        for f in sorted(os.listdir(pkg)):
            zi = zipfile.ZipInfo(f, ZIP_DATE)
            zi.compress_type, zi.create_system, zi.external_attr = zipfile.ZIP_DEFLATED, 0, 0o644 << 16
            zf.writestr(zi, open(os.path.join(pkg, f), 'rb').read())
    print(z, os.path.getsize(z))


if __name__ == '__main__':
    main()
