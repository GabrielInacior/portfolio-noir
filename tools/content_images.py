# -*- coding: utf-8 -*-
"""Gera as texturas de vitrine em data/collages/<id>.png:
- projeto COM imagens: colagem noir de polaroides (fotos com fita, tortas, uma em destaque).
- projeto SEM imagens: cartao estilo terminal/GitHub (nome, descricao, barra de linguagens,
  arvore de pastas, trecho do README, estatisticas), a partir do snapshot do build.
Uso: python tools/content_images.py"""
import json
import os
import random
import textwrap

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = "C:\\Project"
OUT = os.path.join(ROOT, "data", "collages")
FONTS = os.path.join(ROOT, "game", "assets", "fonts")
os.makedirs(OUT, exist_ok=True)

W, H = 1280, 800
NEON = {"rumor": "#ffc83d", "fortress": "#c8762b", "buscavagas": "#00dc82", "orbix": "#4e9bff",
        "formataai": "#ff6fae", "labia": "#b06bff", "airmessage": "#25d366", "inaciocyber": "#e2384f",
        "ankiana": "#6750a4", "atende360": "#00bcd4"}

GA = os.path.join(P, "GabrielInacior", "assets", "projects")
IMG = {
    "rumor": [os.path.join(P, "detetive", "docs", "img", x) for x in ["banner.png", "telas.png", "expressoes.png", "professor.png"]],
    "fortress": [os.path.join(GA, x) for x in ["fortresschaos_menu.png", "fortresschaos_horda.png", "fortresschaos_loja.png", "fortresschaos.png"]],
    "buscavagas": [os.path.join(GA, "buscavagas.png")],
    "orbix": [os.path.join(P, "Orbix", "login-page.png"),
              os.path.join(P, "Orbix", ".playwright-mcp", "page-2026-04-12T21-48-22-565Z.png"),
              os.path.join(P, "Orbix", ".playwright-mcp", "page-2026-04-12T21-48-49-284Z.png")],
    "formataai": [os.path.join(P, "FormataAI", ".playwright-mcp", x) for x in
                  ["page-2026-03-25T17-30-30-872Z.png", "page-2026-03-25T17-31-10-310Z.png", "page-2026-03-25T17-31-48-063Z.png"]],
    "labia": [os.path.join(GA, "labia_logo.png")],
    "atende360": [os.path.join(P, "siteMbm", ".playwright-mcp", x) for x in os.listdir(os.path.join(P, "siteMbm", ".playwright-mcp"))
                if x.endswith(".png")][:4] if os.path.isdir(os.path.join(P, "siteMbm", ".playwright-mcp")) else [],
}


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def backdrop(neon):
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):
        k = y / H
        d.line([(0, y), (W, y)], fill=(int(9 + 7 * (1 - k)), int(12 + 10 * (1 - k)), int(22 + 20 * (1 - k))))
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse((W * 0.2, -H * 0.5, W * 0.8, H * 0.5), fill=70)
    nc = tuple(int(neon[i:i + 2], 16) for i in (1, 3, 5))
    img = Image.composite(Image.new("RGB", (W, H), nc), img, glow.filter(ImageFilter.GaussianBlur(160)).point(lambda v: int(v * 0.5)))
    d = ImageDraw.Draw(img)
    for y in range(0, H, 13):
        for x in range(0, W, 13):
            d.point((x, y), fill=(28, 36, 60))
    return img


def fit(im, w, h):
    # imagem muito larga (banner): encaixa pela largura para nao cortar o logo
    if im.width > im.height * 2.0:
        r = w / im.width
        im = im.resize((w, int(im.height * r)), Image.LANCZOS)
        canvas = Image.new("RGB", (w, h), (14, 18, 30))
        canvas.paste(im, (0, (h - im.height) // 2))
        return canvas
    r = max(w / im.width, h / im.height)
    im = im.resize((int(im.width * r), int(im.height * r)), Image.LANCZOS)
    x = (im.width - w) // 2
    y = (im.height - h) // 2
    return im.crop((x, y, x + w, y + h))


def polaroid(path, w, cap=""):
    try:
        im = Image.open(path).convert("RGB")
    except Exception:
        return None
    h = int(w * 0.72)
    photo = fit(im, w, h)
    pad = int(w * 0.055)
    ch = int(w * 0.17)
    card = Image.new("RGBA", (w + pad * 2, h + pad + ch), (244, 240, 228, 255))
    card.paste(photo, (pad, pad))
    return card


def collage(pid, paths):
    neon = NEON.get(pid, "#ffc83d")
    img = backdrop(neon).convert("RGBA")
    rng = random.Random(hash(pid) & 0xffff)
    paths = [p for p in paths if os.path.exists(p)]
    if not paths:
        return None
    # destaque grande ao centro-esquerda
    hero = polaroid(paths[0], 620)
    spots = [(70, 150, rng.uniform(-5, -2))]
    extras = paths[1:5]
    small_spots = [(760, 70, 4), (900, 360, -6), (720, 470, 7), (980, 120, -3)]
    nc = tuple(int(neon[i:i + 2], 16) for i in (1, 3, 5))
    placed = []
    if hero:
        r = hero.rotate(spots[0][2], expand=True, resample=Image.BICUBIC)
        sh = Image.new("RGBA", r.size, (0, 0, 0, 150)).filter(ImageFilter.GaussianBlur(14))
        img.alpha_composite(sh, (spots[0][0] + 10, spots[0][1] + 16))
        img.alpha_composite(r, (spots[0][0], spots[0][1]))
        placed.append((spots[0][0] + r.width // 2, spots[0][1] + 14))
    for i, pth in enumerate(extras):
        pol = polaroid(pth, 330)
        if not pol:
            continue
        sx, sy, rot = small_spots[i % len(small_spots)]
        r = pol.rotate(rot, expand=True, resample=Image.BICUBIC)
        sh = Image.new("RGBA", r.size, (0, 0, 0, 140)).filter(ImageFilter.GaussianBlur(12))
        img.alpha_composite(sh, (sx + 8, sy + 12))
        img.alpha_composite(r, (sx, sy))
        placed.append((sx + r.width // 2, sy + 12))
    d = ImageDraw.Draw(img)
    # fita nas fotos e tachinhas de neon
    for (px, py) in placed:
        d.ellipse((px - 11, py - 11, px + 11, py + 11), fill=nc + (255,))
        d.ellipse((px - 5, py - 7, px + 2, py), fill=(255, 255, 255, 180))
    return img.convert("RGB")


def lang_bar(d, x, y, w, langs, fnt):
    total = sum(langs.values()) or 1
    colors = {"Python": "#3572A5", "TypeScript": "#3178c6", "GDScript": "#355570", "Dart": "#00B4AB",
              "Vue": "#41b883", "JavaScript": "#f1e05a", "HTML": "#e34c26", "CSS": "#563d7c",
              "GDShader": "#9b5de5", "Java": "#b07219", "C#": "#178600", "PowerShell": "#012456",
              "Shell": "#89e051", "Dockerfile": "#384d54"}
    cx = x
    bar_h = 26
    for k, v in sorted(langs.items(), key=lambda a: -a[1])[:6]:
        seg = int(w * v / total)
        c = colors.get(k, "#888")
        d.rounded_rectangle((cx, y, cx + max(seg, 3), y + bar_h), 4, fill=c)
        cx += seg + 3
    # legenda
    ly = y + bar_h + 16
    lx = x
    for k, v in sorted(langs.items(), key=lambda a: -a[1])[:5]:
        c = colors.get(k, "#888")
        d.ellipse((lx, ly + 3, lx + 14, ly + 17), fill=c)
        label = "%s %.0f%%" % (k, 100 * v / total)
        d.text((lx + 22, ly), label, font=fnt, fill=(190, 200, 220))
        lx += 26 + d.textlength(label, font=fnt) + 26


def terminal_card(pid, proj, repo):
    neon = NEON.get(pid, "#e2384f")
    nc = tuple(int(neon[i:i + 2], 16) for i in (1, 3, 5))
    img = Image.new("RGB", (W, H), (7, 10, 18))
    d = ImageDraw.Draw(img)
    for y in range(0, H, 3):
        d.line([(0, y), (W, y)], fill=(10, 14, 24))
    m = 70
    d.rounded_rectangle((m, m, W - m, H - m), 18, fill=(12, 16, 26), outline=nc, width=2)
    mono = font("SpecialElite-Regular.ttf", 26)
    monosm = font("SpecialElite-Regular.ttf", 21)
    big = font("BebasNeue-Regular.ttf", 72)
    ui = font("Nunito-Var.ttf", 24)
    # barra de titulo do terminal
    d.rounded_rectangle((m, m, W - m, m + 54), 18, fill=(18, 24, 38))
    d.rectangle((m, m + 30, W - m, m + 54), fill=(18, 24, 38))
    for i, cc in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]):
        d.ellipse((m + 24 + i * 34, m + 18, m + 24 + i * 34 + 18, m + 36), fill=cc)
    d.text((m + 150, m + 15), "GabrielInacior/" + repo.get("repo", pid), font=monosm, fill=(150, 165, 190))
    priv = repo.get("private", True)
    tag = "PRIVADO" if priv else "PUBLICO"
    tw = d.textlength(tag, font=monosm)
    d.rounded_rectangle((W - m - 40 - tw, m + 12, W - m - 16, m + 44), 8, outline=nc, width=2)
    d.text((W - m - 28 - tw, m + 15), tag, font=monosm, fill=nc)
    x = m + 44
    y = m + 92
    d.text((x, y), proj["title"].upper(), font=big, fill=nc)
    y += 84
    for line in textwrap.wrap(proj["desc"], 64)[:3]:
        d.text((x, y), line, font=ui, fill=(205, 214, 232))
        y += 34
    y += 18
    langs = repo.get("languages") or ({repo.get("lang"): 1} if repo.get("lang") else {})
    if langs:
        d.text((x, y), "LINGUAGENS", font=monosm, fill=(120, 135, 160))
        y += 34
        lang_bar(d, x, y, W - 2 * m - 88, langs, monosm)
        y += 90
    # arvore de pastas (duas colunas, 5 por coluna, sem encostar no rodape)
    tree = repo.get("tree") or []
    if tree:
        d.text((x, y), "ESTRUTURA", font=monosm, fill=(120, 135, 160))
        ty = y + 34
        for i, node in enumerate(tree[:8]):
            col = x if i < 4 else x + 380
            row = i if i < 4 else i - 4
            icon = "[ ]" if node.endswith("/") else " . "
            d.text((col, ty + row * 30), icon + " " + node, font=monosm,
                   fill=(150, 200, 170) if node.endswith("/") else (170, 180, 200))
    # stats em neon no rodape: stack em linha propria, depois ano e estrelas
    yb = H - m - 74
    d.text((m + 44, yb), "STACK", font=monosm, fill=(120, 135, 160))
    d.text((m + 150, yb), " / ".join(proj.get("stack", [])[:5]), font=mono, fill=nc)
    d.text((m + 44, yb + 38), "ANO", font=monosm, fill=(120, 135, 160))
    d.text((m + 150, yb + 38), str(proj.get("year", "")), font=mono, fill=nc)
    d.text((m + 360, yb + 38), "ESTRELAS", font=monosm, fill=(120, 135, 160))
    d.text((m + 540, yb + 38), str(repo.get("stars", 0)), font=mono, fill=nc)
    return img


def main():
    projects = {p["id"]: p for p in json.load(open(os.path.join(ROOT, "data", "projects.json"), encoding="utf8"))}
    snap = {r["id"]: r for r in json.load(open(os.path.join(ROOT, "data", "github_snapshot.json"), encoding="utf8"))["repos"]}
    made = []
    for pid, proj in projects.items():
        paths = IMG.get(pid, [])
        existing = [p for p in paths if os.path.exists(p)]
        if len(existing) >= 1:
            im = collage(pid, existing)
            kind = "colagem(%d)" % len(existing)
        else:
            im = terminal_card(pid, proj, snap.get(pid, {}))
            kind = "terminal"
        if im:
            im.save(os.path.join(OUT, pid + ".png"), optimize=True)
            made.append((pid, kind))
    for pid, k in made:
        print(pid, k)


if __name__ == "__main__":
    main()
