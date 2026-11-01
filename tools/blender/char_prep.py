"""Prepara um GLB do Meshy para o Mixamo e para o jogo.

blender -b -P tools/blender/char_prep.py -- entrada.glb saida_base (sem extensão) [tris_max] [tex]
Gera saida_base.fbx (para o auto-rig da Mixamo, textura embutida) e saida_base_tex.png.
Limpa: junta malhas, aplica transformações, altura 1,80 m, pés no chão, centro em X/Y,
decima até tris_max e reduz a textura para tex px.
"""
import sys

import bmesh
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, base = argv[0], argv[1]
tris_max = int(argv[2]) if len(argv) > 2 else 12000
tex_px = int(argv[3]) if len(argv) > 3 else 1024

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in bpy.context.scene.objects:
    o.select_set(o.type == "MESH")
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active
# solta de pais/empties e aplica transformações
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for o in list(bpy.context.scene.objects):
    if o != ob:
        bpy.data.objects.remove(o, do_unlink=True)

# altura 1,80 m, pés no chão, centrado
bb = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
zmin = min(v.z for v in bb)
zmax = max(v.z for v in bb)
cx = (min(v.x for v in bb) + max(v.x for v in bb)) / 2
cy = (min(v.y for v in bb) + max(v.y for v in bb)) / 2
s = 1.80 / (zmax - zmin)
for v in ob.data.vertices:
    v.co = Vector(((v.co.x - cx) * s, (v.co.y - cy) * s, (v.co.z - zmin) * s))
ob.location = (0, 0, 0)

# triângulos atuais e decimação
bm = bmesh.new()
bm.from_mesh(ob.data)
tris = sum(len(f.verts) - 2 for f in bm.faces)
bm.free()
if tris > tris_max:
    mod = ob.modifiers.new("dec", "DECIMATE")
    mod.ratio = tris_max / tris
    bpy.ops.object.modifier_apply(modifier="dec")
bm = bmesh.new()
bm.from_mesh(ob.data)
tris2 = sum(len(f.verts) - 2 for f in bm.faces)
bm.free()

# textura: reduz e salva ao lado
img = None
for m in ob.data.materials:
    if m and m.use_nodes:
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image:
                img = n.image
                break
if img:
    if max(img.size) > tex_px:
        img.scale(tex_px, tex_px)
    img.filepath_raw = base + "_tex.png"
    img.file_format = "PNG"
    img.save()
ob.name = "Body"
ob.data.name = "Body"
bpy.ops.export_scene.fbx(filepath=base + ".fbx", use_selection=False, path_mode="COPY", embed_textures=True,
                         apply_scale_options="FBX_SCALE_ALL", axis_forward="-Z", axis_up="Y")
print(f"PREP tris {tris} -> {tris2}, tex {img.size[:] if img else None}, altura 1.80")
