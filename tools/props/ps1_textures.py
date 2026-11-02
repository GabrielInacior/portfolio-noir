"""Texturas no grão PS1 do jogo: reduz para 96/192 px (ou o lado pedido), achata realces e ruído fino,
quantiza na PALETA ÚNICA noir/neon do jogo e regrava. Usado nas texturas geradas pelo Stable Diffusion
(portas, outdoors de fundo, paredes) e importável (`from ps1_textures import to_ps1, PALETTE`).
Uso: python tools/props/ps1_textures.py <arquivos...> [--lado 192]"""
import glob
import os
import shutil

from PIL import Image, ImageFilter, ImageOps

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PROPS = os.path.join(ROOT, "game", "assets", "props")

PALETTE = ["05060c", "0b1020", "16121c", "1c1a28", "2a2632", "3a3850", "3e2418", "5a3c28", "7a5a3e", "a07850", "c8a070",
           "4a4e58", "6a707c", "9aa0ac", "c8ccd4", "e8ecf8", "5a1a1e", "9a2a3a", "e2384f", "ff4fa3", "ff9ad0", "ff7a3d",
           "c85a2a", "ffc83d", "d8a830", "f1e6c8", "1a3a2a", "2a6a4a", "5fd38a", "39ff6a", "1a2a5a", "26407a", "4e9bff",
           "9fd8ff", "2a1a4a", "4a2a6a", "b06bff", "5bd0ff", "e0b090", "a06a4a", "2e2a22", "6a5a48"]
BIG = {"balcao_bar", "estante_livros", "fliperama", "mesa_detetive", "mesa_monitores", "rack_servidor", "servidor_ia",
       "sofa_couro", "mesa_cartas", "mesa_escritorio", "bancada_lab", "arquivo_aco", "quadro_cortica"}


def palette_image():
    pal = []
    for h in PALETTE:
        pal += [int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)]
    pal += pal[:3] * (256 - len(PALETTE))
    im = Image.new("P", (1, 1))
    im.putpalette(pal)
    return im


def to_ps1(src, side=192, quant=True):
    im = src.convert("RGB").resize((side, side), Image.LANCZOS)
    im = im.filter(ImageFilter.MedianFilter(3)).filter(ImageFilter.SMOOTH_MORE)
    im = Image.eval(im, lambda v: int(min(v, 228) * 1.02))
    if quant:
        im = im.quantize(palette=palette_image(), dither=Image.Dither.NONE).convert("RGB")
    return im


def main():
    import sys
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    side = int(sys.argv[sys.argv.index("--lado") + 1]) if "--lado" in sys.argv else 192
    for f in args:
        if f == str(side):
            continue
        to_ps1(Image.open(f), side).save(f, quality=96)
        print("PS1:", f)


if __name__ == "__main__":
    main()
