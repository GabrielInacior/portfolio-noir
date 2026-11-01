"""Elenco NOIR estilizado (personagem moderno liso, proporções humanas) sobre o rig Mixamo.

Corpo e cabeça por metaballs fundidas (noir_body.py) + remalha e suavização; cabelo em mechas
grossas; roupas noir em volumes (sobretudo, jaqueta de couro, colete e avental, moletom com capuz);
decalques de rosto projetados na superfície (expressões em atlas). Pesos automáticos (calor dos ossos)
por peça; peças rígidas (cabelo, chapéu, óculos) presas à cabeça.

blender --background --factory-startup --python tools/blender/noir_cast.py [-- preview <pasta>]
Saída: game/assets/characters/noir_cast.glb (malhas Cast_<id>)
"""
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(__file__))
import noir_body as nb  # noqa: E402

ROOT = nb.ROOT
OUT = os.path.join(ROOT, "game", "assets", "characters", "noir_cast.glb")
P = nb.P
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

rig = nb.setup_rig()
H, T, Meta, lerp = nb.H, nb.T, nb.Meta, nb.lerp


def mat(name, hexcol):
    return nb.mat(name, hexcol)


def finish(ob, matname, auto=True, rigid=None):
    ob.data.materials.clear()
    ob.data.materials.append(matname if not isinstance(matname, str) else bpy.data.materials[matname])
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    if rigid:
        bpy.ops.object.parent_set(type="ARMATURE_NAME")
        vg = ob.vertex_groups.get(P + rigid) or ob.vertex_groups.new(name=P + rigid)
        vg.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    elif auto:
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    return ob


def mesh_from(name, verts, faces):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def smooth_mod(ob, levels=2):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    m = ob.modifiers.new("sub", "SUBSURF")
    m.levels = levels
    bpy.ops.object.modifier_apply(modifier="sub")
    bpy.ops.object.shade_smooth()




def shell(cid, name, skin_ob, pick, offset, color, rigid="Head", extra=None):
    """Casca justa: copia as faces da pele escolhidas por pick(co, normal) e afasta pela normal."""
    me = skin_ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    keep = [f for f in bm.faces if all(pick(v.co, v.normal) for v in f.verts)]
    out = bmesh.new()
    vmap = {}
    for f in keep:
        vs = []
        for v in f.verts:
            if v.index not in vmap:
                off = offset(v.co) if callable(offset) else offset
                vmap[v.index] = out.verts.new(v.co + v.normal * off)
            vs.append(vmap[v.index])
        try:
            out.faces.new(vs)
        except ValueError:
            pass
    bm.free()
    nm = bpy.data.meshes.new(name + "_" + cid)
    out.to_mesh(nm)
    out.free()
    ob = bpy.data.objects.new(name + "_" + cid, nm)
    bpy.context.scene.collection.objects.link(ob)
    sol = ob.modifiers.new("sol", "SOLIDIFY")
    sol.thickness = 0.006
    sol.offset = 1.0
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier="sol")
    bpy.ops.object.shade_smooth()
    return finish(ob, mat("M_%s_%s" % (cid, name.lower()), color), rigid=rigid)

# ───────────────────────────── peças
def skin_body(cid, c):
    m = Meta("Skin_" + cid)
    nb.body_skin(m, c.get("fem", False), c.get("bulk", 1.0))
    head_skin(m, c)
    ob = m.to_mesh(9000)
    return finish(ob, mat("M_%s_skin" % cid, c["skin"]))


def head_skin(m, c):
    """Cabeça com massa adulta: crânio, maxilar largo (bloco arredondado), queixo forte, maçãs e
    bochechas firmes, testa e arcada com volume, nariz com ponte e asas, lábios, orelhas reais."""
    b = H("Head")
    z0 = b.z
    fem = c.get("fem", False)
    w = c.get("face_w", 0.94 if fem else 1.06)
    jaw = c.get("jaw", 1.0)
    m.ball((0, b.y + 0.012, z0 + 0.155), 0.145, 0.95 * w, 1.06, 0.98, stiff=1.4)                     # crânio
    m.ball((0, b.y - 0.02, z0 + 0.082), 0.075, 1.0 * w * jaw, 0.85, 0.62, kind="CUBE", stiff=0.9)    # maxilar largo
    m.ball((0, b.y - 0.058, z0 + 0.048), 0.05 * (0.85 if fem else 1) * c.get("chin", 1.0), 1.3, 0.85, 0.85, stiff=1.0)  # queixo
    for x in (-1, 1):
        m.ball((x * 0.052 * w, b.y - 0.048, z0 + 0.112), 0.05, 1.15, 0.85, 0.9, stiff=0.8)          # maçã
        m.ball((x * 0.058 * w, b.y - 0.035, z0 + 0.075), 0.052, 1.0, 0.85, 1.0, stiff=0.8)          # bochecha firme
        m.ball((x * 0.086 * w, b.y + 0.004, z0 + 0.108), 0.04, 0.45, 0.95, 1.35, stiff=1.0)         # orelha
        m.ball((x * 0.014, b.y - 0.093, z0 + 0.09), 0.014, 1.0, 1.0, 0.9, stiff=0.9)                # asa do nariz
    m.ball((0, b.y - 0.085, z0 + 0.112), 0.026 * c.get("nose", 1.0), 0.75, 1.0, 1.9, stiff=0.9)    # ponte
    m.ball((0, b.y - 0.095, z0 + 0.09), 0.022 * c.get("nose", 1.0), 1.05, 1.0, 0.9, stiff=0.9)     # ponta
    m.ball((0, b.y - 0.072, z0 + 0.152), 0.034, 3.1 * w, 0.8, 0.8, stiff=0.8)                      # arcada
    m.ball((0, b.y - 0.06, z0 + 0.19), 0.06, 2.0 * w, 0.7, 0.9, stiff=0.8)                         # testa
    m.ball((0, b.y - 0.077, z0 + 0.06), 0.022, 1.6, 0.8, 0.6, stiff=0.8)                           # lábios


def cloth_top(cid, c, color, sleeves=True, long_sleeve=True, inflate=0.018, collar_h=0.0):
    """camisa/jaqueta/sobretudo: o tronco e os braços do corpo, inflados."""
    fem = c.get("fem", False)
    s = 0.88 if fem else 1.0
    m = Meta("Top_" + cid)
    hips, sp, sp1, sp2, nk = H("Hips"), H("Spine"), H("Spine1"), H("Spine2"), H("Neck")
    k = 1.0 + inflate * 6
    m.ball(hips + Vector((0, 0.005, -0.02)), 0.155 * k, 1.1 * (1.15 if fem else 1), 0.8, 0.7, stiff=1.0)
    m.ball(sp + Vector((0, 0.0, 0.05)), 0.155 * k, 1.02 * (0.9 if fem else 1), 0.74, 1.15, stiff=0.8)
    m.ball(sp1 + Vector((0, -0.005, 0.08)), 0.185 * k, 1.25 * s, 0.74, 1.05, stiff=0.8)
    m.ball(sp2 + Vector((0, 0.005, 0.11)), 0.195 * k, 1.5 * s, 0.68, 0.78, stiff=0.8)
    for x in (-1, 1):
        arm = H("LeftArm" if x > 0 else "RightArm")
        m.capsule(nk + Vector((x * 0.02, 0.005, -0.04)), arm + Vector((-x * 0.03, 0.0, 0.02)), 0.08 * s * k, stiff=1.0)
        m.ball(arm, 0.075 * s * k, 1.0, 0.95, 1.0, stiff=0.8)
    if collar_h > 0:
        m.capsule(nk + Vector((0, 0.01, -0.02)), nk + Vector((0, 0.01, collar_h)), 0.15, stiff=0.9)
    if sleeves:
        for side in ("Left", "Right"):
            ar, fa, ha = H(side + "Arm"), H(side + "ForeArm"), H(side + "Hand")
            m.capsule(ar, lerp(ar, fa, 0.98), 0.13 * s * k, stiff=0.8)
            if long_sleeve:
                m.capsule(fa, lerp(fa, ha, 0.92), 0.115 * s * k, stiff=0.8)
                m.ball(lerp(fa, ha, 0.9), 0.06 * k, 0.6, 1.0, 1.0, stiff=0.8)   # punho
    ob = m.to_mesh(6000)
    return finish(ob, mat("M_%s_top" % cid, color))


def cloth_pants(cid, c, color, boots=None):
    m = Meta("Pants_" + cid)
    hips = H("Hips")
    k = 1.12
    m.ball(hips + Vector((0, 0.005, -0.06)), 0.155 * k, 1.12 * (1.15 if c.get("fem") else 1), 0.8, 0.75, stiff=1.0)
    for side in ("Left", "Right"):
        up, kn, an = H(side + "UpLeg"), H(side + "Leg"), H(side + "Foot")
        m.capsule(up + Vector((0, 0, -0.02)), lerp(up, kn, 0.98), 0.15 * (1.05 if c.get("fem") else 1), stiff=0.9)
        m.capsule(kn, lerp(kn, an, 0.92), 0.118, stiff=0.9)
    ob = m.to_mesh(4000)
    return finish(ob, mat("M_%s_pants" % cid, color))


def shoes(cid, c, color, boots=False):
    m = Meta("Shoe_" + cid)
    for side in ("Left", "Right"):
        kn, an = H(side + "Leg"), H(side + "Foot")
        toe = T(side + "ToeBase")
        m.capsule(an + Vector((0, 0.025, -0.07)), Vector((toe.x, toe.y + 0.01, 0.04)), 0.085, stiff=1.0)
        if boots:
            m.capsule(lerp(kn, an, 0.55), an + Vector((0, 0.01, -0.04)), 0.095, stiff=1.0)
    ob = m.to_mesh(2400)
    return finish(ob, mat("M_%s_shoes" % cid, color))


def hair(cid, c, color, style, skin_ob):
    b = H("Head")
    z0 = b.z
    w = c.get("face_w", 0.9 if c.get("fem") else 1.0)

    def line(co):
        # linha do cabelo: alta na testa, desce para trás e atrás das orelhas
        t = max(0.0, min(1.0, (co.y - (b.y - 0.09)) / 0.18))
        return z0 + 0.175 - t * 0.12

    def pick(co, n):
        return co.z > line(co) and not (abs(co.x) > 0.07 * w and co.z < z0 + 0.15 and co.y < b.y + 0.03)
    thick = 0.004 if style == "raspado" else 0.016
    ob = shell(cid, "Hair", skin_ob, pick, thick, color)
    if style in ("topete", "curto", "longo"):
        m = Meta("Locks_" + cid, res=0.005)
        if style == "topete":
            for x, y, z, r in [(0.0, -0.075, 0.215, 0.05), (-0.03, -0.06, 0.225, 0.045), (0.035, -0.055, 0.222, 0.045),
                               (0.0, -0.035, 0.24, 0.05), (-0.045, -0.015, 0.228, 0.04), (0.045, -0.015, 0.228, 0.04)]:
                m.capsule((x, b.y + y, z0 + z), (x * 1.15, b.y + y + 0.08, z0 + z + 0.008), r, stiff=1.0)
        elif style == "curto":
            for x in (-0.04, 0.0, 0.04):
                m.capsule((x, b.y - 0.075, z0 + 0.205), (x * 1.1, b.y + 0.03, z0 + 0.235), 0.04, stiff=1.0)
        elif style == "longo":
            for x in (-0.078, 0.078):
                m.capsule((x * w, b.y - 0.01, z0 + 0.18), (x * w * 1.3, b.y + 0.03, z0 - 0.06), 0.055, stiff=1.0)
            m.capsule((0, b.y + 0.075, z0 + 0.18), (0, b.y + 0.08, z0 - 0.08), 0.12, stiff=1.0)
            m.capsule((-0.055, b.y - 0.08, z0 + 0.205), (0.06, b.y - 0.07, z0 + 0.19), 0.04, stiff=1.0)
        lo = m.to_mesh(2000)
        finish(lo, mat("M_%s_hair" % cid, color), rigid="Head")
    return ob


def beard(cid, c, color, kind, skin_ob):
    b = H("Head")
    z0 = b.z

    def mouth_hole(co):
        return abs(co.x) < 0.03 and abs(co.z - (z0 + 0.058)) < 0.014 and co.y < b.y - 0.06
    if kind == "barba":
        def pick(co, n):
            return co.z < z0 + 0.092 and co.y < b.y + 0.035 and abs(co.x) < 0.092 and not mouth_hole(co)
        return shell(cid, "Beard", skin_ob, pick, 0.006, color)
    sy = surface_y(skin_ob, 0.0, z0 + 0.075, b.y)
    m = Meta("Stache_" + cid, res=0.004)
    if kind == "bigode":
        m.capsule((-0.032, sy - 0.004, z0 + 0.072), (0.0, sy - 0.008, z0 + 0.078), 0.03, stiff=1.0)
        m.capsule((0.0, sy - 0.008, z0 + 0.078), (0.032, sy - 0.004, z0 + 0.072), 0.03, stiff=1.0)
    elif kind == "cavanhaque":
        sc = surface_y(skin_ob, 0.0, z0 + 0.035, b.y)
        m.ball((0, sc - 0.004, z0 + 0.035), 0.034, 1.0, 0.7, 1.2, stiff=1.0)
        m.capsule((-0.025, sy - 0.003, z0 + 0.074), (0.025, sy - 0.003, z0 + 0.074), 0.018, stiff=1.0)
    ob = m.to_mesh(800)
    return finish(ob, mat("M_%s_beard" % cid, color), rigid="Head")


def coat_skirt(cid, color, length=0.55):
    """saia do sobretudo: tronco de cone suave, aberto na frente, barra levemente irregular."""
    hips = H("Hips")
    top_z = hips.z + 0.04
    rings = []
    n = 18
    for r_i, (z, rx, ry) in enumerate([(top_z, 0.19, 0.135), (top_z - length * 0.5, 0.235, 0.17), (top_z - length, 0.28, 0.2)]):
        ring = []
        for i in range(n + 1):
            a = -math.pi / 2 + 0.32 + (math.tau - 0.64) * i / n
            ring.append(Vector((math.cos(a) * rx, math.sin(a) * ry, z - (0.02 * math.sin(i * 1.7) if r_i == 2 else 0))))
        rings.append(ring)
    verts = [v for r in rings for v in r]
    faces = []
    for r in range(len(rings) - 1):
        for i in range(n):
            a, b = r * (n + 1) + i, r * (n + 1) + i + 1
            faces.append((a, b, b + n + 1, a + n + 1))
    ob = mesh_from("Skirt_" + cid, verts, faces)
    sol = ob.modifiers.new("sol", "SOLIDIFY")
    sol.thickness = 0.012
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier="sol")
    smooth_mod(ob, 1)
    return finish(ob, mat("M_%s_coat" % cid, color))


def fedora(cid, color, band):
    b = H("Head")
    z0 = b.z
    fedora_crown(cid, color)
    # aba reta: disco fino
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=28, radius1=0.17, radius2=0.165, depth=0.012)
    me = bpy.data.meshes.new("Brim_" + cid)
    bm.to_mesh(me)
    bm.free()
    br = bpy.data.objects.new("Brim_" + cid, me)
    bpy.context.scene.collection.objects.link(br)
    br.location = (0, b.y + 0.005, z0 + 0.198)
    br.scale = (1.0, 1.08, 1.0)
    bpy.ops.object.select_all(action="DESELECT")
    br.select_set(True)
    bpy.context.view_layer.objects.active = br
    bpy.ops.object.transform_apply(location=True, scale=True)
    bpy.ops.object.shade_smooth()
    finish(br, mat("M_%s_hat" % cid, color), rigid="Head")
    # fita
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, segments=24, radius1=0.123, radius2=0.12, depth=0.028)
    me = bpy.data.meshes.new("Band_" + cid)
    bm.to_mesh(me)
    bm.free()
    bd = bpy.data.objects.new("Band_" + cid, me)
    bpy.context.scene.collection.objects.link(bd)
    bd.location = (0, b.y + 0.01, z0 + 0.218)
    bd.scale = (1.0, 1.06, 1.0)
    bpy.ops.object.select_all(action="DESELECT")
    bd.select_set(True)
    bpy.context.view_layer.objects.active = bd
    bpy.ops.object.transform_apply(location=True, scale=True)
    finish(bd, mat("M_%s_band" % cid, band), rigid="Head")


def plate(cid, name, pts, color, bone=None, thick=0.008, target=None):
    """placa (lapela, colete, avental) a partir de um contorno: subdividida e encostada na roupa."""
    ob = mesh_from(name + "_" + cid, pts, [list(range(len(pts)))])
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=5, use_grid_fill=True)
    if target is not None:
        new = project_pts([v.co.copy() for v in bm.verts], target, 0.003)
        for v, q in zip(bm.verts, new):
            v.co = q
    bm.to_mesh(ob.data)
    bm.free()
    sol = ob.modifiers.new("sol", "SOLIDIFY")
    sol.thickness = thick
    sol.offset = 1.0
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier="sol")
    bpy.ops.object.shade_smooth()
    return finish(ob, mat("M_%s_%s" % (cid, name.lower()), color), rigid=bone, auto=bone is None)


def surface_y(head_ob, x, z, start_y):
    """onde a frente do rosto está (raio de frente para trás)."""
    bvh = BVHTree.FromObject(head_ob, bpy.context.evaluated_depsgraph_get())
    hit = bvh.ray_cast(Vector((x, start_y - 0.3, z)), Vector((0, 1, 0)), 0.6)
    return hit[0].y if hit[0] is not None else start_y


def face_decals(cid, skin_ob, fem=False):
    b = H("Head")
    z0 = b.z
    out = []
    for nm, (cz, hw, hh) in (("M_face_eyes", (z0 + 0.13, 0.088, 0.044)), ("M_face_mouth", (z0 + 0.058, 0.05, 0.025))):
        # grade 6x2 projetada na superfície do rosto
        nx, ny = 6, 2
        verts, uvs, faces = [], [], []
        for j in range(ny + 1):
            for i in range(nx + 1):
                u, v = i / nx, j / ny
                x = -hw + 2 * hw * u
                z = cz - hh + 2 * hh * v
                y = surface_y(skin_ob, x, z, b.y) - 0.0035
                verts.append((x, y, z))
                uvs.append((u * 0.25, 0.5 + v * 0.5))
        for j in range(ny):
            for i in range(nx):
                a = j * (nx + 1) + i
                faces.append((a, a + 1, a + nx + 2, a + nx + 1))
        ob = mesh_from(nm.replace("M_", "") + "_" + cid, verts, faces)
        uvl = ob.data.uv_layers.new(name="UVMap")
        for poly in ob.data.polygons:
            for li in poly.loop_indices:
                uvl.data[li].uv = uvs[ob.data.loops[li].vertex_index]
        key = nm + ("_f" if fem else "")
        m = bpy.data.materials.get(key)
        if m is None:
            m = bpy.data.materials.new(key)
            m.use_nodes = True
            nt = m.node_tree
            bs = nt.nodes.get("Principled BSDF")
            img = nt.nodes.new("ShaderNodeTexImage")
            which = "eyes" if "eyes" in nm else "mouth"
            img.image = bpy.data.images.load(os.path.join(ROOT, "game", "assets", "characters", "%s_atlas_noir%s.png" % (which, "_f" if fem else "")))
            nt.links.new(img.outputs["Color"], bs.inputs["Base Color"])
            nt.links.new(img.outputs["Alpha"], bs.inputs["Alpha"])
            m.blend_method = "CLIP"
        ob.data.materials.append(m)
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        rig.select_set(True)
        bpy.context.view_layer.objects.active = rig
        bpy.ops.object.parent_set(type="ARMATURE_NAME")
        ob.vertex_groups.get(P + "Head") or ob.vertex_groups.new(name=P + "Head")
        ob.vertex_groups[P + "Head"].add(list(range(len(verts))), 1.0, "REPLACE")
        out.append(ob)
    return out




def project_pts(pts, target, lift=0.004):
    """encosta pontos na superfície da roupa (raio de frente para trás)."""
    bvh = BVHTree.FromObject(target, bpy.context.evaluated_depsgraph_get())
    out = []
    for q in pts:
        hit = bvh.ray_cast(Vector((q.x, -0.6, q.z)), Vector((0, 1, 0)), 1.2)
        out.append(Vector((q.x, hit[0].y - lift, q.z)) if hit[0] is not None else q)
    return out


def cut_skin(skin_ob, covered):
    """apaga a pele escondida pela roupa (sem vazamento e com menos polígonos)."""
    bm = bmesh.new()
    bm.from_mesh(skin_ob.data)
    kill = [f for f in bm.faces if all(covered(v.co) for v in f.verts)]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.to_mesh(skin_ob.data)
    bm.free()


def fedora_crown(cid, color):
    b = H("Head")
    z0 = b.z
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=20, radius1=0.112, radius2=0.094, depth=0.115)
    # vinco no topo (fedora): afunda o centro e pinça a frente
    for v in bm.verts:
        if v.co.z > 0.05:
            r = math.hypot(v.co.x, v.co.y)
            if r < 0.06:
                v.co.z -= 0.02
            if v.co.y < -0.07:
                v.co.x *= 0.85
    me = bpy.data.meshes.new("Crown_" + cid)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("Crown_" + cid, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = (0, b.y + 0.012, z0 + 0.255)
    ob.scale = (1.0, 1.1, 1.0)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=True, scale=True)
    m = ob.modifiers.new("bv", "BEVEL")
    m.width = 0.006
    m.segments = 2
    bpy.ops.object.modifier_apply(modifier="bv")
    bpy.ops.object.shade_smooth()
    return finish(ob, mat("M_%s_hat" % cid, color), rigid="Head")


def decimate_to(ob, faces):
    if len(ob.data.polygons) <= faces:
        return
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    m = ob.modifiers.new("dec", "DECIMATE")
    m.ratio = faces / len(ob.data.polygons)
    bpy.ops.object.modifier_apply(modifier="dec")

# ───────────────────────────── elenco
CAST = {
    "detetive": dict(skin="#c69373", hair_col="#2b2522", hair="curto", beard="barba", top="#4d3f31", pants="#1d1c24", shoes="#1a1310",
                     jaw=1.08, chin=1.1, nose=1.1),
    "couro": dict(fem=True, skin="#e0ae8a", hair_col="#5a1c22", hair="longo", top="#1a161d", pants="#211e2a", shoes="#120e10",
                  face_w=0.95, jaw=0.92, chin=0.92, nose=0.85),
    "bartender": dict(skin="#8c5c3c", hair_col="#16121a", hair="raspado", beard="bigode", top="#d8d2c4", pants="#18161e", shoes="#130f0d",
                      jaw=1.12, chin=1.0, nose=1.15, bulk=1.08),
    "hacker": dict(skin="#cf9c7a", hair_col="#15121a", hair="topete", beard="cavanhaque", top="#232a3c", pants="#17191f", shoes="#e3ded3",
                   jaw=1.0, chin=1.0, nose=1.0),
}

made = {}
for cid, c in CAST.items():
    parts = []
    sk = skin_body(cid, c)
    parts.append(sk)
    fem = c.get("fem", False)
    if cid == "detetive":
        parts.append(cloth_top(cid, c, "#e8e2d6", True, True, 0.012))                  # camisa por baixo
        top = cloth_top(cid + "_coat", c, c["top"], True, True, 0.03, collar_h=0.07)
        parts.append(top)
        parts.append(coat_skirt(cid, c["top"], 0.6))
        sp2, sp1 = H("Spine2"), H("Spine1")
        for sx in (-1, 1):
            parts.append(plate(cid, "Lapel%s" % ("L" if sx > 0 else "R"), [sp2 + Vector((sx * 0.025, -0.138, 0.15)), sp2 + Vector((sx * 0.15, -0.13, 0.13)),
                                                                          sp1 + Vector((sx * 0.06, -0.145, -0.03))][::sx], "#3d3227", "Spine2", target=top))
        parts.append(plate(cid, "Tie", [sp2 + Vector((-0.017, -0.142, 0.13)), sp2 + Vector((0.017, -0.142, 0.13)), sp1 + Vector((0.0, -0.146, -0.05))],
                           "#6a1a26", "Spine2", target=top))
        fedora(cid, "#1d1b23", "#5a1f2a")
    elif cid == "couro":
        top = cloth_top(cid, c, c["top"], True, True, 0.022, collar_h=0.05)
        parts.append(top)
        parts.append(plate(cid, "Belt", [H("Hips") + Vector((x, -0.135, 0.0)) for x in (-0.15, 0.15)] +
                           [H("Hips") + Vector((x, -0.135, 0.03)) for x in (0.15, -0.15)], "#b02a4a", "Hips", target=top))
    elif cid == "bartender":
        top = cloth_top(cid, c, c["top"], True, False, 0.014, collar_h=0.03)
        parts.append(top)
        sp2, sp1, hips = H("Spine2"), H("Spine1"), H("Hips")
        vm = Meta("Vest_" + cid)
        sp = H("Spine")
        k = 1.3
        vm.ball(sp + Vector((0, 0.0, 0.05)), 0.155 * k, 1.02, 0.74, 1.15, stiff=0.8)
        vm.ball(sp1 + Vector((0, -0.005, 0.08)), 0.185 * k, 1.25, 0.74, 1.05, stiff=0.8)
        vm.ball(sp2 + Vector((0, 0.005, 0.09)), 0.19 * k, 1.4, 0.68, 0.7, stiff=0.8)
        vm.ball(sp2 + Vector((0, -0.16, 0.14)), 0.12, 0.7, 1.0, 1.6, neg=True, stiff=1.2)   # decote em V
        for x in (-1, 1):
            vm.ball(sp2 + Vector((x * 0.21, 0.0, 0.11)), 0.1, 1.0, 1.2, 1.2, neg=True, stiff=1.2)   # cavas
        vo = vm.to_mesh(3000)
        parts.append(finish(vo, mat("M_bartender_vest", "#2a1c22")))
        apron_pts = [hips + Vector((-0.17, -0.13, 0.0)), hips + Vector((0.17, -0.13, 0.0)),
                     hips + Vector((0.19, -0.15, -0.55)), hips + Vector((-0.19, -0.15, -0.55))]
    elif cid == "hacker":
        parts.append(cloth_top(cid, c, c["top"], True, True, 0.026, collar_h=0.0))
        hm = Meta("Hood_" + cid, res=0.006)
        nk = H("Neck")
        hm.capsule(nk + Vector((-0.1, 0.06, 0.03)), nk + Vector((0.1, 0.06, 0.03)), 0.09, stiff=1.0)
        ob = hm.to_mesh(1200)
        parts.append(finish(ob, mat("M_hacker_hood", "#2a3146"), rigid="Spine2"))
    pants = cloth_pants(cid, c, c["pants"])
    parts.append(pants)
    if cid == "bartender":
        bpy.context.view_layer.update()
        pts = project_pts(apron_pts, pants, 0.01)
        parts.append(plate(cid, "Apron", [Vector((q.x, q.y - 0.01, q.z)) for q in apron_pts], "#e6e0d4", None))
    # pele escondida pela roupa sai
    hips_z, neck_z = H("Hips").z, H("Neck").z
    wrist = abs(H("LeftHand").x) - 0.01
    elbow = abs(H("LeftForeArm").x) + (0.0 if cid != "bartender" else -0.06)
    reach = elbow if cid == "bartender" else wrist

    def covered(co, hz=hips_z, nz=neck_z, reach=reach):
        if co.z < hz - 0.06:
            return True
        if hz - 0.12 < co.z < nz - 0.04 and abs(co.x) < 0.2:
            return True
        if abs(co.x) >= 0.17 and abs(co.x) < reach and co.z > nz - 0.16:
            return True
        return False
    cut_skin(sk, covered)
    parts.append(shoes(cid, c, c["shoes"], boots=fem))
    parts.append(hair(cid, c, c["hair_col"], c["hair"], sk))
    if c.get("beard"):
        parts.append(beard(cid, c, c["hair_col"], c["beard"], sk))
    decals = face_decals(cid, sk, fem)
    # junta tudo do personagem numa malha só (pesos se mantêm por nome de osso)
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH" and not o.name.startswith("Cast_")
            and (o.name.split(".")[0].endswith("_" + cid) or o.name.split(".")[0].endswith("_" + cid + "_coat"))
            and o not in decals]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = sk
    bpy.ops.object.join()
    decimate_to(sk, 9000)
    bpy.ops.object.select_all(action="DESELECT")
    for o in decals:
        o.select_set(True)
    sk.select_set(True)
    bpy.context.view_layer.objects.active = sk
    bpy.ops.object.join()
    sk.name = "Cast_" + cid
    sk.data.name = "Cast_" + cid
    made[cid] = sk
    print("personagem", sk.name, len(sk.data.polygons), "faces")

if args and args[0] == "preview":
    for cid, ob in made.items():
        for o in made.values():
            o.hide_render = o is not ob
        nb.look_studio(os.path.join(args[1], "cast_%s.png" % cid), [ob])
    for o in made.values():
        o.hide_render = False

bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
for o in made.values():
    o.select_set(True)
bpy.context.view_layer.objects.active = rig
rig.data.pose_position = "POSE"
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_animations=True,
                          export_skins=True, export_yup=True, export_apply=False, export_animation_mode="NLA_TRACKS")
print("OK", OUT)
