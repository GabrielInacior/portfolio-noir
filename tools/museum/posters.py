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


# ═══════════ rodada 8: anúncios como MONTAGEM (gráfico domina, texto curto) ═══════════
TEXT_MAX = 0.30      # fração máxima da área ocupada por texto
GRAPH_MIN = 0.38     # fração mínima da área ocupada pelo bloco gráfico (texto fica <= 0,30)


def _short(text, n=2, maxc=74):
    """No máximo n frases curtas (cortadas no limite de palavra)."""
    out = []
    for b in _bullets(text, 4):
        if len(b) > maxc:
            cut = b[:maxc].rsplit(" ", 1)[0].rstrip(",;:")
            b = cut + "…"
        out.append(b)
        if len(out) >= n:
            break
    return out


def _icons_for(stack, k=6):
    out, seen = [], set()
    for s_ in stack:
        ic = _tech_icon(s_)
        if ic is None:
            continue
        key = ic.tobytes()[:4096]
        if key in seen:
            continue
        seen.add(key)
        out.append((s_, ic))
        if len(out) >= k:
            break
    return out


def _paste_icon(img, ic, cx, cy, sz):
    sz = max(8, int(sz))
    im = ic.resize((sz, sz), Image.LANCZOS)
    img.paste(im, (int(cx - sz / 2), int(cy - sz / 2)), im)


def _g_arch(d, img, box, stack, acc, acc2, ink, bg):
    """Diagrama de arquitetura em camadas com os logos: cliente -> serviços -> dados."""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    for gx in range(int(x0), int(x1), 28):
        d.line([gx, y0, gx, y1], fill=acc + (16,))
    for gy in range(int(y0), int(y1), 28):
        d.line([x0, gy, x1, gy], fill=acc + (16,))
    icons = _icons_for(stack, 6)
    if len(icons) < 2:
        return 0
    if len(icons) >= 3:
        rows = [icons[:1], icons[1:-1], icons[-1:]]
        labels = ["CLIENTE", "SERVIÇOS", "DADOS"]
    else:
        rows = [icons[:1], icons[1:]]
        labels = ["CLIENTE", "BACKEND"]
    rh = h / len(rows)
    centers = []
    fnt = _font(BODY, max(16, int(min(rh * 0.13, w * 0.04))))
    lfnt = _font(BODY, max(14, int(rh * 0.1)))
    for r, row in enumerate(rows):
        cy = y0 + rh * (r + 0.5)
        d.text((x0 + 6, y0 + rh * r + 4), labels[r], font=lfnt, fill=acc2 + (230,))
        n = len(row)
        cw = min(w * 0.9 / n, rh * 1.15)
        rowc = []
        for k, (name, ic) in enumerate(row):
            cx = x0 + w * (k + 0.5) / n
            d.rounded_rectangle([cx - cw * 0.45, cy - rh * 0.36, cx + cw * 0.45, cy + rh * 0.36], radius=18,
                                fill=bg + (235,), outline=acc + (255,), width=4)
            _paste_icon(img, ic, cx, cy - rh * 0.07, min(cw * 0.5, rh * 0.46))
            d.text((cx, cy + rh * 0.25), name, font=fnt, fill=ink, anchor="mm")
            rowc.append((cx, cy))
        centers.append(rowc)
    for r in range(len(centers) - 1):
        for a in centers[r]:
            for b in centers[r + 1]:
                ya, yb = a[1] + rh * 0.36, b[1] - rh * 0.36
                d.line([a[0], ya, b[0], yb], fill=acc2 + (230,), width=5)
                d.polygon([(b[0] - 9, yb - 14), (b[0] + 9, yb - 14), (b[0], yb)], fill=acc2)
    return w * h


def _ui_lines(d, x, y, w, n, acc, ink, gap=26):
    for k in range(n):
        ww = w * (0.9 - (k % 3) * 0.22)
        d.rounded_rectangle([x, y + k * gap, x + ww, y + k * gap + 12], radius=6,
                            fill=(ink if k else acc) + (90 if k else 230,))


def _screen_ui(d, img, sx0, sy0, sx1, sy1, kind_ui, acc, acc2, ink, bg, title, icons):
    sw, sh = sx1 - sx0, sy1 - sy0
    d.rectangle([sx0, sy0, sx1, sy1], fill=tuple(max(0, c - 8) for c in bg) + (255,))
    d.rectangle([sx0, sy0, sx1, sy0 + sh * 0.1], fill=acc)
    tf = _font(BODY, max(14, int(sh * 0.055)))
    d.text((sx0 + sw * 0.05, sy0 + sh * 0.05), title[:22], font=tf, fill=bg, anchor="lm")
    top = sy0 + sh * 0.14
    if kind_ui == "chat":
        for k in range(4):
            left = k % 2 == 0
            bw_ = sw * (0.62 if left else 0.5)
            bx = sx0 + sw * 0.06 if left else sx1 - sw * 0.06 - bw_
            by = top + k * sh * 0.2
            d.rounded_rectangle([bx, by, bx + bw_, by + sh * 0.14], radius=14,
                                fill=(acc2 if left else acc) + (220,))
            _ui_lines(d, bx + 12, by + sh * 0.035, bw_ - 24, 2, bg, bg, gap=int(sh * 0.045))
    elif kind_ui == "chart":
        vals = [0.35, 0.6, 0.45, 0.8, 0.65, 0.95]
        bw_ = sw * 0.8 / len(vals)
        base = sy1 - sh * 0.12
        for k, v in enumerate(vals):
            bx = sx0 + sw * 0.1 + k * bw_
            d.rectangle([bx + 4, base - v * sh * 0.55, bx + bw_ - 6, base], fill=(acc if k % 2 else acc2) + (230,))
        d.line([sx0 + sw * 0.08, base, sx1 - sw * 0.06, base], fill=ink, width=3)
        _ui_lines(d, sx0 + sw * 0.08, top, sw * 0.5, 2, acc, ink, gap=int(sh * 0.06))
    else:
        cw = sw * 0.42
        for k in range(4):
            cx_ = sx0 + sw * 0.05 + (k % 2) * (cw + sw * 0.06)
            cy_ = top + (k // 2) * sh * 0.4
            d.rounded_rectangle([cx_, cy_, cx_ + cw, cy_ + sh * 0.34], radius=12, fill=ink + (26,),
                                outline=(acc if k == 0 else acc2) + (200,), width=3)
            if k < len(icons):
                _paste_icon(img, icons[k][1], cx_ + cw * 0.25, cy_ + sh * 0.12, min(cw * 0.3, sh * 0.16))
            _ui_lines(d, cx_ + 10, cy_ + sh * 0.23, cw - 20, 2, acc, ink, gap=int(sh * 0.045))


def _ui_kind(text):
    t = text.lower()
    if any(w in t for w in ("whatsapp", "chat", "mensag", "sms", "conversa", "npc", "fala")):
        return "chat"
    if any(w in t for w in ("métric", "seo", "financ", "estoque", "dados", "anális", "nota", "ranking", "licita")):
        return "chart"
    return "cards"


def _g_phone(d, img, box, title, text, stack, acc, acc2, ink, bg):
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    ph = h * 0.96
    pw = min(ph * 0.5, w * 0.5)
    cx = x0 + w * 0.32
    px0, py0 = cx - pw / 2, y0 + h * 0.02
    d.rounded_rectangle([px0 + 10, py0 + 14, px0 + pw + 10, py0 + ph + 14], radius=int(pw * 0.14), fill=(0, 0, 0, 110))
    d.rounded_rectangle([px0, py0, px0 + pw, py0 + ph], radius=int(pw * 0.14), fill=(18, 18, 26),
                        outline=acc + (255,), width=5)
    icons = _icons_for(stack, 4)
    _screen_ui(d, img, px0 + pw * 0.07, py0 + ph * 0.06, px0 + pw * 0.93, py0 + ph * 0.94, _ui_kind(text),
               acc, acc2, ink, bg, title, icons)
    rx = x0 + w * 0.74
    for k, (name, ic) in enumerate(icons[:3]):
        cy = y0 + h * (0.2 + k * 0.3)
        sz = min(w * 0.22, h * 0.2)
        d.ellipse([rx - sz * 0.62, cy - sz * 0.62, rx + sz * 0.62, cy + sz * 0.62], fill=acc + (40,),
                  outline=acc + (200,), width=3)
        _paste_icon(img, ic, rx, cy, sz * 0.8)
    return w * h


def _g_laptop(d, img, box, title, text, stack, acc, acc2, ink, bg):
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    lw = min(w * 0.96, h * 1.45)
    lh = lw * 0.62
    lx0 = x0 + (w - lw) / 2
    ly0 = y0 + (h - lh * 1.08) / 2
    d.rounded_rectangle([lx0, ly0, lx0 + lw, ly0 + lh], radius=16, fill=(16, 16, 24), outline=acc + (255,), width=5)
    d.polygon([(lx0 - lw * 0.06, ly0 + lh + lh * 0.08), (lx0 + lw * 1.06, ly0 + lh + lh * 0.08),
               (lx0 + lw, ly0 + lh), (lx0, ly0 + lh)], fill=(40, 40, 54))
    icons = _icons_for(stack, 4)
    sx0, sy0, sx1, sy1 = lx0 + lw * 0.04, ly0 + lh * 0.06, lx0 + lw * 0.96, ly0 + lh * 0.94
    d.rectangle([sx0, sy0, sx1, sy0 + lh * 0.07], fill=(30, 30, 42))
    for k, c in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]):
        d.ellipse([sx0 + 10 + k * 22, sy0 + lh * 0.02, sx0 + 24 + k * 22, sy0 + lh * 0.02 + 14], fill=c)
    _screen_ui(d, img, sx0, sy0 + lh * 0.07, sx1, sy1, _ui_kind(text), acc, acc2, ink, bg, title, icons)
    return w * h


def _g_bignum(d, img, box, num, text, stack, acc, acc2, ink):
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    fnt = _font(TITLE, int(h * 0.75))
    while d.textlength(num, font=fnt) > w * 0.62 and fnt.size > 40:
        fnt = _font(TITLE, fnt.size - 8)
    d.text((x0 + 8, y0 + h * 0.5 + 6), num, font=fnt, fill=acc2 + (160,), anchor="lm")
    d.text((x0, y0 + h * 0.5), num, font=fnt, fill=acc, anchor="lm")
    nw = d.textlength(num, font=fnt)
    icons = _icons_for(stack, 4)
    gx = x0 + nw + (w - nw) * 0.08
    if icons:
        cols = 2
        sz = min((x1 - gx) / cols * 0.8, h / 2 * 0.8)
        for k, (name, ic) in enumerate(icons[:4]):
            cx = gx + (k % cols + 0.5) * (x1 - gx) / cols
            cy = y0 + (k // cols + 0.5) * h / 2
            _paste_icon(img, ic, cx, cy, sz)
    else:
        _icon(d, gx + (x1 - gx) / 2, y0 + h / 2, min(x1 - gx, h) * 0.35, _icon_for(text), acc2, acc, ink)
    return w * h


def _g_iconwall(d, img, box, stack, acc, acc2, ink, text):
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    icons = _icons_for(stack, 6)
    if not icons:
        r = min(w, h) * 0.38
        _icon(d, x0 + w / 2, y0 + h / 2, r, _icon_for(text), acc, acc2, ink)
        return w * h * 0.6
    n = len(icons)
    cols = 3 if n > 4 else 2 if n > 1 else 1
    rows = (n + cols - 1) // cols
    cw, ch = w / cols, h / rows
    fnt = _font(BODY, max(16, int(min(cw, ch) * 0.12)))
    for k, (name, ic) in enumerate(icons):
        cx = x0 + (k % cols + 0.5) * cw
        cy = y0 + (k // cols + 0.5) * ch
        s = min(cw, ch) * 0.82
        d.rounded_rectangle([cx - s / 2, cy - s / 2, cx + s / 2, cy + s / 2], radius=20, fill=acc + (28,),
                            outline=(acc if k % 2 == 0 else acc2) + (210,), width=4)
        _paste_icon(img, ic, cx, cy - s * 0.08, s * 0.55)
        d.text((cx, cy + s * 0.34), name, font=fnt, fill=ink, anchor="mm")
    return w * h


def _pick_graphic(item, project, idx):
    text = (item.get("title", "") + " " + item.get("text", "") + " " + item.get("tag", "")).lower()
    nums = re.findall(r"\b\d+[\.,]?\d*\+?", text)
    if any(w in text for w in ("como foi feito", "arquitetura", "backend", "stack", "servidor", "api ", "infra", "deploy")):
        return "arch", None
    if nums and idx % 3 == 1:
        return "bignum", nums[0]
    if any(w in text for w in ("app", "celular", "flutter", "mobile", "android", "whatsapp")):
        return "phone", None
    if any(w in text for w in ("site", "página", "landing", "web", "seo", "painel", "dashboard", "plataforma",
                               "saas", "crm")):
        return "laptop", None
    return ["phone", "laptop", "iconwall", "arch"][idx % 4], None


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
    M = int(min(W, H) * 0.06)
    land = W > H
    if style_name == "terminal":
        for yy in range(0, H, 6):
            d.line([(0, yy), (W, yy)], fill=(0, 40, 12, 60))
        d.rectangle([M // 2, M // 2, W - M // 2, H - M // 2], outline=acc + (180,), width=4)
    elif style_name == "arcade":
        for k in range(14):
            d.polygon([(W // 2, H * 0.5), (k * W // 7 - W // 2, -10), (k * W // 7 - W // 2 + W // 14, -10)],
                      fill=acc2 + (20,) if k % 2 else acc + (16,))
        d.rectangle([M // 3, M // 3, W - M // 3, H - M // 3], outline=acc + (255,), width=10)
    elif style_name in ("cinema", "barber"):
        d.rectangle([0, 0, W, int(H * 0.05)], fill=_hex(st["bg"]))
        d.rectangle([0, H - int(H * 0.07), W, H], fill=_hex(st["bg"]))
        d.rectangle([M // 2, M // 2 + int(H * 0.05), W - M // 2, H - M // 2 - int(H * 0.07)],
                    outline=acc2 + (230,), width=5)
    elif style_name == "bar":
        for r_ in range(10, max(W, H), 70):
            d.ellipse([W * 0.7 - r_, H * 0.2 - r_, W * 0.7 + r_, H * 0.2 + r_], outline=acc + (14,), width=3)
        d.rounded_rectangle([M // 2, M // 2, W - M // 2, H - M // 2], radius=40, outline=acc + (230,), width=6)
    else:
        d.polygon([(W, 0), (W, int(H * 0.5)), (int(W * 0.5), 0)], fill=acc + (36,))
        d.polygon([(0, H), (int(W * 0.35), H), (0, int(H * 0.72))], fill=acc2 + (26,))
    text_area = 0.0
    title = (item.get("title") or project.get("title") or "").upper()
    status = (project.get("status") or "").upper()
    seal = (project.get("title") or pid).upper() + (("  ·  " + status) if status else "")
    bullets = _short(item.get("text", ""), 2 if not land else 1, 70 if not land else 64)
    cta = project.get("links", {}).get("site") or project.get("links", {}).get("github") or "inaciodev.online"
    cta = cta.replace("https://", "").replace("http://", "").rstrip("/")
    stack = [s_.strip() for s_ in item.get("tag", "").replace(",", "·").split("·") if s_.strip()]
    stack += [s_ for s_ in project.get("stack", []) if s_ not in stack]
    gkind, num = _pick_graphic(item, project, idx)
    if gkind == "arch" and len(_icons_for(stack, 6)) < 2:
        gkind = "laptop"
    top_pad = int(H * 0.05) + 8 if paper else 0
    x0 = M + (10 if style_name in ("terminal", "arcade") else 0)
    inner_w = W - 2 * x0
    if land:
        tx0, tx1 = int(W * 0.58), W - x0
        gbox = (x0, M + top_pad, int(W * 0.55), H - M - int(H * 0.04))
        col_w = tx1 - tx0
    else:
        tx0, tx1 = x0, W - x0
        col_w = inner_w
    y = M + top_pad + 4
    fs_seal = int(H * (0.028 if not land else 0.04))
    f = _font(BODY, fs_seal)
    while d.textlength(seal, font=f) + 30 > col_w and fs_seal > 12:
        fs_seal -= 1
        f = _font(BODY, fs_seal)
    sw = d.textlength(seal, font=f) + 30
    d.rounded_rectangle([tx0, y, tx0 + sw, y + fs_seal + 14], radius=9, fill=acc + (255,))
    d.text((tx0 + 15, y + 5), seal, font=f, fill=bg if _lum(acc) > 0.3 else (255, 255, 255))
    text_area += sw * (fs_seal + 14)
    y += fs_seal + 26
    fs_t = int(H * (0.11 if not land else 0.13) * tscale)
    tl, ft = [title], _font(st["title_font"], fs_t)
    while fs_t > 34:
        ft = _font(st["title_font"], fs_t)
        tl = _wrap(d, title, ft, col_w)
        if len(tl) <= 2:
            break
        fs_t -= 4
    for t in tl:
        if style_name in ("arcade", "bar"):
            d.text((tx0 + 4, y + 4), t, font=ft, fill=acc2 + (200,))
        d.text((tx0, y), t, font=ft, fill=acc if not paper else ink)
        text_area += d.textlength(t, font=ft) * fs_t * 0.9
        y += int(fs_t * 0.9)
    y += 8
    px_per_mm = H / (PHYS_H[kind] * 1000.0)
    min_px = int(MIN_CAP_MM * px_per_mm / 0.7)
    fs_b = max(min_px, int(H * (0.036 if not land else 0.05) * (0.6 + 0.4 * tscale)))
    fb = _font(st["body_font"], fs_b)
    # frases COMPLETAS que cabem em até 2 linhas (nunca cortar no meio): a frase inteira, ou a primeira
    # oração dela se tiver sentido sozinha (4+ palavras); senão a peça fica só com título + gráfico
    blines = []
    want = 2 if not land else 1
    for cand in _bullets(item.get("text", ""), 6):
        if len(blines) >= want:
            break
        opts = [cand]
        if "," in cand:
            first = cand.split(",")[0].strip()
            if len(first.split()) >= 4:
                opts.append(first)
        for o in opts:
            wl = _wrap(d, o.rstrip(".") , fb, col_w - 34)
            if len(wl) <= (3 if not land else 2):
                blines.append(wl)
                break
    bullets = [" ".join(bl) for bl in blines]
    if not land:
        foot = int(H * 0.07)
        need_b = sum(len(bl) for bl in blines) * int(fs_b * 1.25) + len(blines) * int(fs_b * 0.4)
        gbox = (x0, y + 6, W - x0, H - M - foot - need_b - 18)
        by = gbox[3] + 14
    else:
        by = y + 6
    for bl in blines:
        mark_y = by + int(fs_b * 0.3)
        if style_name == "terminal":
            d.text((tx0, by), ">", font=fb, fill=acc)
        else:
            d.rectangle([tx0, mark_y, tx0 + 14, mark_y + 14], fill=acc)
        for t in bl:
            d.text((tx0 + 30, by), t, font=fb, fill=ink)
            text_area += d.textlength(t, font=fb) * fs_b * 1.1
            by += int(fs_b * 1.25)
        by += int(fs_b * 0.4)
    g = gbox
    garea = 0
    if g[3] - g[1] > H * 0.2:
        ptitle = project.get("title", pid)
        if gkind == "arch":
            garea = _g_arch(d, img, g, stack, acc, acc2, ink, bg)
        elif gkind == "phone":
            garea = _g_phone(d, img, g, ptitle, item.get("text", ""), stack, acc, acc2, ink, bg)
        elif gkind == "laptop":
            garea = _g_laptop(d, img, g, ptitle, item.get("text", ""), stack, acc, acc2, ink, bg)
        elif gkind == "bignum":
            garea = _g_bignum(d, img, g, num, item.get("text", ""), stack, acc, acc2, ink)
        else:
            garea = _g_iconwall(d, img, g, stack, acc, acc2, ink, item.get("text", ""))
    fs_c = int(H * (0.032 if not land else 0.042))
    fc = _font(BODY, fs_c)
    while d.textlength(">> " + cta, font=fc) > col_w and fs_c > 12:
        fs_c -= 1
        fc = _font(BODY, fs_c)
    cy_ = H - M - fs_c if not paper else H - int(H * 0.07) + int(H * 0.018)
    d.text((tx0, cy_), (">> " + cta) if not paper else cta.upper(), font=fc, fill=acc2 if not paper else acc)
    text_area += d.textlength(">> " + cta, font=fc) * fs_c
    img = _texture(img, paper, acc)
    tfrac = text_area / float(W * H)
    gfrac = garea / float(W * H)
    checks = [("cabe", by <= H - M + 2), ("texto_max_30", tfrac <= TEXT_MAX), ("grafico_min", gfrac >= GRAPH_MIN),
              ("max_2_bullets", len(bullets) <= 2), ("corpo_legivel_2m", fs_b >= min_px),
              ("sem_reticencias", not any(b.endswith("…") or b.endswith("...") for b in bullets)),
              ("contraste_texto", contrast(ink, bg) >= 4.5)]
    if not all(c[1] for c in checks) and tscale > 0.6:
        return make(item, pid, project, kind, dst, theme_over, tscale * 0.88, idx)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    img.save(dst, optimize=True)
    return {"file": os.path.relpath(dst, ROOT), "kind": kind, "style": style_name, "graphic_kind": gkind,
            "text_frac": round(tfrac, 3), "graphic_frac": round(gfrac, 3), "bullets": len(bullets),
            "ok": all(c[1] for c in checks), "checks": {k: v for k, v in checks}}


def load_theme_over():
    p = os.path.join(ROOT, "data", "themes.json")
    if not os.path.exists(p):
        return {}
    try:
        return json.load(open(p, encoding="utf8"))
    except Exception:
        return {}
