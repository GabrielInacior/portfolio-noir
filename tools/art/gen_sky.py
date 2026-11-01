"""Céu noturno pintado (equiretangular 2048x1024) para o portfólio noir: gradiente azul-violeta,
brilho neon no horizonte, lua com halo, nuvens pinceladas e estrelas. Leve, sem IA.
Uso: python tools/art/gen_sky.py"""
import os, math, random
from PIL import Image, ImageDraw, ImageFilter

W, H = 2048, 1024
rnd = random.Random(7)
img = Image.new("RGB", (W, H))
px = img.load()
# gradiente vertical: topo quase preto azulado -> horizonte violeta/magenta
top = (8, 10, 26); horiz = (46, 26, 58); low = (10, 10, 22)
for y in range(H):
    t = y / H
    if t < 0.62:
        k = t / 0.62
        c = tuple(int(top[i] + (horiz[i]-top[i]) * (k**1.6)) for i in range(3))
    else:
        k = (t-0.62)/0.38
        c = tuple(int(horiz[i] + (low[i]-horiz[i]) * k) for i in range(3))
    for x in range(W):
        px[x, y] = c
d = ImageDraw.Draw(img, "RGBA")
# brilho neon do horizonte da cidade (faixas quentes e frias)
glow = Image.new("RGBA", (W, H), (0,0,0,0))
gd = ImageDraw.Draw(glow)
for cx, col in [(W*0.2,(80,40,120)), (W*0.5,(120,40,90)), (W*0.78,(40,70,140)), (W*0.9,(120,70,30))]:
    gd.ellipse((cx-360, H*0.58, cx+360, H*0.82), fill=col+(90,))
glow = glow.filter(ImageFilter.GaussianBlur(90))
img = Image.alpha_composite(img.convert("RGBA"), glow).convert("RGB")
d = ImageDraw.Draw(img, "RGBA")
# estrelas
for _ in range(900):
    x, y = rnd.randint(0, W-1), rnd.randint(0, int(H*0.6))
    b = rnd.randint(40, 170)
    d.point((x, y), fill=(b, b, min(255, b+30)))
# lua com halo
mx, my, r = W*0.72, H*0.22, 46
halo = Image.new("RGBA", (W, H), (0,0,0,0))
ImageDraw.Draw(halo).ellipse((mx-180, my-180, mx+180, my+180), fill=(180,200,255,60))
halo = halo.filter(ImageFilter.GaussianBlur(70))
img = Image.alpha_composite(img.convert("RGBA"), halo).convert("RGB")
d = ImageDraw.Draw(img, "RGBA")
d.ellipse((mx-r, my-r, mx+r, my+r), fill=(222, 230, 248))
d.ellipse((mx-r+14, my-r+6, mx+r+14, my+r+6), fill=(206, 216, 240, 120))
# nuvens pinceladas iluminadas por baixo
clouds = Image.new("RGBA", (W, H), (0,0,0,0))
cd = ImageDraw.Draw(clouds)
for _ in range(26):
    cy = rnd.randint(int(H*0.2), int(H*0.5))
    cx = rnd.randint(0, W)
    ww = rnd.randint(180, 460); hh = rnd.randint(30, 70)
    shade = rnd.randint(30, 70)
    cd.ellipse((cx-ww, cy-hh, cx+ww, cy+hh), fill=(shade+20, shade, shade+30, 120))
clouds = clouds.filter(ImageFilter.GaussianBlur(26))
img = Image.alpha_composite(img.convert("RGBA"), clouds).convert("RGB")
out = os.path.join(os.path.dirname(__file__), "..", "..", "game", "assets", "sky_night.png")
img.save(out, optimize=True)
print("ok", out)
