"""Artes dos outdoors da cidade (foto do Gabriel + nome/skills/números), geradas na PROPORÇÃO EXATA
de cada superfície, com o rosto inteiro em destaque e o texto dentro da margem de segurança.
Saída: game/assets/billboards/<id>_<pt|en>.png  (o city.gd escolhe pela língua).
Uso: python tools/deploy/billboards.py"""
import json
import os

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont, ImageOps

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "billboards")
F = os.path.join(ROOT, "game", "assets", "fonts")
PHOTO = os.path.join(ROOT, "game", "assets", "foto_gabriel.png")
os.makedirs(OUT, exist_ok=True)

YEL, PINK, CYAN, VIO, GRN = (255, 200, 61), (255, 79, 163), (63, 211, 255), (180, 92, 255), (57, 255, 106)
NIGHT = (8, 10, 22)


def font(name, size):
    f = ImageFont.truetype(os.path.join(F, name), size)
    if name.startswith("Nunito"):
        try:
            f.set_variation_by_name("Black")
        except Exception:
            pass
    return f


def photo_fit(w, h, tone=None):
    """Foto recortada centrada no rosto (terço de cima), sem nunca cortar a cabeça."""
    im = Image.open(PHOTO).convert("RGB")
    iw, ih = im.size
    r = w / h
    if iw / ih > r:
        nw = int(ih * r)
        box = ((iw - nw) // 2, 0, (iw - nw) // 2 + nw, ih)
    else:
        nh = int(iw / r)
        top = max(0, min(ih - nh, int(ih * 0.08)))  # mantém o topo da cabeça
        box = (0, top, iw, top + nh)
    im = im.crop(box).resize((w, h), Image.LANCZOS)
    if tone:
        g = ImageOps.grayscale(im)
        im = ImageOps.colorize(g, black=NIGHT, white=tone, mid=tuple(int(c * 0.55) for c in tone))
    return ImageEnhance.Contrast(im).enhance(1.08)


def glow_text(base, xy, text, fnt, col, anchor="la", g=10):
    lay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(lay).text(xy, text, font=fnt, fill=col + (255,), anchor=anchor)
    blur = lay.filter(ImageFilter.GaussianBlur(g))
    base.alpha_composite(blur)
    base.alpha_composite(blur)
    base.alpha_composite(lay)


def fit_font(d, text, name, size, maxw):
    f = font(name, size)
    while d.textlength(text, font=f) > maxw and size > 12:
        size -= 2
        f = font(name, size)
    return f


def frame(base, col):
    d = ImageDraw.Draw(base)
    w, h = base.size
    d.rectangle([6, 6, w - 7, h - 7], outline=col, width=8)


def wide(name, w, h, lines, sub, foot, col, photo_left=True, tone=None):
    """Outdoor horizontal: foto inteira de um lado, texto centralizado na outra metade."""
    base = Image.new("RGBA", (w, h), NIGHT + (255,))
    pw = int(h * 0.82)
    ph = photo_fit(pw, h, tone)
    px = 0 if photo_left else w - pw
    base.paste(ph, (px, 0))
    # degradê da foto para o fundo
    fade = Image.new("L", (pw // 3, h))
    for x in range(fade.width):
        fade.paste(int(255 * x / fade.width), (x, 0, x + 1, h))
    edge = Image.new("RGBA", fade.size, NIGHT + (255,))
    if photo_left:
        base.paste(edge, (pw - fade.width, 0), fade)
    else:
        base.paste(edge, (px, 0), ImageOps.mirror(fade))
    d = ImageDraw.Draw(base)
    tx0 = (pw if photo_left else 0) + int(h * 0.12)
    tx1 = (w if photo_left else px) - int(h * 0.12)
    cx = (tx0 + tx1) // 2
    maxw = tx1 - tx0
    m = int(h * 0.11)
    # pilha de linhas centralizadas no espaço do texto
    blocks = []
    if sub:
        blocks.append(("sub", sub, fit_font(d, sub, "Nunito-Var.ttf", int(h * 0.08), maxw), PINK))
    for ln in lines:
        blocks.append(("t", ln, fit_font(d, ln, "BebasNeue-Regular.ttf", int(h * 0.3), maxw), col))
    if foot:
        blocks.append(("f", foot, fit_font(d, foot, "SpecialElite-Regular.ttf", int(h * 0.075), maxw), (235, 235, 245)))
    hs = [int(b[2].size * (1.02 if b[0] == "t" else 1.5)) for b in blocks]
    y = (h - sum(hs)) // 2
    y = max(m, y)
    for b, hh in zip(blocks, hs):
        if b[0] == "t":
            glow_text(base, (cx, y), b[1], b[2], b[3], "ma", 14)
        else:
            d.text((cx, y), b[1], font=b[2], fill=b[3], anchor="ma")
        y += hh
    frame(base, col)
    base.convert("RGB").save(os.path.join(OUT, name + ".png"), optimize=True)


def numbers(name, w, h, stats, col, title):
    base = Image.new("RGBA", (w, h), NIGHT + (255,))
    d = ImageDraw.Draw(base)
    for k in range(0, w, 40):
        d.line([(k, 0), (k - h // 2, h)], fill=(20, 24, 48), width=2)
    tf = fit_font(d, title, "BebasNeue-Regular.ttf", int(h * 0.14), w - 120)
    d.text((w // 2, int(h * 0.1)), title, font=tf, fill=PINK, anchor="ma")
    n = len(stats)
    cw = (w - 120) // n
    for i, (val, lab) in enumerate(stats):
        cx = 60 + cw * i + cw // 2
        vf = fit_font(d, val, "BebasNeue-Regular.ttf", int(h * 0.42), cw - 30)
        glow_text(base, (cx, int(h * 0.3)), val, vf, [YEL, CYAN, GRN][i % 3], "ma", 16)
        lf = fit_font(d, lab.upper(), "Nunito-Var.ttf", int(h * 0.075), cw - 30)
        d.text((cx, int(h * 0.78)), lab.upper(), font=lf, fill=(235, 235, 245), anchor="ma")
    frame(base, col)
    base.convert("RGB").save(os.path.join(OUT, name + ".png"), optimize=True)


def portrait(name, w, h, top, title, sub, foot, col):
    base = Image.new("RGBA", (w, h), NIGHT + (255,))
    phh = int(h * 0.62)
    base.paste(photo_fit(w, phh), (0, 0))
    grad = Image.new("L", (w, int(h * 0.18)))
    for y in range(grad.height):
        grad.paste(int(255 * y / grad.height), (0, y, w, y + 1))
    base.paste(Image.new("RGBA", grad.size, NIGHT + (255,)), (0, phh - grad.height), grad)
    d = ImageDraw.Draw(base)
    y = phh + int(h * 0.02)
    tf = fit_font(d, top, "Nunito-Var.ttf", int(h * 0.035), w - 80)
    d.text((w // 2, y), top, font=tf, fill=PINK, anchor="ma")
    y += int(h * 0.055)
    nf = fit_font(d, title, "BebasNeue-Regular.ttf", int(h * 0.13), w - 80)
    glow_text(base, (w // 2, y), title, nf, col, "ma", 12)
    y += int(h * 0.14)
    sf = fit_font(d, sub, "Nunito-Var.ttf", int(h * 0.033), w - 80)
    d.text((w // 2, y), sub, font=sf, fill=(235, 235, 245), anchor="ma")
    y += int(h * 0.06)
    ff = fit_font(d, foot, "SpecialElite-Regular.ttf", int(h * 0.036), w - 80)
    d.text((w // 2, y), foot, font=ff, fill=CYAN, anchor="ma")
    frame(base, col)
    base.convert("RGB").save(os.path.join(OUT, name + ".png"), optimize=True)


def main():
    prof = json.load(open(os.path.join(ROOT, "data", "profile.json"), encoding="utf8"))
    stats = prof.get("stats") or []
    pairs = []
    for s in stats[:3]:
        if isinstance(s, dict):
            pairs.append((str(s.get("value", s.get("valor", ""))), str(s.get("label", s.get("rotulo", "")))))
    if len(pairs) < 3:
        pairs = [("4+", "anos de experiência"), ("40+", "tecnologias"), ("∞", "curiosidade")]
    T = {
        "pt": {"role": "engenharia de software · games · IA", "port": "PORTFÓLIO", "stats_t": "EM NÚMEROS",
               "web": "WEB E MOBILE", "game": "GAME DEV", "ai": "INTELIGÊNCIA ARTIFICIAL", "arch": "ARQUITETURA",
               "contact": "VAMOS CONVERSAR", "labs": ["anos de experiência", "tecnologias", "curiosidade"]},
        "en": {"role": "software engineering · games · AI", "port": "PORTFOLIO", "stats_t": "BY THE NUMBERS",
               "web": "WEB AND MOBILE", "game": "GAME DEV", "ai": "ARTIFICIAL INTELLIGENCE", "arch": "ARCHITECTURE",
               "contact": "LET'S TALK", "labs": ["years of experience", "technologies", "curiosity"]},
    }
    for lg, t in T.items():
        wide("bb_nome169_%s" % lg, 1600, 900, ["GABRIEL", "INÁCIO"], t["port"], t["role"], YEL)
        wide("bb_rumor_%s" % lg, 1800, 1000, ["RUMOR"], "GAME DEV" if lg == "pt" else "GAME DEV",
             "jogo de detetive para a sala de aula" if lg == "pt" else "classroom detective game", YEL, False)
        wide("bb_nome_%s" % lg, 2400, 600, ["GABRIEL INÁCIO"], t["port"], t["role"] + "   ·   inaciodev.online", YEL)
        wide("bb_web_%s" % lg, 1800, 600, ["VUE · REACT · NODE", "FLUTTER · NUXT"], t["web"], "Gabriel Inácio · inaciodev.online", CYAN, False, CYAN)
        wide("bb_game_%s" % lg, 1800, 600, ["GODOT · BLENDER · 3D"], t["game"], "RUMOR · Fortress Chaos · Lábia", PINK, True, PINK)
        wide("bb_ai_%s" % lg, 1800, 600, ["CLAUDE · AGENTES · IA LOCAL" if lg == "pt" else "CLAUDE · AGENTS · LOCAL AI"],
             t["ai"], "Ollama · Whisper · OpenAI · Gemini", GRN, False, GRN)
        wide("bb_arch_%s" % lg, 1800, 600, ["INTEGRAÇÕES · TEMPO REAL" if lg == "pt" else "INTEGRATIONS · REAL TIME"],
             t["arch"], "APIs · WebSocket · Postgres · AWS", VIO, True, VIO)
        st = [(pairs[i][0], t["labs"][i]) for i in range(3)]
        numbers("bb_numeros_%s" % lg, 1600, 900, st, YEL, t["stats_t"])
        portrait("bb_ponto_%s" % lg, 900, 1600, t["port"], "GABRIEL INÁCIO", t["role"], "inaciodev.online", YEL)
        wide("bb_contato_%s" % lg, 1800, 600, [t["contact"]], "LINKEDIN · GITHUB · E-MAIL", "inaciodev.online", PINK, True)
    print("outdoors:", len(os.listdir(OUT)))


if __name__ == "__main__":
    main()
