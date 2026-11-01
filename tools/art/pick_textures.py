"""Escolhe as texturas do SD (tools/art/sd_tex) e gera por código as de padrão regular.
Copia para game/assets/tex/ (512, contínuas)."""
import os, numpy as np
from PIL import Image, ImageFilter, ImageDraw
R = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SD = os.path.join(R, "tools", "art", "sd_tex")
OUT = os.path.join(R, "game", "assets", "tex")
pick = {"madeira": "madeira_1", "calcada": "calcada_1", "carpete": "carpete_1", "concreto": "concreto_1",
        "azulejo": "azulejo_2", "acustico": "acustico_1", "fachada": "fachada_2", "tijolo": "tijolo_2",
        "painel_madeira": "painel_madeira_1", "papel_parede": "papel_parede_1", "parede": "concreto_0"}
for dst, src in pick.items():
    Image.open(os.path.join(SD, src + ".png")).convert("RGB").resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, dst + ".png"))
rng = np.random.default_rng(5)
def tile_noise(scale, amp):
    n = rng.random((512 // scale, 512 // scale))
    im = Image.fromarray((n * 255).astype("uint8")).resize((512, 512), Image.BICUBIC)
    a = np.asarray(im, dtype=np.float32) / 255.0
    return (a - 0.5) * amp
# asfalto: grão fino + manchas suaves (contínuo por wrap das manchas em baixa freq)
base = np.full((512, 512, 3), 70.0)
for s, a in [(64, 30), (16, 16), (2, 26)]:
    base += tile_noise(s, a)[..., None]
Image.fromarray(np.clip(base, 0, 255).astype("uint8")).save(os.path.join(OUT, "asfalto.png"))
# ladrilho: xadrez 8x8 com rejunte e brilho
im = Image.new("RGB", (512, 512)); d = ImageDraw.Draw(im); c = 64
for y in range(8):
    for x in range(8):
        col = (232, 228, 218) if (x + y) % 2 == 0 else (32, 32, 38)
        d.rectangle([x * c + 2, y * c + 2, x * c + c - 2, y * c + c - 2], fill=col)
arr = np.asarray(im, dtype=np.float32) + tile_noise(8, 14)[..., None]
Image.fromarray(np.clip(arr, 0, 255).astype("uint8")).filter(ImageFilter.SMOOTH).save(os.path.join(OUT, "ladrilho.png"))
# metal escovado com painéis e rebites
arr = np.full((512, 512), 120.0) + np.repeat(rng.random((512, 1)) * 18, 512, 1) + tile_noise(4, 10)
im = Image.fromarray(np.clip(arr, 0, 255).astype("uint8")).convert("RGB"); d = ImageDraw.Draw(im)
for k in (0, 256):
    d.line([(0, k), (512, k)], fill=(70, 70, 76), width=3); d.line([(k, 0), (k, 512)], fill=(70, 70, 76), width=3)
    for t in range(16, 512, 48):
        for (px, py) in [(k + 10, t), (t, k + 10)]:
            d.ellipse([px - 3, py - 3, px + 3, py + 3], fill=(165, 165, 172))
im.save(os.path.join(OUT, "metal.png"))
print("ok")
