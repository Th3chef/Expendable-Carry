"""Expendable Carry release art: the scene, a flat illustration. A dusky battlefield (warm haze over dark hills,
smoke, two stratagem beams far off) and, in front, two equipment slots as the game draws them: the expendable in
your hands (the EAT-17) and your own support weapon on your back (the RS-422 Railgun), the game's own stratagem
silhouettes, with the support weapon key (3) and swap arrows between them. hero(W, H, cx, cy, s) -> RGB image, the
slots centered at (cx, cy), s = one slot's width. The title and the other text are added by the HTML cards
(cards.py). Drawn at 2x and scaled down. The weapon silhouettes are the red layer of the game's HUD stratagem icons
(icons/, extracted from the game with Filediver: they are the game's own art, not shipped in the mod)."""
import math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy.ndimage import gaussian_filter, label

HERE = os.path.dirname(os.path.abspath(__file__))
YELLOW = (255, 231, 16)
INK = (14, 16, 18)
PALE = (236, 230, 214)
ANTON = os.path.join(HERE, '..', 'fonts', 'anton-latin-400-normal.ttf')


def noise(w, h, sigma, seed):
    rnd = np.random.default_rng(seed)
    a = gaussian_filter(rnd.standard_normal((h, w)), sigma)
    return (a - a.min()) / (a.max() - a.min() + 1e-9)


def glow(base, layer, radius, strength=1.0):
    """Screen-blend a blurred copy of an RGB layer (black = nothing) onto base."""
    g = np.asarray(layer.filter(ImageFilter.GaussianBlur(radius)), float) * strength
    b = np.asarray(base, float)
    out = 255 - (255 - b) * (255 - np.clip(g, 0, 255)) / 255
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def silhouette(name, width):
    """the weapon silhouette (the icon's red layer), cropped, scaled to width, as a smooth alpha mask"""
    im = Image.open(os.path.join(HERE, 'icons', name + '.png')).convert('RGB')
    r, g, b = [np.asarray(c, float) for c in im.split()]
    m = np.clip((r - np.maximum(g, b)) / 255.0, 0, 1)
    lab, n = label(m > 0.3)                                   # the weapon only: its largest shape (not the small
    if n > 1:                                                  # 'support weapon drop' glyph some icons carry)
        sizes = np.bincount(lab.ravel())[1:]
        m = m * (lab == (np.argmax(sizes) + 1))
    ys, xs = np.nonzero(m > 0.3)
    m = m[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h = int(round(m.shape[0] * width / m.shape[1]))
    big = Image.fromarray((m * 255).astype(np.uint8)).resize((width, max(1, h)), Image.LANCZOS)
    big = big.filter(ImageFilter.GaussianBlur(width / 900))
    a = np.asarray(big, float) / 255
    a = np.clip((a - 0.35) / 0.3, 0, 1)                        # crisp edge after the upscale
    return Image.fromarray((a * 255).astype(np.uint8))


def background(W2, H2, horizon, seed):
    yy = np.linspace(0, 1, H2)[:, None]
    top, mid, low = np.array([16, 22, 34.]), np.array([58, 52, 58.]), np.array([196, 120, 62.])
    t = np.clip(yy / (horizon / H2), 0, 1)
    sky = top + (mid - top) * np.clip(t * 1.4, 0, 1)[..., None] + (low - mid) * np.clip((t - 0.55) / 0.45, 0, 1)[..., None] ** 1.6
    img = np.repeat(sky, W2, axis=1).reshape(H2, W2, 3)
    # clouds: soft noise bands in the upper sky
    n = noise(W2 // 4, H2 // 4, 9, seed)
    n = np.asarray(Image.fromarray((n * 255).astype(np.uint8)).resize((W2, H2), Image.BILINEAR), float) / 255
    cl = np.clip((n - 0.55) * 2.2, 0, 1) * np.clip(1 - yy / (horizon / H2) * 1.1, 0, 1)
    img = img * (1 - cl[..., None] * 0.35) + np.array([90, 80, 86.]) * cl[..., None] * 0.35
    return img


def hills(img, W2, horizon, seed, layers):
    rnd = np.random.default_rng(seed)
    H2 = img.shape[0]
    xs = np.arange(W2)
    for k, (base, amp, col, haze) in enumerate(layers):
        ph = rnd.uniform(0, 6.28, 3)
        f = rnd.uniform(0.6, 1.4, 3)
        y = (horizon + base + amp * (0.55 * np.sin(xs / W2 * 6.28 * f[0] + ph[0]) + 0.3 * np.sin(xs / W2 * 6.28 * 2.7 * f[1] + ph[1])
             + 0.15 * np.sin(xs / W2 * 6.28 * 7.3 * f[2] + ph[2])))
        rows = np.arange(H2)[:, None]
        mask = rows >= y[None, :]
        c = np.array(col, float)
        img[mask] = img[mask] * haze + c * (1 - haze)
    return img


def beam(d, x, top, bottom, w, col):
    for i in range(6):
        ww = w * (1 - i / 6)
        a = int(40 + i * 30)
        d.rectangle((x - ww, top, x + ww, bottom), fill=tuple(int(v * a / 255) for v in col))


def slot(img, x0, y0, w, h, k):
    """a HUD equipment slot: dark glass, a yellow frame with cut corners"""
    d = ImageDraw.Draw(img, 'RGBA')
    c = 0.09 * h
    poly = [(x0 + c, y0), (x0 + w, y0), (x0 + w, y0 + h - c), (x0 + w - c, y0 + h), (x0, y0 + h), (x0, y0 + c)]
    d.polygon(poly, fill=(10, 12, 16, 196))
    d.line(poly + [poly[0]], fill=YELLOW + (255,), width=max(2, int(5 * k)), joint='curve')
    # inner hairline and corner ticks
    m = 0.045 * h
    d.rectangle((x0 + m + c * 0.6, y0 + m, x0 + w - m, y0 + h - m - c * 0.6), outline=(255, 231, 16, 70), width=max(1, int(2 * k)))


def tint(mask, col, alpha=255):
    layer = Image.new('RGBA', mask.size, col + (0,))
    a = np.asarray(mask, float) * alpha / 255
    layer.putalpha(Image.fromarray(a.astype(np.uint8)))
    return layer


def arrow_arc(d, cx, cy, r, a0, a1, w, col):
    pts = [(cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))) for a in np.linspace(a0, a1, 40)]
    d.line(pts, fill=col, width=int(w), joint='curve')
    # arrow head at the end, along the arc's direction
    ex, ey = pts[-1]
    px, py = pts[-3]
    ang = math.atan2(ey - py, ex - px)
    L = w * 2.6
    head = [(ex + L * math.cos(ang), ey + L * math.sin(ang)),
            (ex + L * 0.9 * math.cos(ang + 2.3), ey + L * 0.9 * math.sin(ang + 2.3)),
            (ex + L * 0.9 * math.cos(ang - 2.3), ey + L * 0.9 * math.sin(ang - 2.3))]
    d.polygon(head, fill=col)


def hero(W, H, cx, cy, s, seed=7, labels=True):
    k = 2
    W2, H2, cx, cy, s = W * k, H * k, cx * k, cy * k, s * k
    horizon = int(H2 * 0.62)
    img = background(W2, H2, horizon, seed)
    img = hills(img, W2, horizon, seed, [(-0.10 * H2, 0.05 * H2, (70, 52, 50), 0.35),
                                         (-0.03 * H2, 0.05 * H2, (44, 36, 38), 0.2),
                                         (0.06 * H2, 0.04 * H2, (26, 24, 26), 0.0)])
    # ground grain
    g = noise(W2 // 2, H2 // 2, 1.2, seed + 5)
    g = np.asarray(Image.fromarray((g * 255).astype(np.uint8)).resize((W2, H2), Image.BILINEAR), float) / 255
    rows = np.arange(H2)[:, None] > horizon + 0.06 * H2
    img = img + (g[..., None] - 0.5) * 22 * rows[..., None]
    base = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
    # smoke columns and two stratagem beams far off
    lay = Image.new('RGB', (W2, H2), (0, 0, 0))
    d = ImageDraw.Draw(lay)
    rnd = np.random.default_rng(seed + 9)
    for bx, col in ((0.14, (255, 70, 40)), (0.86, (90, 170, 255))):
        x = int(W2 * (bx + rnd.uniform(-0.03, 0.03)))
        beam(d, x, int(H2 * 0.05), horizon + int(0.02 * H2), max(2, int(W2 * 0.0025)), col)
    base = glow(base, lay, 10 * k, 1.0)
    base = glow(base, lay, 2 * k, 0.9)
    smoke = Image.new('L', (W2, H2), 0)
    ds = ImageDraw.Draw(smoke)
    for i in range(5):
        x = W2 * rnd.uniform(0.05, 0.95)
        for j in range(16):
            r = H2 * (0.02 + 0.006 * j)
            yy = horizon - j * H2 * 0.02
            xx = x + math.sin(j * 0.6 + i) * r * 0.6
            ds.ellipse((xx - r, yy - r, xx + r, yy + r), fill=int(70 - j * 3))
    smoke = smoke.filter(ImageFilter.GaussianBlur(14 * k))
    sm = np.asarray(smoke, float)[..., None] / 255
    arr = np.asarray(base, float) * (1 - sm) + np.array([40, 38, 42.]) * sm
    base = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).convert('RGBA')
    # stones and tufts on the ground, smaller toward the horizon
    d0 = ImageDraw.Draw(base, 'RGBA')
    gy0 = horizon + 0.07 * H2
    for i in range(int(W2 * H2 / 40000)):
        y = gy0 + (H2 - gy0) * rnd.uniform(0, 1) ** 0.7
        x = rnd.uniform(0, W2)
        sc = 0.3 + 1.6 * (y - gy0) / (H2 - gy0 + 1)
        if rnd.uniform() < 0.6:
            r = rnd.uniform(2, 7) * sc * k
            sh = int(rnd.uniform(36, 62))
            d0.ellipse((x - r * 1.4, y - r * 0.6, x + r * 1.4, y + r * 0.6), fill=(sh, sh - 4, sh - 6, 255))
        else:
            for j in range(4):
                a = rnd.uniform(-0.9, 0.9)
                L = rnd.uniform(5, 12) * sc * k
                d0.line((x, y, x + math.sin(a) * L, y - math.cos(a) * L), fill=(52, 58, 40, 255), width=max(1, int(sc * k)))
    # vignette
    yy, xx = np.mgrid[0:H2, 0:W2]
    v = np.clip(1 - 0.55 * (((xx - W2 / 2) / (W2 / 1.6)) ** 2 + ((yy - H2 / 2) / (H2 / 1.4)) ** 2), 0.35, 1)
    arr = np.asarray(base.convert('RGB'), float) * v[..., None]
    base = Image.fromarray(arr.astype(np.uint8)).convert('RGBA')

    # the two slots
    sw, sh = s, s * 0.62
    gap = s * 0.62
    lx, rx = cx - gap / 2 - sw, cx + gap / 2
    ty = cy - sh / 2
    slot(base, lx, ty, sw, sh, k)
    slot(base, rx, ty, sw, sh, k)
    # the weapons: the EAT in your hands (lit), the Railgun on your back
    eat = silhouette('eat', int(sw * 0.82))
    rg = silhouette('railgun', int(sw * 0.82))
    for m, x0, col in ((eat, lx, YELLOW), (rg, rx, PALE)):
        px, py = int(x0 + (sw - m.size[0]) / 2), int(cy - m.size[1] / 2 + sh * 0.04)
        gl = Image.new('RGB', base.size, (0, 0, 0))
        gl.paste(tint(m, col, 150).convert('RGB'), (px, py), m)
        base = glow(base.convert('RGB'), gl, 9 * k, 0.55).convert('RGBA')
        base.alpha_composite(tint(m, col), (px, py))
    d = ImageDraw.Draw(base, 'RGBA')
    if labels:
        f = ImageFont.truetype(ANTON, int(sh * 0.12))
        for x0, t in ((lx, 'IN YOUR HANDS'), (rx, 'ON YOUR BACK')):
            tw = d.textlength(t, font=f)
            d.text((x0 + sw / 2 - tw / 2, ty + sh * 0.08), t, font=f, fill=PALE + (235,))
    # the support weapon key between them, with swap arrows
    kc = sh * 0.36
    kx, ky = cx - kc / 2, cy - kc / 2 + sh * 0.02
    d.rounded_rectangle((kx, ky + kc * 0.1, kx + kc, ky + kc * 1.1), kc * 0.16, fill=(120, 104, 10, 255))
    d.rounded_rectangle((kx, ky, kx + kc, ky + kc), kc * 0.16, fill=YELLOW + (255,), outline=INK + (255,), width=int(3 * k))
    fk = ImageFont.truetype(ANTON, int(kc * 0.72))
    tw = d.textlength('3', font=fk)
    d.text((cx - tw / 2, ky + kc * 0.06), '3', font=fk, fill=INK + (255,))
    r = kc * 1.05
    arrow_arc(d, cx, cy + sh * 0.02, r, 200, 320, kc * 0.1, YELLOW + (255,))
    arrow_arc(d, cx, cy + sh * 0.02, r, 20, 140, kc * 0.1, YELLOW + (255,))
    out = base.convert('RGB').resize((W, H), Image.LANCZOS)
    return out


if __name__ == '__main__':      # python3 hero.py <out.png>: the scene alone, for a look
    import sys
    hero(1920, 1080, 1250, 560, 520).save(sys.argv[1] if len(sys.argv) > 1 else 'hero.png')
