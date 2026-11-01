"""Corpo estilizado liso (estilo "modular character" moderno) por METABALLS sobre o rig Mixamo.

Uso (estudo do corpo nu + render de comparação):
  blender --background --factory-startup --python tools/blender/noir_body.py -- study <saida.png>
Uso como biblioteca: import noir_body; noir_body.setup_rig(); noir_body.build_skin(...)
"""
import math
import os
import sys

import bpy
from mathutils import Quaternion, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "game", "assets", "characters", "student.glb")
P = "mixamorig:"
F = {"Hips": 1.14, "Spine": 1.21, "Spine1": 1.15, "Spine2": 1.27, "Neck": 1.0, "Head": 0.58, "HeadTop_End": 0.58,
     "LeftUpLeg": 1.16, "RightUpLeg": 1.16, "LeftLeg": 1.46, "RightLeg": 1.46,
     "LeftFoot": 1.08, "RightFoot": 1.08, "LeftToeBase": 1.08, "RightToeBase": 1.08,
     "LeftShoulder": 1.3, "RightShoulder": 1.3, "LeftArm": 1.2, "RightArm": 1.2, "LeftForeArm": 1.3, "RightForeArm": 1.3,
     "LeftHand": 1.12, "RightHand": 1.12}
J = {}
rig = None


def setup_rig():
    global rig
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)
    rig = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = rig.data.edit_bones
    old = {b.name: (b.head.copy(), b.tail.copy()) for b in eb}
    roll = {b.name: b.roll for b in eb}
    nh = {}

    def place(b):
        nm = b.name.replace(P, "")
        oh, ot = old[b.name]
        if b.parent is None:
            h = Vector((oh.x, oh.y, 1.0)) if nm == "Hips" else oh.copy()
        else:
            pn = b.parent.name
            h = nh[pn] + (oh - old[pn][0]) * F.get(pn.replace(P, ""), 1.0)
        nh[b.name] = h
        b.head = h
        b.tail = h + (ot - oh) * F.get(nm, 1.0)
        for c in b.children:
            place(c)
    for b in [b for b in eb if b.parent is None]:
        place(b)
    for b in eb:
        b.roll = roll[b.name]
    for b in eb:
        J[b.name.replace(P, "")] = (b.head.copy(), b.tail.copy())
    bpy.ops.object.mode_set(mode="OBJECT")
    # pose de descanso (T) para modelar e pesar
    rig.data.pose_position = "REST"
    return rig


def H(n):
    return J[n][0]


def T(n):
    return J[n][1]


class Meta:
    """Uma família de metaballs (vira UMA malha lisa)."""

    def __init__(self, name, res=0.0075):
        self.mb = bpy.data.metaballs.new(name)
        self.mb.resolution = res
        self.mb.render_resolution = res
        self.mb.threshold = 0.18
        self.ob = bpy.data.objects.new(name, self.mb)
        bpy.context.scene.collection.objects.link(self.ob)

    def ball(self, co, r, sx=1.0, sy=1.0, sz=1.0, kind="ELLIPSOID", rot=None, neg=False, stiff=2.0):
        e = self.mb.elements.new(type=kind)
        e.co = Vector(co)
        e.radius = r
        e.stiffness = stiff
        if kind == "ELLIPSOID":
            e.size_x, e.size_y, e.size_z = sx, sy, sz      # multiplicadores do raio
        elif kind == "CUBE":
            e.size_x, e.size_y, e.size_z = r * sx * 0.6, r * sy * 0.6, r * sz * 0.6   # semi-eixos absolutos
            e.radius = r * 0.55
        if rot is not None:
            e.rotation = rot
        e.use_negative = neg
        return e

    def capsule(self, a, b, r, stiff=2.0):
        r = r * 0.62
        a, b = Vector(a), Vector(b)
        d = b - a
        e = self.mb.elements.new(type="CAPSULE")
        e.co = (a + b) / 2
        e.radius = r
        e.size_x = d.length / 2
        e.rotation = Vector((1, 0, 0)).rotation_difference(d.normalized())
        e.stiffness = stiff
        return e

    def to_mesh(self, target_faces=None, smooth=True):
        bpy.ops.object.select_all(action="DESELECT")
        self.ob.select_set(True)
        bpy.context.view_layer.objects.active = self.ob
        bpy.ops.object.convert(target="MESH")
        ob = bpy.context.view_layer.objects.active
        # funde os volumes: remalha em voxel e suaviza (tira os "calombos" das metaballs)
        rm = ob.modifiers.new("rm", "REMESH")
        rm.mode = "VOXEL"
        rm.voxel_size = 0.006
        bpy.ops.object.modifier_apply(modifier="rm")
        sm = ob.modifiers.new("sm", "SMOOTH")
        sm.factor = 0.9
        sm.iterations = 8
        bpy.ops.object.modifier_apply(modifier="sm")
        if target_faces and len(ob.data.polygons) > target_faces:
            m = ob.modifiers.new("dec", "DECIMATE")
            m.ratio = target_faces / len(ob.data.polygons)
            bpy.ops.object.modifier_apply(modifier="dec")
        if smooth:
            bpy.ops.object.shade_smooth()
        return ob


def lerp(a, b, t):
    return Vector(a).lerp(Vector(b), t)


def body_skin(m: Meta, fem=False, bulk=1.0):
    """Silhueta adulta limpa (vai ser coberta pela roupa): tronco em V, ombros, braços, pernas, mãos, pés."""
    s = 0.88 if fem else 1.0
    hips, sp, sp1, sp2, nk = H("Hips"), H("Spine"), H("Spine1"), H("Spine2"), H("Neck")
    m.ball(hips + Vector((0, 0.005, -0.04)), 0.155, 1.18 * (1.12 if fem else 1), 0.8, 0.85, stiff=1.0)
    m.ball(sp + Vector((0, 0.0, 0.05)), 0.15, 1.02 * (0.9 if fem else 1), 0.74, 1.15, stiff=0.8)
    m.ball(sp1 + Vector((0, -0.005, 0.08)), 0.18, 1.25 * s, 0.74, 1.05, stiff=0.8)
    m.ball(sp2 + Vector((0, 0.005, 0.11)), 0.19, 1.5 * s * bulk, 0.66, 0.78, stiff=0.8)
    m.ball(sp2 + Vector((0, -0.04, 0.06)), 0.12, 1.5 * s, 0.6, 0.7, stiff=1.0)       # peitoral (um volume só)
    for x in (-1, 1):
        arm = H("LeftArm" if x > 0 else "RightArm")
        m.capsule(nk + Vector((x * 0.02, 0.005, -0.03)), arm + Vector((-x * 0.03, 0.0, 0.025)), 0.075 * s, stiff=1.0)   # trapézio
        m.ball(arm + Vector((x * 0.0, 0, -0.005)), 0.07 * s, 1.0, 0.95, 1.0, stiff=0.8)                                # ombro
    m.capsule(nk + Vector((0, 0.005, -0.03)), H("Head") + Vector((0, 0.0, 0.03)), 0.13 * (0.85 if fem else 1), stiff=0.8)
    for side in ("Left", "Right"):
        ar, fa, ha, tip = H(side + "Arm"), H(side + "ForeArm"), H(side + "Hand"), T(side + "Hand")
        m.capsule(ar, lerp(ar, fa, 0.95), 0.12 * s, stiff=0.8)
        m.capsule(fa, lerp(fa, ha, 0.97), 0.1 * s, stiff=0.8)
        d = (tip - ha).normalized()
        q = Vector((1, 0, 0)).rotation_difference(d)
        m.ball(ha + d * 0.05, 0.065, 1.15, 0.9, 0.45, rot=q, stiff=1.2)
        m.capsule(ha + d * 0.07, ha + d * 0.15, 0.042, stiff=1.0)
        m.capsule(ha + d * 0.03 + Vector((0, -0.035, 0.0)), ha + d * 0.075 + Vector((0, -0.06, -0.005)), 0.026, stiff=1.0)
    for side in ("Left", "Right"):
        up, kn, an = H(side + "UpLeg"), H(side + "Leg"), H(side + "Foot")
        toe = T(side + "ToeBase")
        m.capsule(up + Vector((0, 0, -0.02)), lerp(up, kn, 0.96), 0.14 * (1.05 if fem else 1), stiff=1.0)
        m.capsule(kn, lerp(kn, an, 0.97), 0.1, stiff=1.0)
        m.ball(lerp(kn, an, 0.3) + Vector((0, 0.02, 0)), 0.085, 0.9, 1.0, 1.6, stiff=1.0)
        m.capsule(an + Vector((0, 0.02, -0.06)), Vector((toe.x, toe.y + 0.02, 0.035)), 0.065, stiff=1.0)
    return m


def head_skin(m: Meta, fem=False):
    """Cabeça: crânio oval, maxilar quadrado, queixo marcado, maçãs, nariz reto, arcada, orelhas."""
    b = H("Head")
    z0 = b.z
    w = 0.9 if fem else 1.0
    m.ball((0, b.y + 0.012, z0 + 0.155), 0.14, 0.92 * w, 1.05, 0.98, stiff=1.4)                 # crânio
    m.ball((0, b.y - 0.022, z0 + 0.08), 0.068, 0.9 * w, 0.82, 0.6, kind="CUBE", stiff=0.9)    # maxilar
    m.ball((0, b.y - 0.056, z0 + 0.05), 0.044 * (0.85 if fem else 1), 1.25, 0.8, 0.8, stiff=1.0)  # queixo
    for x in (-1, 1):
        m.ball((x * 0.048 * w, b.y - 0.05, z0 + 0.11), 0.04, 1.1, 0.8, 0.9, stiff=0.8)          # maçã
        m.ball((x * 0.083 * w, b.y + 0.005, z0 + 0.105), 0.032, 0.42, 0.9, 1.3, stiff=1.0)     # orelha
    m.ball((0, b.y - 0.085, z0 + 0.108), 0.024, 0.75, 1.0, 1.9, stiff=0.9)                     # nariz
    m.ball((0, b.y - 0.093, z0 + 0.088), 0.02, 1.05, 1.0, 0.9, stiff=0.9)                      # ponta
    m.ball((0, b.y - 0.07, z0 + 0.152), 0.03, 3.0 * w, 0.75, 0.75, stiff=0.8)                  # arcada
    return m


def look_studio(path, objs, center_z=1.5, dist=1.6):
    """Render de estudo (frontal e 3/4, busto) com workbench, fundo escuro."""
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.film_transparent = False
    if not bpy.data.worlds.get("w"):
        w = bpy.data.worlds.new("w")
        w.use_nodes = True
        w.node_tree.nodes["Background"].inputs[0].default_value = (0.04, 0.05, 0.09, 1)
        w.node_tree.nodes["Background"].inputs[1].default_value = 0.8
        sc.world = w
        for rot, en, col in (((50, 0, -35), 3.5, (1.0, 0.9, 0.8)), ((60, 0, 140), 2.5, (1.0, 0.3, 0.55)), ((-20, 0, 20), 0.8, (0.6, 0.7, 1.0))):
            ld = bpy.data.lights.new("l", "SUN")
            ld.energy = en
            ld.color = col
            lo = bpy.data.objects.new("l", ld)
            lo.rotation_euler = [math.radians(v) for v in rot]
            sc.collection.objects.link(lo)
    sc.render.resolution_x = 520
    sc.render.resolution_y = 700
    cam = bpy.data.objects.get("cam")
    if cam is None:
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.lens = 60
    outs = []
    for k, ang in enumerate((0.0, 32.0)):
        a = math.radians(ang)
        cam.location = Vector((math.sin(a) * dist, -math.cos(a) * dist, center_z + 0.05))
        d = Vector((0, 0, center_z)) - cam.location
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        p = path.replace(".png", "_%d.png" % k)
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        outs.append(p)
    return outs


def mat(name, hexcol):
    h = hexcol.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    c = [((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c]
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = (c[0], c[1], c[2], 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1)
    bs.inputs["Roughness"].default_value = 0.8
    return m


if __name__ == "__main__" and "--" in sys.argv:
    args = sys.argv[sys.argv.index("--") + 1:]
    if args and args[0] == "study":
        setup_rig()
        m = Meta("Skin")
        body_skin(m)
        head_skin(m)
        ob = m.to_mesh(9000)
        ob.data.materials.append(mat("M_skin", "#d9a27c"))
        print("faces", len(ob.data.polygons))
        look_studio(args[1], [ob])
