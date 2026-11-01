"""Rig por transferência: usa o esqueleto Mixamo de um personagem já rigado (doador) num modelo
novo da mesma altura e pose (A-pose, 1,80 m), quando o auto-rig da Mixamo recusa a malha.

blender -b -P tools/blender/char_rig_transfer.py -- doador_mixamo.fbx modelo.glb saida.fbx
Cada articulação é empurrada para o centro da malha nova naquela região (centróide dos vértices
próximos do novo menos o do doador), depois a malha nova recebe pesos automáticos.
Os nomes dos ossos ficam iguais aos da Mixamo: as mesmas animações servem.
"""
import sys

import bpy
from mathutils import Vector
from mathutils.kdtree import KDTree

argv = sys.argv[sys.argv.index("--") + 1:]
donor, model, out = argv[0], argv[1], argv[2]
mode = argv[3] if len(argv) > 3 else "all"
move_joints = mode != "nomove"
ARM_ONLY = mode == "arms"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=donor)
arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
dmeshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for a in bpy.data.actions:
    bpy.data.actions.remove(a)
if arm.animation_data:
    arm.animation_data_clear()


def world_verts(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in objs:
        me = o.evaluated_get(dg).to_mesh()
        pts += [o.matrix_world @ v.co for v in me.vertices]
        o.evaluated_get(dg).to_mesh_clear()
    return pts


dpts = world_verts(dmeshes)
before = {o.name for o in bpy.context.scene.objects}
bpy.ops.import_scene.gltf(filepath=model)
nmeshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name not in before]
# o modelo novo na mesma altura e base do doador
npts = world_verts(nmeshes)
dz0, dz1 = min(p.z for p in dpts), max(p.z for p in dpts)
nz0, nz1 = min(p.z for p in npts), max(p.z for p in npts)
s = (dz1 - dz0) / (nz1 - nz0)
dcx = sum(p.x for p in dpts) / len(dpts)
dcy = sum(p.y for p in dpts) / len(dpts)
ncx = sum(p.x for p in npts) / len(npts)
ncy = sum(p.y for p in npts) / len(npts)
for o in nmeshes:
    o.parent = None
for o in nmeshes:
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for o in nmeshes:
    for v in o.data.vertices:
        v.co = Vector(((v.co.x - ncx) * s + dcx, (v.co.y - ncy) * s + dcy, (v.co.z - nz0) * s + dz0))
npts = world_verts(nmeshes)


def tree(pts):
    t = KDTree(len(pts))
    for i, p in enumerate(pts):
        t.insert(p, i)
    t.balance()
    return t


dt, nt = tree(dpts), tree(npts)


def centroid(t, pts, p, r):
    hits = t.find_range(p, r)
    if len(hits) < 6:
        return None
    c = Vector()
    for _, i, _ in hits:
        c += pts[i]
    return c / len(hits)


# ajusta articulações no modo de edição (espaço do mundo)
bpy.ops.object.select_all(action="DESELECT")
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
mw = arm.matrix_world
inv = mw.inverted()
eb = arm.data.edit_bones
joints = {}
for b in eb:
    joints[b.name] = mw @ b.head
newpos = {}
for name, p in joints.items():
    shift = Vector()
    for _ in range(2):
        q = p + shift
        r = 0.07 if "Hand" not in name and "Foot" not in name and "Toe" not in name else 0.05
        cd = centroid(dt, dpts, p, r)
        cn = centroid(nt, npts, q, r)
        if cd is None or cn is None:
            break
        shift = cn - cd
    # só desloca no plano lateral/frontal e pouco na altura (proporção igual)
    shift.z *= 0.5
    newpos[name] = p + shift
def movable(n):
    return (not ARM_ONLY) or any(k in n for k in ("Arm", "Hand"))


for b in eb:
    if move_joints and movable(b.name):
        b.head = inv @ newpos[b.name]
for b in (eb if move_joints else []):
    if not movable(b.name):
        continue
    kids = [c for c in b.children]
    if kids:
        b.tail = sum((c.head for c in kids), Vector()) / len(kids) if len(kids) > 1 else kids[0].head
    else:
        d = (b.tail - b.head)
        b.tail = b.head + d
bpy.ops.object.mode_set(mode="OBJECT")

# pesos: copiados da malha do doador (já pesada pela Mixamo) pelo ponto mais próximo da superfície;
# o peso automático do Blender falha em malhas geradas por IA (não fechadas)
src = dmeshes[0]
if len(dmeshes) > 1:
    bpy.ops.object.select_all(action="DESELECT")
    for o in dmeshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = dmeshes[0]
    bpy.ops.object.join()
    src = bpy.context.view_layer.objects.active
for o in nmeshes:
    for vg in src.vertex_groups:
        if vg.name not in o.vertex_groups:
            o.vertex_groups.new(name=vg.name)
    m = o.modifiers.new("dt", "DATA_TRANSFER")
    m.object = src
    m.use_vert_data = True
    m.data_types_verts = {"VGROUP_WEIGHTS"}
    m.vert_mapping = "POLYINTERP_NEAREST"
    m.layers_vgroup_select_src = "ALL"
    m.layers_vgroup_select_dst = "NAME"
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier="dt")
    am = o.modifiers.new("Armature", "ARMATURE")
    am.object = arm
    o.parent = arm
    o.matrix_parent_inverse = arm.matrix_world.inverted()
bpy.data.objects.remove(src, do_unlink=True)

# braços e mãos: pesos pela distância ao osso mais próximo (o doador não tem o braço no mesmo
# lugar, e a transferência pega quadril/coxa para a mão)
def seg_dist(p, a0, a1):
    d = a1 - a0
    t = max(0.0, min(1.0, (p - a0).dot(d) / max(d.length_squared, 1e-9)))
    return (p - (a0 + d * t)).length


bones = [(b.name, mw @ b.head_local, mw @ b.tail_local) for b in arm.data.bones]
is_arm = lambda n: any(k in n for k in ("Arm", "Hand"))
for o in nmeshes:
    vgs = {vg.name: vg for vg in o.vertex_groups}
    for v in o.data.vertices:
        p = o.matrix_world @ v.co
        ds = sorted(((seg_dist(p, h, t), n) for n, h, t in bones), key=lambda x: x[0])
        best_arm = next((x for x in ds if is_arm(x[1])), None)
        best_other = next((x for x in ds if not is_arm(x[1])), None)
        if best_arm is None or best_arm[0] > 0.14 or best_arm[0] > best_other[0] * 0.85:
            continue
        near = [x for x in ds if is_arm(x[1])][:2]
        w = [1.0 / max(x[0], 0.005) ** 2 for x in near]
        tot = sum(w)
        for g in v.groups:
            o.vertex_groups[g.group].remove([v.index])
        for (dd, n), wi in zip(near, w):
            if n not in vgs:
                vgs[n] = o.vertex_groups.new(name=n)
            vgs[n].add([v.index], wi / tot, "REPLACE")
bpy.ops.export_scene.fbx(filepath=out, use_selection=False, path_mode="COPY", embed_textures=True, add_leaf_bones=False)
print("TRANSFER OK", out, "ossos", len(arm.data.bones))
