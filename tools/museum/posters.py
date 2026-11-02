"""Anúncios/pôsteres de design para as peças das lojas que não têm print real do produto.

Cada peça vira uma composição gerada no build, na proporção exata da superfície onde vai (quadro,
pôster, telão, monitor, placa), com hierarquia forte (selo, título grande, subtítulo, 2 ou 3 linhas
curtas, rodapé com CTA), grid e margens, formas e textura de impressão, no estilo da loja:
  cinema (RUMOR), arcade (Fortress), terminal (InacioCyber), startup (projetos web/SaaS),
  bar (Lábia), studio (FormataAI, AnkiAna), barber (BarberCore).
Se existir data/themes.json (frente de UI), as cores dele têm prioridade, para o pôster na parede e
o painel que abre ao interagir parecerem a mesma peça.

Sonda embutida: cada pôster é conferido (nada cortado, margem mínima, contraste >= 4,5 e corpo de
texto legível a 2 m). Relatório em tools/museum/_posters_report.json.
"""
import json
import os
import re

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FONTS = os.path.join(ROOT, "game", "assets", "fonts")
TITLE = os.path.join(FONTS, "BebasNeue-Regular.ttf")
TYPE = os.path.join(FONTS, "SpecialElite-Regular.ttf")
BODY = os.path.join(FONTS, "Nunito-Var.ttf")
MARK = os.path.join(FONTS, "PermanentMarker-Regular.ttf")

# tamanho em pixels por tipo de superfície (proporção = a da peça na loja)
SIZES = {"frame": (900, 1200), "poster": (900, 1260), "screen": (1600, 1000), "monitor": (1500, 1000),
         "plaque": (1500, 840)}
# altura física aproximada da superfície na loja (m): define o corpo mínimo legível a 2 m
PHYS_H = {"frame": 1.04, "poster": 1.23, "screen": 0.87, "monitor": 0.9, "plaque": 0.77}
MIN_CAP_MM = 9.0          # altura de maiúscula mínima para ler a ~2 m

STYLE_BY_ID = {"rumor": "cinema", "fortress": "arcade", "inaciocyber": "terminal", "labia": "bar",
               "formataai": "studio", "ankiana": "studio", "barbercore": "barber"}

STYLES = {
    "cinema": {"bg": "#1a120c", "paper": "#e9dcc0", "ink": "#1a120c", "accent": "#ffc83d", "accent2": "#e2384f",
               "title_font": TITLE, "body_font": TYPE, "paper_mode": True},
    "arcade": {"bg": "#120a24", "ink": "#f4ecff", "accent": "#ff7a3d", "accent2": "#3fd3ff",
               "title_font": TITLE, "body_font": BODY},
    "terminal": {"bg": "#050a07", "ink": "#c8ffd8", "accent": "#39ff6a", "accent2": "#ff4f6a",
                 "title_font": TITLE, "body_font": TYPE},
    "startup": {"bg": "#0b1022", "ink": "#eef2ff", "accent": "#4e9bff", "accent2": "#ffc83d",
                "title_font": TITLE, "body_font": BODY},
    "bar": {"bg": "#170812", "ink": "#ffe8f2", "accent": "#ff3d7f", "accent2": "#5bd0ff",
            "title_font": TITLE, "body_font": MARK},
    "studio": {"bg": "#10101a", "ink": "#f6f0ff", "accent": "#ff6fae", "accent2": "#4e9bff",
               "title_font": TITLE, "body_font": BODY},
    "barber": {"bg": "#14100a", "paper": "#efe4cc", "ink": "#14100a", "accent": "#c9a227", "accent2": "#a8202e",
               "title_font": TITLE, "body_font": TYPE, "paper_mode": True},
}


def _hex(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def _lum(c):
    def ch(v):
        v /= 255.0
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = c[:3]
    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)


def contrast(a, b):
    la, lb = _lum(a), _lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def _font(path, size):
    f = ImageFont.truetype(path, size)
    if path == BODY:
        try:
            f.set_variation_by_name("Bold")
        except Exception:
            pass
    return f


def _wrap(d, text, font, width):
    words = text.split()
    lines, cur = [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if d.textlength(t, font=font) <= width:
            cur = t
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def _bullets(text, n=3):
    """Quebra a história em 2 ou 3 frases curtas (anúncio, não parágrafo)."""
    parts = [p.strip(" .") for p in re.split(r"(?<=[.!?])\s+|;\s+|:\s+", text) if p.strip(" .")]
    out = []
    for p in parts:
        out.append(p)
    return [o[0].upper() + o[1:] for o in out[:n]]


def _texture(img, mode, accent):
    w, h = img.size
    d = ImageDraw.Draw(img, "RGBA")
    import random
    r = random.Random(w * 7 + h)
    for _ in range(int(w * h / 900)):  # grão de impressão
        x, y = r.randrange(w), r.randrange(h)
        a = r.randrange(6, 22)
        d.point((x, y), fill=(255, 255, 255, a) if not mode else (0, 0, 0, a))
    if mode:  # papel: manchas e dobras
        for _ in range(3):
            y = r.randrange(h)
            d.line([(0, y), (w, y + r.randrange(-10, 10))], fill=(0, 0, 0, 14), width=2)
    return img


def _icon(d, cx, cy, r, kind, col, col2, ink):
    """Ícone geométrico desenhado (sem asset pronto)."""
    if kind == "db":
        for k in range(3):
            d.ellipse([cx - r, cy - r + k * r * 0.7, cx + r, cy - r * 0.4 + k * r * 0.7], outline=col, width=6)
        d.line([cx - r, cy - r * 0.7, cx - r, cy + r * 0.9], fill=col, width=6)
        d.line([cx + r, cy - r * 0.7, cx + r, cy + r * 0.9], fill=col, width=6)
    elif kind == "phone":
        d.rounded_rectangle([cx - r * 0.6, cy - r, cx + r * 0.6, cy + r], radius=int(r * 0.2), outline=col, width=7)
        d.rectangle([cx - r * 0.45, cy - r * 0.75, cx + r * 0.45, cy + r * 0.6], fill=col2)
        d.ellipse([cx - 8, cy + r * 0.72, cx + 8, cy + r * 0.88], fill=col)
    elif kind == "chat":
        d.rounded_rectangle([cx - r, cy - r * 0.7, cx + r, cy + r * 0.4], radius=int(r * 0.3), fill=col)
        d.polygon([(cx - r * 0.5, cy + r * 0.35), (cx - r * 0.8, cy + r * 0.9), (cx - r * 0.1, cy + r * 0.38)], fill=col)
        for k in range(3):
            d.ellipse([cx - r * 0.55 + k * r * 0.45, cy - r * 0.25, cx - r * 0.3 + k * r * 0.45, cy], fill=ink)
    elif kind == "lock":
        d.rounded_rectangle([cx - r * 0.75, cy - r * 0.1, cx + r * 0.75, cy + r], radius=12, fill=col)
        d.arc([cx - r * 0.5, cy - r * 0.9, cx + r * 0.5, cy + r * 0.2], 180, 360, fill=col, width=10)
        d.ellipse([cx - 10, cy + r * 0.3, cx + 10, cy + r * 0.5], fill=ink)
    elif kind == "chart":
        for k, hgt in enumerate((0.4, 0.7, 0.55, 1.0)):
            x = cx - r + k * r * 0.52
            d.rectangle([x, cy + r - hgt * 2 * r, x + r * 0.36, cy + r], fill=col if k % 2 else col2)
        d.line([cx - r, cy + r, cx + r, cy + r], fill=ink, width=4)
    elif kind == "gamepad":
        d.rounded_rectangle([cx - r, cy - r * 0.5, cx + r, cy + r * 0.5], radius=int(r * 0.45), fill=col)
        d.rectangle([cx - r * 0.7, cy - 8, cx - r * 0.3, cy + 8], fill=ink)
        d.rectangle([cx - r * 0.58, cy - r * 0.2, cx - r * 0.42, cy + r * 0.2], fill=ink)
        d.ellipse([cx + r * 0.35, cy - r * 0.2, cx + r * 0.55, cy], fill=col2)
        d.ellipse([cx + r * 0.55, cy, cx + r * 0.75, cy + r * 0.2], fill=col2)
    elif kind == "mic":
        d.rounded_rectangle([cx - r * 0.35, cy - r, cx + r * 0.35, cy + r * 0.2], radius=int(r * 0.35), fill=col)
        d.arc([cx - r * 0.6, cy - r * 0.4, cx + r * 0.6, cy + r * 0.6], 0, 180, fill=col2, width=7)
        d.line([cx, cy + r * 0.6, cx, cy + r], fill=col2, width=7)
    elif kind == "scissors":
        d.ellipse([cx - r, cy + r * 0.2, cx - r * 0.2, cy + r], outline=col, width=8)
        d.ellipse([cx + r * 0.2, cy + r * 0.2, cx + r, cy + r], outline=col, width=8)
        d.line([cx - r * 0.4, cy + r * 0.3, cx + r * 0.5, cy - r], fill=col2, width=9)
        d.line([cx + r * 0.4, cy + r * 0.3, cx - r * 0.5, cy - r], fill=col2, width=9)
    else:
        d.rounded_rectangle([cx - r, cy - r * 0.75, cx + r, cy + r * 0.75], radius=12, outline=col, width=6)
        d.line([cx - r * 0.6, cy - r * 0.3, cx - r * 0.2, cy, cx - r * 0.6, cy + r * 0.3], fill=col2, width=8)
        d.line([cx, cy + r * 0.3, cx + r * 0.55, cy + r * 0.3], fill=col, width=8)


ICON_BY_WORD = [("whatsapp", "chat"), ("chat", "chat"), ("mensag", "chat"), ("sms", "chat"), ("postgres", "db"),
                ("banco", "db"), ("dados", "db"), ("tenant", "db"), ("login", "lock"), ("seguran", "lock"),
                ("jwt", "lock"), ("autoriz", "lock"), ("financ", "chart"), ("métric", "chart"), ("seo", "chart"),
                ("estoque", "chart"), ("flutter", "phone"), ("app", "phone"), ("celular", "phone"),
                ("mobile", "phone"), ("jogo", "gamepad"), ("fase", "gamepad"), ("jogador", "gamepad"),
                ("voz", "mic"), ("fala", "mic"), ("microfone", "mic"), ("barb", "scissors"), ("cadeira", "scissors")]


def _icon_for(text):
    t = text.lower()
    for w, k in ICON_BY_WORD:
        if w in t:
            return k
    return "code"


def _tech_icon(name):
    """Ícone da tecnologia do atlas desenhado por nós (game/assets/tech_icons), se existir."""
    try:
        idx = json.load(open(os.path.join(ROOT, "data", "tech_icons.json"), encoding="utf8"))
    except Exception:
        return None
    key = name.lower().strip()
    for it in idx:
        if key == it["name"].lower() or key == it["id"] or key in [a.lower() for a in it.get("alias", [])]:
            p = os.path.join(ROOT, "game", "assets", "tech_icons", it["id"] + "_128.png")
            if os.path.exists(p):
                return Image.open(p).convert("RGBA")
    return None


def _graphic(d, img, box, item, project, st, idx, ink, acc, acc2, bg):
    """Bloco gráfico do painel (nunca só texto): escolhe por conteúdo e varia por peça."""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    text = item.get("title", "") + " " + item.get("text", "") + " " + item.get("tag", "")
    nums = re.findall(r"\d+[\.,]?\d*\+?", text)
    stack = [s_.strip() for s_ in item.get("tag", "").split("·") if s_.strip()]
    stack += [s_ for s_ in project.get("stack", []) if s_ not in stack]
    variant = idx % 4
    if nums and variant in (0, 2):
        variant = 3
    area = 0
    if variant == 1 and len(stack) >= 3:
        steps = stack[:4]
        n = len(steps)
        bw = (w - (n - 1) * 46) / n
        bh = min(h * 0.62, 170)
        cy = y0 + h / 2
        fnt = _font(BODY, max(16, int(bh * 0.2)))
        for k, stp in enumerate(steps):
            bx = x0 + k * (bw + 46)
            d.rounded_rectangle([bx, cy - bh / 2, bx + bw, cy + bh / 2], radius=14,
                                fill=(acc if k % 2 == 0 else acc2) + (235,))
            ic = _tech_icon(stp)
            ty = cy
            if ic is not None:
                sz = int(bh * 0.42)
                img.paste(ic.resize((sz, sz)), (int(bx + bw / 2 - sz / 2), int(cy - bh / 2 + 10)), ic.resize((sz, sz)))
                ty = cy + bh * 0.2
            lines = _wrap(d, stp, fnt, bw - 16)[:2]
            for j, ln in enumerate(lines):
                d.text((bx + bw / 2, ty - (len(lines) - 1) * fnt.size * 0.6 + j * fnt.size * 1.2), ln, font=fnt,
                       fill=bg, anchor="mm")
            if k < n - 1:
                ax = bx + bw + 8
                d.line([ax, cy, ax + 30, cy], fill=ink, width=5)
                d.polygon([(ax + 30, cy - 9), (ax + 40, cy), (ax + 30, cy + 9)], fill=ink)
        area = w * bh
    elif variant == 3 and nums:
        n = nums[0]
        fnt = _font(TITLE, int(h * 0.95))
        while d.textlength(n, font=fnt) > w * 0.5 and fnt.size > 30:
            fnt = _font(TITLE, fnt.size - 6)
        d.text((x0, y0 + h / 2), n, font=fnt, fill=acc, anchor="lm")
        nw = d.textlength(n, font=fnt)
        _icon(d, x0 + nw + (w - nw) / 2, y0 + h / 2, min(h, w - nw) * 0.33, _icon_for(text), acc2, acc, ink)
        area = w * h * 0.7
    elif variant == 2 and stack:
        fnt = _font(BODY, max(18, int(h * 0.19)))
        cx, cy = x0, y0
        for stp in stack[:8]:
            ic = _tech_icon(stp)
            icw = fnt.size + 8 if ic is not None else 0
            tw = d.textlength(stp, font=fnt) + 34 + icw
            if cx + tw > x1:
                cx = x0
                cy += fnt.size + 26
            if cy + fnt.size + 14 > y1:
                break
            d.rounded_rectangle([cx, cy, cx + tw, cy + fnt.size + 16], radius=fnt.size, outline=acc, width=3,
                                fill=acc + (40,))
            if ic is not None:
                sz = fnt.size + 4
                img.paste(ic.resize((sz, sz)), (int(cx + 12), int(cy + 6)), ic.resize((sz, sz)))
            d.text((cx + 17 + icw, cy + 6), stp, font=fnt, fill=ink)
            area += tw * (fnt.size + 16)
            cx += tw + 14
        area = max(area, w * h * 0.5)
    else:
        r_ = min(w, h) * 0.38
        _icon(d, x0 + r_ * 1.15, y0 + h / 2, r_, _icon_for(text), acc, acc2, ink)
        sx = x0 + r_ * 2.6
        for k in range(3):
            yy = y0 + h * (0.22 + k * 0.25)
            d.rounded_rectangle([sx, yy, sx + (x1 - sx) * (0.95 - k * 0.2), yy + h * 0.12], radius=8,
                                fill=(acc2 if k == 0 else acc) + (110 - k * 25,))
        area = w * h * 0.75
    return area


def make(item, pid, project, kind, dst, theme_over=None, tscale=1.0, idx=0):
    kind = kind if kind in SIZES else "frame"
    W, H = SIZES[kind]
    style_name = STYLE_BY_ID.get(pid, "startup")
    st = dict(STYLES[style_name])
    if theme_over:
        for k in ("accent", "accent2", "bg", "ink"):
            if theme_over.get(k):
                st[k] = theme_over[k]
    elif project.get("neon") and style_name == "startup":
        st["accent"] = project["neon"]
    paper = st.get("paper_mode", False)
    bg = _hex(st["paper"] if paper else st["bg"])
    ink = _hex(st["ink"])
    acc = _hex(st["accent"])
    acc2 = _hex(st["accent2"])
    img = Image.new("RGB", (W, H), bg)
    d = ImageDraw.Draw(img, "RGBA")
    M = int(min(W, H) * 0.075)  # margem
    land = W > H
    # ── fundo gráfico por estilo
    if style_name == "terminal":
        for y in range(0, H, 6):
            d.line([(0, y), (W, y)], fill=(0, 40, 12, 60))
        d.rectangle([M // 2, M // 2, W - M // 2, H - M // 2], outline=acc + (180,), width=4)
        d.rectangle([M // 2, M // 2, W - M // 2, M // 2 + 46], fill=(10, 30, 16))
        for k, c in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]):
            d.ellipse([M // 2 + 18 + k * 34, M // 2 + 12, M // 2 + 40 + k * 34, M // 2 + 34], fill=c)
    elif style_name == "arcade":
        for k in range(14):  # raios
            d.polygon([(W // 2, H * 0.42), (k * W // 7 - W // 2, -10), (k * W // 7 - W // 2 + W // 14, -10)],
                      fill=acc2 + (22,) if k % 2 else acc + (18,))
        d.rectangle([M // 3, M // 3, W - M // 3, H - M // 3], outline=acc + (255,), width=10)
        d.rectangle([M // 3 + 16, M // 3 + 16, W - M // 3 - 16, H - M // 3 - 16], outline=acc2 + (200,), width=4)
    elif style_name == "cinema" or style_name == "barber":
        d.rectangle([0, 0, W, int(H * 0.06)], fill=_hex(st["bg"]))
        d.rectangle([0, H - int(H * 0.09), W, H], fill=_hex(st["bg"]))
        d.rectangle([M // 2, M // 2 + int(H * 0.06), W - M // 2, H - M // 2 - int(H * 0.09)], outline=acc2 + (230,), width=5)
        if style_name == "barber":
            for k in range(0, W + H, 60):  # listras de poste de barbeiro na faixa de cima
                d.polygon([(k, 0), (k + 30, 0), (k + 30 - int(H * 0.06), int(H * 0.06)), (k - int(H * 0.06), int(H * 0.06))], fill=acc2 + (210,))
    elif style_name == "bar":
        for r_ in range(10, max(W, H), 70):
            d.ellipse([W * 0.7 - r_, H * 0.2 - r_, W * 0.7 + r_, H * 0.2 + r_], outline=acc + (14,), width=3)
        d.rounded_rectangle([M // 2, M // 2, W - M // 2, H - M // 2], radius=40, outline=acc + (230,), width=6)
    else:  # startup / studio
        d.polygon([(W, 0), (W, int(H * 0.55)), (int(W * 0.45), 0)], fill=acc + (40,))
        d.polygon([(0, H), (int(W * 0.35), H), (0, int(H * 0.72))], fill=acc2 + (30,))
        for k in range(6):
            d.ellipse([W - M - 26 - k * 30, M, W - M - 10 - k * 30, M + 16], fill=acc + (120,))
    # ── conteúdo
    title = (item.get("title") or project.get("title") or "").upper()
    tag = item.get("tag", "")
    status = (project.get("status") or "").upper()
    bullets = _bullets(item.get("text", ""), 2)
    cta = project.get("links", {}).get("site") or project.get("links", {}).get("github") or "inaciodev.online"
    cta = cta.replace("https://", "").replace("http://", "").rstrip("/")
    x0 = M + (12 if style_name in ("terminal", "arcade") else 0)
    y = M + (56 if style_name == "terminal" else int(H * 0.06) + 10 if paper else 6)
    inner_w = W - 2 * x0
    checks = []
    # selo (projeto / status)
    seal = (project.get("title") or pid).upper() + (("  ·  " + status) if status else "")
    fs_seal = int(H * (0.034 if not land else 0.045))
    f = _font(BODY, fs_seal)
    while d.textlength(seal, font=f) + 34 > inner_w and fs_seal > 14:
        fs_seal -= 1
        f = _font(BODY, fs_seal)
    sw = d.textlength(seal, font=f) + 34
    d.rounded_rectangle([x0, y, x0 + sw, y + fs_seal + 18], radius=10, fill=acc + (255,))
    d.text((x0 + 17, y + 6), seal, font=f, fill=bg if _lum(acc) > 0.3 else (255, 255, 255))
    y += fs_seal + 40
    # título grande, ajusta para caber em até 2 linhas
    fs_t = int(H * (0.16 if not land else 0.19) * tscale)
    while fs_t > 40:
        ft = _font(st["title_font"], fs_t)
        tl = _wrap(d, title, ft, inner_w)
        if len(tl) <= 2 and all(d.textlength(t, font=ft) <= inner_w for t in tl):
            break
        fs_t -= 4
    for t in tl:
        if style_name in ("arcade", "bar"):
            d.text((x0 + 5, y + 5), t, font=ft, fill=acc2 + (200,))
        d.text((x0, y), t, font=ft, fill=acc if not paper else ink)
        y += int(fs_t * 0.92)
    y += 6
    # subtítulo (tag)
    if tag:
        fs_s = int(H * 0.045)
        fsub = _font(st["body_font"], fs_s)
        for t in _wrap(d, tag, fsub, inner_w)[:2]:
            d.text((x0, y), t, font=fsub, fill=acc2 if not paper else acc2)
            y += int(fs_s * 1.25)
    d.line([(x0, y + 10), (x0 + min(inner_w, 260), y + 10)], fill=acc + (255,), width=6)
    y += 36
    # linhas (bullets) com corpo mínimo legível a 2 m
    px_per_mm = H / (PHYS_H[kind] * 1000.0)
    min_px = int(MIN_CAP_MM * px_per_mm / 0.7)  # cap ~70% do corpo
    footer_h = int(H * 0.11)
    avail = H - M - footer_h - y
    fs_b = int(H * (0.052 if not land else 0.075) * (0.5 + 0.5 * tscale))
    fs_b = max(fs_b, min_px)
    for _ in range(12):
        fb = _font(st["body_font"], fs_b)
        blocks = [_wrap(d, b, fb, inner_w - 46) for b in bullets]
        need = sum(len(bl) * int(fs_b * 1.3) + int(fs_b * 0.55) for bl in blocks)
        if need <= avail * 0.62:
            break
        if fs_b - 2 >= min_px:
            fs_b -= 2
        elif len(bullets) > 1:
            bullets = bullets[:-1]
        else:
            break
    fb = _font(st["body_font"], fs_b)
    for bl in [_wrap(d, b, fb, inner_w - 46) for b in bullets]:
        mark_y = y + int(fs_b * 0.35)
        if style_name == "terminal":
            d.text((x0, y), ">", font=fb, fill=acc)
        else:
            d.rectangle([x0, mark_y, x0 + 18, mark_y + 18], fill=acc)
        for t in bl:
            d.text((x0 + 40, y), t, font=fb, fill=ink if not paper else ink)
            y += int(fs_b * 1.3)
        y += int(fs_b * 0.55)
    # bloco gráfico (diagrama, chips, número ou ícone) no espaço que sobrou acima do rodapé
    gtop = y + 6
    gbot = H - M - footer_h
    garea = 0
    if gbot - gtop > H * 0.12:
        garea = _graphic(d, img, (x0, gtop, W - x0, gbot), item, project, st, idx, ink, acc, acc2, bg)
    # rodapé: CTA
    fy = H - M - int(H * 0.06)
    fs_c = int(H * (0.04 if not land else 0.05))
    fc = _font(BODY, fs_c)
    while d.textlength(">> " + cta, font=fc) > inner_w and fs_c > 14:
        fs_c -= 1
        fc = _font(BODY, fs_c)
    if paper:
        d.text((x0, H - int(H * 0.09) + int(H * 0.025)), cta.upper(), font=fc, fill=acc)
    else:
        d.text((x0, fy), ">> " + cta, font=fc, fill=acc2)
    img = _texture(img, paper, acc)
    if style_name == "terminal" or style_name == "arcade":
        img = img.filter(ImageFilter.SMOOTH)
    # ── sonda: corte, margem, contraste, legibilidade
    checks.append(("cabe", y <= H - M - footer_h + 4))
    checks.append(("nao_so_texto", garea >= W * H * 0.07))
    checks.append(("selo_cabe", sw <= inner_w + 1))
    checks.append(("cta_cabe", d.textlength(">> " + cta, font=fc) <= inner_w + 1))
    checks.append(("corpo_legivel_2m", fs_b >= min_px))
    checks.append(("contraste_texto", contrast(ink, bg) >= 4.5))
    checks.append(("contraste_titulo", contrast(acc if not paper else ink, bg) >= 3.0))
    if not all(c[1] for c in checks) and tscale > 0.55:
        return make(item, pid, project, kind, dst, theme_over, tscale * 0.85, idx)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    img.save(dst, optimize=True)
    return {"file": os.path.relpath(dst, ROOT), "kind": kind, "style": style_name, "body_px": fs_b, "min_px": min_px,
            "bullets": len(bullets), "graphic": round(garea / float(W * H), 2), "ok": all(c[1] for c in checks), "checks": {k: v for k, v in checks}}


def load_theme_over():
    p = os.path.join(ROOT, "data", "themes.json")
    if not os.path.exists(p):
        return {}
    try:
        return json.load(open(p, encoding="utf8"))
    except Exception:
        return {}
