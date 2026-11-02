"""Garante textura comprimida na GPU (VRAM) com mipmaps nas imagens grandes usadas em 3D.
Os .import não são versionados, então o build reaplica isto antes de importar."""
import glob, os, re
root = os.path.join(os.path.dirname(__file__), '..', '..', 'game', 'assets')
pats = ['ads/*.png', 'billboards/*.png', 'covers/*.png', 'museum/**/*.png', 'museum/**/*.jpg',
        'data/collages/*.png', 'flyers/*.jpg', 'sky_night.png', 'foto_gabriel.png']
n = 0
for p in pats:
    for f in glob.glob(os.path.join(root, p), recursive=True):
        imp = f + '.import'
        if not os.path.exists(imp):
            continue
        s = open(imp, encoding='utf8').read()
        t = re.sub(r'^compress/mode=\d', 'compress/mode=2', s, flags=re.M)
        t = re.sub(r'^mipmaps/generate=\w+', 'mipmaps/generate=true', t, flags=re.M)
        if t != s:
            open(imp, 'w', encoding='utf8', newline='\n').write(t); n += 1
print('imports ajustados:', n)
