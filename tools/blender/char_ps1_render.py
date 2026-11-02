"""Folha de contato dos personagens PS1 (Blender, Workbench com cor de vértice e textura).

Uso: blender -b -P tools/blender/char_ps1_render.py -- <saida.png> <ids,separados> [anim1,anim2,...] [frac]
Sem animações: pose de repouso de frente e 3/4. Com animações: uma coluna por animação (no instante frac
do ciclo, 0..1; padrão 0,45), linhas = personagem x (frente, 3/4, lado).
"""
import math
import os
import sys

import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
D = os.path.join(ROOT, "game", "assets", "characters", "ps1")
argv = sys.argv[sys.argv.index("--") + 1:]
out = argv[0]
ids = argv[1].split(",")
anims = argv[2].split(",") if len(argv) > 2 and argv[2] else []
frac = float(argv[3]) if len(argv) > 3 else 0.45

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        sc.render.engine = eng
        break
    except TypeError:
        pass
sh = sc.display.shading
sh.light = "STUDIO"
sh.color_type = "TEXTURE"
sh.show_object_outline = False
sc.render.resolution_x = 260
sc.render.resolution_y = 420
sc.render.film_transparent = False
sc.world = bpy.data.worlds.new("w")
sc.world.color = (0.08, 0.09, 0.16)
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
sc.collection.objects.link(sun)
fill = bpy.data.objects.new("fill", bpy.data.lights.new("fill", "SUN"))
fill.data.energy = 1.2
fill.rotation_euler = (math.radians(70), 0, math.radians(150))
sc.collection.objects.link(fill)
sc.world.use_nodes = True
bg = sc.world.node_tree.nodes.get("Background")
if bg:
    bg.inputs[0].default_value = (0.08, 0.09, 0.16, 1)
    bg.inputs[1].default_value = 0.8

# animações
act_src = {}
if anims:
    bpy.ops.import_scene.gltf(filepath=os.path.join(D, "anims.glb"))
    for a in bpy.data.actions:
        act_src[a.name.split("|")[0]] = a
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.lens = 50

tiles = []
views = [("frente", 0), ("3/4", 40), ("lado", 90)] if anims else [("frente", 0), ("3/4", 40), ("costas", 180)]
cols = anims if anims else ["repouso"]
for cid in ids:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(D, cid + ".glb"))
    objs = [o for o in bpy.data.objects if o not in before]
    arm = [o for o in objs if o.type == "ARMATURE"][0]
    # cor de vértice -> cor base (o importador do glTF nem sempre liga) e transparência do rosto
    for o in objs:
        if o.type != "MESH":
            continue
        for m in o.data.materials:
            nt = m.node_tree
            bs = [n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"][0]
            bs.inputs["Roughness"].default_value = 1.0
            if not bs.inputs["Base Color"].is_linked and len(o.data.color_attributes):
                vc = nt.nodes.new("ShaderNodeVertexColor")
                vc.layer_name = o.data.color_attributes[0].name
                nt.links.new(vc.outputs["Color"], bs.inputs["Base Color"])
            try:
                m.surface_render_method = "DITHERED"
            except Exception:
                pass
    for an in cols:
        if anims:
            act = None
            for k, a in act_src.items():
                if k == an or k.endswith(an):
                    act = a
            if act is None:
                print("SEM ANIM", an, list(act_src))
                continue
            ad = arm.animation_data_create()
            ad.action = act
            try:
                ad.action_slot = act.slots[0]
            except Exception:
                pass
            f0, f1 = act.frame_range
            sc.frame_set(int(f0 + (f1 - f0) * frac))
        for vn, ang in views:
            a = math.radians(ang)
            cam.location = Vector((math.sin(a) * 3.2, -math.cos(a) * 3.2, 1.05))
            cam.rotation_euler = (math.radians(90), 0, a)
            p = os.path.join(os.path.dirname(out), "_t_%s_%s_%s.png" % (cid, an, ang))
            sc.render.filepath = p
            bpy.ops.render.render(write_still=True)
            tiles.append((cid, an, vn, p))
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)

# monta a folha (sem PIL dentro do Blender: usa imagens do próprio Blender)
W, H = sc.render.resolution_x, sc.render.resolution_y
ncol = len(cols) * len(views) if anims else len(views)
rows_ = len(ids)
if anims:
    ncol = len(cols)
    rows_ = len(ids) * len(views)
sheet = bpy.data.images.new("sheet", W * ncol, H * rows_)
px = [0.0] * (W * ncol * H * rows_ * 4)
for (cid, an, vn, p) in tiles:
    im = bpy.data.images.load(p)
    src = list(im.pixels)
    ci = ids.index(cid)
    vi = [v[0] for v in views].index(vn)
    if anims:
        col = cols.index(an)
        row = ci * len(views) + vi
    else:
        col = vi
        row = ci
    oy = (rows_ - 1 - row) * H
    ox = col * W
    for y in range(H):
        s = y * W * 4
        d = ((oy + y) * W * ncol + ox) * 4
        px[d:d + W * 4] = src[s:s + W * 4]
    os.remove(p)
sheet.pixels = px
sheet.filepath_raw = out
sheet.file_format = "PNG"
sheet.save()
print("FOLHA", out)
