"""Renderiza um personagem rigado em poses de uma animação Mixamo (prova de deformação).

blender -b -P tools/blender/char_pose_render.py -- personagem.fbx animacao.fbx saida_prefixo [quadros...]
"""
import math
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
char, anim, out = argv[0], argv[1], argv[2]
frames = [float(f) for f in argv[3:]] or [0.15, 0.5, 0.85]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=char)
arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
before = set(bpy.context.scene.objects)
acts_before = set(bpy.data.actions)
bpy.ops.import_scene.fbx(filepath=anim)
new_objs = [o for o in bpy.context.scene.objects if o not in before]
act = next(a for a in bpy.data.actions if a not in acts_before)
for o in new_objs:
    bpy.data.objects.remove(o, do_unlink=True)
arm.animation_data_create()
arm.animation_data.action = act
if hasattr(arm.animation_data, "action_slot") and act.slots:
    arm.animation_data.action_slot = act.slots[0]
f0, f1 = act.frame_range

sc = bpy.context.scene
eng = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
sc.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in eng else "BLENDER_EEVEE_NEXT"
sc.world = bpy.data.worlds.new("w")
sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.12, 0.13, 0.16, 1)
sc.view_settings.view_transform = "Standard"
for n, rot, e in [("k", (55, 0, 30), 3.0), ("f", (70, 0, -60), 1.2)]:
    d = bpy.data.lights.new(n, "SUN")
    d.energy = e
    o = bpy.data.objects.new(n, d)
    o.rotation_euler = [math.radians(x) for x in rot]
    sc.collection.objects.link(o)
cam_d = bpy.data.cameras.new("c")
cam = bpy.data.objects.new("c", cam_d)
sc.collection.objects.link(cam)
sc.camera = cam
sc.render.resolution_x = 500
sc.render.resolution_y = 800
for i, fr in enumerate(frames):
    sc.frame_set(int(f0 + (f1 - f0) * fr))
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in meshes:
        me = o.evaluated_get(dg).to_mesh()
        pts += [o.matrix_world @ v.co for v in me.vertices]
        o.evaluated_get(dg).to_mesh_clear()
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    c = (lo + hi) / 2
    h = hi.z - lo.z
    a = math.radians(25)
    cam.location = Vector((c.x + math.sin(a) * h * 2.3, c.y - math.cos(a) * h * 2.3, c.z))
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = f"{out}_{i}.png"
    bpy.ops.render.render(write_still=True)
print("POSES OK", out, "quadros", f0, f1)
