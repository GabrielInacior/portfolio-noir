"""Rostos dos personagens PS1 (pixel art 64x64 por expressão, pintado por código).

Gera, por personagem, um atlas 512x128: 8 colunas (expressões) x 2 linhas (boca fechada / aberta para a
fala). O rosto é um decalque com transparência sobre a cabeça low-poly (tools/blender/char_ps1_build.py):
o fundo é transparente e só os traços (sobrancelha, olhos, sombra do nariz, boca, barba) são pintados.
Expressões contidas e adultas (régua do usuário: sério, nada de cara de desenho infantil).
Uso: python tools/blender/char_ps1_faces.py
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "characters", "ps1")
os.makedirs(OUT, exist_ok=True)

EXPRS = ["serio", "desconfiado", "intrigado", "pensativo", "sorriso_canto", "cansado", "firme", "neutro"]
C = 64

CHARS = {
    "vance": {"skin": (214, 160, 122), "brow": (40, 28, 22), "eye": (74, 56, 40), "beard": (52, 36, 26), "female": False},
    "lena": {"skin": (230, 182, 150), "brow": (92, 34, 26), "eye": (60, 90, 70), "lips": (150, 40, 52), "female": True},
    "otto": {"skin": (120, 74, 50), "brow": (150, 150, 150), "eye": (40, 26, 18), "mustache": (170, 168, 164), "female": False},
    "kai": {"skin": (220, 176, 136), "brow": (24, 22, 26), "eye": (40, 30, 24), "goatee": (28, 24, 26), "female": False},
    "extra1": {"skin": (190, 140, 104), "brow": (60, 44, 30), "eye": (50, 40, 30), "female": False},
    "extra2": {"skin": (236, 196, 166), "brow": (200, 170, 110), "eye": (60, 80, 120), "lips": (170, 80, 90), "female": True},
}

# por expressão: sobrancelha (altura, inclinação interna), pálpebra (0 aberto .. 1 fechado), boca
SHAPES = {
    "serio": dict(bh=0, tilt=1, lid=0.35, mouth="reta"),
    "desconfiado": dict(bh=1, tilt=2, lid=0.6, mouth="reta_baixa", asym=True),
    "intrigado": dict(bh=-2, tilt=-1, lid=0.15, mouth="pequena"),
    "pensativo": dict(bh=0, tilt=1, lid=0.45, mouth="canto_baixo", look=-2),
    "sorriso_canto": dict(bh=-1, tilt=0, lid=0.35, mouth="sorriso_canto"),
    "cansado": dict(bh=-1, tilt=-2, lid=0.7, mouth="reta_baixa"),
    "firme": dict(bh=2, tilt=3, lid=0.4, mouth="firme"),
    "neutro": dict(bh=0, tilt=0, lid=0.3, mouth="reta"),
}


def dark(c, k):
    return tuple(max(0, int(v * k)) for v in c) + (255,)


def face(ch, ex, open_mouth):
    p = CHARS[ch]
    s = SHAPES[ex]
    im = Image.new("RGBA", (C, C), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    skin = p["skin"]
    shade = dark(skin, 0.72)
    # sombra lateral do nariz e das olheiras (dá volume ao rosto sem geometria)
    d.line([(33, 26), (34, 39)], fill=shade, width=1)
    d.line([(29, 40), (35, 41)], fill=dark(skin, 0.6), width=1)
    d.point([(30, 39), (34, 39)], fill=dark(skin, 0.55))
    # barba (antes dos olhos e da boca, que ficam por cima)
    if "beard" in p:
        bc = p["beard"]
        for y in range(37, 64):
            # contorno do maxilar: largo nas bochechas, afina no queixo
            half = int(27 - max(0, y - 50) * 1.15) if y > 44 else 22 + (y - 37) // 2
            for x in range(32 - half, 32 + half):
                edge = min(x - (32 - half), (32 + half) - x)
                dense = y > 50 and edge > 2
                if dense or (x * 7 + y * 13) % 4 == 0 or (y > 46 and (x + y) % 2 == 0):
                    if not (46 <= y <= 51 and 25 <= x <= 39):
                        d.point((x, y), fill=bc + (255,))
        # bigode
        d.rectangle([23, 43, 41, 45], fill=bc + (255,))
    if "goatee" in p:
        gc = p["goatee"] + (255,)
        d.rectangle([29, 53, 35, 60], fill=gc)
        d.rectangle([26, 43, 38, 44], fill=gc)
    # olhos
    look = s.get("look", 0)
    for side, cx in ((-1, 21), (1, 43)):
        ey = 26
        lid = s["lid"] + (0.2 if s.get("asym") and side > 0 else 0)
        # branco do olho (estreito, adulto) e íris
        d.rectangle([cx - 5, ey - 2, cx + 5, ey + 2], fill=(226, 222, 214, 255))
        d.rectangle([cx - 2 + look, ey - 2, cx + 1 + look, ey + 2], fill=p["eye"] + (255,))
        d.point((cx - 1 + look, ey - 1), fill=(240, 236, 228, 255))
        # pálpebra superior cobre parte do olho
        cover = int(round(lid * 4))
        if cover > 0:
            d.rectangle([cx - 6, ey - 3, cx + 6, ey - 3 + cover], fill=dark(skin, 0.86))
        d.line([(cx - 6, ey - 3 + cover), (cx + 6, ey - 3 + cover)], fill=dark(skin, 0.35), width=1)
        # pálpebra inferior / olheira
        d.line([(cx - 5, ey + 3), (cx + 5, ey + 3)], fill=dark(skin, 0.7), width=1)
        if p["female"]:
            d.line([(cx + 5 * side, ey - 3 + cover), (cx + 7 * side, ey - 5 + cover)], fill=(20, 16, 18, 255), width=1)
        # sobrancelha grossa: altura e inclinação (interna para baixo = desconfiado/firme)
        by = 17 + s["bh"]
        t = s["tilt"] + (1 if s.get("asym") and side < 0 else 0)
        inner = (cx - 6 * side, by + t)
        outer = (cx + 6 * side, by - t // 2)
        d.line([inner, outer], fill=p["brow"] + (255,), width=3 if not p["female"] else 2)
    # boca
    lips = p.get("lips")
    dark_skin = sum(skin) / 3 < 110
    mc = (lips + (255,)) if lips else ((176, 112, 92, 255) if dark_skin else dark(skin, 0.42))
    inner = (120, 44, 48, 255) if dark_skin else (40, 16, 18, 255)
    m = s["mouth"]
    my = 49
    if open_mouth:
        d.rectangle([27, my - 1, 37, my + 3], fill=inner)
        d.line([(27, my - 2), (37, my - 2)], fill=mc, width=1)
        d.line([(28, my + 4), (36, my + 4)], fill=mc, width=1)
    elif m == "reta":
        d.line([(26, my), (38, my)], fill=mc, width=2 if lips else 1)
    elif m == "reta_baixa":
        d.line([(26, my + 1), (38, my + 1)], fill=mc, width=1)
        d.point([(25, my + 2), (39, my + 2)], fill=mc)
    elif m == "pequena":
        d.line([(29, my), (35, my)], fill=mc, width=2)
    elif m == "canto_baixo":
        d.line([(26, my), (36, my)], fill=mc, width=1)
        d.point((37, my + 1), fill=mc)
    elif m == "sorriso_canto":
        d.line([(26, my + 1), (34, my + 1)], fill=mc, width=1)
        d.line([(34, my + 1), (39, my - 2)], fill=mc, width=1)
    elif m == "firme":
        d.line([(25, my), (39, my)], fill=mc, width=2)
        d.point([(24, my + 1), (40, my + 1)], fill=mc)
    # bigode do Otto por cima da boca
    if "mustache" in p:
        mu = p["mustache"] + (255,)
        d.rectangle([23, 42, 41, 44], fill=mu)
        d.rectangle([21, 44, 24, 47], fill=mu)
        d.rectangle([40, 44, 43, 47], fill=mu)
    return im


def main():
    for ch in CHARS:
        atlas = Image.new("RGBA", (C * len(EXPRS), C * 2), (0, 0, 0, 0))
        for i, ex in enumerate(EXPRS):
            atlas.paste(face(ch, ex, False), (i * C, 0))
            atlas.paste(face(ch, ex, True), (i * C, C))
        atlas.save(os.path.join(OUT, "face_%s.png" % ch))
    print("rostos:", len(CHARS))


if __name__ == "__main__":
    main()
