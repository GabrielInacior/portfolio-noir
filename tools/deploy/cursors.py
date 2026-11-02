"""Cursores noir/neon (padrão, apontar, texto, arrastar, carregando) em 32 e 64 px para o Godot e para o
carregador HTML. Uso: python tools/deploy/cursors.py"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "ui")
WEB = os.path.join(ROOT, "game", "shell")
YEL, PINK, INK, WHITE = (255, 200, 61), (255, 79, 163), (8, 10, 22), (240, 242, 250)


def glowify(img, col, r):
    a = img.split()[3].filter(ImageFilter.GaussianBlur(r))
    g = Image.new("RGBA", img.size, col + (0,))
    g.putalpha(a.point(lambda v: int(v * 0.8)))
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.alpha_composite(g)
    out.alpha_composite(img)
    return out


def arrow(s):
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    k = s / 32
    pts = [(3, 2), (3, 25), (9.5, 19), (13.5, 28), (17, 26.5), (13, 17.5), (21.5, 17.5)]
    pts = [(x * k, y * k) for x, y in pts]
    d.polygon(pts, fill=INK + (255,), outline=YEL + (255,), width=max(2, int(2 * k)))
    return glowify(im, YEL, 2 * k), (int(3 * k), int(2 * k))


def hand(s):
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    k = s / 32
    c = (s / 2, s / 2)
    r = 10 * k
    d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], outline=PINK + (255,), width=max(2, int(2.2 * k)))
    for a in range(4):
        ang = a * math.pi / 2
        x0, y0 = c[0] + math.cos(ang) * 5 * k, c[1] + math.sin(ang) * 5 * k
        x1, y1 = c[0] + math.cos(ang) * 14 * k, c[1] + math.sin(ang) * 14 * k
        d.line([(x0, y0), (x1, y1)], fill=PINK + (255,), width=max(2, int(2 * k)))
    d.ellipse([c[0] - 2 * k, c[1] - 2 * k, c[0] + 2 * k, c[1] + 2 * k], fill=YEL + (255,))
    return glowify(im, PINK, 2.5 * k), (s // 2, s // 2)


def ibeam(s):
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    k = s / 32
    x = s / 2
    w = max(2, int(2 * k))
    d.line([(x, 5 * k), (x, 27 * k)], fill=YEL + (255,), width=w)
    for y in (5 * k, 27 * k):
        d.line([(x - 5 * k, y), (x + 5 * k, y)], fill=YEL + (255,), width=w)
    return glowify(im, YEL, 1.5 * k), (s // 2, s // 2)


def drag(s):
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    k = s / 32
    c = s / 2
    w = max(2, int(2 * k))
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        tip = (c + dx * 13 * k, c + dy * 13 * k)
        d.line([(c, c), tip], fill=YEL + (255,), width=w)
        px, py = -dy, dx
        d.polygon([tip, (tip[0] - dx * 5 * k + px * 4 * k, tip[1] - dy * 5 * k + py * 4 * k),
                   (tip[0] - dx * 5 * k - px * 4 * k, tip[1] - dy * 5 * k - py * 4 * k)], fill=YEL + (255,))
    return glowify(im, YEL, 2 * k), (s // 2, s // 2)


def busy(s):
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    k = s / 32
    m = 5 * k
    d.arc([m, m, s - m, s - m], 200, 470, fill=PINK + (255,), width=max(3, int(3 * k)))
    d.arc([m, m, s - m, s - m], 20, 110, fill=YEL + (255,), width=max(3, int(3 * k)))
    return glowify(im, PINK, 2 * k), (s // 2, s // 2)


hot = {}
for name, fn in (("arrow", arrow), ("hand", hand), ("ibeam", ibeam), ("drag", drag), ("busy", busy)):
    for s in (32, 64):
        im, hs = fn(s)
        im.save(os.path.join(OUT, "cursor_%s_%d.png" % (name, s)))
        if s == 32:
            hot[name] = hs
    im32, _ = fn(32)
    im32.save(os.path.join(WEB, "cursor_%s.png" % name))
print(hot)
