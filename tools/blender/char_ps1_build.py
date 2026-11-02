"""Personagens NOIR low-poly estilo PS1, construídos por código sobre o esqueleto Mixamo.

Por que assim: o esqueleto (e as 15 animações) vêm de tools/mixamo_raw/*.fbx, todos baixados no MESMO
rig; a malha nova é gerada em volta dos ossos desse rig, na pose de repouso dele. Resultado: as animações
servem a todos os personagens sem nenhuma conversão (a causa dos braços torcendo no elenco antigo), e os
braços nascem SEPARADOS do tronco (nenhum vértice de braço encosta no corpo/casaco), com pesos limpos:
cada anel de vértices pertence a 1 ou 2 ossos, braço sem peso no tronco e vice-versa.
Cor por vértice (sem textura, como no PS1) + um decalque de rosto com atlas de expressões
(tools/blender/char_ps1_faces.py). 1.200 a 2.500 triângulos por personagem.

Uso:
  blender -b -P tools/blender/char_ps1_build.py -- <id|all> [saida_dir]
Saída: game/assets/characters/ps1/<id>.glb  (+ anims.glb com todas as animações no mesmo esqueleto)
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RAW = os.path.join(ROOT, "tools", "mixamo_raw")
OUT = os.path.join(ROOT, "game", "assets", "characters", "ps1")
os.makedirs(OUT, exist_ok=True)
P = "mixamorig:"

# ------------------------------------------------------------------ especificação dos personagens
# medidas em metros (raio x = largura, raio y = profundidade); cores RGB 0..1
def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


CHARS = {
    "vance": dict(skin="#d6a07a", hair="#2a1c16", top="#a07850", top2="#8a6440", shirt="#e0dcd0", tie="#8a1f2c",
                  vest="#1c1a24", pants="#1c1a24", shoes="#3e2418", shoulders=0.175, chest=0.155, waist=0.135,
                  hips=0.15, coat=True, hat=True, face="vance", lapel=True),
    "lena": dict(skin="#e6b696", hair="#6a1e1a", top="#16121c", top2="#22202a", shirt="#7a1a26", tie=None,
                 vest=None, pants="#16121c", shoes="#0b0a10", shoulders=0.15, chest=0.135, waist=0.105,
                 hips=0.145, long_hair=True, face="lena", jacket=True, scale=0.95, female=True),
    "otto": dict(skin="#784a32", hair="#9a9a9a", top="#e0dcd4", top2="#c8c4bc", shirt="#e0dcd4", tie="#101014",
                 vest="#141218", pants="#1c1a22", shoes="#0b0a10", shoulders=0.185, chest=0.17, waist=0.16,
                 hips=0.16, apron="#5a3c28", face="otto", short_sleeve=True),
    "kai": dict(skin="#dcb088", hair="#18161a", top="#1a2440", top2="#22305a", shirt="#2a2a32", tie=None,
                vest=None, pants="#141418", shoes="#e8ecf0", shoulders=0.165, chest=0.145, waist=0.13,
                hips=0.14, hood=True, face="kai", drawstrings="#5bd0ff", scale=0.98),
    "extra1": dict(skin="#be8c68", hair="#3c2c1e", top="#3a3850", top2="#2e2c40", shirt="#9aa0ac", tie=None,
                   vest=None, pants="#2a2632", shoes="#16121c", shoulders=0.17, chest=0.15, waist=0.14,
                   hips=0.15, face="extra1", cap=True),
    "extra2": dict(skin="#ecc4a6", hair="#c8a070", top="#5a1a1e", top2="#4a1418", shirt="#e8ecf8", tie=None,
                   vest=None, pants="#1c1a28", shoes="#16121c", shoulders=0.145, chest=0.13, waist=0.105,
                   hips=0.145, long_hair=True, face="extra2", coat=True, scale=0.95, female=True),
}


# ------------------------------------------------------------------ cena e esqueleto
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_fbx(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=False)
    return [o for o in bpy.data.objects if o not in before]


def base_armature():
    objs = import_fbx(os.path.join(RAW, "vance_idle_serio.fbx"))
    arm = [o for o in objs if o.type == "ARMATURE"][0]
    for o in objs:
        if o.type == "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    arm.name = "Armature"
    # dedos extras não existem na malha nova: ficam no esqueleto (as animações os usam) sem peso
    return arm


def bone_pts(arm):
    mw = arm.matrix_world
    pts = {}
    for b in arm.data.bones:
        pts[b.name.replace(P, "")] = (mw @ b.head_local, mw @ b.tail_local)
    return pts


# ------------------------------------------------------------------ construção da malha
class Builder:
    def __init__(self, name):
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.color.new("Col")
        self.groups = []                    # nome de osso por índice de grupo
        self.dl = self.bm.verts.layers.deform.verify()
        self.name = name

    def gi(self, bone):
        if bone not in self.groups:
            self.groups.append(bone)
        return self.groups.index(bone)

    def vert(self, co, weights):
        v = self.bm.verts.new(co)
        tot = sum(w for _, w in weights)
        for b, w in weights:
            v[self.dl][self.gi(P + b)] = w / tot
        return v

    def ring(self, c, axis, fwd, rx, ry, n, weights, front_off=0.0, front_half=None):
        axis = axis.normalized()
        f = (fwd - axis * fwd.dot(axis)).normalized()
        r = axis.cross(f).normalized()
        vs = []
        for i in range(n):
            if front_half is None:
                a = math.pi / 2 - math.pi / n + 2 * math.pi * i / n
            else:
                # face da frente estreita (faixa da camisa/gravata) e as outras repartem o resto
                rest = (2 * math.pi - 2 * front_half) / (n - 1)
                a = math.pi / 2 - front_half + (0 if i == 0 else 2 * front_half + rest * (i - 1))
            co = c + r * (rx * math.cos(a)) + f * (ry * math.sin(a)) + f * (front_off * max(0.0, math.sin(a)))
            vs.append(self.vert(co, weights))
        return vs

    def face(self, vs, color):
        try:
            fa = self.bm.faces.new(vs)
        except ValueError:
            return None
        for lp in fa.loops:
            lp[self.col] = color + (1.0,) if len(color) == 3 else color
        return fa

    def loft(self, rings, colorf, cap_start=True, cap_end=True, skip=None):
        n = len(rings[0])
        for k in range(len(rings) - 1):
            a, b = rings[k], rings[k + 1]
            for i in range(n):
                if skip and skip(k, i):
                    continue
                self.face([a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]], colorf(k, i))
        if cap_start:
            self.face(list(reversed(rings[0])), colorf(-1, 0))
        if cap_end:
            self.face(rings[-1], colorf(len(rings) - 1, 0))

    def box(self, center, x, y, z, size, color, weights):
        sx, sy, sz = size
        cs = []
        for dz in (-1, 1):
            for dy in (-1, 1):
                for dx in (-1, 1):
                    cs.append(self.vert(center + x * (dx * sx) + y * (dy * sy) + z * (dz * sz), weights))
        fs = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
        for f in fs:
            self.face([cs[i] for i in f], color)

    def to_object(self, arm):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        for g in self.groups:
            ob.vertex_groups.new(name=g)
        ob.parent = arm
        ob.matrix_parent_inverse = arm.matrix_world.inverted()
        md = ob.modifiers.new("Armature", "ARMATURE")
        md.object = arm
        return ob


FWD = Vector((0, -1, 0))   # o rig olha para -Y
UP = Vector((0, 0, 1))


def lerp(a, b, t):
    return a + (b - a) * t


def jitter(c, i, amt=0.035):
    """Variação mínima de tom por face (o "grão" do PS1 sem textura)."""
    k = 1.0 + (((i * 2654435761) % 1000) / 1000.0 - 0.5) * amt
    return tuple(min(1.0, max(0.0, v * k)) for v in c)


def build_body(spec, arm, pts):
    B = Builder("Body")
    sk, hair, top, top2 = rgb(spec["skin"]), rgb(spec["hair"]), rgb(spec["top"]), rgb(spec["top2"])
    shirt, pants, shoes = rgb(spec["shirt"]), rgb(spec["pants"]), rgb(spec["shoes"])
    tie = rgb(spec["tie"]) if spec.get("tie") else None
    vest = rgb(spec["vest"]) if spec.get("vest") else None
    n = 10

    # ---------------- tronco: anéis presos à coluna (do quadril ao pescoço)
    hipc = pts["Hips"][0]
    sp, sp1, sp2, nk = pts["Spine"][0], pts["Spine1"][0], pts["Spine2"][0], pts["Neck"][0]
    yc = lambda p: Vector((0, p.y + 0.01, p.z))
    W, C, Wa, H = spec["shoulders"], spec["chest"], spec["waist"], spec["hips"]
    tor = [
        (Vector((0, hipc.y + 0.01, hipc.z - 0.07)), H, 0.105, [("Hips", 1)]),
        (yc(hipc) + Vector((0, 0, 0.03)), H * 0.98, 0.10, [("Hips", 0.7), ("Spine", 0.3)]),
        (yc(sp) + Vector((0, 0, 0.06)), Wa, 0.095, [("Spine", 1)]),
        (yc(sp1), C * 0.96, 0.105, [("Spine1", 0.7), ("Spine", 0.3)]),
        (yc(sp1) + Vector((0, 0, 0.09)), C, 0.11, [("Spine1", 0.4), ("Spine2", 0.6)]),
        (yc(sp2) + Vector((0, 0, 0.1)), W, 0.10, [("Spine2", 1)]),
        (yc(nk) + Vector((0, 0, 0.005)), W * 0.55, 0.07, [("Spine2", 0.6), ("Neck", 0.4)]),
    ]
    rings = [B.ring(c, UP, FWD, rx, ry, n, w, front_off=0.012 if 2 <= k <= 5 and spec.get("female") else 0.0,
                    front_half=math.radians(9))
             for k, (c, rx, ry, w) in enumerate(tor)]

    def torso_col(k, i):
        front = i in (0, 1, n - 1)
        if k < 1:
            return jitter(top if spec.get("coat") else pants, i)
        if spec.get("short_sleeve") and vest:
            # colete do bartender por cima da camisa: frente aberta mostra camisa e gravata-borboleta
            if i == 0 and k >= 1:
                return tie if k >= 5 and tie else shirt
            return jitter(vest, i)
        if tie and front and i == 0 and k >= 2 and not spec.get("short_sleeve"):
            return shirt
        if spec.get("lapel") and front and k >= 2:
            return jitter(vest if vest else shirt, i) if i == 0 else jitter(top2, i)
        if spec.get("jacket") and i == 0 and 1 <= k <= 4:
            return shirt
        if spec.get("hood") and i == 0 and 2 <= k <= 5:
            return jitter(top2, i)
        return jitter(top if (k + i) % 3 else top2, i) if not spec.get("lapel") else jitter(top, i)

    B.loft(rings, torso_col, cap_start=True, cap_end=False)
    if tie and not spec.get("short_sleeve"):
        # gravata fina por cima da camisa (caixa colada na frente do peito)
        front_y = lambda r: r[0].y - r[2] - 0.004
        top_c, bot_c = tor[5], tor[2]
        tz0, tz1 = bot_c[0].z + 0.02, top_c[0].z - 0.02
        tc = Vector((0, (front_y(top_c) + front_y(bot_c)) / 2 - 0.006, (tz0 + tz1) / 2))
        B.box(tc, Vector((1, 0, 0)), Vector((0, 1, 0)), UP, (0.018, 0.006, (tz1 - tz0) / 2), tie,
              [("Spine1", 0.5), ("Spine2", 0.5)])
    elif tie:
        # gravata-borboleta do bartender
        tc = Vector((0, tor[6][0].y - tor[6][2] - 0.012, tor[6][0].z - 0.035))
        B.box(tc, Vector((1, 0, 0)), Vector((0, 1, 0)), UP, (0.035, 0.008, 0.014), tie, [("Spine2", 1)])

    # pescoço e cabeça
    hd = pts["Head"][0]
    neck = [
        B.ring(Vector((0, nk.y + 0.005, nk.z)), UP, FWD, 0.048, 0.05, 8, [("Neck", 1)]),
        B.ring(Vector((0, hd.y + 0.005, hd.z + 0.03)), UP, FWD, 0.045, 0.048, 8, [("Head", 0.6), ("Neck", 0.4)]),
    ]
    B.loft(neck, lambda k, i: jitter(sk, i), cap_start=False, cap_end=False)
    # tampa do pescoço por dentro do tronco
    B.face(list(reversed(neck[0])), sk)

    hy = hd.y + 0.012
    hz = hd.z
    head_rings_spec = [
        (0.045, 0.040, 0.035, -0.010),    # queixo
        (0.085, 0.066, 0.075, -0.006),    # maxilar
        (0.150, 0.078, 0.090, 0.000),     # maçã do rosto
        (0.185, 0.081, 0.095, 0.002),     # olhos
        (0.225, 0.079, 0.093, 0.004),     # sobrancelha / testa
        (0.270, 0.068, 0.082, 0.008),     # alto da cabeça
        (0.300, 0.040, 0.050, 0.010),
    ]
    hn = 10
    hrings = []
    HS = 1.1   # cabeça um pouco maior que a real (leitura do rosto a distância, padrão de jogo)
    head_rings_spec = [(dz * HS, rx * HS, ry * HS, dy) for (dz, rx, ry, dy) in head_rings_spec]
    for (dz, rx, ry, dy) in head_rings_spec:
        hrings.append(B.ring(Vector((0, hy + dy, hz + dz)), UP, FWD, rx, ry, hn, [("Head", 1)]))

    def head_col(k, i):
        back = i in (4, 5, 6)
        side = i in (3, 7)
        if k >= 4 or (k == 3 and (back or side)) or (k >= 2 and back):
            return jitter(hair, i)
        return jitter(sk, i)

    B.loft(hrings, head_col, cap_start=True, cap_end=True)
    if spec.get("long_hair"):
        # mecha longa atrás e dos lados até a nuca (para no pescoço: não encosta no ombro)
        lh = []
        for (dz, rx, ry) in [(0.29, 0.07, 0.07), (0.22, 0.092, 0.098), (0.12, 0.094, 0.098), (0.02, 0.085, 0.08)]:
            lh.append(B.ring(Vector((0, hy + 0.012, hz + dz)), UP, FWD, rx, ry, hn,
                             [("Head", 1)] if dz > 0.05 else [("Head", 0.7), ("Neck", 0.3)]))
        B.loft(lh, lambda k, i: jitter(hair, i), cap_start=False, cap_end=True,
               skip=lambda k, i: i in (0, 1, hn - 1) and k >= 0)
    if spec.get("hat"):
        hat = rgb("#24222a")
        brim = []
        for (dz, r) in [(0.255, 0.155), (0.268, 0.15)]:
            brim.append(B.ring(Vector((0, hy + 0.01, hz + dz)), UP, FWD, r, r * 1.05, 12, [("Head", 1)]))
        B.loft(brim, lambda k, i: jitter(hat, i), cap_start=True, cap_end=False)
        crown = []
        for (dz, r) in [(0.262, 0.088), (0.29, 0.087), (0.36, 0.082), (0.375, 0.06)]:
            crown.append(B.ring(Vector((0, hy + 0.012, hz + dz)), UP, FWD, r, r * 1.08, 10, [("Head", 1)]))
        B.loft(crown, lambda k, i: jitter(rgb("#5a1a1e") if k == 0 else hat, i), cap_start=False, cap_end=True)
    if spec.get("cap"):
        capc = rgb("#26407a")
        cr = []
        for (dz, r) in [(0.22, 0.086), (0.29, 0.076), (0.31, 0.04)]:
            cr.append(B.ring(Vector((0, hy + 0.008, hz + dz)), UP, FWD, r, r * 1.08, 10, [("Head", 1)]))
        B.loft(cr, lambda k, i: jitter(capc, i), cap_start=False, cap_end=True)
        x = Vector((1, 0, 0))
        B.box(Vector((0, hy - 0.11, hz + 0.225)), x, Vector((0, 1, 0)), UP, (0.06, 0.04, 0.006), capc, [("Head", 1)])
    if spec.get("hood"):
        # capuz caído atrás do pescoço (preso à parte de cima das costas)
        hc = rgb(spec["top2"])
        hr = []
        for (dz, rx, ry, dy) in [(-0.02, 0.13, 0.09, 0.04), (0.05, 0.12, 0.09, 0.06), (0.11, 0.08, 0.06, 0.07)]:
            hr.append(B.ring(Vector((0, nk.y + dy, nk.z + dz)), UP, FWD, rx, ry, 10, [("Spine2", 0.7), ("Neck", 0.3)]))
        B.loft(hr, lambda k, i: jitter(hc, i), cap_start=False, cap_end=True, skip=lambda k, i: i in (0, 1, 9))
        if spec.get("drawstrings"):
            ds = rgb(spec["drawstrings"])
            for sx in (-0.03, 0.03):
                B.box(Vector((sx, sp2.y - 0.105, sp2.z - 0.02)), Vector((1, 0, 0)), Vector((0, 1, 0)), UP,
                      (0.004, 0.004, 0.06), ds, [("Spine2", 1)])

    # ---------------- braços: tubo de anéis do ombro à mão, SEPARADO do tronco
    for side in ("Left", "Right"):
        a0, a1 = pts[side + "Arm"]
        f0, f1 = pts[side + "ForeArm"]
        h0, h1 = pts[side + "Hand"]
        sh = pts[side + "Shoulder"][0]
        sleeve = top if not spec.get("short_sleeve") else shirt
        cuff = shirt if spec.get("lapel") or spec.get("coat") else sleeve
        pr = [
            (lerp(sh, a0, 0.65), 0.07, [(side + "Shoulder", 0.4), (side + "Arm", 0.6)]),
            (a0 + (a1 - a0) * 0.12, 0.068, [(side + "Arm", 1)]),
            (lerp(a0, a1, 0.55), 0.061, [(side + "Arm", 1)]),
            (a1, 0.055, [(side + "Arm", 0.5), (side + "ForeArm", 0.5)]),
            (lerp(f0, f1, 0.45), 0.052, [(side + "ForeArm", 1)]),
            (lerp(f0, f1, 0.9), 0.044, [(side + "ForeArm", 0.8), (side + "Hand", 0.2)]),
        ]
        arm_rings = []
        for k, (c, r, w) in enumerate(pr):
            nxt = pr[min(k + 1, len(pr) - 1)][0]
            prv = pr[max(k - 1, 0)][0]
            axis = (nxt - prv)
            arm_rings.append(B.ring(c, axis, FWD, r, r * 0.95, 8, w))

        def arm_col(k, i, sleeve=sleeve, cuff=cuff):
            if spec.get("short_sleeve") and k >= 3:
                return jitter(sk, i)
            if k == len(pr) - 2 and (spec.get("coat") or spec.get("lapel")):
                return cuff
            return jitter(sleeve, i)

        B.loft(arm_rings, arm_col, cap_start=True, cap_end=True)
        # mão: punho + palma em bloco + polegar (mão de PS1)
        hx = (h1 - h0).normalized()
        handlen = 0.17
        tip = h0 + hx * handlen
        fwdh = (FWD - hx * FWD.dot(hx)).normalized()
        rgt = hx.cross(fwdh).normalized()
        hr = [
            (h0 - hx * 0.01, 0.032, 0.022, [(side + "Hand", 1)]),
            (h0 + hx * 0.06, 0.044, 0.02, [(side + "Hand", 1)]),
            (h0 + hx * 0.11, 0.042, 0.017, [(side + "Hand", 0.5), (side + "HandIndex1", 0.5)]),
            (tip, 0.034, 0.012, [(side + "HandIndex2", 1)]),
        ]
        hrs = [B.ring(c, hx, FWD, rx, ry, 6, w) for (c, rx, ry, w) in hr]
        B.loft(hrs, lambda k, i: jitter(sk, i), cap_start=True, cap_end=True)
        thumb_side = 1 if side == "Left" else -1
        tc = h0 + hx * 0.045 + fwdh * 0.03 + rgt * (0.0 * thumb_side)
        B.box(tc + hx * 0.02, hx, fwdh, rgt, (0.03, 0.012, 0.012), sk, [(side + "Hand", 1)])

    # ---------------- pernas
    for side in ("Left", "Right"):
        u0, u1 = pts[side + "UpLeg"]
        l0, l1 = pts[side + "Leg"]
        ft0, ft1 = pts[side + "Foot"]
        te = pts[side + "Toe_End"][1]
        pr = [
            (u0 + Vector((0, 0, 0.02)), H * 0.58, [(side + "UpLeg", 0.6), ("Hips", 0.4)]),
            (lerp(u0, u1, 0.3), 0.088, [(side + "UpLeg", 1)]),
            (lerp(u0, u1, 0.75), 0.072, [(side + "UpLeg", 1)]),
            (u1, 0.062, [(side + "UpLeg", 0.5), (side + "Leg", 0.5)]),
            (lerp(l0, l1, 0.4), 0.06, [(side + "Leg", 1)]),
            (l1 + Vector((0, 0, 0.01)), 0.046, [(side + "Leg", 0.5), (side + "Foot", 0.5)]),
        ]
        leg_rings = []
        for k, (c, r, w) in enumerate(pr):
            nxt = pr[min(k + 1, len(pr) - 1)][0]
            prv = pr[max(k - 1, 0)][0]
            leg_rings.append(B.ring(c, nxt - prv, FWD, r, r, 8, w))
        B.loft(leg_rings, lambda k, i: jitter(pants, i), cap_start=False, cap_end=True)
        # sapato
        fx = Vector(((te - ft0).x, (te - ft0).y, 0)).normalized()
        fc = Vector(((ft0.x + te.x) / 2, (ft0.y + te.y) / 2 + 0.01, 0.045))
        B.box(fc, Vector((-fx.y, fx.x, 0)), fx, UP, (0.05, 0.135, 0.04), shoes,
              [(side + "Foot", 0.6), (side + "ToeBase", 0.4)])

    # ---------------- sobretudo / avental: saia aberta na frente, dividida em 2 abas (uma por perna)
    if spec.get("coat") or spec.get("apron"):
        colc = rgb(spec["apron"]) if spec.get("apron") else top
        lvls = [(hipc.z + 0.0, H * 1.04, 0.115), (hipc.z - 0.2, H * 1.18, 0.13), (hipc.z - 0.42, H * 1.3, 0.145)]
        if spec.get("apron"):
            lvls = [(hipc.z + 0.03, H * 1.02, 0.112), (hipc.z - 0.2, H * 1.06, 0.12), (hipc.z - 0.38, H * 1.08, 0.125)]
        nn = 12
        for side, sgn in (("Left", 1), ("Right", -1)):
            rs = []
            for j, (z, rx, ry) in enumerate(lvls):
                w = [("Hips", 1)] if j == 0 else ([("Hips", 0.45), (side + "UpLeg", 0.55)] if j == 1 else
                                                  [("Hips", 0.2), (side + "UpLeg", 0.8)])
                ring = []
                for i in range(nn):
                    a = math.pi / 2 - math.pi / nn + 2 * math.pi * i / nn
                    x = rx * math.cos(a)
                    if x * sgn < -0.005:
                        ring.append(None)
                        continue
                    co = Vector((x, hipc.y + 0.01 - ry * math.sin(a), z))
                    ring.append(B.vert(co, w))
                rs.append(ring)
            for j in range(len(rs) - 1):
                for i in range(nn):
                    a, b = rs[j][i], rs[j][(i + 1) % nn]
                    c, d = rs[j + 1][(i + 1) % nn], rs[j + 1][i]
                    if None in (a, b, c, d):
                        continue
                    if spec.get("apron") and not (i in (0, 1, nn - 1) or i in (11, 10)):
                        continue          # avental só na frente
                    if spec.get("coat") and i == 0:
                        continue          # sobretudo aberto na frente
                    B.face([a, b, c, d], jitter(colc, i + j))
                    B.face([d, c, b, a], jitter(colc, i + j))   # dupla face (a saia é uma chapa)
    if spec.get("jacket"):
        # barra da jaqueta de couro (curta, só até o quadril, sem cobrir o braço)
        pass
    ob = B.to_object(arm)
    return ob


def build_face(spec, arm, pts):
    """Decalque do rosto: 4x3 quads sobre a frente da cabeça, com UV no atlas (coluna 0 = sério)."""
    B = Builder("Face")
    hd = pts["Head"][0]
    hy = hd.y + 0.012
    hz = hd.z
    uvl = B.bm.loops.layers.uv.new("UVMap")
    HS = 1.1
    # mesma superfície da cabeça (anéis de build_body com a mesma escala HS), 2 mm para fora
    rows = [(0.07, 0.073, 0.083, -0.005), (0.12, 0.077, 0.088, -0.002), (0.17, 0.08, 0.093, 0.001),
            (0.21, 0.0805, 0.094, 0.003), (0.245, 0.077, 0.09, 0.005)]
    rows = [(dz * HS, rx * HS + 0.002, ry * HS + 0.002, dy) for (dz, rx, ry, dy) in rows]
    cols = 7
    span = math.radians(112)
    grid = []
    for (dz, rx, ry, dy) in rows:
        rowv = []
        for c in range(cols):
            a = math.pi / 2 - span / 2 + span * c / (cols - 1)
            co = Vector((rx * math.cos(a), hy + dy - ry * math.sin(a), hz + dz))
            rowv.append((B.vert(co, [("Head", 1)]), c / (cols - 1)))
        grid.append(rowv)
    zmin, zmax = rows[0][0], rows[-1][0]
    cell_u = 1.0 / 8.0
    cell_v = 1.0 / 2.0
    for r in range(len(rows) - 1):
        for c in range(cols - 1):
            vs = [grid[r][c][0], grid[r][c + 1][0], grid[r + 1][c + 1][0], grid[r + 1][c][0]]
            fa = B.face(vs, (1, 1, 1))
            if fa is None:
                continue
            for lp in fa.loops:
                v = lp.vert
                # posição na grade -> uv da célula 0 (boca fechada)
                for rr in range(len(rows)):
                    for cc in range(cols):
                        if grid[rr][cc][0] == v:
                            u = 1.0 - grid[rr][cc][1]   # o rig olha para -Y: espelha
                            t = (rows[rr][0] - zmin) / (zmax - zmin)
                            lp[uvl].uv = (u * cell_u, 1.0 - (1.0 - t) * cell_v)
    ob = B.to_object(arm)
    return ob


def make_materials(body, face, cid):
    m = bpy.data.materials.new("Body_" + cid)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    body.data.materials.append(m)
    fm = bpy.data.materials.new("Face_" + cid)
    fm.use_nodes = True
    fm.blend_method = "CLIP" if hasattr(fm, "blend_method") else fm.blend_method
    nt = fm.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    img = bpy.data.images.load(os.path.join(OUT, "face_%s.png" % CHARS[cid]["face"]))
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    face.data.materials.append(fm)


def tri_count(ob):
    me = ob.data
    return sum(len(p.vertices) - 2 for p in me.polygons)


def export_char(cid, out_dir):
    reset()
    arm = base_armature()
    # repouso, sem ação
    arm.animation_data_clear()
    pts = bone_pts(arm)
    spec = CHARS[cid]
    body = build_body(spec, arm, pts)
    face = build_face(spec, arm, pts)
    make_materials(body, face, cid)
    tris = tri_count(body) + tri_count(face)
    path = os.path.join(out_dir, cid + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    for o in (arm, body, face):
        o.select_set(True)
    kw = dict(filepath=path, export_format="GLB", use_selection=True, export_animations=False,
              export_skins=True, export_apply=False, export_yup=True)
    try:
        bpy.ops.export_scene.gltf(export_vertex_color="ACTIVE", **kw)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)
    print("PERSONAGEM", cid, "tris", tris, "->", path)
    return tris


EXTRA_POSES = {}


def export_anims(out_dir):
    reset()
    arm = base_armature()
    arm.animation_data_clear()
    names = []
    for f in sorted(os.listdir(RAW)):
        if not f.endswith(".fbx"):
            continue
        name = f.replace("vance_", "").replace(".fbx", "")
        if name in ("sentado", "digitando", "encostado", "apontando"):
            continue
        objs = import_fbx(os.path.join(RAW, f))
        src = [o for o in objs if o.type == "ARMATURE"][0]
        # os FBX "sem pele" vêm com repouso em T e o personagem está em A: copiar a rotação local
        # torceria os braços para dentro. Copia a POSE VISUAL (espaço do mundo, osso a osso) e assa.
        baked = bake_from(arm, src, name)
        for o in objs:
            if o.type == "MESH":
                bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.objects.remove(src, do_unlink=True)
        names.append(name)
    # poses novas por pose-chave (IK temporário + bake): braços cruzados e mãos nos bolsos
    names += make_ik_pose(arm, "bracos_cruzados", {
        "Left": Vector((-0.15, -0.175, 1.12)), "Right": Vector((0.16, -0.16, 1.15))}, pole_out=0.5)
    names += make_ik_pose(arm, "maos_bolsos", {
        "Left": Vector((0.205, -0.005, 0.86)), "Right": Vector((-0.205, -0.005, 0.86))}, pole_out=-0.6)
    # braço x tronco: corrige cada animação contra o corpo mais largo do elenco (o Otto); os outros,
    # mais estreitos, ficam com folga ainda maior
    pts = bone_pts(arm)
    collider = build_body(CHARS["otto"], arm, pts)
    for nm in names:
        a = bpy.data.actions.get(nm)
        if a is not None:
            correct_arms(arm, collider, a)
    bpy.data.objects.remove(collider, do_unlink=True)
    # todas as ações no glTF como animações separadas
    ad = arm.animation_data_create()
    for nm in names:
        a = bpy.data.actions.get(nm)
        if a is None:
            continue
        tr = ad.nla_tracks.new()
        tr.name = nm
        st = tr.strips.new(nm, int(a.frame_range[0]), a)
        tr.mute = True
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    path = os.path.join(out_dir, "anims.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_animations=True,
                              export_animation_mode="NLA_TRACKS", export_skins=True, export_yup=True,
                              export_force_sampling=True, export_optimize_animation_size=True, export_frame_step=2)
    print("ANIMS", names, "->", path)


def bake_from(arm, src, name):
    act = src.animation_data.action
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    bpy.context.view_layer.objects.active = arm
    for o in bpy.context.selected_objects:
        o.select_set(False)
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="POSE")
    cons = []
    for pb in arm.pose.bones:
        if pb.name not in src.pose.bones:
            continue
        c = pb.constraints.new("COPY_TRANSFORMS")
        c.target = src
        c.subtarget = pb.name
        c.target_space = "WORLD"
        c.owner_space = "WORLD"
        cons.append(c)
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.nla.bake(frame_start=f0, frame_end=f1, step=1, only_selected=False, visual_keying=True,
                     clear_constraints=True, use_current_action=False, bake_types={"POSE"})
    bpy.ops.object.mode_set(mode="OBJECT")
    ad = arm.animation_data
    out = ad.action
    out.name = name
    out.use_fake_user = True
    ad.action = None
    return out


def _torso_setup(body):
    gname = {g.index: g.name.replace(P, "") for g in body.vertex_groups}
    dom = {}
    for v in body.data.vertices:
        if v.groups:
            g = max(v.groups, key=lambda x: x.weight)
            dom[v.index] = gname[g.group]
    torso = ("Spine", "Spine1", "Spine2", "Hips")
    tf = [list(p.vertices) for p in body.data.polygons if all(dom.get(i) in torso for i in p.vertices)]
    sides = {}
    for side in ("Left", "Right"):
        sides[side] = [i for i, n in dom.items() if n.startswith(side) and ("ForeArm" in n or "Hand" in n)]
    return tf, sides


def _inside(bvh, p):
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


def _penetration(body, tf, idxs, margin=0.012):
    from mathutils.bvhtree import BVHTree
    dg = bpy.context.evaluated_depsgraph_get()
    ev = body.evaluated_get(dg)
    me = ev.to_mesh()
    mw = body.matrix_world
    vs = [mw @ v.co for v in me.vertices]
    ev.to_mesh_clear()
    bvh = BVHTree.FromPolygons(vs, tf)
    worst = 0.0
    for i in idxs:
        p = vs[i]
        loc, nrm, _, dist = bvh.find_nearest(p, 0.4)
        if loc is None:
            continue
        if _inside(bvh, p):
            worst = max(worst, dist + margin)
        elif dist < margin:
            worst = max(worst, margin - dist)
    return worst


def assign(ad, act):
    """Blender 4.4+: ação com 'slots'; sem escolher o slot, a ação de outro objeto não anima nada."""
    ad.action = act
    try:
        if act is not None and len(act.slots) and ad.action_slot is None:
            ad.action_slot = act.slots[0]
    except AttributeError:
        pass


def correct_arms(arm, body, act):
    """Assa na ação uma rotação mínima do braço (ombro) que tira antebraço e mão de dentro do tronco.
    Por quadro: se penetra, tenta abrir o braço (abdução), trazer para a frente (flexão) ou os dois,
    em passos crescentes, e fica com o menor que resolve. Depois suaviza no tempo e grava as chaves."""
    ad = arm.animation_data_create()
    assign(ad, act)
    bpy.context.view_layer.objects.active = arm
    tf, sides = _torso_setup(body)
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    frames = list(range(f0, f1 + 1, 1))
    if frames[-1] != f1:
        frames.append(f1)
    corr = {"Left": {}, "Right": {}}
    sc = bpy.context.scene
    for f in frames:
        sc.frame_set(f)
        for side, sx in (("Left", 1.0), ("Right", -1.0)):
            pb = arm.pose.bones[P + side + "Arm"]
            base = pb.matrix.copy()
            pen = _penetration(body, tf, sides[side])
            if pen < 0.003:
                corr[side][f] = (0.0, 0.0)
                continue
            best = None
            for ang in range(4, 81, 4):
                for (ab, fl) in ((ang, 0), (0, ang), (ang * 0.6, ang * 0.6), (ang * 0.3, ang * 0.9), (ang * 0.9, ang * 0.3)):
                    _apply_corr(arm, pb, base, side, sx, ab, fl)
                    bpy.context.view_layer.update()
                    if _penetration(body, tf, sides[side]) < 0.003:
                        best = (ab, fl)
                        break
                if best:
                    break
            pb.matrix = base
            bpy.context.view_layer.update()
            corr[side][f] = best if best else (40.0, 20.0)
    # suaviza: máximo numa janela curta (não deixa entrar entre amostras) e média
    for side in corr:
        ks = sorted(corr[side])
        vals = [corr[side][k] for k in ks]
        mx = []
        for i in range(len(vals)):
            w = vals[max(0, i - 2):i + 3]
            mx.append((max(v[0] for v in w), max(v[1] for v in w)))
        sm = []
        for i in range(len(mx)):
            w = mx[max(0, i - 1):i + 2]
            sm.append((sum(v[0] for v in w) / len(w), sum(v[1] for v in w) / len(w)))
        corr[side] = dict(zip(ks, sm))
    # grava: em cada quadro, rotação de correção aplicada ao braço e chave de rotação
    for side, sx in (("Left", 1.0), ("Right", -1.0)):
        if all(v == (0.0, 0.0) for v in corr[side].values()):
            continue
        pb = arm.pose.bones[P + side + "Arm"]
        ks = sorted(corr[side])
        for f in range(f0, f1 + 1):
            # interpola a correção entre amostras
            j = 0
            while j + 1 < len(ks) and ks[j + 1] < f:
                j += 1
            k0, k1 = ks[j], ks[min(j + 1, len(ks) - 1)]
            t = 0.0 if k1 == k0 else (f - k0) / (k1 - k0)
            ab = corr[side][k0][0] * (1 - t) + corr[side][k1][0] * t
            fl = corr[side][k0][1] * (1 - t) + corr[side][k1][1] * t
            sc.frame_set(f)
            if ab < 0.05 and fl < 0.05:
                pb.keyframe_insert("rotation_quaternion" if pb.rotation_mode == "QUATERNION" else "rotation_euler", frame=f)
                continue
            base = pb.matrix.copy()
            _apply_corr(arm, pb, base, side, sx, ab, fl)
            bpy.context.view_layer.update()
            pb.keyframe_insert("rotation_quaternion" if pb.rotation_mode == "QUATERNION" else "rotation_euler", frame=f)
    ad.action = None


def _apply_corr(arm, pb, base, side, sx, ab_deg, fl_deg):
    """Gira o braço em volta do ombro no espaço do esqueleto: abdução (abre para o lado) e flexão
    (leva para a frente). O rig olha para -Y (no espaço do objeto o 'para cima' é +Z após o FBX)."""
    inv = arm.matrix_world.inverted()
    head = base.translation.copy()
    fwd_ax = (inv.to_3x3() @ Vector((0, -1, 0))).normalized()   # eixo frente-trás
    side_ax = (inv.to_3x3() @ Vector((1, 0, 0))).normalized()   # eixo lateral
    r = Matrix.Rotation(math.radians(ab_deg) * sx, 4, fwd_ax) @ Matrix.Rotation(-math.radians(fl_deg), 4, side_ax)
    m = Matrix.Translation(head) @ r @ Matrix.Translation(-head) @ base
    pb.matrix = m


def make_ik_pose(arm, name, targets, pole_out=0.5):
    """Pose estática (com respiração da 'respirando') levada por IK até alvos das mãos, assada em ação."""
    base = bpy.data.actions.get("respirando") or bpy.data.actions.get("idle_serio")
    ad = arm.animation_data_create()
    assign(ad, base)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    empties = []
    for side, tgt in targets.items():
        e = bpy.data.objects.new("T_" + side, None)
        e.location = tgt
        bpy.context.scene.collection.objects.link(e)
        pl = bpy.data.objects.new("P_" + side, None)
        sx = 1 if side == "Left" else -1
        pl.location = Vector((0.6 * sx, 0.05 if pole_out > 0 else 0.35, 1.0))
        bpy.context.scene.collection.objects.link(pl)
        pb = arm.pose.bones[P + side + "ForeArm"]
        c = pb.constraints.new("IK")
        c.target = e
        c.pole_target = pl
        c.pole_angle = math.radians(-90 if side == "Left" else -90)
        c.chain_count = 2
        empties += [e, pl]
    f0, f1 = int(base.frame_range[0]), int(base.frame_range[1])
    bpy.ops.nla.bake(frame_start=f0, frame_end=f1, step=2, only_selected=False, visual_keying=True,
                     clear_constraints=True, use_current_action=False, bake_types={"POSE"})
    baked = ad.action
    baked.name = name
    baked.use_fake_user = True
    ad.action = None
    bpy.ops.object.mode_set(mode="OBJECT")
    for e in empties:
        bpy.data.objects.remove(e, do_unlink=True)
    return [name]


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["all"]
    which = argv[0] if argv else "all"
    out_dir = argv[1] if len(argv) > 1 else OUT
    ids = list(CHARS) if which == "all" else ([] if which == "anims" else [which])
    for cid in ids:
        export_char(cid, out_dir)
    if which in ("all", "anims"):
        export_anims(out_dir)


main()
