"""Expendable Carry release art: thumbnail (1254x1254), gallery photo (1920x1080), the GitHub social preview
(1280x640) and the AyakaMods cover (1600x1000: the site's mod cards crop the cover to a 200 px high box from about
1.2:1 to 2:1 wide, so the title and the slots sit in the middle 1190x800). No hazard stripes. The scene
comes from hero.py (a flat illustration); the title, version badge and text are HTML rendered with Playwright
Chromium (Anton + Barlow Condensed in fonts/, SIL Open Font License, from @fontsource).
python cards.py <out dir> [version badge, e.g. 1.0]"""
import base64, io, os, sys
from playwright.sync_api import sync_playwright
import hero

HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = {'Anton': 'fonts/anton-latin-400-normal.woff2',
         'Barlow Condensed': 'fonts/barlow-condensed-latin-600-normal.woff2',
         'Barlow Condensed B': 'fonts/barlow-condensed-latin-800-normal.woff2'}

TAGLINE = 'Keep your support weapon on your back'
FEATURES = ['EAT-17 / 700 / 411', 'MGX-42', 'MLS-4X', 'SOLO SILO REMOTE', 'TWO AT ONCE', "SWAP, DON'T DROP"]


def b64(path_or_img):
    if isinstance(path_or_img, str):
        return base64.b64encode(open(os.path.join(HERE, path_or_img), 'rb').read()).decode()
    buf = io.BytesIO(); path_or_img.save(buf, 'PNG'); return base64.b64encode(buf.getvalue()).decode()


def font_css():
    return '\n'.join("@font-face{font-family:'%s';src:url(data:font/woff2;base64,%s) format('woff2');}" % (n, b64(f))
                     for n, f in FONTS.items())


CSS = """
* { margin:0; padding:0; box-sizing:border-box; }
body { width:%(W)dpx; height:%(H)dpx; overflow:hidden; background:#000; position:relative; }
.bg { position:absolute; inset:0; background:url(data:image/png;base64,%(bg)s) no-repeat; background-size:100%% 100%%; }
.title { font-family:'Anton'; color:#ffe710; letter-spacing:0.02em; line-height:0.95; text-transform:uppercase;
  text-shadow: 0 0.04em 0 #000, 0 0 0.12em rgba(0,0,0,.9), 0 0 0.35em rgba(0,0,0,.6); }
.badge { display:inline-block; font-family:'Barlow Condensed B'; background:#ffe710; color:#111; padding:0.04em 0.32em 0.02em;
  border:0.06em solid #111; box-shadow:0 0.08em 0.25em rgba(0,0,0,.6); letter-spacing:0.03em; }
.feat { font-family:'Barlow Condensed B'; color:#111; display:flex; flex-wrap:wrap; gap:0.35em; }
.feat span { background:rgba(255,231,16,.95); padding:0.06em 0.4em 0.02em; border:0.05em solid #111; letter-spacing:0.04em;
  box-shadow:0 0.06em 0.2em rgba(0,0,0,.55); white-space:nowrap; }
.band { display:inline-block; padding:0.3em 0.68em 0.26em; background:linear-gradient(rgba(8,10,14,.6),rgba(8,10,14,.48));
  border-top:0.08em solid #ffe710; border-bottom:0.08em solid #ffe710; box-shadow:0 6px 24px rgba(0,0,0,.55);
  font-family:'Barlow Condensed B'; letter-spacing:0.12em; text-transform:uppercase; color:#eadfc8; text-shadow:0 2px 3px #000;
  white-space:nowrap; }
.plate { position:absolute; background:linear-gradient(rgba(8,10,14,.84),rgba(8,10,14,.74)); border:3px solid #ffe710;
  box-shadow:0 8px 30px rgba(0,0,0,.6); }
"""


def render(page, W, H, bg, body):
    html = '<html><head><style>%s\n%s</style></head><body><div class="bg"></div>%s</body></html>' % (
        font_css(), CSS % {'W': W, 'H': H, 'bg': b64(bg)}, body)
    page.set_viewport_size({'width': W, 'height': H})
    page.set_content(html)
    page.wait_for_timeout(300)
    return page.screenshot(type='png')


def feats(size, center=False):
    return '<div class="feat" style="font-size:%dpx;%s">%s</div>' % (size, 'justify-content:center' if center else '',
                                                                     ''.join('<span>%s</span>' % f for f in FEATURES))


def main():
    out = sys.argv[1]
    ver = sys.argv[2] if len(sys.argv) > 2 else '1.0'
    os.makedirs(out, exist_ok=True)
    jobs = []
    # square thumbnail: the title at the top, the two slots in the middle, the tagline and features at the bottom
    W = H = 1254
    bg = hero.hero(W, H, 627, 690, 410, seed=7)
    jobs.append(('thumbnail.png', W, H, bg, """
      <div style="position:absolute;left:0;right:0;top:70px;text-align:center">
        <div class="title" style="font-size:156px;white-space:nowrap">Expendable</div>
        <div style="display:flex;justify-content:center;align-items:flex-start;gap:26px;margin-top:6px">
          <div class="title" style="font-size:156px;white-space:nowrap">Carry</div>
          <span class="badge" style="font-size:54px;margin-top:12px">v%(v)s</span></div>
      </div>
      <div style="position:absolute;left:0;right:0;bottom:150px;text-align:center">
        <span class="band" style="font-size:46px">%(t)s</span></div>
      <div style="position:absolute;left:40px;right:40px;bottom:58px">%(f)s</div>""" % {'v': ver, 't': TAGLINE, 'f': feats(34, True)}))
    # gallery photo 16:9: the slots on the right, the text on the left
    W, H = 1920, 1080
    bg = hero.hero(W, H, 1320, 560, 400, seed=11)
    jobs.append(('gallery_1920x1080.png', W, H, bg, """
      <div class="plate" style="left:70px;top:170px;width:600px;padding:44px 40px 46px">
        <div class="title" style="font-size:104px">Expendable<br>Carry</div>
        <div style="margin:26px 0 30px"><span class="badge" style="font-size:46px">v%(v)s</span></div>
        <span class="band" style="font-size:24px">%(t)s</span>
        <div style="margin-top:34px">%(f)s</div>
      </div>""" % {'v': ver, 't': TAGLINE, 'f': feats(28)}))
    # GitHub social preview 2:1 (40 px clear at the edges)
    W, H = 1280, 640
    bg = hero.hero(W, H, 905, 330, 245, seed=5)
    jobs.append(('GitHub-Social-1280x640.png', W, H, bg, """
      <div class="plate" style="left:48px;top:70px;width:440px;padding:30px 28px 32px">
        <div class="title" style="font-size:72px">Expendable<br>Carry</div>
        <div style="margin:18px 0 20px"><span class="badge" style="font-size:34px">v%(v)s</span></div>
        <span class="band" style="font-size:18px">%(t)s</span>
        <div style="margin-top:22px">%(f)s</div>
      </div>""" % {'v': ver, 't': TAGLINE, 'f': feats(19)}))
    # AyakaMods cover 1.6:1: everything that matters inside the middle 1190x800
    W, H = 1600, 1000
    bg = hero.hero(W, H, 800, 600, 400, seed=13)
    jobs.append(('AyakaMods-Cover-1600x1000.png', W, H, bg, """
      <div style="position:absolute;left:0;right:0;top:150px;display:flex;justify-content:center;align-items:flex-start;gap:22px">
        <div class="title" style="font-size:118px;white-space:nowrap">Expendable Carry</div>
        <span class="badge" style="font-size:44px;margin-top:8px">v%(v)s</span></div>
      <div style="position:absolute;left:0;right:0;bottom:170px;text-align:center">
        <span class="band" style="font-size:34px">%(t)s</span></div>""" % {'v': ver, 't': TAGLINE}))
    with sync_playwright() as p:
        b = p.chromium.launch()
        page = b.new_page()
        for name, W, H, bg, body in jobs:
            open(os.path.join(out, name), 'wb').write(render(page, W, H, bg, body))
            print(name)
        b.close()


if __name__ == '__main__':
    main()
