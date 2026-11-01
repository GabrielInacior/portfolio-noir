"""Atlas de rostos NOIR (adulto, sério, traço fino). Mesmo layout 4x2 do decalque de rosto do
modelo, mas desenho novo: olhos pequenos amendoados, pálpebra pesada, sobrancelhas grossas e retas,
boca fina, sulcos e barba por fazer.
Uso: python tools/art/noir_faces.py  ->  game/assets/characters/{eyes,mouth}_atlas_noir[_f].png
Células (col,lin):
 olhos: serio(0,0) sorriso_canto(1,0) intrigado(2,0) desconfiado(3,0) pensativo(0,1) cansado(1,1) firme(2,1) piscando(3,1)
 boca : serio(0,0) sorriso_canto(1,0) falaA(2,0) intrigado(3,0) cansado(0,1) desconfiado(1,1) pensativo(2,1) falaE(3,1)
"""
import math
import os
import random

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "game", "assets", "characters")
SS = 4
C = 256
CS = C * SS
INK = (16, 13, 22, 255)
LINE = (40, 30, 36, 255)
WHITE = (226, 220, 210, 255)


def P(x, y):
    return (x * SS, y * SS)


def arc_pts(cx, cy, w, h, a0, a1, n=24):
    return [P(cx + math.cos(math.radians(a0 + (a1 - a0) * i / n)) * w,
              cy + math.sin(math.radians(a0 + (a1 - a0) * i / n)) * h) for i in range(n + 1)]


def eye(cell, cx, cy, side, lid=0.0, low=0.0, look=(0, 0), closed=False, iris=(64, 44, 34), fem=False, bag=False):
    d = ImageDraw.Draw(cell)
    w, h = 30.0, 12.5
    if closed:
        d.line(arc_pts(cx, cy + 1, w, 4, 0, 180), fill=INK, width=5 * SS, joint="curve")
        return
    top_y = cy - h + lid * h * 1.6
    bot_y = cy + h - low * h * 1.1
    upper, lower = [], []
    for i in range(21):
        t = i / 20
        x = cx - w + 2 * w * t
        k = (abs(t - 0.45) / 0.55) ** 1.8
        upper.append((x, top_y + (cy - top_y) * k))
    for i in range(21):
        t = i / 20
        x = cx + w - 2 * w * t
        k = (abs(t - 0.5) / 0.5) ** 1.6
        lower.append((x, bot_y - (bot_y - cy) * k))
    if side < 0:
        upper = [(2 * cx - x, y) for x, y in upper]
        lower = [(2 * cx - x, y) for x, y in lower]
    up = [P(x, y) for x, y in upper]
    lo = [P(x, y) for x, y in lower]
    shape = up + lo
    mask = Image.new("L", (CS, CS), 0)
    ImageDraw.Draw(mask).polygon(shape, fill=255)
    layer = Image.new("RGBA", (CS, CS), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ld.polygon(shape, fill=WHITE)
    ix, iy = cx + look[0] * 6, cy + 0.5 + look[1] * 3
    r = 10.5
    ld.ellipse([P(ix - r, iy - r), P(ix + r, iy + r)], fill=iris + (255,))
    ld.ellipse([P(ix - r * 0.52, iy - r * 0.52), P(ix + r * 0.52, iy + r * 0.52)], fill=(12, 9, 10, 255))
    ld.ellipse([P(ix + 1.5, iy - 4.2), P(ix + 4, iy - 1.8)], fill=(255, 250, 240, 230))
    ld.rectangle([P(cx - w - 2, top_y - 3), P(cx + w + 2, top_y + 3.4)], fill=(34, 24, 28, 130))
    cell.paste(layer, (0, 0), mask)
    d.line(up, fill=INK, width=int(6.0 * SS), joint="curve")
    d.line(lo, fill=LINE, width=int(1.6 * SS), joint="curve")
    d.line([P(cx - w * 0.85, top_y - 5.5), P(cx, top_y - 7.5 + lid * 2), P(cx + w * 0.9, top_y - 6)],
           fill=(60, 44, 46, 190), width=int(1.6 * SS), joint="curve")
    if fem:
        ox = cx + side * w
        for k in range(3):
            d.line([P(ox - side * k * 3.5, top_y + 2 + k * 1.2), P(ox + side * (4 - k), top_y - 4 + k * 1.5)],
                   fill=INK, width=int(2.2 * SS))
    if bag or not fem:
        d.line(arc_pts(cx, bot_y + 4.5, w * 0.75, 3.2 + (2 if bag else 0), 20, 160),
               fill=(70, 50, 52, 170 if bag else 105), width=int(1.4 * SS))


def brow(cell, cx, cy, side, tilt=0.0, raise_=0.0, fem=False):
    d = ImageDraw.Draw(cell)
    w = 30.0
    inner = cx - side * w * 0.95
    outer = cx + side * w * 1.05
    yi = cy - raise_ + tilt * 7
    yo = cy - raise_ - tilt * 3 + 1
    mid = (inner + outer) / 2
    ym = (yi + yo) / 2 - 3 - (4 if fem else 0)
    t = 9.0 * (0.62 if fem else 1.0)

    def bez(a, b, c, n=12):
        out = []
        for i in range(n + 1):
            u = i / n
            out.append(((1 - u) ** 2 * a[0] + 2 * (1 - u) * u * b[0] + u * u * c[0],
                        (1 - u) ** 2 * a[1] + 2 * (1 - u) * u * b[1] + u * u * c[1]))
        return out
    top = bez((inner, yi - t * 0.55), (mid, ym - t * 0.7), (outer, yo - t * 0.1))
    bot = bez((outer, yo + t * 0.2), (mid, ym + t * 0.5), (inner, yi + t * 0.55))
    d.polygon([P(x, y) for x, y in top + bot], fill=(22, 17, 24, 255))
    rnd = random.Random(int(cx * 7 + cy))
    for _ in range(8 if fem else 18):
        u = rnd.random()
        x = inner + (outer - inner) * u
        y = yi + (yo - yi) * u
        d.line([P(x, y + t * 0.3), P(x + side * 4, y - t * 0.5)], fill=(48, 36, 42, 255), width=SS)


EYES = [
    ("serio", dict(lid=0.32, br=dict(tilt=0.15))),
    ("sorriso_canto", dict(lid=0.22, low=0.35, br=dict(tilt=-0.05, raise_=1), br_r=dict(raise_=4))),
    ("intrigado", dict(lid=0.1, br=dict(tilt=0.35), br_r=dict(raise_=9, tilt=-0.4), look=(0.2, 0))),
    ("desconfiado", dict(lid=0.5, low=0.3, br=dict(tilt=0.55, raise_=-2), look=(-0.5, 0.1))),
    ("pensativo", dict(lid=0.25, br=dict(tilt=-0.35, raise_=3), look=(0.7, -0.6))),
    ("cansado", dict(lid=0.6, low=0.1, bag=True, br=dict(tilt=-0.5, raise_=-1))),
    ("firme", dict(lid=0.38, low=0.2, br=dict(tilt=0.9, raise_=-4))),
    ("piscando", dict(closed=True, br=dict(tilt=0.1))),
]


def eyes_atlas(fem):
    img = Image.new("RGBA", (CS * 4, CS * 2), (0, 0, 0, 0))
    for i, (_, p) in enumerate(EYES):
        cell = Image.new("RGBA", (CS, CS), (0, 0, 0, 0))
        for side, cx in [(-1, 80), (1, 176)]:
            bp = p["br_r"] if side > 0 and "br_r" in p else p.get("br", {})
            brow(cell, cx, 100, side, fem=fem, **bp)
            eye(cell, cx, 150, side, lid=p.get("lid", 0), low=p.get("low", 0), look=p.get("look", (0, 0)),
                closed=p.get("closed", False), fem=fem, bag=p.get("bag", False),
                iris=(52, 66, 54) if fem else (64, 44, 34))
        img.paste(cell, ((i % 4) * CS, (i // 4) * CS))
    img.resize((C * 4, C * 2), Image.LANCZOS).save(os.path.join(OUT, "eyes_atlas_noir%s.png" % ("_f" if fem else "")))


MOUTH = [
    ("serio", dict(curve=-1.5)),
    ("sorriso_canto", dict(curve=0, corner=6)),
    ("falaA", dict(open_=9)),
    ("intrigado", dict(open_=4, narrow=0.55)),
    ("cansado", dict(curve=-3.5, lower=True)),
    ("desconfiado", dict(curve=-1, shift=7, narrow=0.6, corner=-3)),
    ("pensativo", dict(curve=-0.5, narrow=0.75, press=True, shift=-3)),
    ("falaE", dict(open_=5, wide=True)),
]


def mouth_atlas(fem):
    img = Image.new("RGBA", (CS * 4, CS * 2), (0, 0, 0, 0))
    for i, (_, p) in enumerate(MOUTH):
        cell = Image.new("RGBA", (CS, CS), (0, 0, 0, 0))
        d = ImageDraw.Draw(cell)
        cx, cy = 128 + p.get("shift", 0), 146
        w = 30 * p.get("narrow", 1.0) * (1.15 if p.get("wide") else 1.0)
        if not fem:
            rnd = random.Random(i * 13 + 5)
            for _ in range(900):
                a = rnd.uniform(0, math.tau)
                rr = rnd.uniform(0, 1) ** 0.6
                x = 128 + math.cos(a) * 78 * rr
                y = 160 + math.sin(a) * 56 * rr
                if y < 112 or (abs(x - cx) < w * 0.9 and abs(y - cy) < 7):
                    continue
                s = rnd.uniform(0.6, 1.3)
                d.ellipse([P(x - s, y - s), P(x + s, y + s)], fill=(30, 24, 30, rnd.randint(50, 110)))
        for side in (-1, 1):
            x0 = 128 + side * 46
            d.line([P(x0, 92), P(x0 + side * 6, 122), P(x0 + side * 3, 150)], fill=(60, 42, 44, 120),
                   width=int(1.6 * SS), joint="curve")
        lipc = (150, 70, 74, 255) if fem else (120, 72, 66, 255)
        if p.get("open_"):
            oh = p["open_"]
            d.ellipse([P(cx - w * 0.75, cy - oh * 0.5), P(cx + w * 0.75, cy + oh)], fill=(40, 16, 20, 255),
                      outline=INK, width=int(3 * SS))
            d.rectangle([P(cx - w * 0.45, cy - oh * 0.35), P(cx + w * 0.45, cy - oh * 0.02)], fill=(225, 216, 200, 255))
        else:
            c = p.get("curve", 0)
            cr = p.get("corner", 0)
            pts = []
            for k in range(21):
                u = k / 20
                x = cx - w + 2 * w * u
                y = cy - c * (1 - (2 * u - 1) ** 2)
                if u > 0.75:
                    y -= cr * ((u - 0.75) / 0.25) ** 2
                pts.append(P(x, y))
            if fem:
                d.line([(x, y + 5 * SS) for x, y in pts[3:-3]], fill=lipc, width=int(4 * SS), joint="curve")
            d.line(pts, fill=INK, width=int((3.6 if p.get("press") else 3.0) * SS), joint="curve")
            if p.get("lower") or not fem:
                d.line([P(cx - w * 0.35, cy + 10), P(cx + w * 0.35, cy + 10)], fill=(70, 48, 50, 140), width=int(1.6 * SS))
        img.paste(cell, ((i % 4) * CS, (i // 4) * CS))
    img.resize((C * 4, C * 2), Image.LANCZOS).save(os.path.join(OUT, "mouth_atlas_noir%s.png" % ("_f" if fem else "")))


if __name__ == "__main__":
    for fem in (False, True):
        eyes_atlas(fem)
        mouth_atlas(fem)
    print("ok")
