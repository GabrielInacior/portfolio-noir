"""Renderiza um personagem (GLB/FBX) para comparação: frente e 3/4, corpo inteiro e busto.

blender -b -P tools/blender/char_render.py -- modelo.glb saida_prefixo
Gera <prefixo>_corpo.png (frente | 3/4) e <prefixo>_busto.png (frente | 3/4).
"""
import math
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
if src.lower().endswith(".fbx"):
    bpy.ops.import_scene.fbx(filepath=src)
else:
    bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
zmin, zmax = min(p.z for p in pts), max(p.z for p in pts)
h = zmax - zmin
cx = (min(p.x for p in pts) + max(p.x for p in pts)) / 2
cy = (min(p.y for p in pts) + max(p.y for p in pts)) / 2

sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE_NEXT"
sc.world = bpy.data.worlds.new("w")
sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.12, 0.13, 0.16, 1)
sc.world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
sc.view_settings.view_transform = "Standard"

def light(name, rot, energy, col=(1, 1, 1)):
    d = bpy.data.lights.new(name, "SUN")
    d.energy = energy
    d.color = col
    o = bpy.data.objects.new(name, d)
    o.rotation_euler = rot
    sc.collection.objects.link(o)

light("key", (math.radians(55), 0, math.radians(30)), 3.0)
light("fill", (math.radians(70), 0, math.radians(-60)), 1.2, (0.8, 0.85, 1.0))
light("rim", (math.radians(110), 0, math.radians(180)), 2.0, (1.0, 0.5, 0.8))

cam_d = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_d)
sc.collection.objects.link(cam)
sc.camera = cam


def shot(path, yaw_deg, target_z, dist, lens, w, hgt):
    sc.render.resolution_x = w
    sc.render.resolution_y = hgt
    cam_d.lens = lens
    # Meshy/glTF: personagem olhando para -Y no Blender após import (frente = -Y)
    a = math.radians(yaw_deg)
    pos = Vector((cx + math.sin(a) * dist, cy - math.cos(a) * dist, target_z))
    cam.location = pos
    d = Vector((cx, cy, target_z)) - pos
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


for yaw, tag in [(0, "f"), (35, "q")]:
    shot(f"{out}_corpo_{tag}.png", yaw, zmin + h * 0.5, h * 2.2, 50, 600, 900)
    shot(f"{out}_busto_{tag}.png", yaw, zmin + h * 0.85, h * 0.75, 50, 600, 600)
print("RENDER OK", out, "altura", round(h, 3))
