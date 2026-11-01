"""Texturas dos 4 personagens no grão PS1 do jogo (mesma PALETA ÚNICA dos props, lida de
tools/props/ps1_textures.py): 512 px (256 deixava pontos escuros nas emendas das ilhas), realces especulares achatados, quantizadas na paleta.
Originais guardados em tools/props/_orig (fora do git). Rodar de novo é seguro (parte do original).
Uso: python tools/blender/char_ps1_textures.py [lado_px]
"""
import os
import shutil
import sys

from PIL import Image, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "props"))
import ps1_textures as P  # noqa: E402  (paleta compartilhada com os props)

CH = os.path.join(ROOT, "game", "assets", "characters", "meshy")
TEX = ["vance_vance_tex.jpg", "otto_otto_tex.jpg", "kai_kai_tex.jpg", "lena_Image_0.jpg"]
side = int(sys.argv[1]) if len(sys.argv) > 1 else 512
pim = P.palette_image()
for name in TEX:
    f = os.path.join(CH, name)
    orig = os.path.join(P.ORIG, "char_" + name)
    if not os.path.exists(orig):
        shutil.copy2(f, orig)
    src = Image.open(orig).convert("RGB")
    # a textura da Meshy é um mosaico de ilhas: reduzir pela caixa (média por bloco) vaza menos
    # cor de uma ilha na outra do que filtros largos
    im = src.resize((side, side), Image.BOX)
    im = im.filter(ImageFilter.MedianFilter(3))
    im = Image.eval(im, lambda v: int(min(v, 232) * 1.02))
    q = im.quantize(palette=pim, dither=Image.Dither.NONE).convert("RGB")
    # pele (rosto, mãos): a paleta tem poucos tons de pele e o rosto viraria máscara clara; ali só
    # posteriza (mantém os meios-tons que desenham nariz, olhos e boca), o resto fica na paleta
    import numpy as np
    a = np.asarray(im).astype(np.int16)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    skin = (r > g) & (g > b) & ((r - b) > 28) & (r > 70) & ((r - g) < 90)
    post = (a // 16) * 16 + 8
    out = np.where(skin[..., None], post, np.asarray(q).astype(np.int16))
    # branco nunca puro: camisa/colarinho viram cinza claro levemente quente (o branco chapado
    # estourava com a luz da rua e o contorno neon, sem forma)
    o = out.astype(np.float32)
    lum = o.mean(2, keepdims=True)
    hi = lum > 170
    warm = np.array([200, 192, 178], np.float32)
    o = np.where(hi, warm * (0.82 + 0.18 * (lum - 170) / 85.0) * (o / np.maximum(lum, 1)) ** 0.3, o)
    out = np.clip(o, 0, 214)
    Image.fromarray(out.astype(np.uint8)).save(f, quality=96)
    # máscara do contorno: forte no escuro, fraca no claro (superfície clara não "brilha" de neon)
    rim = (255 * np.clip(1.15 - out.mean(2) / 200.0, 0.15, 1.0)).astype(np.uint8)
    Image.fromarray(rim, "L").save(f.replace(".jpg", "_rim.png"))
    print("  pele preservada: %.1f%%" % (skin.mean() * 100))
    print("PS1", name, side)
