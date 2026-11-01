"""Texturas pinceladas tileáveis para o bairro e as lojas-museu: madeira, carpete, papel de parede,
cortiça, metal escovado, concreto, ladrilho, calçada e janela de vitrine. Sem IA, só PIL.
Uso: python tools/art/gen_textures_interior.py"""
import os, math, random
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "game", "assets", "tex")
os.makedirs(OUT, exist_ok=True)
S = 512


def strokes(img, rnd, cols, n, w, l, alpha=70, ang=None):
    d = ImageDraw.Draw(img, "RGBA")
    for _ in range(n):
        x, y = rnd.randint(0, S), rnd.randint(0, S)
        a = rnd.uniform(0, math.pi) if ang is None else ang + rnd.uniform(-0.12, 0.12)
        ln, wd = rnd.randint(*l), rnd.randint(*w)
        c = rnd.choice(cols)
        dx, dy = math.cos(a) * ln, math.sin(a) * ln
        for ox in (-S, 0, S):
            for oy in (-S, 0, S):
                d.line([(x - dx + ox, y - dy + oy), (x + dx + ox, y + dy + oy)], fill=c + (alpha,), width=wd)


def save(img, name, blur=0.5):
    if blur:
        img = img.filter(ImageFilter.GaussianBlur(blur))
    img.convert("RGB").save(os.path.join(OUT, name), optimize=True)
    print(name)


# madeira escura de assoalho: tábuas com veios pincelados
rnd = random.Random(11)
img = Image.new("RGBA", (S, S), (46, 28, 20, 255))
d = ImageDraw.Draw(img, "RGBA")
bw = 64
for i, x in enumerate(range(0, S, bw)):
    c = rnd.choice([(58, 34, 22), (48, 28, 18), (66, 40, 26), (42, 24, 16)])
    d.rectangle([x, 0, x + bw - 2, S], fill=c + (255,))
strokes(img, rnd, [(78, 48, 30), (34, 20, 14), (90, 58, 36)], 700, (1, 4), (30, 120), 60, ang=math.pi / 2)
d = ImageDraw.Draw(img, "RGBA")
for x in range(0, S, bw):
    d.line([(x, 0), (x, S)], fill=(18, 10, 8, 255), width=3)
    yy = rnd.randint(0, S)
    d.line([(x, yy), (x + bw, yy)], fill=(20, 12, 8, 200), width=2)
save(img, "madeira.png")

# carpete vinho com trama
rnd = random.Random(12)
img = Image.new("RGBA", (S, S), (54, 16, 26, 255))
strokes(img, rnd, [(70, 22, 34), (40, 12, 22), (84, 30, 40)], 1600, (1, 3), (3, 10), 90)
d = ImageDraw.Draw(img, "RGBA")
for k in range(0, S, 64):
    d.rectangle([k + 28, 0, k + 34, S], fill=(110, 70, 30, 60))
save(img, "carpete.png", 0.4)

# papel de parede verde-escuro com listras e ornamento losango
rnd = random.Random(13)
img = Image.new("RGBA", (S, S), (22, 40, 36, 255))
d = ImageDraw.Draw(img, "RGBA")
for x in range(0, S, 64):
    d.rectangle([x, 0, x + 6, S], fill=(40, 62, 50, 255))
    d.rectangle([x + 30, 0, x + 32, S], fill=(110, 90, 50, 140))
for y in range(32, S, 64):
    for x in range(48, S, 64):
        d.polygon([(x - 8, y), (x, y - 12), (x + 8, y), (x, y + 12)], fill=(120, 96, 52, 120))
strokes(img, rnd, [(14, 26, 24), (34, 54, 46)], 380, (8, 24), (30, 100), 40, ang=math.pi / 2)
save(img, "papel_parede.png")

# cortiça
rnd = random.Random(14)
img = Image.new("RGBA", (S, S), (122, 82, 52, 255))
d = ImageDraw.Draw(img, "RGBA")
for _ in range(4000):
    x, y, r = rnd.randint(0, S), rnd.randint(0, S), rnd.randint(1, 4)
    c = rnd.choice([(140, 96, 60), (98, 64, 40), (160, 116, 74), (84, 54, 34)])
    d.ellipse([x - r, y - r, x + r, y + r], fill=c + (200,))
save(img, "cortica.png", 0.3)

# metal escovado escuro
rnd = random.Random(15)
img = Image.new("RGBA", (S, S), (40, 44, 54, 255))
strokes(img, rnd, [(58, 62, 74), (30, 32, 40), (72, 78, 92)], 900, (1, 2), (80, 260), 60, ang=0)
save(img, "metal.png", 0.3)

# concreto manchado
rnd = random.Random(16)
img = Image.new("RGBA", (S, S), (44, 46, 56, 255))
strokes(img, rnd, [(56, 58, 70), (34, 36, 46), (50, 44, 60)], 600, (10, 30), (20, 80), 50)
for _ in range(60):
    d = ImageDraw.Draw(img, "RGBA")
    x, y, r = rnd.randint(0, S), rnd.randint(0, S), rnd.randint(10, 50)
    d.ellipse([x - r, y - r, x + r, y + r], fill=(24, 22, 34, 40))
save(img, "concreto.png", 0.8)

# ladrilho preto e branco (xadrez sujo) de bar
rnd = random.Random(17)
img = Image.new("RGBA", (S, S), (20, 20, 26, 255))
d = ImageDraw.Draw(img, "RGBA")
t = 64
for i in range(S // t):
    for j in range(S // t):
        c = (176, 170, 156) if (i + j) % 2 == 0 else (24, 24, 30)
        c = tuple(max(0, min(255, v + rnd.randint(-12, 12))) for v in c)
        d.rectangle([i * t + 1, j * t + 1, i * t + t - 2, j * t + t - 2], fill=c + (255,))
strokes(img, rnd, [(60, 50, 70), (120, 110, 100)], 300, (4, 14), (10, 40), 30)
save(img, "ladrilho.png", 0.5)

# calçada de lajotas
rnd = random.Random(18)
img = Image.new("RGBA", (S, S), (40, 44, 60, 255))
d = ImageDraw.Draw(img, "RGBA")
t = 128
for i in range(S // t):
    for j in range(S // t):
        c = rnd.choice([(46, 50, 68), (38, 42, 58), (52, 54, 72)])
        d.rectangle([i * t + 3, j * t + 3, i * t + t - 3, j * t + t - 3], fill=c + (255,))
strokes(img, rnd, [(60, 64, 86), (30, 32, 46)], 400, (4, 16), (14, 50), 45)
d = ImageDraw.Draw(img, "RGBA")
for k in range(0, S, t):
    d.line([(k, 0), (k, S)], fill=(14, 16, 24, 255), width=4)
    d.line([(0, k), (S, k)], fill=(14, 16, 24, 255), width=4)
save(img, "calcada.png")

# fachada com janelas (andares) pincelada: concreto + janelas escuras emolduradas
rnd = random.Random(19)
img = Image.new("RGBA", (S, S), (30, 32, 48, 255))
strokes(img, rnd, [(38, 40, 60), (24, 26, 40), (40, 30, 52)], 500, (8, 26), (30, 110), 55, ang=math.pi / 2)
d = ImageDraw.Draw(img, "RGBA")
for y in (40, 296):
    for x in (40, 296):
        d.rectangle([x - 6, y - 6, x + 182, y + 182], fill=(18, 18, 26, 255))
        d.rectangle([x, y, x + 176, y + 176], fill=(10, 12, 20, 255))
        d.line([(x + 88, y), (x + 88, y + 176)], fill=(26, 26, 36, 255), width=6)
        d.line([(x, y + 88), (x + 176, y + 88)], fill=(26, 26, 36, 255), width=6)
        d.rectangle([x - 10, y + 182, x + 186, y + 194], fill=(46, 46, 62, 255))
save(img, "fachada_janelas.png")
