"""Texturas pinceladas e tileáveis para a cidade noir: asfalto molhado, parede pintada, tijolo.
Pinceladas visíveis, variação de cor (sombras azul/roxo), sem IA. Uso: python tools/art/gen_textures.py"""
import os, math, random
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "game", "assets", "tex")
os.makedirs(OUT, exist_ok=True)
S = 512


def brush(img, rnd, base, cols, n, w_range, l_range, alpha=70):
    d = ImageDraw.Draw(img, "RGBA")
    for _ in range(n):
        x, y = rnd.randint(0, S), rnd.randint(0, S)
        ang = rnd.uniform(0, math.pi)
        ln = rnd.randint(*l_range); wd = rnd.randint(*w_range)
        col = rnd.choice(cols)
        dx, dy = math.cos(ang), math.sin(ang)
        for off in (-S, 0, S):            # tileável: repete deslocado
            for off2 in (-S, 0, S):
                d.line([(x-dx*ln+off, y-dy*ln+off2), (x+dx*ln+off, y+dy*ln+off2)], fill=col+(alpha,), width=wd)
    return img


def save(img, name):
    img.convert("RGB").save(os.path.join(OUT, name), optimize=True)
    print(name)


# asfalto molhado: base azul-escuro, pinceladas roxas/azuis e brilhos frios
rnd = random.Random(1)
img = Image.new("RGBA", (S, S), (12, 14, 26, 255))
brush(img, rnd, None, [(18,16,34),(10,12,24),(26,22,46)], 500, (6,22), (20,70), 90)
brush(img, rnd, None, [(40,46,86),(60,40,90)], 120, (2,6), (10,40), 60)   # reflexos frios
img = img.filter(ImageFilter.GaussianBlur(0.6))
save(img, "asfalto.png")

# parede pintada: base cinza-azulada, pinceladas verticais, manchas de umidade roxas
rnd = random.Random(2)
img = Image.new("RGBA", (S, S), (26, 30, 48, 255))
brush(img, rnd, None, [(20,24,40),(32,36,56),(18,20,36)], 420, (8,26), (40,120), 70)
brush(img, rnd, None, [(44,30,60),(30,40,66)], 90, (20,60), (30,90), 40)  # umidade
save(img, "parede.png")

# tijolo pintado: fileiras com variação de cor e pinceladas
rnd = random.Random(3)
img = Image.new("RGBA", (S, S), (40, 24, 28, 255))
d = ImageDraw.Draw(img, "RGBA")
bh, bw = 26, 60
for ry, y in enumerate(range(0, S, bh)):
    off = (bw//2) if ry % 2 else 0
    for x in range(-bw, S, bw):
        c = rnd.choice([(58,32,34),(48,26,30),(66,38,36),(40,22,28)])
        d.rectangle([x+off+2, y+2, x+off+bw-3, y+bh-3], fill=c+(255,))
brush(img, rnd, None, [(70,42,40),(34,20,26)], 300, (3,10), (14,40), 45)
d = ImageDraw.Draw(img, "RGBA")   # argamassa escura
for y in range(0, S, bh):
    d.line([(0,y),(S,y)], fill=(16,12,18,255), width=3)
save(img, "tijolo.png")
