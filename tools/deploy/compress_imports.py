"""Imagens grandes em WebP com perda (pck pequeno: baixa rápido no navegador). VRAM comprimida (S3TC+ETC2)
dobrava o pck, então ficou de fora; mipmaps só onde a imagem é vista de longe (anúncios, panfletos).
Os .import não são versionados, então o build reaplica isto antes de importar."""
import glob, os, re
root = os.path.join(os.path.dirname(__file__), '..', '..', 'game', 'assets')
pats = ['ads/*.png', 'billboards/*.png', 'covers/*.png', 'covers/*.jpg', 'museum/**/*.png', 'museum/**/*.jpg',
        'data/collages/*.png', 'flyers/*.jpg', 'sky_night.png', 'foto_gabriel.png']
n = 0
for p in pats:
    for f in glob.glob(os.path.join(root, p), recursive=True):
        imp = f + '.import'
        if not os.path.exists(imp):
            continue
        s = open(imp, encoding='utf8').read()
        t = re.sub(r'^compress/mode=\d', 'compress/mode=1', s, flags=re.M)
        t = re.sub(r'^compress/lossy_quality=[0-9.]+', 'compress/lossy_quality=0.82', t, flags=re.M)
        t = re.sub(r'^mipmaps/generate=\w+', 'mipmaps/generate=' + ('true' if '/ads/' in f.replace(chr(92), '/') or 'flyers' in f else 'false'), t, flags=re.M)
        if t != s:
            open(imp, 'w', encoding='utf8', newline='\n').write(t); n += 1
print('imports ajustados:', n)

# texturas de SUPERFÍCIE (paredes, piso, teto, calçada, asfalto, fachadas): estilo PS1 liberado pelo usuário
# (rodada 4): 128 px, com mipmaps (o shader amostra o texel exato do nível certo, sem borrar nem cintilar).
# Ficam de fora: textos, imagens de projeto, logos, interface, o atlas de janelas e o fundo do OG.
SURF_PX = 128
m = 0
for f in glob.glob(os.path.join(root, 'tex', '*.png')):
    if os.path.basename(f) in ('janelas_atlas.png', 'og_bg.png'):
        continue
    imp = f + '.import'
    if not os.path.exists(imp):
        continue
    s = open(imp, encoding='utf8').read()
    t = re.sub(r'^process/size_limit=\d+', 'process/size_limit=%d' % SURF_PX, s, flags=re.M)
    t = re.sub(r'^mipmaps/generate=\w+', 'mipmaps/generate=true', t, flags=re.M)
    if t != s:
        open(imp, 'w', encoding='utf8', newline='\n').write(t); m += 1
print('texturas de superfície em %d px: %d' % (SURF_PX, m))
