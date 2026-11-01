"""Rig da Lena (ou de qualquer malha que a Mixamo recusou) ENCAIXADO na geometria do corpo.

blender -b -P tools/blender/char_rig_fit.py -- doador_mixamo.fbx malha.(fbx|glb) saida.fbx [debug.png]

1. Esqueleto Mixamo do doador, escalado para a altura da malha (nomes iguais: as animações servem).
2. Cada articulação vai para o CENTRO da fatia do corpo naquela altura: tronco e cabeça pelo
   centro do tronco; pernas pelo centro de cada perna; braços seguindo o próprio braço da malha
   (centros das fatias do braço, separados do tronco pelo vão da axila), até a ponta da mão.
3. Pesos por "calor dos ossos" numa cópia FECHADA da malha (voxel remesh: o Meshy entrega malha
   aberta e o cálculo falha nela), depois copiados para a malha real (face mais próxima,
   interpolado), suavizados, no máximo 4 ossos por vértice e normalizados.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
donor, model, out = argv[0], argv[1], argv[2]
debug_png = argv[3] if len(argv) > 3 else ""

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=donor)
arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
for o in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
    bpy.data.objects.remove(o, do_unlink=True)
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
if arm.animation_data:
    arm.animation_data_clear()
# esqueleto da Mixamo vem com rotação e escala 0,01 no objeto: aplica para trabalhar em metros
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

before = set(bpy.context.scene.objects)
if model.lower().endswith(".glb") or model.lower().endswith(".gltf"):
    bpy.ops.import_scene.gltf(filepath=model)
else:
    bpy.ops.import_scene.fbx(filepath=model)
new = [o for o in bpy.context.scene.objects if o not in before]
meshes = [o for o in new if o.type == "MESH"]
for o in meshes:
    mwo = o.matrix_world.copy()
    o.parent = None
    o.matrix_world = mwo
for o in [o for o in new if o.type != "MESH"]:
    bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    for m in list(o.modifiers):
        o.modifiers.remove(m)
    o.vertex_groups.clear()
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
body = bpy.context.view_layer.objects.active
body.name = "Body"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
# solda vértices duplicados (a malha do Meshy chega com frestas finas que mostram o lado de dentro)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
nv0 = len(body.data.vertices)
bpy.ops.mesh.remove_doubles(threshold=0.0008)
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode="OBJECT")
print("SOLDA", nv0, "->", len(body.data.vertices))
P = [v.co.copy() for v in body.data.vertices]
z0 = min(p.z for p in P)
z1 = max(p.z for p in P)
H = z1 - z0
print("ALTURA", round(H, 3))


def slice_pts(z, dz=0.012, pts=P):
    return [p for p in pts if abs(p.z - z) < dz]


def center(pts):
    if not pts:
        return None
    n = len(pts)
    return Vector((sum(p.x for p in pts) / n, sum(p.y for p in pts) / n, sum(p.z for p in pts) / n))


def mid_xy(pts):
    """centro pela caixa (não pelo centróide: densidade de malha desigual puxa o centróide)"""
    xs = [p.x for p in pts]
    ys = [p.y for p in pts]
    return Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, 0))


def clusters_x(pts, gap=0.02):
    """agrupa os pontos da fatia por vãos no eixo x"""
    s = sorted(pts, key=lambda p: p.x)
    groups = [[s[0]]] if s else []
    for p in s[1:]:
        if p.x - groups[-1][-1].x > gap:
            groups.append([p])
        else:
            groups[-1].append(p)
    return [g for g in groups if len(g) > 8]


# --- esqueleto do doador na altura da malha (pés no chão, centrado no tronco)
eb_heads = {b.name: arm.matrix_world @ b.head_local for b in arm.data.bones}
dz0 = min(v.z for v in eb_heads.values())
dzmax = max(v.z for v in eb_heads.values())
d_top = (arm.matrix_world @ arm.data.bones["mixamorig:HeadTop_End"].head_local).z if "mixamorig:HeadTop_End" in arm.data.bones else dzmax
s = H / max(d_top - min(0.0, dz0), 0.01)
hips_z = eb_heads["mixamorig:Hips"].z * s
torso = slice_pts(z0 + (hips_z - z0) * 1.25, 0.02)
c_t = mid_xy(clusters_x(torso, 0.03)[len(clusters_x(torso, 0.03)) // 2] if clusters_x(torso, 0.03) else torso)
print("ESCALA", round(s, 3), "CENTRO TRONCO", tuple(round(c, 3) for c in c_t))

bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
eb = arm.data.edit_bones
mw = arm.matrix_world
mwi = mw.inverted()


def W(b, which="head"):
    return mw @ getattr(eb[b], which)


def setw(b, head=None, tail=None):
    if head is not None:
        eb[b].head = mwi @ head
    if tail is not None:
        eb[b].tail = mwi @ tail


# escala uniforme em torno do chão e centraliza no tronco
for b in eb:
    h, t = mw @ b.head, mw @ b.tail
    h = Vector((h.x * s + c_t.x, h.y * s + c_t.y, h.z * s))
    t = Vector((t.x * s + c_t.x, t.y * s + c_t.y, t.z * s))
    b.head, b.tail = mwi @ h, mwi @ t

N = "mixamorig:"
# --- coluna, pescoço e cabeça: centro do tronco em cada altura
for nm in ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head"]:
    b = N + nm
    h = W(b)
    sl = slice_pts(h.z, 0.015)
    cl = clusters_x(sl, 0.03)
    if cl:
        mid = min(cl, key=lambda g: abs(center(g).x - c_t.x))
        m = mid_xy(mid)
        setw(b, head=Vector((m.x, m.y, h.z)))
for nm in ["Hips", "Spine", "Spine1", "Spine2", "Neck"]:
    nxt = {"Hips": "Spine", "Spine": "Spine1", "Spine1": "Spine2", "Spine2": "Neck", "Neck": "Head"}[nm]
    setw(N + nm, tail=W(N + nxt))
hd = W(N + "Head")
setw(N + "Head", tail=Vector((hd.x, hd.y, z1 - 0.02)))
if N + "HeadTop_End" in eb:
    setw(N + "HeadTop_End", head=Vector((hd.x, hd.y, z1 - 0.02)), tail=Vector((hd.x, hd.y, z1 + 0.1)))


# --- pernas: centro de cada perna (lado +x e -x) na altura de cada junta
def leg_center(z, side):
    sl = slice_pts(z, 0.015)
    # perto da cintura as mãos pendentes entram na fatia: só o que está junto do tronco
    lim = 0.17 if z > z0 + H * 0.38 else 0.5
    pts = [p for p in sl if 0.01 < (p.x - c_t.x) * side < lim]
    if len(pts) < 8:
        return None
    return mid_xy(pts)


for side, pre in [(1, "Left"), (-1, "Right")]:
    for nm in ["UpLeg", "Leg", "Foot"]:
        b = N + pre + nm
        h = W(b)
        z = max(h.z, 0.06) if nm == "Foot" else h.z
        c = leg_center(z, side)
        if c:
            setw(b, head=Vector((c.x, c.y if nm != "Foot" else h.y, h.z)))
    setw(N + pre + "UpLeg", tail=W(N + pre + "Leg"))
    setw(N + pre + "Leg", tail=W(N + pre + "Foot"))
    # pé e dedo: frente do pé da malha
    fh = W(N + pre + "Foot")
    foot = [p for p in P if p.z < 0.08 and (p.x - c_t.x) * side > 0.01]
    if foot:
        front = min(foot, key=lambda p: p.y)  # frente = -y (Mixamo/Meshy olham para -y)
        toe = Vector((fh.x, front.y + 0.04, 0.02))
        setw(N + pre + "Foot", tail=toe)
        if N + pre + "ToeBase" in eb:
            setw(N + pre + "ToeBase", head=toe, tail=Vector((fh.x, front.y, 0.02)))
        if N + pre + "Toe_End" in eb:
            setw(N + pre + "Toe_End", head=Vector((fh.x, front.y, 0.02)), tail=Vector((fh.x, front.y - 0.04, 0.02)))


# --- braços: ombro pela largura do tronco na altura do ombro; braço como linha até a ponta da mão
def hand_tip(side):
    band = [p for p in P if z0 + H * 0.38 < p.z < z0 + H * 0.56 and (p.x - c_t.x) * side > 0]
    far = sorted(band, key=lambda p: -abs(p.x - c_t.x))[:200]
    lowest = min(far, key=lambda p: p.z)
    return lowest


z_sh = None
for side, pre in [(1, "Left"), (-1, "Right")]:
    d_sh = W(N + pre + "Arm")
    z_sh = d_sh.z
    sl = slice_pts(z_sh, 0.015)
    outer = max(sl, key=lambda p: (p.x - c_t.x) * side)
    width = abs(outer.x - c_t.x)
    yc = mid_xy([p for p in sl if abs(p.x - c_t.x) < width]).y
    shoulder = Vector((c_t.x + side * (width - 0.055), yc, z_sh))
    tip = hand_tip(side)
    line = tip - shoulder
    elbow = shoulder + line * 0.44 + Vector((0, 0.015, 0))
    wrist = shoulder + line * 0.80
    setw(N + pre + "Arm", head=shoulder, tail=elbow)
    setw(N + pre + "ForeArm", head=elbow, tail=wrist)
    hand_dir = tip - wrist
    setw(N + pre + "Hand", head=wrist, tail=wrist + hand_dir * 0.5)
    sp2 = W(N + "Spine2", "tail")
    setw(N + pre + "Shoulder", head=Vector((c_t.x + side * 0.05, yc, z_sh + 0.06)), tail=shoulder)
    up = hand_dir.normalized()
    hl = hand_dir.length
    for b in [b for b in eb if b.name.startswith(N + pre + "Hand") and b.name != N + pre + "Hand"]:
        nm = b.name
        idx = int(nm[-1]) if nm[-1].isdigit() else 1
        lat = Vector((-0.022 * side, -0.02, 0)) if "Thumb" in nm else Vector((0, 0, 0))
        base = wrist + up * (hl * (0.42 + 0.16 * (idx - 1))) + lat
        b.head = mwi @ base
        b.tail = mwi @ (base + up * hl * 0.15)
    print("BRACO", pre, "ombro", tuple(round(c, 3) for c in shoulder), "cotovelo", tuple(round(c, 3) for c in elbow),
          "punho", tuple(round(c, 3) for c in wrist), "ponta", tuple(round(c, 3) for c in tip))

# rolagem coerente: recalcula pelo eixo Z global (o retarget no Godot compensa qualquer rolagem)
bpy.ops.armature.select_all(action="SELECT")
bpy.ops.armature.calculate_roll(type="GLOBAL_POS_Z")
bpy.ops.object.mode_set(mode="OBJECT")

# --- pesos: calor dos ossos numa cópia fechada, transferidos para a malha real
proxy = body.copy()
proxy.data = body.data.copy()
proxy.name = "Proxy"
bpy.context.scene.collection.objects.link(proxy)
rm = proxy.modifiers.new("vox", "REMESH")
rm.mode = "VOXEL"
rm.voxel_size = float(__import__("os").environ.get("VOXEL", "0.005"))
bpy.context.view_layer.objects.active = proxy
bpy.ops.object.modifier_apply(modifier="vox")
dec = proxy.modifiers.new("dec", "DECIMATE")
dec.ratio = 0.25
bpy.ops.object.modifier_apply(modifier="dec")
bpy.ops.object.select_all(action="DESELECT")
proxy.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
print("PROXY pesos", len(proxy.vertex_groups))

for g in proxy.vertex_groups:
    body.vertex_groups.new(name=g.name)
dt = body.modifiers.new("dt", "DATA_TRANSFER")
dt.object = proxy
dt.use_vert_data = True
dt.data_types_verts = {"VGROUP_WEIGHTS"}
dt.vert_mapping = "POLYINTERP_NEAREST"
dt.layers_vgroup_select_src = "ALL"
dt.layers_vgroup_select_dst = "NAME"
bpy.ops.object.select_all(action="DESELECT")
bpy.context.view_layer.objects.active = body
body.select_set(True)
bpy.ops.object.modifier_apply(modifier="dt")
bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
bpy.ops.object.mode_set(mode="OBJECT")
# dedos: peso vai para a mão (dedos encaixados por estimativa torceriam a mão ao fechar)
names = {g.index: g.name for g in body.vertex_groups}
for side in ["Left", "Right"]:
    hand = body.vertex_groups[N + side + "Hand"]
    fing = [g for g in body.vertex_groups if g.name.startswith(N + side + "Hand") and g.name != N + side + "Hand"]
    fidx = {g.index for g in fing}
    for v in body.data.vertices:
        add = sum(g.weight for g in v.groups if g.group in fidx)
        if add > 0:
            cur = next((g.weight for g in v.groups if g.group == hand.index), 0.0)
            hand.add([v.index], min(1.0, cur + add), "REPLACE")
    for g in fing:
        g.remove([v.index for v in body.data.vertices])
# vértice sem peso segue o osso mais próximo
segs = [(b.name, arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local) for b in arm.data.bones
        if "Hand" not in b.name or b.name.endswith("Hand")]


def dseg(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (a + ab * t - p).length


fixed = 0
for v in body.data.vertices:
    if sum(g.weight for g in v.groups) < 1e-4:
        p = body.matrix_world @ v.co
        nm = min(segs, key=lambda sgm: dseg(p, sgm[1], sgm[2]))[0]
        body.vertex_groups[nm].add([v.index], 1.0, "REPLACE")
        fixed += 1
print("SEM PESO CORRIGIDOS", fixed)
# raio do braço (m): até onde um vértice conta como manga/pele do braço. Braço pendente encostado
# na jaqueta pede raio curto no antebraço, senão a barra da jaqueta vai junto com o gesto.
R_ARM = float(os.environ.get("R_ARM", "0.055"))
R_FORE = float(os.environ.get("R_FORE", "0.042"))
R_HAND = float(os.environ.get("R_HAND", "0.075"))
# separação por região: mão encostada na coxa e braço junto do tronco "vazam" peso entre si
ARM_CHAIN = {s_: {N + s_ + "Arm", N + s_ + "ForeArm", N + s_ + "Hand"} for s_ in ["Left", "Right"]}
ALL_ARM = ARM_CHAIN["Left"] | ARM_CHAIN["Right"]
gidx = {g.name: g.index for g in body.vertex_groups}
gname = {g.index: g.name for g in body.vertex_groups}
arm_heads = {s_: arm.matrix_world @ arm.data.bones[N + s_ + "Arm"].head_local for s_ in ["Left", "Right"]}
cut = 0
for v in body.data.vertices:
    p = body.matrix_world @ v.co
    dists = {sgm[0]: dseg(p, sgm[1], sgm[2]) for sgm in segs}
    nearest = min(dists, key=dists.get)
    side = ""
    for s_ in ["Left", "Right"]:
        # dentro do braço de verdade (manga/pele), não a lateral do tronco que encosta nele
        in_arm = dists[N + s_ + "Arm"] < R_ARM or dists[N + s_ + "ForeArm"] < R_FORE or dists[N + s_ + "Hand"] < R_HAND
        if in_arm and min(dists[n_] for n_ in ARM_CHAIN[s_]) <= min(dists.values()) + 1e-6:
            side = s_
    if not side and nearest in ALL_ARM:
        nearest = min((n_ for n_ in dists if n_ not in ALL_ARM), key=dists.get)
    for g in list(v.groups):
        nm = gname[g.group]
        drop = False
        if side:
            # vértice do braço: só ossos do próprio braço (e ombro/peito perto da axila)
            if nm not in ARM_CHAIN[side]:
                near_sh = (p - arm_heads[side]).length < 0.09
                drop = not (near_sh and (nm.endswith("Shoulder") or nm.endswith("Spine2")))
        else:
            # tronco/perna: sem ossos do braço, a não ser junto do ombro
            if nm in ALL_ARM:
                s_ = "Left" if nm in ARM_CHAIN["Left"] else "Right"
                drop = (p - arm_heads[s_]).length > 0.09
        if drop and g.weight > 0:
            body.vertex_groups[nm].remove([v.index])
            cut += 1
    if sum(g.weight for g in v.groups) < 1e-4:
        body.vertex_groups[nearest].add([v.index], 1.0, "REPLACE")
print("PESOS CRUZADOS CORTADOS", cut)
bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
bpy.ops.object.vertex_group_smooth(group_select_mode="ALL", factor=0.5, repeat=2)
bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
bpy.ops.object.vertex_group_normalize_all(lock_active=False)
bpy.ops.object.mode_set(mode="OBJECT")
bpy.data.objects.remove(proxy, do_unlink=True)
body.parent = arm
body.matrix_parent_inverse = arm.matrix_world.inverted()
mod = body.modifiers.new("Armature", "ARMATURE")
mod.object = arm


def render_debug(path, poses):
    """renders na mesma sessão: repouso e poses extremas (braço erguido, apontar, cruzar)"""
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x = 520
    sc.render.resolution_y = 760
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2.0
    import os
    base, ext = os.path.splitext(path)
    for i, (name, rots) in enumerate(poses):
        for pb in arm.pose.bones:
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = (0, 0, 0)
        for bn, eul in rots.items():
            pb = arm.pose.bones.get(N + bn)
            if pb:
                pb.rotation_euler = tuple(math.radians(v) for v in eul)
        for view, loc, rot in [("f", (c_t.x, -4, 0.95), (90, 0, 0)), ("l", (c_t.x + 4, c_t.y, 0.95), (90, 0, 90))]:
            cam.location = loc
            cam.rotation_euler = tuple(math.radians(v) for v in rot)
            sc.render.filepath = f"{base}_{name}_{view}{ext}"
            bpy.ops.render.render(write_still=True)
    for pb in arm.pose.bones:
        pb.rotation_euler = (0, 0, 0)


if debug_png:
    render_debug(debug_png, [
        ("repouso", {}),
        ("ergue", {"LeftArm": (0, 0, 70), "RightArm": (0, 0, -70), "LeftForeArm": (0, 0, 30), "RightForeArm": (0, 0, -30)}),
        ("frente", {"LeftArm": (70, 0, 0), "RightArm": (70, 0, 0), "LeftForeArm": (0, 0, 60), "RightForeArm": (0, 0, -60)}),
    ])

if out.lower().endswith(".blend"):
    bpy.ops.wm.save_as_mainfile(filepath=out)
else:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=out, use_selection=True, add_leaf_bones=False, bake_anim=False,
                             path_mode="COPY", embed_textures=True)
print("RIG OK", out)
