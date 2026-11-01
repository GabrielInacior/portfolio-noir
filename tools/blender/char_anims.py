"""Biblioteca de animações comum (esqueleto Mixamo): um GLB só com o esqueleto e todas as ações.

blender -b -P tools/blender/char_anims.py -- pasta_fbx saida.glb base.fbx
Cada <prefixo>_<nome>.fbx (sem skin) vira a animação <nome>. Raiz travada no lugar (sem andar
para longe), chaves otimizadas pelo exportador.
"""
import glob
import os
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
folder, out, base = argv[0], argv[1], argv[2]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=base)
arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
arm.name = "Armature"
arm.data.name = "Armature"
for o in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
    bpy.data.objects.remove(o, do_unlink=True)
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)

names = []
for f in sorted(glob.glob(os.path.join(folder, "*.fbx"))):
    nm = os.path.basename(f).split("_", 1)[1][:-4]
    if nm == "idle_serio" and "_skin" in f:
        continue
    before_o = set(bpy.context.scene.objects)
    before_a = set(bpy.data.actions)
    bpy.ops.import_scene.fbx(filepath=f)
    act = next((a for a in bpy.data.actions if a not in before_a), None)
    for o in [o for o in bpy.context.scene.objects if o not in before_o]:
        bpy.data.objects.remove(o, do_unlink=True)
    if act is None:
        continue
    act.name = nm
    act.use_fake_user = True
    # sem deslocamento da raiz no plano (o personagem fica onde foi posto)
    for fc in getattr(act, "fcurves", []):
        if fc.data_path.endswith("location") and "Hips" in fc.data_path and fc.array_index in (0, 2):
            v0 = fc.keyframe_points[0].co[1] if fc.keyframe_points else 0.0
            for kp in fc.keyframe_points:
                kp.co[1] = v0
                kp.handle_left[1] = v0
                kp.handle_right[1] = v0
    names.append(nm)

# empilha cada ação numa trilha NLA para o exportador levar todas
arm.animation_data_create()
for nm in names:
    tr = arm.animation_data.nla_tracks.new()
    tr.name = nm
    st = tr.strips.new(nm, 1, bpy.data.actions[nm])
    tr.mute = True
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animations=True, export_animation_mode="NLA_TRACKS",
                          export_optimize_animation_size=True, export_skins=True, export_yup=True)
print("ANIMS OK", out, os.path.getsize(out), "bytes", names)
