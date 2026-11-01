"""Close do rosto com combinações de shape keys (prova das expressões).

blender -b -P tools/blender/char_face_render.py -- personagem.glb saida_prefixo
"""
import math
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], argv[1]
EXPR = {
    "serio": {"brow_down": 0.6},
    "desconfiado": {"brow_down": 1.0, "squint": 1.0},
    "intrigado": {"brow_up": 1.0},
    "sorriso_canto": {"smile_r": 1.0},
    "cansado": {"squint": 1.0, "brow_up": 0.4},
    "falando": {"jaw": 1.0},
}
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
ob = next(o for o in bpy.context.scene.objects if o.type == "MESH")
arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
hb = next(b for b in arm.data.bones if b.name.endswith("Head"))
hp = arm.matrix_world @ hb.head_local
sc = bpy.context.scene
eng = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
sc.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in eng else "BLENDER_EEVEE_NEXT"
sc.world = bpy.data.worlds.new("w")
sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.1, 0.11, 0.14, 1)
sc.view_settings.view_transform = "Standard"
for n, rot, e in [("k", (60, 0, 25), 3.0), ("f", (75, 0, -50), 1.0)]:
    d = bpy.data.lights.new(n, "SUN")
    d.energy = e
    o = bpy.data.objects.new(n, d)
    o.rotation_euler = [math.radians(x) for x in rot]
    sc.collection.objects.link(o)
cam_d = bpy.data.cameras.new("c")
cam_d.lens = 85
cam = bpy.data.objects.new("c", cam_d)
sc.collection.objects.link(cam)
sc.camera = cam
target = hp + Vector((0, 0, 0.09))
cam.location = target + Vector((0.12, -0.75, 0.0))
cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
sc.render.resolution_x = 360
sc.render.resolution_y = 400
keys = ob.data.shape_keys.key_blocks
for name, vals in EXPR.items():
    for k in keys:
        if k.name != "Basis":
            k.value = vals.get(k.name, 0.0)
    sc.render.filepath = f"{out}_{name}.png"
    bpy.ops.render.render(write_still=True)
print("FACES OK", out)
