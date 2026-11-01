"""Exporta um personagem rigado pela Mixamo para o jogo: GLB leve com skin, textura JPEG e
shape keys de expressão feitas por código na região do rosto (o Meshy pinta o rosto na textura;
mover os vértices do rosto move a pintura junto).

blender -b -P tools/blender/char_export.py -- personagem_mixamo.fbx saida.glb [tex_px]

Shape keys: brow_down (sério/desconfiado), brow_up (intrigado), smile_r (sorriso de canto),
squint (cansado/desconfiado), jaw (fala). Sem animação no arquivo (vem da biblioteca comum).
"""
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], argv[1]
tex_px = int(argv[2]) if len(argv) > 2 else 1024

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)
arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
arm.name = "Armature"
arm.data.name = "Armature"
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
if arm.animation_data:
    arm.animation_data_clear()
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
ob = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
ob.name = "Body"

# ---------- marcos do rosto (espaço do mundo; frente = -Y no Blender)
mw = ob.matrix_world
head = arm.data.bones.get("mixamorig:Head") or next(b for b in arm.data.bones if b.name.endswith("Head"))
hp = arm.matrix_world @ head.head_local

# cabeça numa malha própria: as shape keys só guardam a cabeça (o Godot copia a malha inteira por key)
import bmesh as _bm
bpy.ops.object.select_all(action="DESELECT")
bpy.context.view_layer.objects.active = ob
ob.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
bmh = _bm.from_edit_mesh(ob.data)
for f in bmh.faces:
    f.select = all(((mw @ v.co) - hp).length < 0.24 and (mw @ v.co).z > hp.z - 0.07 for v in f.verts)
_bm.update_edit_mesh(ob.data)
bpy.ops.mesh.separate(type="SELECTED")
bpy.ops.object.mode_set(mode="OBJECT")
parts = [o for o in bpy.context.scene.objects if o.type == "MESH"]
headob = next(o for o in parts if o != ob)
headob.name = "Head"
body_ob = ob
ob = headob
mw = ob.matrix_world
verts = [(i, mw @ v.co) for i, v in enumerate(ob.data.vertices)]
# rosto: vértices perto da cabeça e na metade da frente
near = [(i, p) for i, p in verts if (p - hp).length < 0.20 and p.z > hp.z - 0.06]
front_y = min(p.y for _, p in near)
face = [(i, p) for i, p in near if p.y < front_y + 0.07 and abs(p.x - hp.x) < 0.075]
nose = min(face, key=lambda t: t[1].y)[1]           # ponta do nariz = vértice mais à frente
eye_z = nose.z + 0.030
brow_z = nose.z + 0.050
mouth_z = nose.z - 0.030
inv = mw.inverted()


def band(z0, z1, xmax=0.07, depth=0.05):
    return [(i, p) for i, p in face if z0 <= p.z <= z1 and abs(p.x - hp.x) <= xmax and p.y < front_y + depth]


def fall(d, r):
    return max(0.0, 1.0 - d / r)


if ob.data.shape_keys is None:
    ob.shape_key_add(name="Basis")


def key(name, fn):
    sk = ob.shape_key_add(name=name, from_mix=False)
    n = 0
    for i, p in face:
        off = fn(p)
        if off is not None and off.length > 1e-6:
            q = p + off
            sk.data[i].co = inv @ q
            n += 1
    return n


def brow(dz):
    def f(p):
        w = fall(abs(p.z - brow_z), 0.018) * fall(abs(p.x - hp.x), 0.07)
        # centro da testa desce mais (franze) que as pontas
        inner = fall(abs(p.x - hp.x), 0.035)
        return Vector((0, 0, dz * w * (0.6 + 0.6 * inner)))
    return f


def smile_r(p):
    # canto direito do personagem (x negativo no Blender) sobe e afasta
    side = hp.x - p.x
    if side < 0.005:
        return None
    w = fall(abs(p.z - mouth_z), 0.016) * fall(abs(side - 0.024), 0.022)
    return Vector((-0.006 * w, 0, 0.009 * w))


def squint(p):
    w = fall(abs(p.z - (eye_z + 0.008)), 0.010) * fall(abs(abs(p.x - hp.x) - 0.032), 0.025)
    return Vector((0, 0, -0.006 * w))


def jaw(p):
    if p.z > mouth_z + 0.002:
        return None
    w = fall(abs(p.x - hp.x), 0.05) * min(1.0, (mouth_z + 0.002 - p.z) / 0.012) * fall(abs(p.z - mouth_z), 0.05)
    return Vector((0, 0.003 * w, -0.011 * w))


counts = {
    "brow_down": key("brow_down", brow(-0.0085)),
    "brow_up": key("brow_up", brow(0.009)),
    "smile_r": key("smile_r", smile_r),
    "squint": key("squint", squint),
    "jaw": key("jaw", jaw),
}

# ---------- textura em JPEG reduzida
for m in body_ob.data.materials:
    if m and m.use_nodes:
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image:
                img = n.image
                if max(img.size) > tex_px:
                    img.scale(tex_px, tex_px)
                # sem brilho: o estilo é pintado e chapado
                bsdf = next((x for x in m.node_tree.nodes if x.type == "BSDF_PRINCIPLED"), None)
                if bsdf:
                    bsdf.inputs["Roughness"].default_value = 0.85
                    if "Specular IOR Level" in bsdf.inputs:
                        bsdf.inputs["Specular IOR Level"].default_value = 0.2
                    bsdf.inputs["Metallic"].default_value = 0.0

bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_image_format="JPEG", export_jpeg_quality=85,
                          export_animations=False, export_morph=True, export_skins=True, export_yup=True)
import os
print("EXPORT OK", out, os.path.getsize(out), "bytes", "tris", sum(len(p.vertices) - 2 for o2 in (ob, body_ob) for p in o2.data.polygons), "cabeca_v", len(ob.data.vertices),
      "ossos", len(arm.data.bones), "rosto", len(face), counts)
