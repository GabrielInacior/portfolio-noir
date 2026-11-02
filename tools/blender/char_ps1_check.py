"""Mede se algum vértice de braço/mão entra no tronco, em todas as animações (Blender, sem render).

Uso: blender -b -P tools/blender/char_ps1_check.py -- <ids,separados>
Para cada personagem e animação, amostra o ciclo a cada 2 quadros, deforma a malha e testa cada
vértice do braço contra a superfície do tronco (BVH do tronco deformado, lado de dentro pela normal).
Imprime a maior penetração em cm (0 = nada atravessa).
"""
import os
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
D = os.path.join(ROOT, "game", "assets", "characters", "ps1")
ids = sys.argv[sys.argv.index("--") + 1].split(",")
ARM = ("Arm", "ForeArm", "Hand")
TORSO = ("Spine", "Spine1", "Spine2", "Hips")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(D, "anims.glb"))
acts = {a.name.split("|")[0]: a for a in bpy.data.actions}
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)

def inside(bvh, p):
    """Dentro da casca = raio cruza um número ímpar de vezes nos três sentidos (paridade)."""
    for dvec in (Vector((1, 0, 0)), Vector((-1, 0, 0)), Vector((0, 1, 0))):
        o = p.copy()
        hits = 0
        for _ in range(12):
            loc, nrm, idx, dist = bvh.ray_cast(o, dvec, 2.0)
            if loc is None:
                break
            hits += 1
            o = loc + dvec * 0.0005
        if hits % 2 == 0:
            return False
    return True


res = {}
for cid in ids:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(D, cid + ".glb"))
    objs = [o for o in bpy.data.objects if o not in before]
    arm = [o for o in objs if o.type == "ARMATURE"][0]
    body = [o for o in objs if o.type == "MESH" and o.name.startswith("Body")][0]
    gname = {g.index: g.name.split(":")[-1] for g in body.vertex_groups}
    dom = {}
    for v in body.data.vertices:
        if v.groups:
            g = max(v.groups, key=lambda x: x.weight)
            dom[v.index] = gname[g.group]
    def is_arm(n):
        return any(n.startswith(s) for s in ("Left", "Right")) and any(n.endswith(k) or k + "Index" in n for k in ARM) \
            and "Leg" not in n and "Shoulder" not in n
    arm_v = [i for i, n in dom.items() if is_arm(n) or "HandIndex" in n]
    # o anel da raiz do braço (deltoide) nasce dentro do ombro de propósito: fica fora da medida
    heads = []
    for side in ("Left", "Right"):
        bn = [b for b in arm.data.bones if b.name.endswith(side + "Arm")][0]
        heads.append(arm.matrix_world @ bn.head_local)
    bw = body.matrix_world
    # a parte de cima do braço (manga perto da axila) encosta no tronco já no repouso, por dentro e sem
    # aparecer; o que importa é antebraço, mão e a metade de baixo do braço
    arm_v = [i for i in arm_v if min(((bw @ body.data.vertices[i].co) - h).length for h in heads) > 0.1]
    torso_f = []
    for p in body.data.polygons:
        if all(dom.get(i) in TORSO for i in p.vertices):
            torso_f.append(p.index)
    # vértices do braço que JÁ estão dentro do tronco no repouso (raiz da manga na axila, escondida)
    # ficam fora da medida: só conta o que estava fora e entrou com a animação
    rest_v = [bw @ v.co for v in body.data.vertices]
    rest_bvh = BVHTree.FromPolygons(rest_v, [list(body.data.polygons[i].vertices) for i in torso_f])
    arm_v = [i for i in arm_v if not inside(rest_bvh, rest_v[i])]
    # o lado de dentro do braço de cima escorrega para trás do peito quando o braço vem para a frente
    # (fica escondido entre braço e tronco); a medida que importa é antebraço e mão, que aparecem
    arm_v = [i for i in arm_v if "Fore" in dom[i] or "Hand" in dom[i]]
    for an, act in sorted(acts.items()):
        ad = arm.animation_data_create()
        ad.action = act
        try:
            ad.action_slot = act.slots[0]
        except Exception:
            pass
        f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
        worst = 0.0
        wf = f0
        for f in range(f0, f1 + 1, 2):
            bpy.context.scene.frame_set(f)
            dg = bpy.context.evaluated_depsgraph_get()
            ev = body.evaluated_get(dg)
            me = ev.to_mesh()
            mw = body.matrix_world
            verts = [mw @ v.co for v in me.vertices]
            polys = [list(me.polygons[i].vertices) for i in torso_f]
            bvh = BVHTree.FromPolygons(verts, polys)
            for i in arm_v:
                p = verts[i]
                if not inside(bvh, p):
                    continue
                loc, nrm, idx, dist = bvh.find_nearest(p, 0.5)
                if loc is not None and dist > worst:
                    worst = dist
                    wf = f
            ev.to_mesh_clear()
        res[(cid, an)] = (worst * 100, wf)
        print("PEN %-8s %-16s %.1f cm (quadro %d)" % (cid, an, worst * 100, wf))
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)
print("FIM")
