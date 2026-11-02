"""Prancha de auditoria: python tools/dev_ui_sheet.py <pasta> <saida.png> [tamanhos...]"""
import sys, glob, os
from PIL import Image, ImageDraw
d, out = sys.argv[1], sys.argv[2]
sizes = sys.argv[3:] or ['360x780','405x720','430x932','844x390','1920x1080']
steps = sorted({os.path.basename(f).split('_',1)[1] for f in glob.glob(os.path.join(d,'*.png'))})
cw = 260
rows = []
for s in sizes:
    ims = []
    for st in steps:
        f = os.path.join(d, f'{s}_{st}')
        ims.append(Image.open(f).convert('RGB') if os.path.exists(f) else None)
    hs = [int(cw*i.height/i.width) if i else 50 for i in ims]
    row = Image.new('RGB', (cw*len(steps), max(hs)), (25,25,25))
    for k,i in enumerate(ims):
        if i: row.paste(i.resize((cw, hs[k])), (k*cw, 0))
    rows.append(row)
out_im = Image.new('RGB', (cw*len(steps), sum(r.height for r in rows)+4*len(rows)), (60,60,60))
y = 0
for r in rows:
    out_im.paste(r, (0,y)); y += r.height+4
out_im.save(out); print(out_im.size, steps)
