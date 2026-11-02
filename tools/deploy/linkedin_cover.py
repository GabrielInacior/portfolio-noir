"""Capa do LinkedIn (1584x396 e 3168x792) a partir de uma captura do jogo (tools_dev/hero_shot.tscn, HERO=capa).
Texto composto em resolução cheia (nunca pixelado), à direita e centralizado na vertical; canto inferior
esquerdo livre (a foto de perfil cobre). Uso: python tools/deploy/linkedin_cover.py <captura.png>"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
F = os.path.join(ROOT, "game", "assets", "fonts")
W, H = 3168, 792
src = Image.open(sys.argv[1]).convert("RGB")
bg = src.resize((W, int(W * src.height / src.width)), Image.BICUBIC)
bg = bg.crop((0, (bg.height - H) // 2, W, (bg.height - H) // 2 + H)).convert("RGBA")
# escurece a área do texto (direita) com degradê, para ler bem sobre a rua
shade = Image.new("L", (W, H), 0)
d = ImageDraw.Draw(shade)
for x in range(W):
    k = max(0.0, (x - W * 0.48) / (W * 0.30))
    d.line([(x, 0), (x, H)], fill=int(205 * min(1.0, k) ** 1.2))
bg = Image.composite(Image.new("RGBA", (W, H), (5, 6, 14, 255)), bg, shade)
# vinheta leve
vig = Image.new("L", (W, H), 0)
ImageDraw.Draw(vig).rectangle((0, 0, W, H), outline=255, width=1)
vig = Image.new("L", (W, H), 0)
dv = ImageDraw.Draw(vig)
for i in range(60):
    dv.rectangle((i * 3, i * 2, W - i * 3, H - i * 2), outline=int(150 * (1 - i / 60)))
bg = Image.composite(Image.new("RGBA", (W, H), (0, 0, 0, 255)), bg, vig.filter(ImageFilter.GaussianBlur(30)))


def font(n, s):
    return ImageFont.truetype(os.path.join(F, n), s)


cx = int(W * 0.765)  # centro do bloco de texto
lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
dl = ImageDraw.Draw(lay)
over = "P O R T F Ó L I O"
dl.text((cx, 205), over, font=font("SpecialElite-Regular.ttf", 44), fill=(255, 79, 163, 255), anchor="mm")
title_f = font("BebasNeue-Regular.ttf", 250)
# brilho neon atrás do título
glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
dg = ImageDraw.Draw(glow)
dg.text((cx - 8, 382), "GABRIEL INÁCIO", font=title_f, fill=(90, 170, 220, 200), anchor="mm")
dg.text((cx + 8, 390), "GABRIEL INÁCIO", font=title_f, fill=(255, 79, 163, 220), anchor="mm")
glow = glow.filter(ImageFilter.GaussianBlur(16))
dl.text((cx, 386), "GABRIEL INÁCIO", font=title_f, fill=(243, 234, 216, 255), anchor="mm")
dl.text((cx, 555), "engenharia de software · games · IA", font=font("SpecialElite-Regular.ttf", 58), fill=(255, 200, 61, 255), anchor="mm")
dl.text((cx, 650), "inaciodev.online", font=font("BebasNeue-Regular.ttf", 64), fill=(159, 176, 216, 255), anchor="mm")
out = Image.alpha_composite(Image.alpha_composite(bg, glow), lay).convert("RGB")
dst = os.path.join(ROOT, "docs", "img")
out.save(os.path.join(dst, "linkedin_capa@2x.png"), optimize=True)
out.resize((1584, 396), Image.LANCZOS).save(os.path.join(dst, "linkedin_capa.png"), optimize=True)
print("ok", dst)
