"""Cidade capitalista onde a propaganda é o Gabriel: dezenas de anúncios gerados na proporção EXATA
de cada superfície (topo de prédio, faixa, letreiro vertical, lightbox, telão animado, lambe-lambe,
luminoso de táxi, lateral de van), sempre com a foto (variações de enquadramento e tratamento), o nome,
um slogan curto e a fila de ÍCONES das tecnologias (atlas game/assets/tech_icons). Texto centralizado,
margem de segurança, rosto nunca cortado.
Saída: game/assets/ads/<id>_<pt|en>.png e game/assets/ads/ads.json (lista para o city.gd).
Uso: python tools/deploy/ads.py
"""
import json
import os

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont, ImageOps

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "ads")
F = os.path.join(ROOT, "game", "assets", "fonts")
PHOTO = os.path.join(ROOT, "game", "assets", "foto_gabriel.png")
ICONS = os.path.join(ROOT, "game", "assets", "tech_icons")
os.makedirs(OUT, exist_ok=True)

YEL, PINK, CYAN, VIO, GRN, ORG = (255, 200, 61), (255, 79, 163), (63, 211, 255), (180, 92, 255), (57, 255, 106), (255, 122, 61)
NIGHT = (8, 10, 22)
WHITE = (238, 240, 248)

SIZES = {"top": (1600, 400), "tall": (400, 1200), "lightbox": (720, 960), "tv": (1024, 576), "lambe": (480, 720),
         "faixa": (1800, 300), "taxi": (600, 200), "van": (900, 360)}

SLOGANS = {
    "pt": ["CONTRATE O INÁCIO", "4+ ANOS DE CÓDIGO", "IA QUE ENTREGA", "SEU PRODUTO NO AR", "FULL-STACK 24/7",
           "DA IDEIA À PRODUÇÃO", "SPRINT DE 2 SEMANAS EM 3 DIAS", "MIGRAÇÃO SEM REGRESSÃO", "GAMES QUE RODAM NA WEB",
           "ARQUITETURA QUE ESCALA", "VUE · NODE · FLUTTER", "GODOT · BLENDER · 3D", "CLAUDE · AGENTES · IA LOCAL",
           "POSTGRES · AWS · DOCKER", "SAAS MULTI-TENANT", "CÓDIGO QUE VAI PRA PRODUÇÃO"],
    "en": ["HIRE INÁCIO", "4+ YEARS OF CODE", "AI THAT SHIPS", "YOUR PRODUCT LIVE", "FULL-STACK 24/7",
           "FROM IDEA TO PRODUCTION", "2-WEEK SPRINT IN 3 DAYS", "MIGRATION, ZERO REGRESSIONS", "GAMES THAT RUN ON THE WEB",
           "ARCHITECTURE THAT SCALES", "VUE · NODE · FLUTTER", "GODOT · BLENDER · 3D", "CLAUDE · AGENTS · LOCAL AI",
           "POSTGRES · AWS · DOCKER", "MULTI-TENANT SAAS", "CODE THAT REACHES PRODUCTION"],
}
ROLE = {"pt": "engenharia de software · games · IA", "en": "software engineering · games · AI"}
STACKS = [["vue", "node", "flutter", "postgres", "aws", "docker"], ["godot", "blender", "javascript", "typescript"],
          ["claude", "ollama", "openai", "python"], ["nuxt", "react", "next", "tailwind"], ["nest", "prisma", "postgres", "redis"],
          ["rust", "tauri", "electron", "linux"], ["git", "github", "figma", "vite"]]
TONES = [None, PINK, CYAN, YEL, VIO, GRN]
ACCENTS = [YEL, PINK, CYAN, GRN, VIO, ORG]


def font(name, size):
    f = ImageFont.truetype(os.path.join(F, name), max(8, int(size)))
    if name.startswith("Nunito"):
        try:
            f.set_variation_by_name("Black")
        except Exception:
            pass
    return f


def fit(d, text, name, size, maxw):
    f = font(name, size)
    while d.textlength(text, font=f) > maxw and size > 10:
        size -= 2
        f = font(name, size)
    return f


def icon(id_, sz):
    p = os.path.join(ICONS, id_ + "_256.png")
    if not os.path.exists(p):
        return None
    return Image.open(p).convert("RGBA").resize((int(sz), int(sz)), Image.LANCZOS)


def photo(w, h, tone=None, tight=False):
    im = Image.open(PHOTO).convert("RGB")
    iw, ih = im.size
    if tight:  # recorte mais fechado no rosto (terço de cima, centro)
        cw, ch = int(iw * 0.72), int(ih * 0.62)
        im = im.crop(((iw - cw) // 2, int(ih * 0.04), (iw - cw) // 2 + cw, int(ih * 0.04) + ch))
        iw, ih = im.size
    r = w / h
    if iw / ih > r:
        nw = int(ih * r)
        box = ((iw - nw) // 2, 0, (iw - nw) // 2 + nw, ih)
    else:
        nh = int(iw / r)
        top = 0
        box = (0, top, iw, top + nh)
    im = im.crop(box).resize((max(1, w), max(1, h)), Image.LANCZOS)
    if tone:
        g = ImageOps.grayscale(im)
        im = ImageOps.colorize(g, black=NIGHT, white=tuple(min(255, c + 40) for c in tone), mid=tuple(int(c * 0.55) for c in tone))
    return ImageEnhance.Contrast(im).enhance(1.1)


def glow(base, xy, text, fnt, col, anchor="mm", g=10):
    lay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(lay).text(xy, text, font=fnt, fill=col + (255,), anchor=anchor)
    b = lay.filter(ImageFilter.GaussianBlur(g))
    base.alpha_composite(b)
    base.alpha_composite(lay)


def icon_row(base, ids, cx, cy, size, maxw, gap=0.25):
    ims = [i for i in (icon(x, size) for x in ids) if i is not None]
    if not ims:
        return
    n = len(ims)
    while n * size * (1 + gap) > maxw and size > 16:
        size *= 0.9
        ims = [i.resize((int(size), int(size)), Image.LANCZOS) for i in ims]
    total = n * size + (n - 1) * size * gap
    x = cx - total / 2
    for im in ims:
        base.alpha_composite(im, (int(x), int(cy - size / 2)))
        x += size * (1 + gap)


def frame(base, col, wdt=8):
    d = ImageDraw.Draw(base)
    w, h = base.size
    d.rectangle([wdt // 2, wdt // 2, w - wdt // 2 - 1, h - wdt // 2 - 1], outline=col, width=wdt)


def bg(w, h, col, k):
    """Fundo noir com padrão sutil (desenhado numa camada e composto: o alfa precisa misturar)."""
    base = Image.new("RGBA", (w, h), NIGHT + (255,))
    lay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    if k % 3 == 0:
        for x in range(-h, w, 36):
            d.line([(x, 0), (x + h, h)], fill=col + (26,), width=3)
    elif k % 3 == 1:
        for y in range(0, h, 6):
            d.line([(0, y), (w, y)], fill=(0, 0, 0, 70))
        d.ellipse([w * 0.55, -h * 0.6, w * 1.4, h * 1.2], fill=col + (34,))
    else:
        for r in range(20, max(w, h), 60):
            d.ellipse([w * 0.8 - r, h * 0.2 - r, w * 0.8 + r, h * 0.2 + r], outline=col + (22,), width=3)
    base.alpha_composite(lay)
    return base


PHOTO_IDS = {("top", 0), ("top", 1), ("top", 2), ("tall", 0), ("lightbox", 0), ("lightbox", 1), ("tv", 0), ("tv", 1),
             ("lambe", 0), ("van", 0)}


def monogram(base, cx, cy, r, col):
    """Selo "GI" em neon (marca do Gabriel) para as peças sem foto."""
    lay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    pts = [(cx + r * __import__("math").cos(a), cy + r * __import__("math").sin(a)) for a in
           [__import__("math").pi / 6 + i * __import__("math").pi / 3 for i in range(6)]]
    d.polygon(pts, outline=col + (255,), width=max(3, int(r * 0.09)))
    f = font("BebasNeue-Regular.ttf", r * 1.15)
    d.text((cx, cy + r * 0.05), "GI", font=f, fill=col + (255,), anchor="mm")
    base.alpha_composite(lay.filter(ImageFilter.GaussianBlur(max(2, int(r * 0.12)))))
    base.alpha_composite(lay)


def typo_h(kind, lg, k, slogan, stack):
    """Peça horizontal SEM foto: logotipo GABRIEL INÁCIO em neon como protagonista, selo GI, slogan e ícones."""
    w, h = SIZES[kind]
    col = ACCENTS[k % len(ACCENTS)]
    base = bg(w, h, col, k)
    d = ImageDraw.Draw(base)
    m = int(h * 0.1)
    left = k % 2 == 0
    r = h * 0.3
    mx = m + r if left else w - m - r
    monogram(base, mx, h / 2, r, col)
    tx0 = (mx + r + m) if left else m
    tx1 = (w - m) if left else (mx - r - m)
    cx, maxw = (tx0 + tx1) / 2, tx1 - tx0
    if kind == "taxi":
        nf = fit(d, "GABRIEL INÁCIO · DEV", "BebasNeue-Regular.ttf", h * 0.42, maxw)
        glow(base, (cx, h * 0.38), "GABRIEL INÁCIO · DEV", nf, YEL, g=6)
        sf = fit(d, "inaciodev.online", "Nunito-Var.ttf", h * 0.16, maxw)
        d.text((cx, h * 0.76), "inaciodev.online", font=sf, fill=WHITE, anchor="mm")
    else:
        rows = [("name", "GABRIEL INÁCIO", 0.34), ("slogan", slogan, 0.16), ("icons", None, 0.18), ("role", ROLE[lg] + "  ·  inaciodev.online", 0.08)]
        if kind == "faixa":
            rows = [("name", "GABRIEL INÁCIO", 0.4), ("slogan", slogan + "  ·  inaciodev.online", 0.2), ("icons", None, 0.2)]
        total = sum(rr[2] for rr in rows) * 1.18
        y = (h - total * h) / 2
        for kind_r, txt, frac in rows:
            hh = frac * h
            yc = y + hh * 0.59
            if kind_r == "icons":
                icon_row(base, stack, cx, yc, hh, maxw)
            elif kind_r == "name":
                f = fit(d, txt, "BebasNeue-Regular.ttf", hh * 1.15, maxw)
                glow(base, (cx, yc), txt, f, col, g=14)
            elif kind_r == "slogan":
                f = fit(d, txt, "BebasNeue-Regular.ttf", hh * 1.1, maxw)
                d.text((cx, yc), txt, font=f, fill=WHITE, anchor="mm")
            else:
                f = fit(d, txt, "Nunito-Var.ttf", hh * 1.1, maxw)
                d.text((cx, yc), txt, font=f, fill=PINK if col != PINK else CYAN, anchor="mm")
            y += hh * 1.18
    frame(base, col, max(4, h // 60))
    return base


def typo_v(kind, lg, k, slogan, stack):
    """Peça vertical SEM foto: selo GI, GABRIEL INÁCIO em neon empilhado, slogan, ícones e endereço;
    tudo encolhe junto até caber na altura (nada passa da margem)."""
    w, h = SIZES[kind]
    col = ACCENTS[k % len(ACCENTS)]
    base = bg(w, h, col, k + 1)
    d = ImageDraw.Draw(base)
    m = int(w * 0.08)
    maxw = w - 2 * m
    cx = w / 2
    scale = 1.0
    for _ in range(40):
        r = w * 0.2 * scale
        nf = [fit(d, wd, "BebasNeue-Regular.ttf", w * 0.3 * scale, maxw) for wd in ("GABRIEL", "INÁCIO")]
        s_sz = w * 0.11 * scale
        sf = font("BebasNeue-Regular.ttf", s_sz)
        lines, cur = [], ""
        for wd in slogan.split():
            t = (cur + " " + wd).strip()
            if d.textlength(t, font=sf) <= maxw:
                cur = t
            else:
                if cur:
                    lines.append(cur)
                cur = wd
        lines.append(cur)
        ic = w * 0.13 * scale
        rf = fit(d, "inaciodev.online", "Nunito-Var.ttf", w * 0.055, maxw)
        need = r * 2 + h * 0.025 + sum(f.size * 0.9 for f in nf) + h * 0.02 + len(lines) * s_sz * 0.95 + ic * 1.5 + rf.size * 1.6
        if need <= h - 2 * m and len(lines) <= 3:
            break
        scale *= 0.94
    y = m + (h - 2 * m - need) / 2
    monogram(base, cx, y + r, r, col)
    y += r * 2 + h * 0.025
    for wd, f in zip(("GABRIEL", "INÁCIO"), nf):
        glow(base, (cx, y + f.size * 0.45), wd, f, col, g=12)
        y += f.size * 0.9
    y += h * 0.02
    for ln in lines:
        f = fit(d, ln, "BebasNeue-Regular.ttf", s_sz, maxw)
        d.text((cx, y + s_sz * 0.5), ln, font=f, fill=WHITE, anchor="mm")
        y += s_sz * 0.95
    icon_row(base, stack[:4], cx, y + ic * 0.7, ic, maxw)
    y += ic * 1.5
    d.text((cx, y + rf.size * 0.6), "inaciodev.online", font=rf, fill=PINK if col != PINK else CYAN, anchor="mm")
    if kind == "lambe":
        base = ImageEnhance.Color(base).enhance(0.85)
        ImageDraw.Draw(base).rectangle([0, 0, w - 1, h - 1], outline=(230, 225, 210), width=10)
    else:
        frame(base, col, max(4, w // 70))
    return base


def horizontal(kind, lg, k, slogan, stack):
    """Topo de prédio, faixa, van, táxi, telão: foto num lado, nome + slogan + ícones no centro do resto."""
    w, h = SIZES[kind]
    col = ACCENTS[k % len(ACCENTS)]
    base = bg(w, h, col, k)
    left = k % 2 == 0
    pw = int(h * (0.82 if kind not in ("taxi",) else 0.9))
    if kind == "faixa":
        pw = int(h * 0.9)
    ph = photo(pw, h, TONES[k % len(TONES)], tight=(k % 3 == 1))
    px = 0 if left else w - pw
    base.paste(ph, (px, 0))
    fade = Image.new("L", (max(1, pw // 3), h))
    for x in range(fade.width):
        fade.paste(int(255 * x / max(1, fade.width)), (x, 0, x + 1, h))
    edge = Image.new("RGBA", fade.size, NIGHT + (255,))
    if left:
        base.paste(edge, (pw - fade.width, 0), fade)
    else:
        base.paste(edge, (px, 0), ImageOps.mirror(fade))
    d = ImageDraw.Draw(base)
    m = int(h * 0.1)
    tx0 = (pw if left else 0) + m
    tx1 = (w if left else px) - m
    cx, maxw = (tx0 + tx1) / 2, tx1 - tx0
    if kind == "taxi":
        nf = fit(d, "GABRIEL INÁCIO · DEV", "BebasNeue-Regular.ttf", h * 0.42, maxw)
        glow(base, (cx, h * 0.38), "GABRIEL INÁCIO · DEV", nf, YEL, g=6)
        sf = fit(d, "inaciodev.online", "Nunito-Var.ttf", h * 0.16, maxw)
        d.text((cx, h * 0.76), "inaciodev.online", font=sf, fill=WHITE, anchor="mm")
    else:
        rows = [("name", "GABRIEL INÁCIO", 0.2 if kind != "faixa" else 0.26), ("slogan", slogan, 0.24 if kind != "faixa" else 0.3),
                ("icons", None, 0.2), ("role", ROLE[lg] + "  ·  inaciodev.online", 0.09)]
        if kind == "faixa":
            rows = [("slogan", slogan, 0.36), ("icons", None, 0.26), ("name", "GABRIEL INÁCIO  ·  inaciodev.online", 0.13)]
        total = sum(r[2] for r in rows) * 1.18
        y = (h - total * h) / 2
        for kind_r, txt, frac in rows:
            hh = frac * h
            yc = y + hh * 0.59
            if kind_r == "icons":
                icon_row(base, stack, cx, yc, hh, maxw)
            elif kind_r == "slogan":
                f = fit(d, txt, "BebasNeue-Regular.ttf", hh * 1.15, maxw)
                glow(base, (cx, yc), txt, f, col, g=12)
            elif kind_r == "name":
                f = fit(d, txt, "BebasNeue-Regular.ttf", hh * 1.1, maxw)
                d.text((cx, yc), txt, font=f, fill=WHITE, anchor="mm")
            else:
                f = fit(d, txt, "Nunito-Var.ttf", hh * 1.1, maxw)
                d.text((cx, yc), txt, font=f, fill=PINK if col != PINK else CYAN, anchor="mm")
            y += hh * 1.18
    frame(base, col, max(4, h // 60))
    return base


def vertical(kind, lg, k, slogan, stack):
    """Letreiro vertical, lightbox, lambe-lambe: foto em cima (cabeça inteira), slogan, ícones, nome,
    tudo centralizado e encolhendo até caber (nada passa da margem)."""
    w, h = SIZES[kind]
    col = ACCENTS[k % len(ACCENTS)]
    base = bg(w, h, col, k + 1)
    phh = int(h * (0.48 if kind != "tall" else 0.4))
    base.paste(photo(w, phh, TONES[(k + 2) % len(TONES)], tight=False), (0, 0))
    grad = Image.new("L", (w, max(1, int(h * 0.1))))
    for y in range(grad.height):
        grad.paste(int(255 * y / grad.height), (0, y, w, y + 1))
    base.paste(Image.new("RGBA", grad.size, NIGHT + (255,)), (0, phh - grad.height), grad)
    d = ImageDraw.Draw(base)
    m = int(w * 0.08)
    maxw = w - 2 * m
    cx = w / 2
    avail = h - phh - m - h * 0.01
    scale = 1.0
    for _ in range(30):
        s_sz = w * (0.19 if kind != "tall" else 0.23) * scale
        sf = font("BebasNeue-Regular.ttf", s_sz)
        lines, cur = [], ""
        for wd in slogan.split():
            t = (cur + " " + wd).strip()
            if d.textlength(t, font=sf) <= maxw:
                cur = t
            else:
                if cur:
                    lines.append(cur)
                cur = wd
        lines.append(cur)
        ic = w * 0.15 * scale
        nm = fit(d, "GABRIEL INÁCIO", "BebasNeue-Regular.ttf", w * 0.13 * scale, maxw)
        rf = fit(d, "inaciodev.online", "Nunito-Var.ttf", w * 0.055 * max(scale, 0.8), maxw)
        need = len(lines) * s_sz * 0.95 + ic * 1.35 + nm.size * 1.05 + rf.size * 1.4
        if need <= avail and len(lines) <= 3:
            break
        scale *= 0.93
    y = phh + h * 0.01 + (avail - need) / 2
    for ln in lines:
        f = fit(d, ln, "BebasNeue-Regular.ttf", s_sz, maxw)
        glow(base, (cx, y + s_sz * 0.5), ln, f, col, g=10)
        y += s_sz * 0.95
    icon_row(base, stack[:4], cx, y + ic * 0.62, ic, maxw)
    y += ic * 1.35
    d.text((cx, y + nm.size * 0.5), "GABRIEL INÁCIO", font=nm, fill=WHITE, anchor="mm")
    y += nm.size * 1.05
    d.text((cx, y + rf.size * 0.6), "inaciodev.online", font=rf, fill=PINK if col != PINK else CYAN, anchor="mm")
    if kind == "lambe":
        base = ImageEnhance.Color(base).enhance(0.85)
        ImageDraw.Draw(base).rectangle([0, 0, w - 1, h - 1], outline=(230, 225, 210), width=10)
    else:
        frame(base, col, max(4, w // 70))
    return base


def main():
    plan = [("top", 8), ("tall", 6), ("lightbox", 6), ("tv", 9), ("lambe", 8), ("faixa", 4), ("taxi", 1), ("van", 3)]
    meta = {}
    for lg in ("pt", "en"):
        sl = SLOGANS[lg]
        n = 0
        for kind, count in plan:
            for i in range(count):
                k = n + i
                slogan = sl[(k * 5 + len(kind)) % len(sl)]
                stack = STACKS[k % len(STACKS)]
                hz = kind in ("top", "tv", "faixa", "taxi", "van")
                if (kind, i) in PHOTO_IDS:
                    im = horizontal(kind, lg, k, slogan, stack) if hz else vertical(kind, lg, k, slogan, stack)
                else:
                    im = typo_h(kind, lg, k, slogan, stack) if hz else typo_v(kind, lg, k, slogan, stack)
                aid = "%s_%02d" % (kind, i)
                im.convert("RGB").save(os.path.join(OUT, "%s_%s.png" % (aid, lg)), optimize=True)
                meta.setdefault(kind, [])
                if lg == "pt":
                    meta[kind].append(aid)
            n += count
    # sequências de lambe-lambe variadas: 5 cartazes diferentes por muro (3 do Gabriel + 2 panfletos de
    # projetos), um atlas por sequência (1 draw call por muro)
    import glob
    proj = sorted(glob.glob(os.path.join(ROOT, "game", "assets", "museum", "*", "ad_0[1-3].png")))
    lw, lh = SIZES["lambe"]
    seqs = []
    for lg in ("pt", "en"):
        for si in range(6):
            strip = Image.new("RGB", (lw * 5, lh), (20, 18, 24))
            for j in range(5):
                if j in (1, 3) and proj:
                    src = Image.open(proj[(si * 2 + j) % len(proj)]).convert("RGB")
                    src.thumbnail((lw - 24, lh - 24))
                    cell = Image.new("RGB", (lw, lh), (232, 226, 210))
                    cell.paste(src, ((lw - src.width) // 2, (lh - src.height) // 2))
                else:
                    cell = Image.open(os.path.join(OUT, "lambe_%02d_%s.png" % ((si * 3 + j) % len(meta["lambe"]), lg))).convert("RGB")
                strip.paste(cell, (j * lw, 0))
            strip.save(os.path.join(OUT, "lseq_%02d_%s.png" % (si, lg)), optimize=True)
            if lg == "pt":
                seqs.append("lseq_%02d" % si)
    meta["lseq"] = seqs
    atlas = {}
    PAGE = 2048
    for lg in ("pt", "en"):
        items = []
        for kind, ids in meta.items():
            for aid in ids:
                im = Image.open(os.path.join(OUT, "%s_%s.png" % (aid, lg))).convert("RGB")
                sc = 0.5 if kind != "lseq" else 0.42
                im = im.resize((max(1, int(im.width * sc)), max(1, int(im.height * sc))), Image.LANCZOS)
                items.append((aid, im))
        items.sort(key=lambda t: -t[1].height)
        pages, x, y, row_h = [Image.new("RGB", (PAGE, PAGE), NIGHT)], 1, 1, 0
        amap = {}
        for aid, im in items:
            if x + im.width + 1 > PAGE:
                x, y, row_h = 1, y + row_h + 2, 0
            if y + im.height + 1 > PAGE:
                pages.append(Image.new("RGB", (PAGE, PAGE), NIGHT))
                x, y, row_h = 1, 1, 0
            pages[-1].paste(im, (x, y))
            amap[aid] = [len(pages) - 1, x / PAGE, y / PAGE, im.width / PAGE, im.height / PAGE]
            x += im.width + 2
            row_h = max(row_h, im.height)
        for pi, pg in enumerate(pages):
            pg.save(os.path.join(OUT, "atlas_%s_%d.png" % (lg, pi)), optimize=True)
        atlas[lg] = {"pages": len(pages), "map": amap}
    # as peças soltas não vão para o jogo (só o atlas); ficam fora do export pelo nome
    for f in os.listdir(OUT):
        if f.endswith(".png") and not f.startswith("atlas_"):
            os.remove(os.path.join(OUT, f))
            if os.path.exists(os.path.join(OUT, f + ".import")):
                os.remove(os.path.join(OUT, f + ".import"))
    json.dump({"sizes": {k: list(v) for k, v in SIZES.items()}, "ads": meta, "atlas": atlas}, open(os.path.join(OUT, "ads.json"), "w", encoding="utf8"),
              ensure_ascii=False, indent=1)
    print("anúncios:", sum(len(v) for v in meta.values()), "x 2 línguas")


if __name__ == "__main__":
    main()
