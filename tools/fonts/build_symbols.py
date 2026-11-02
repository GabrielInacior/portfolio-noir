"""Gera assets/fonts/NoirSymbols.ttf: fonte própria só com os símbolos da interface (desenhados aqui
como polígonos), usada como fallback das fontes de texto. No navegador o Godot não tem fonte do
sistema para completar glifos, e ✕ ↗ ▶ ★ viravam quadrados. Uso: python tools/fonts/build_symbols.py"""
import math
import os

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "game", "assets", "fonts", "NoirSymbols.ttf")
UPM = 1000
ADV = 900


def poly(pen, pts):
    pen.moveTo(pts[0])
    for p in pts[1:]:
        pen.lineTo(p)
    pen.closePath()


def bar(pen, a, b, w):
    """retângulo de espessura w ligando a -> b"""
    (x1, y1), (x2, y2) = a, b
    dx, dy = x2 - x1, y2 - y1
    ln = math.hypot(dx, dy) or 1
    nx, ny = -dy / ln * w / 2, dx / ln * w / 2
    poly(pen, [(x1 + nx, y1 + ny), (x2 + nx, y2 + ny), (x2 - nx, y2 - ny), (x1 - nx, y1 - ny)])


def circle(pen, cx, cy, r, n=20, ccw=True):
    pts = [(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n)) for i in range(n)]
    poly(pen, pts if ccw else pts[::-1])


def g_x(p):
    bar(p, (200, 120), (700, 620), 110)
    bar(p, (200, 620), (700, 120), 110)


def g_ne(p):
    bar(p, (200, 120), (640, 560), 100)
    poly(p, [(380, 640), (720, 640), (720, 300), (620, 400), (620, 540), (480, 540)])


def g_right(p):
    bar(p, (150, 370), (620, 370), 100)
    poly(p, [(560, 560), (760, 370), (560, 180)])


def g_left(p):
    bar(p, (280, 370), (750, 370), 100)
    poly(p, [(340, 560), (140, 370), (340, 180)][::-1])


def g_tri_r(p):
    poly(p, [(220, 660), (720, 370), (220, 80)][::-1])


def g_tri_r_small(p):
    poly(p, [(300, 560), (640, 370), (300, 180)][::-1])


def g_tri_l(p):
    poly(p, [(680, 660), (180, 370), (680, 80)])


def g_star(p):
    pts = []
    for i in range(10):
        r = 340 if i % 2 == 0 else 140
        a = math.pi / 2 + i * math.pi / 5
        pts.append((450 + r * math.cos(a), 360 + r * math.sin(a)))
    poly(p, pts[::-1])


def g_note(p):
    circle(p, 330, 170, 120, ccw=False)
    bar(p, (430, 170), (430, 680), 70)
    poly(p, [(465, 680), (680, 600), (680, 500), (465, 580)][::-1])


def g_phone(p):
    bar(p, (200, 520), (700, 520), 120)
    poly(p, [(150, 600), (300, 600), (300, 420), (150, 420)][::-1])
    poly(p, [(600, 600), (750, 600), (750, 420), (600, 420)][::-1])
    poly(p, [(260, 360), (640, 360), (720, 100), (180, 100)][::-1])


def g_half(p):
    poly(p, [(100, 760), (450, 760), (450, -160), (100, -160)][::-1])


def g_check(p):
    bar(p, (160, 380), (360, 160), 110)
    bar(p, (330, 170), (740, 640), 110)


def g_menu(p):
    for y in (160, 370, 580):
        poly(p, [(170, y + 55), (730, y + 55), (730, y - 55), (170, y - 55)][::-1])


def g_speaker_off(p):
    poly(p, [(140, 470), (300, 470), (480, 640), (480, 100), (300, 270), (140, 270)][::-1])
    bar(p, (560, 250), (780, 490), 80)
    bar(p, (560, 490), (780, 250), 80)


def g_speaker(p):
    poly(p, [(140, 470), (300, 470), (480, 640), (480, 100), (300, 270), (140, 270)][::-1])
    bar(p, (580, 260), (640, 370), 60)
    bar(p, (640, 370), (580, 480), 60)
    bar(p, (680, 180), (780, 370), 60)
    bar(p, (780, 370), (680, 560), 60)


def g_dot(p):
    circle(p, 450, 360, 150, ccw=False)


GLYPHS = {
    0x2715: g_x, 0x2716: g_x, 0x00D7: g_x,
    0x2197: g_ne, 0x2192: g_right, 0x2190: g_left,
    0x25B6: g_tri_r, 0x25B8: g_tri_r_small, 0x25C0: g_tri_l,
    0x2605: g_star, 0x266A: g_note, 0x260E: g_phone, 0x258C: g_half,
    0x2713: g_check, 0x2714: g_check, 0x25CF: g_dot,
    0x2630: g_menu, 0x1F507: g_speaker_off, 0x1F50A: g_speaker,
}


def main():
    order = [".notdef", "space"] + ["u%04X" % cp for cp in GLYPHS]
    fb = FontBuilder(UPM, isTTF=True)
    fb.setupGlyphOrder(order)
    cmap = {0x20: "space"}
    cmap.update({cp: "u%04X" % cp for cp in GLYPHS})
    fb.setupCharacterMap(cmap)
    glyphs, metrics = {}, {}
    empty = TTGlyphPen(None)
    empty.moveTo((0, 0)); empty.lineTo((0, 1)); empty.lineTo((1, 1)); empty.closePath()
    glyphs[".notdef"] = TTGlyphPen(None).glyph()
    glyphs["space"] = TTGlyphPen(None).glyph()
    metrics[".notdef"] = (ADV, 0)
    metrics["space"] = (300, 0)
    for cp, fn in GLYPHS.items():
        pen = TTGlyphPen(None)
        fn(pen)
        glyphs["u%04X" % cp] = pen.glyph()
        metrics["u%04X" % cp] = (ADV, 60)
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=800, descent=-200)
    fb.setupNameTable({"familyName": "NoirSymbols", "styleName": "Regular"})
    fb.setupOS2(sTypoAscender=800, sTypoDescender=-200, usWinAscent=800, usWinDescent=200)
    fb.setupPost()
    fb.save(OUT)
    print("ok", OUT, len(GLYPHS), "glifos")


if __name__ == "__main__":
    main()
