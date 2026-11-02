"""Miniaturas (384 px) dos prints dos projetos usadas como panfletos na rua (poupa VRAM)."""
import os
from PIL import Image
root = os.path.join(os.path.dirname(__file__), '..', '..', 'game', 'assets')
out = os.path.join(root, 'flyers'); os.makedirs(out, exist_ok=True)
for id in sorted(os.listdir(os.path.join(root, 'museum'))):
    d = os.path.join(root, 'museum', id)
    if not os.path.isdir(d): continue
    pics = sorted(f for f in os.listdir(d) if f.lower().endswith(('.jpg', '.png')) and not f.startswith('numeros'))
    for i, f in enumerate(pics[:5]):
        im = Image.open(os.path.join(d, f)).convert('RGB'); im.thumbnail((384, 384))
        im.save(os.path.join(out, '%s_%d.jpg' % (id, i)), quality=82)
