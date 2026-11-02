"""Imagem de prévia do link (Open Graph, 1200x627) a partir de uma captura real do jogo.
Texto composto em resolução cheia, centralizado, com margem de segurança (o LinkedIn corta as bordas).
Gera site/assets/og.png (pt) e og_en.png (en) e a cópia em game/web/assets.
Uso: python tools/deploy/og_image.py <captura_1920x1080.png>"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
F = os.path.join(ROOT, "game", "assets", "fonts")
W, H = 1200, 627


def font(n, s):
    f = ImageFont.truetype(os.path.join(F, n), s)
    if n.startswith("Nunito"):
        try:
            f.set_variation_by_name("Black")
        except Exception:
            pass
    return f


def make(src_path, lang):
    src = Image.open(src_path).convert("RGB")
    r = max(W / src.width, H / src.height)
    bg = src.resize((int(src.width * r) + 1, int(src.height * r) + 1), Image.LANCZOS)
    bg = bg.crop(((bg.width - W) // 2, (bg.height - H) // 2, (bg.width - W) // 2 + W, (bg.height - H) // 2 + H)).convert("RGBA")
    # faixa central escurecida (degradê) para o texto ler sobre a rua
    shade = Image.new("L", (W, H), 0)
    sd = ImageDraw.Draw(shade)
    for y in range(H):
        k = 1 - abs(y - H * 0.5) / (H * 0.5)
        sd.line([(0, y), (W, y)], fill=int(205 * min(1.0, k * 1.5)))
    bg = Image.composite(Image.new("RGBA", (W, H), (4, 6, 18, 255)), bg, shade)
    d = ImageDraw.Draw(bg)
    port = "PORTFÓLIO" if lang == "pt" else "PORTFOLIO"
    role = "engenharia de software · games · IA" if lang == "pt" else "software engineering · games · AI"
    cx = W // 2
    d.text((cx, 128), " ".join(port), font=font("Nunito-Var.ttf", 34), fill=(255, 79, 163), anchor="mm")
    name = "GABRIEL INÁCIO"
    nf = font("BebasNeue-Regular.ttf", 170)
    while d.textlength(name, font=nf) > W - 160:
        nf = font("BebasNeue-Regular.ttf", nf.size - 4)
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lay)
    for off, c in [((-5, -3), (90, 170, 220)), ((5, 3), (255, 79, 163)), ((0, 0), (255, 200, 61))]:
        ld.text((cx + off[0], 262 + off[1]), name, font=nf, fill=c + (255,), anchor="mm")
    glow = lay.filter(ImageFilter.GaussianBlur(14))
    bg.alpha_composite(glow)
    bg.alpha_composite(lay)
    d = ImageDraw.Draw(bg)
    d.text((cx, 392), role, font=font("SpecialElite-Regular.ttf", 40), fill=(236, 238, 248), anchor="mm")
    d.rounded_rectangle([cx - 190, 452, cx + 190, 516], radius=14, outline=(255, 200, 61), width=3, fill=(10, 12, 26, 200))
    d.text((cx, 485), "inaciodev.online", font=font("BebasNeue-Regular.ttf", 46), fill=(255, 200, 61), anchor="mm")
    out = bg.convert("RGB")
    name_ = "og.png" if lang == "pt" else "og_en.png"
    for folder in (os.path.join(ROOT, "site", "assets"), os.path.join(ROOT, "game", "web", "assets")):
        os.makedirs(folder, exist_ok=True)
        out.save(os.path.join(folder, name_), optimize=True)
    print(name_, os.path.getsize(os.path.join(ROOT, "site", "assets", name_)) // 1024, "KB")


if __name__ == "__main__":
    for lg in ("pt", "en"):
        make(sys.argv[1], lg)
