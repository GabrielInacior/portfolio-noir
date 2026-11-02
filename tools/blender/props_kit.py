"""Kit de props das lojas feito à mão no Blender (31 props das lojas).

Low-poly no estilo PS1 dos personagens novos: volumes simples com chanfro, cores chapadas por
material (o jogo converte para o material PS1 com luz por vértice), emissão só onde brilha
(telas, LEDs, lâmpadas). Mesmas medidas dos modelos antigos para caber nos mesmos lugares.
Frente do modelo = -Y no Blender (= +Z no Godot). Origem no chão, centro da base.

  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup -P tools/blender/props_kit.py -- [nomes...]
"""
import math
import os
import random
import sys

import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "props")
R = random.Random(7)
PI = math.pi

_mats = {}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()


def mat(name, rgb, emit=0.0, rough=0.7):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    if emit > 0:
        b.inputs["Emission Color"].default_value = (*rgb, 1)
        b.inputs["Emission Strength"].default_value = emit
    _mats[name] = m
    return m


def hexc(h):
    h = h.lstrip("#")
    return tuple((int(h[i:i + 2], 16) / 255.0) ** 2.2 for i in (0, 2, 4))


def M(h, emit=0.0):
    return mat(h + ("_e%g" % emit if emit else ""), hexc(h), emit)


def _fin(o, m, bevel):
    if bevel > 0:
        mod = o.modifiers.new("b", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        mod.limit_method = "ANGLE"
    o.data.materials.append(m)
    return o


def box(c, s, m, bevel=0.01, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=c, rotation=rot)
    o = bpy.context.active_object
    o.scale = (s[0] / 2, s[1] / 2, s[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    return _fin(o, m, min(bevel, min(s) * 0.3))


def cyl(c, r, h, m, v=10, rot=(0, 0, 0), r2=None, bevel=0.0):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=v, radius=r, depth=h, location=c, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=v, radius1=r, radius2=r2, depth=h, location=c, rotation=rot)
    return _fin(bpy.context.active_object, m, bevel)


def ball(c, r, m, seg=8, scl=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=max(4, seg // 2), radius=r, location=c)
    o = bpy.context.active_object
    o.scale = scl
    bpy.ops.object.transform_apply(scale=True)
    return _fin(o, m, 0)


def torus(c, r, t, m, rot=(0, 0, 0), seg=12):
    bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=t, major_segments=seg, minor_segments=6,
                                     location=c, rotation=rot)
    return _fin(bpy.context.active_object, m, 0)


def _bake_vertex_colors(o):
    """Cor do material vira cor por vértice; o objeto fica com 1 material ("vc" ou "vc_glow")."""
    me = o.data
    m = me.materials[0] if me.materials else None
    col, emit = (0.5, 0.5, 0.5), 0.0
    if m is not None and m.use_nodes:
        b = m.node_tree.nodes["Principled BSDF"]
        col = tuple(b.inputs["Base Color"].default_value[:3])
        emit = b.inputs["Emission Strength"].default_value
    if emit > 0:  # o que brilha mantém material próprio (poucas cores); o jogo desenha sem luz
        m.name = "glow_" + m.name.split("_e")[0].lstrip("#")
        return
    attr = me.color_attributes.get("Col") or me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    for d in attr.data:
        d.color = (*col, 1.0)
    me.color_attributes.active_color = attr
    me.materials.clear()
    me.materials.append(_shared("vc"))


def _shared(name):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        nt = m.node_tree
        attr = nt.nodes.new("ShaderNodeVertexColor")
        attr.layer_name = "Col"
        nt.links.new(attr.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    return m


def export(name):
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in objs:
        bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
        _bake_vertex_colors(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    for p in o.data.polygons:  # sombreamento chapado por face (PS1)
        p.use_smooth = False
    dst = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_apply=True, export_yup=True,
                              export_vertex_color="ACTIVE")
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    print("OK %s tris=%d mats=%d KB=%d" % (name, tris, len(o.data.materials), os.path.getsize(dst) // 1024))


# ─────────────────────────────── paleta (mesma família do jogo)
WOOD_D = "#3b2416"
WOOD = "#6a4529"
WOOD_L = "#8c613f"
BRASS = "#b08a3c"
STEEL = "#6b7280"
STEEL_D = "#3a3f4a"
BLACK = "#14161c"
INK = "#0b0d12"
PAPER = "#e8e1cf"
GREEN_LAMP = "#2f7a4a"
CREAM = "#d9cfb6"
LEATHER = "#5a2e1c"
RED = "#a8202e"
NEON_G = "#39ff6a"
NEON_C = "#3fd3ff"
NEON_P = "#ff4fa3"
NEON_V = "#b45cff"
AMBER = "#ffc83d"


def drawer_front(x, y, z, w, h, body, handle):
    box((x, y - 0.004, z), (w, 0.012, h), body, 0.004)
    box((x, y - 0.016, z), (w * 0.28, 0.012, 0.02), handle, 0.003)


# ─────────────────────────────── RUMOR (escritório de detetive)
def mesa_detetive():
    w, d, h = 1.15, 0.55, 0.78
    top = M(WOOD)
    box((0, 0, h - 0.02), (w, d, 0.04), top, 0.012)
    box((0, 0, h - 0.04), (w - 0.04, d - 0.04, 0.012), M("#2c4a34"), 0.004)  # tampo de couro verde
    for sx in (-1, 1):  # gaveteiros laterais
        box((sx * (w / 2 - 0.17), 0, (h - 0.04) / 2), (0.32, d - 0.04, h - 0.04), M(WOOD_D), 0.01)
        for k in range(3):
            drawer_front(sx * (w / 2 - 0.17), -d / 2 + 0.02, 0.14 + k * 0.22, 0.28, 0.18, M(WOOD), M(BRASS))
    box((0, d / 2 - 0.03, 0.45), (w - 0.66, 0.02, 0.5), M(WOOD_D), 0.004)  # painel de fundo
    drawer_front(0, -d / 2 + 0.02, h - 0.12, 0.42, 0.08, M(WOOD), M(BRASS))
    # sobre a mesa: pasta, papéis, cinzeiro e caneca
    box((0.22, 0.02, h + 0.008), (0.28, 0.2, 0.012), M("#c9a76a"), 0.002, rot=(0, 0, 0.2))
    box((0.25, -0.02, h + 0.018), (0.2, 0.26, 0.004), M(PAPER), 0, rot=(0, 0, -0.15))
    cyl((-0.32, 0.08, h + 0.015), 0.06, 0.03, M(STEEL_D), 10)
    cyl((-0.2, -0.12, h + 0.05), 0.04, 0.1, M("#e9e4d8"), 10)


def maquina_escrever():
    blk = M(BLACK)
    box((0, 0.02, 0.06), (0.42, 0.34, 0.12), blk, 0.02)
    box((0, 0.1, 0.15), (0.38, 0.16, 0.08), blk, 0.02, rot=(0.25, 0, 0))
    cyl((0, 0.13, 0.22), 0.035, 0.44, M("#2a2d35"), 12, rot=(0, PI / 2, 0))  # rolo
    for s in (-1, 1):
        cyl((s * 0.23, 0.13, 0.22), 0.025, 0.03, M(STEEL), 8, rot=(0, PI / 2, 0))
    box((0, 0.15, 0.3), (0.3, 0.01, 0.16), M(PAPER), 0, rot=(-0.2, 0, 0))  # folha
    for row in range(4):  # teclas redondas
        for k in range(9 - row % 2):
            x = -0.16 + k * 0.04 + (row % 2) * 0.02
            cyl((x, -0.12 + row * 0.04, 0.125 + row * 0.012), 0.013, 0.012, M(CREAM), 6)
    box((0, -0.17, 0.11), (0.2, 0.02, 0.012), M(CREAM), 0)  # barra de espaço


def abajur_banqueiro():
    cyl((0, 0, 0.015), 0.11, 0.03, M(BRASS), 12)
    box((0, 0, 0.03), (0.22, 0.12, 0.02), M(BRASS), 0.005)
    cyl((0, 0.02, 0.2), 0.012, 0.34, M(BRASS), 6)
    box((0, 0.0, 0.38), (0.27, 0.11, 0.05), M(GREEN_LAMP), 0.02)  # cúpula verde (meia-cana deitada)
    box((0, 0.0, 0.405), (0.25, 0.08, 0.02), M("#3f9a5e"), 0.008)
    box((0, 0.0, 0.352), (0.22, 0.07, 0.006), M("#fff1c4", 2.5), 0)  # luz por baixo
    box((0, 0.02, 0.36), (0.04, 0.03, 0.03), M(BRASS), 0.005)  # encaixe na haste
    cyl((0.06, -0.05, 0.08), 0.004, 0.08, M(BRASS), 4)  # cordinha
    ball((0.06, -0.05, 0.035), 0.008, M(BRASS), 6)


def arquivo_aco():
    w, d, h = 0.5, 0.62, 1.32
    g = M("#5b6371")
    box((0, 0, h / 2), (w, d, h), g, 0.01)
    for k in range(4):
        z = 0.18 + k * 0.32
        box((0, -d / 2 - 0.006, z), (w - 0.05, 0.012, 0.28), M("#6c7484"), 0.004)
        box((0, -d / 2 - 0.02, z + 0.06), (0.14, 0.02, 0.025), M(STEEL), 0.004)
        box((0, -d / 2 - 0.014, z + 0.1), (0.08, 0.01, 0.035), M(PAPER), 0)  # etiqueta
    # gaveta de baixo entreaberta com pastas
    box((0, -d / 2 - 0.1, 0.18), (w - 0.06, 0.2, 0.24), M("#6c7484"), 0.004)
    for k in range(5):
        box((-0.15 + k * 0.075, -d / 2 - 0.1, 0.32), (0.012, 0.16, 0.06), M(["#c9a76a", "#d6b67a", "#b8925a"][k % 3]), 0)


def quadro_cortica():
    w, h = 1.56, 1.1
    box((0, 0, 0.8), (w + 0.06, 0.06, h + 0.06), M(WOOD_D), 0.01)
    box((0, -0.03, 0.8), (w, 0.02, h), M("#9c6b3e"), 0)
    pins = []
    cols = [PAPER, "#f2e6a0", "#d9e1f2", PAPER, "#f0c9c9", PAPER, "#e2f0d0"]
    for k in range(9):
        x = -0.6 + (k % 3) * 0.6 + R.uniform(-0.1, 0.1)
        z = 0.48 + (k // 3) * 0.32 + R.uniform(-0.04, 0.04)
        box((x, -0.045, z), (0.2, 0.006, 0.24), M(cols[k % len(cols)]), 0, rot=(0, R.uniform(-0.15, 0.15), 0))
        box((x, -0.05, z + 0.03), (0.14, 0.004, 0.1), M("#2a2f3a"), 0, rot=(0, R.uniform(-0.1, 0.1), 0))  # "foto"
        ball((x, -0.055, z + 0.11), 0.012, M(RED), 6)
        pins.append((x, z + 0.11))
    import itertools
    for a, b in [(0, 4), (4, 8), (1, 4), (4, 6), (2, 5), (3, 7)]:  # fios vermelhos
        (x1, z1), (x2, z2) = pins[a], pins[b]
        L = math.hypot(x2 - x1, z2 - z1)
        ang = math.atan2(z2 - z1, x2 - x1)
        box(((x1 + x2) / 2, -0.058, (z1 + z2) / 2), (L, 0.004, 0.006), M("#e2384f"), 0, rot=(0, -ang, 0))
    cyl((0, 0, 0.12), 0.02, 0.24, M(WOOD_D), 6)  # pé (quadro sobre cavalete)
    box((0, 0.1, 0.02), (0.9, 0.3, 0.04), M(WOOD_D), 0.005)


def cabideiro():
    wd = M(WOOD_D)
    cyl((0, 0, 0.92), 0.025, 1.8, wd, 8)
    for a in range(3):
        ang = a * 2 * PI / 3
        box((math.cos(ang) * 0.16, math.sin(ang) * 0.16, 0.05), (0.34, 0.04, 0.03), wd, 0.005, rot=(0, 0.25, ang))
    for a in range(4):
        ang = a * PI / 2 + 0.4
        box((math.cos(ang) * 0.09, math.sin(ang) * 0.09, 1.72), (0.16, 0.025, 0.025), M(BRASS), 0, rot=(0, -0.6, ang))
    ball((0, 0, 1.83), 0.04, wd, 8)
    # sobretudo bege pendurado e fedora
    coat = M("#a08a62")
    cyl((0.0, -0.11, 1.25), 0.2, 0.9, coat, 8, r2=0.13)
    box((0, -0.24, 1.55), (0.22, 0.06, 0.18), coat, 0.02)  # gola
    cyl((0.0, -0.11, 0.78), 0.21, 0.06, M("#8a7652"), 8)
    cyl((0.12, 0.05, 1.79), 0.17, 0.02, M("#2b2b33"), 12)  # aba do chapéu
    cyl((0.12, 0.05, 1.86), 0.1, 0.12, M("#2b2b33"), 10, r2=0.085)
    cyl((0.12, 0.05, 1.82), 0.102, 0.025, M("#5a2e1c"), 10)  # fita


def telefone_antigo():
    b = M(BLACK)
    box((0, 0, 0.04), (0.24, 0.15, 0.08), b, 0.025)
    cyl((0, -0.02, 0.085), 0.06, 0.012, M(CREAM), 12)  # disco
    for k in range(10):
        a = k * 2 * PI / 12
        cyl((math.cos(a) * 0.04, -0.02 + math.sin(a) * 0.04, 0.093), 0.007, 0.006, b, 5)
    box((-0.1, 0.045, 0.11), (0.03, 0.04, 0.05), b, 0.008)
    box((0.1, 0.045, 0.11), (0.03, 0.04, 0.05), b, 0.008)
    box((0, 0.045, 0.15), (0.26, 0.04, 0.03), b, 0.012)  # monofone
    for s in (-1, 1):
        cyl((s * 0.12, 0.045, 0.14), 0.03, 0.04, b, 8)
    torus((0.14, 0.03, 0.03), 0.03, 0.006, b, rot=(PI / 2, 0, 0), seg=8)  # fio


# ─────────────────────────────── InacioCyber (sala de segurança)
def rack_servidor():
    w, d, h = 0.6, 0.9, 1.98
    box((0, 0, h / 2), (w, d, h), M("#121419"), 0.012)
    box((0, -d / 2 - 0.004, h / 2), (w - 0.04, 0.01, h - 0.06), M("#1b1f28"), 0)
    for k in range(16):
        z = 0.12 + k * 0.115
        box((0, -d / 2 - 0.012, z), (w - 0.08, 0.012, 0.09), M("#3a4152"), 0.003)
        for j in range(4):
            col = [NEON_G, NEON_C, NEON_G, AMBER][(k + j) % 4]
            box((-0.2 + j * 0.03, -d / 2 - 0.02, z + 0.02), (0.012, 0.006, 0.01), M(col, 3.0), 0)
        box((0.12, -d / 2 - 0.02, z), (0.18, 0.006, 0.04), M("#0e1015"), 0)  # baias
    for s in (-1, 1):  # trilhos e cabos
        box((s * (w / 2 - 0.02), -d / 2 - 0.02, h / 2), (0.02, 0.02, h - 0.1), M(STEEL_D), 0)
    for k in range(5):
        cyl((-0.27 + k * 0.012, -d / 2 + 0.05, h + 0.12), 0.006, 0.26, M(["#2a6fd6", "#d6a62a", "#2ad66f"][k % 3]), 5)


def mesa_monitores():
    box((0, 0.05, 0.74), (1.6, 0.78, 0.04), M("#1a1d24"), 0.01)
    for s in (-1, 1):
        box((s * 0.76, 0.05, 0.37), (0.04, 0.72, 0.72), M("#22262f"), 0.005)
    for k, ang in enumerate((0.45, 0.0, -0.45)):
        x = (k - 1) * 0.52
        y = 0.22 - abs(k - 1) * 0.1
        box((x, y + 0.04, 0.77), (0.18, 0.12, 0.02), M(STEEL_D), 0.004)
        cyl((x, y + 0.06, 0.86), 0.015, 0.18, M(STEEL_D), 6)
        box((x, y, 1.02), (0.5, 0.03, 0.3), M(BLACK), 0.008, rot=(0, 0, ang))
        box((x - math.sin(ang) * 0.016, y - math.cos(ang) * 0.016, 1.02), (0.46, 0.004, 0.26),
            M(["#0c2a14", "#0a1f2a", "#2a0c18"][k], 1.5), 0, rot=(0, 0, ang))
        for line in range(6):  # linhas de código
            box((x - 0.12 - math.sin(ang) * 0.02, y - math.cos(ang) * 0.02, 0.92 + line * 0.035),
                (R.uniform(0.08, 0.3), 0.003, 0.012), M([NEON_G, NEON_C, NEON_P][k], 2.5), 0, rot=(0, 0, ang))
    box((0, -0.15, 0.765), (0.46, 0.15, 0.02), M("#22262f"), 0.004)  # teclado
    for k in range(12):
        box((-0.2 + k * 0.036, -0.15, 0.778), (0.028, 0.11, 0.006), M("#3a4150"), 0)
    box((0.36, -0.15, 0.77), (0.07, 0.11, 0.02), M("#2a2f3a"), 0.01)  # mouse
    box((-0.6, 0.25, 0.86), (0.18, 0.36, 0.2), M("#121419"), 0.008)  # gabinete
    box((-0.6, 0.06, 0.86), (0.02, 0.01, 0.16), M(NEON_G, 3), 0)
    cyl((0.62, -0.1, 0.81), 0.04, 0.1, M("#e9e4d8"), 8)  # caneca


def cadeira_gamer():
    blk, grn = M("#2c2f38"), M("#1f9d55")
    for k in range(5):
        a = k * 2 * PI / 5
        box((math.cos(a) * 0.17, math.sin(a) * 0.17, 0.06), (0.32, 0.05, 0.03), blk, 0.01, rot=(0, 0, a))
        cyl((math.cos(a) * 0.33, math.sin(a) * 0.33, 0.03), 0.03, 0.03, M(INK), 6, rot=(PI / 2, 0, a))
    cyl((0, 0, 0.27), 0.03, 0.4, M(STEEL), 8)
    box((0, 0.0, 0.5), (0.55, 0.52, 0.1), blk, 0.03)
    box((0, 0.0, 0.56), (0.32, 0.46, 0.02), grn, 0.005)
    box((0, 0.27, 0.92), (0.52, 0.12, 0.78), blk, 0.04, rot=(0.12, 0, 0))
    box((0, 0.22, 0.92), (0.26, 0.02, 0.66), grn, 0.005, rot=(0.12, 0, 0))
    box((0, 0.31, 1.27), (0.32, 0.12, 0.16), blk, 0.03, rot=(0.12, 0, 0))  # encosto de cabeça
    for s in (-1, 1):
        box((s * 0.3, 0.0, 0.66), (0.06, 0.38, 0.04), blk, 0.01)
        box((s * 0.3, 0.08, 0.6), (0.04, 0.04, 0.12), M(STEEL_D), 0)


def cadeado():
    s = M("#8c939e")
    box((0, 0, 0.06), (0.12, 0.05, 0.11), s, 0.01)
    torus((0, 0, 0.12), 0.042, 0.009, M("#c9ced6"), rot=(PI / 2, 0, 0), seg=10)
    cyl((0, -0.027, 0.05), 0.012, 0.01, M(INK), 8, rot=(PI / 2, 0, 0))


def roteador():
    b = M("#1a1d24")
    box((0, 0, 0.03), (0.32, 0.22, 0.05), b, 0.012)
    for k in range(6):
        box((-0.11 + k * 0.045, -0.111, 0.032), (0.012, 0.004, 0.008), M(NEON_C if k else NEON_G, 3), 0)
    for k, x in enumerate((-0.13, -0.045, 0.045, 0.13)):
        cyl((x, 0.09, 0.15), 0.008, 0.2, b, 6, rot=(R.uniform(-0.2, 0.2), R.uniform(-0.2, 0.2), 0))


# ─────────────────────────────── Fortress (fliperama)
def fliperama():
    body, side = M("#2a1b47"), M(NEON_V)
    for s in (-1, 1):  # laterais com a silhueta clássica
        box((s * 0.4, 0.05, 0.9), (0.04, 0.9, 1.8), body, 0.01)
        box((s * 0.42, 0.05, 0.9), (0.006, 0.8, 1.6), side, 0, rot=(0, 0, 0))
    box((0, 0.48, 0.9), (0.8, 0.04, 1.8), body, 0)
    box((0, -0.25, 0.4), (0.78, 0.4, 0.8), body, 0.01)  # base
    box((0, -0.3, 0.95), (0.78, 0.35, 0.06), M("#1a1230"), 0.01, rot=(-0.2, 0, 0))  # painel de controle
    cyl((-0.2, -0.33, 1.0), 0.012, 0.08, M(STEEL), 6)
    ball((-0.2, -0.33, 1.05), 0.03, M(RED), 8)
    for k in range(4):
        cyl((0.02 + k * 0.07, -0.32 - (k % 2) * 0.04, 0.99), 0.022, 0.02, M([NEON_C, NEON_P, AMBER, NEON_G][k], 1.5), 8)
    box((0, -0.05, 1.33), (0.66, 0.04, 0.5), M(BLACK), 0.01, rot=(-0.15, 0, 0))  # tela
    box((0, -0.075, 1.33), (0.6, 0.004, 0.44), M("#1a2a5a", 1.8), 0, rot=(-0.15, 0, 0))
    box((0, -0.12, 1.68), (0.78, 0.18, 0.22), M("#160e2a"), 0.01)  # marquise
    box((0, -0.21, 1.68), (0.7, 0.004, 0.16), M(NEON_P, 2.5), 0)
    box((0, -0.43, 0.25), (0.2, 0.01, 0.12), M(INK), 0)  # porta da moeda
    box((0, -0.44, 0.27), (0.04, 0.006, 0.02), M(AMBER, 2), 0)


def mesa_cartas():
    box((0, 0, 0.76), (1.25, 1.1, 0.05), M(WOOD), 0.015)
    box((0, 0, 0.785), (1.12, 0.96, 0.006), M("#1f5a3a"), 0)  # feltro verde
    for sx in (-1, 1):
        for sy in (-1, 1):
            cyl((sx * 0.55, sy * 0.47, 0.37), 0.035, 0.74, M(WOOD_D), 8, r2=0.025)
    cols = ["#e2384f", "#3f7fd6", "#e2b23f", "#5fbf6a", "#9b59d6"]
    for k in range(14):
        box((R.uniform(-0.45, 0.45), R.uniform(-0.38, 0.38), 0.792 + k * 0.001), (0.09, 0.13, 0.003),
            M(cols[k % 5]), 0, rot=(0, 0, R.uniform(-PI, PI)))
    for k in range(3):  # pilha de fichas e dados
        cyl((0.45, -0.35 + k * 0.05, 0.8), 0.02, 0.02 + k * 0.01, M([RED, NEON_C, AMBER][k]), 8)
    box((-0.45, 0.35, 0.805), (0.04, 0.04, 0.04), M(PAPER), 0.006)


def miniatura_fortaleza():
    box((0, 0, 0.03), (0.5, 0.46, 0.06), M(WOOD_D), 0.01)
    box((0, 0, 0.07), (0.44, 0.4, 0.03), M("#4f6b3a"), 0.01)  # grama
    stone, roof = M("#8a8478"), M("#7a2a2a")
    box((0, 0.02, 0.17), (0.3, 0.26, 0.18), stone, 0.004)  # muralha
    for x in (-0.15, 0.15):
        for y in (-0.11, 0.15):
            cyl((x, y, 0.22), 0.045, 0.28, stone, 8)
            cyl((x, y, 0.4), 0.055, 0.1, roof, 8, r2=0.0)
    box((0, 0.05, 0.3), (0.12, 0.12, 0.22), stone, 0.004)  # torre central
    cyl((0, 0.05, 0.45), 0.09, 0.12, roof, 4, r2=0.0)
    box((0, -0.11, 0.14), (0.06, 0.01, 0.1), M(INK), 0)  # portão
    for k in range(5):  # ameias
        box((-0.12 + k * 0.06, -0.11, 0.28), (0.03, 0.03, 0.03), stone, 0)
    cyl((0, 0.05, 0.53), 0.004, 0.08, M(STEEL), 4)
    box((0.02, 0.05, 0.56), (0.04, 0.002, 0.025), M(RED), 0)  # bandeira


def trofeu():
    g = M("#d4a63a")
    box((0, 0, 0.04), (0.2, 0.2, 0.08), M(BLACK), 0.005)
    box((0, -0.101, 0.04), (0.12, 0.003, 0.03), M(BRASS), 0)  # plaquinha
    cyl((0, 0, 0.1), 0.05, 0.04, g, 10)
    cyl((0, 0, 0.17), 0.015, 0.1, g, 8)
    cyl((0, 0, 0.3), 0.1, 0.16, g, 12, r2=0.05)
    for s in (-1, 1):
        torus((s * 0.11, 0, 0.32), 0.045, 0.01, g, rot=(PI / 2, 0, 0), seg=10)
    ball((0, 0, 0.42), 0.025, g, 8)


# ─────────────────────────────── LAB de skills
def bancada_lab():
    box((0, 0, 0.92), (1.15, 0.56, 0.05), M("#2b2f38"), 0.01)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box((sx * 0.53, sy * 0.24, 0.46), (0.04, 0.04, 0.9), M(STEEL_D), 0)
    box((0, 0, 0.25), (1.06, 0.48, 0.02), M("#2b2f38"), 0.004)  # prateleira de baixo
    box((0.2, 0.0, 0.955), (0.36, 0.25, 0.02), M("#1a1d24"), 0.006)  # notebook
    box((0.2, 0.13, 1.08), (0.36, 0.02, 0.24), M("#1a1d24"), 0.006, rot=(-0.25, 0, 0))
    box((0.2, 0.115, 1.08), (0.32, 0.004, 0.2), M("#0e2a3a", 1.6), 0, rot=(-0.25, 0, 0))
    box((-0.3, 0.05, 0.98), (0.16, 0.12, 0.08), M("#3a6fd6"), 0.008)  # placa/arduino
    for k in range(4):
        box((-0.36 + k * 0.04, 0.0, 1.03), (0.02, 0.02, 0.02), M([NEON_G, AMBER, NEON_C, RED][k], 2), 0)
    box((-0.05, -0.15, 0.96), (0.16, 0.1, 0.04), M("#c94f2a"), 0.008)  # ferramenta
    for k in range(3):  # caixas organizadoras
        box((-0.35 + k * 0.35, 0.0, 0.33), (0.3, 0.4, 0.14), M(["#3f7fd6", "#d6a62a", "#5fbf6a"][k]), 0.01)


def servidor_ia():
    blk = M("#262a35")
    for k in range(2):
        x = -0.34 + k * 0.68
        box((x, 0, 0.93), (0.62, 0.74, 1.86), blk, 0.015)
        box((x, -0.375, 0.93), (0.56, 0.01, 1.76), M("#30354a"), 0)
        for j in range(10):
            box((x, -0.383, 0.15 + j * 0.17), (0.5, 0.006, 0.12), M("#454b66"), 0.002)
        box((x, -0.39, 0.93), (0.02, 0.006, 1.7), M(NEON_V, 3.0), 0)  # filete de luz roxa
        for j in range(6):
            box((x - 0.2, -0.39, 0.3 + j * 0.25), (0.06, 0.006, 0.012), M(NEON_C, 2.5), 0)
    box((0, -0.39, 1.75), (0.5, 0.006, 0.08), M(NEON_P, 2.2), 0)  # letreiro
    for k in range(6):
        cyl((-0.5 + k * 0.2, 0.1, 1.9), 0.012, 0.1, M(STEEL_D), 6)


# ─────────────────────────────── comuns
def estante_livros():
    w, d, h = 1.34, 0.44, 2.08
    wd = M(WOOD_D)
    for sx in (-1, 1):
        box((sx * (w / 2 - 0.02), 0, h / 2), (0.04, d, h), wd, 0.006)
    box((0, d / 2 - 0.015, h / 2), (w - 0.04, 0.03, h), M("#24160d"), 0)  # fundo escuro
    box((0, 0, 0.02), (w, d, 0.04), wd, 0.006)
    cols = ["#7a2a2a", "#2a4a7a", "#3a6a3a", "#7a6a2a", "#5a2a6a", "#2a6a6a", "#8a4a2a", "#c9b48a", "#3a3a4a"]
    for row in range(5):
        z0 = 0.06 + row * 0.4
        box((0, 0, z0), (w - 0.04, d - 0.02, 0.025), wd, 0.004)
        x = -w / 2 + 0.06
        while x < w / 2 - 0.08:
            bw = R.uniform(0.025, 0.055)
            bh = R.uniform(0.22, 0.33)
            tilt = R.uniform(-0.25, 0.0) if R.random() < 0.08 else 0
            box((x + bw / 2, -0.02, z0 + 0.012 + bh / 2), (bw, d * 0.75, bh), M(R.choice(cols)), 0, rot=(0, tilt, 0))
            x += bw + 0.004
            if R.random() < 0.05:
                x += 0.08
    box((0, 0, h - 0.02), (w + 0.04, d + 0.04, 0.04), wd, 0.006)


def balcao_bar():
    w, d, h = 2.8, 0.6, 1.08
    box((0, 0, h / 2 - 0.02), (w, d, h - 0.04), M(WOOD_D), 0.01)
    for k in range(7):  # painéis
        box((-w / 2 + 0.2 + k * 0.4, -d / 2 - 0.006, h / 2 - 0.05), (0.34, 0.012, h - 0.3), M("#7a5032"), 0.004)
    box((0, -0.04, h), (w + 0.1, d + 0.2, 0.06), M(WOOD_L), 0.015)  # tampo
    cyl((0, -d / 2 - 0.12, 0.15), 0.02, w, M(BRASS), 8, rot=(0, PI / 2, 0))  # apoio de pé de latão
    for k in range(6):
        cyl((-w / 2 + 0.3 + k * 0.45, -d / 2 - 0.08, 0.15), 0.012, 0.12, M(BRASS), 6, rot=(PI / 2, 0, 0))
    box((0, -d / 2 - 0.01, 0.06), (w, 0.01, 0.03), M(NEON_P, 2.5), 0)  # luz embaixo do balcão
    box((0, 0.62, 0.52), (w, 0.3, 1.04), M(WOOD), 0.01)  # balcão de trás
    for k in range(5):
        cyl((-0.9 + k * 0.45, -0.05, h + 0.05), 0.03, 0.04, M("#cfe8f0"), 8)  # copos


def banqueta_bar():
    cyl((0, 0, 0.78), 0.17, 0.06, M(RED), 12)
    cyl((0, 0, 0.74), 0.15, 0.03, M(STEEL), 10)
    cyl((0, 0, 0.4), 0.025, 0.7, M(STEEL), 8)
    torus((0, 0, 0.28), 0.12, 0.012, M(STEEL), seg=10)
    cyl((0, 0, 0.02), 0.16, 0.04, M(STEEL_D), 12)


def garrafas():
    shapes = [(0.04, 0.26, "#3a7a3a"), (0.035, 0.3, "#7a4a1a"), (0.045, 0.22, "#c9d6e0"), (0.03, 0.32, "#2a2a6a"),
              (0.05, 0.2, "#8a1a2a"), (0.038, 0.28, "#d6a62a")]
    for k, (r, h, col) in enumerate(shapes):
        x = -0.18 + k * 0.075
        y = R.uniform(-0.06, 0.06)
        cyl((x, y, h * 0.35), r, h * 0.7, M(col), 8)
        cyl((x, y, h * 0.78), r, h * 0.12, M(col), 8, r2=r * 0.35)
        cyl((x, y, h * 0.92), r * 0.35, h * 0.16, M(col), 6)
        box((x, y - r - 0.001, h * 0.32), (r * 1.3, 0.003, h * 0.22), M(PAPER), 0)  # rótulo


def microfone_estudio():
    s = M(STEEL_D)
    for k in range(3):
        a = k * 2 * PI / 3
        box((math.cos(a) * 0.15, math.sin(a) * 0.15, 0.03), (0.32, 0.03, 0.03), s, 0.005, rot=(0, -0.15, a))
    cyl((0, 0, 0.75), 0.015, 1.45, s, 8)
    cyl((0, -0.1, 1.48), 0.012, 0.25, s, 6, rot=(0.8, 0, 0))
    cyl((0, -0.2, 1.53), 0.05, 0.16, M("#b8bcc4"), 10, rot=(0.3, 0, 0))  # cápsula
    torus((0, -0.2, 1.53), 0.06, 0.008, M(BLACK), rot=(PI / 2 + 0.3, 0, 0), seg=10)
    cyl((0, -0.29, 1.56), 0.07, 0.006, M("#2a2a33"), 12, rot=(PI / 2 + 0.3, 0, 0))  # pop filter


def mesa_som():
    box((0, 0.05, 0.3), (1.15, 0.95, 0.6), M("#4a3424"), 0.01)
    for s_ in (-1, 1):
        box((s_ * 0.58, -0.1, 0.62), (0.04, 0.72, 0.12), M(WOOD_L), 0.006, rot=(-0.12, 0, 0))
    box((0, -0.1, 0.62), (1.1, 0.7, 0.08), M("#5a6070"), 0.01, rot=(-0.12, 0, 0))
    for k in range(16):  # faders e botões
        x = -0.48 + k * 0.064
        box((x, -0.25, 0.65), (0.012, 0.22, 0.006), M(INK), 0)
        box((x, -0.25 + R.uniform(-0.08, 0.08), 0.665), (0.03, 0.02, 0.02), M(CREAM), 0.003)
        for j in range(3):
            cyl((x, 0.0 + j * 0.06, 0.69), 0.012, 0.02, M([NEON_C, AMBER, NEON_P][j]), 6)
    for k in range(2):  # medidores
        box((-0.2 + k * 0.4, 0.25, 0.75), (0.25, 0.02, 0.12), M(BLACK), 0.004)
        box((-0.2 + k * 0.4, 0.239, 0.75), (0.21, 0.004, 0.08), M("#16301a", 1.5), 0)
        box((-0.25 + k * 0.4, 0.236, 0.74), (0.1, 0.004, 0.04), M(NEON_G, 2.5), 0)


def mesa_escritorio():
    box((0, 0, 0.74), (1.32, 0.54, 0.04), M("#2a2d35"), 0.008)
    for s in (-1, 1):
        box((s * 0.62, 0, 0.37), (0.05, 0.5, 0.72), M("#3a3f4a"), 0.005)
    box((0, 0.24, 0.45), (1.2, 0.02, 0.4), M("#3a3f4a"), 0.004)
    box((0.42, 0, 0.32), (0.4, 0.46, 0.56), M("#33373f"), 0.008)  # gaveteiro
    for k in range(3):
        drawer_front(0.42, -0.23, 0.12 + k * 0.18, 0.36, 0.15, M("#3d424c"), M(STEEL))
    box((-0.3, 0.1, 0.77), (0.28, 0.2, 0.02), M(PAPER), 0, rot=(0, 0, 0.3))
    cyl((0.0, -0.05, 0.8), 0.035, 0.09, M("#2a6fd6"), 8)


def cadeira_escritorio():
    blk = M("#33363f")
    for k in range(5):
        a = k * 2 * PI / 5
        box((math.cos(a) * 0.16, math.sin(a) * 0.16, 0.06), (0.3, 0.045, 0.03), blk, 0.008, rot=(0, 0, a))
        cyl((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.03), 0.028, 0.03, M(INK), 6, rot=(PI / 2, 0, a))
    cyl((0, 0, 0.25), 0.025, 0.36, M(STEEL), 8)
    box((0, 0, 0.47), (0.5, 0.48, 0.08), blk, 0.03)
    box((0, 0.24, 0.8), (0.46, 0.06, 0.55), blk, 0.04, rot=(0.1, 0, 0))
    box((0, 0.21, 0.8), (0.38, 0.01, 0.45), M("#4a4f5c"), 0, rot=(0.1, 0, 0))  # tela de malha
    for s in (-1, 1):
        box((s * 0.27, 0.02, 0.62), (0.05, 0.3, 0.035), blk, 0.008)


def monitor():
    box((0, 0.05, 0.015), (0.22, 0.14, 0.03), M(STEEL_D), 0.006)
    cyl((0, 0.06, 0.13), 0.018, 0.22, M(STEEL_D), 6)
    box((0, 0, 0.32), (0.48, 0.035, 0.29), M(BLACK), 0.008)
    box((0, -0.019, 0.32), (0.44, 0.004, 0.25), M("#10223a", 1.4), 0)
    for k in range(5):
        box((-0.12, -0.022, 0.24 + k * 0.035), (R.uniform(0.08, 0.26), 0.003, 0.012), M(NEON_C, 2.2), 0)


def planta_vaso():
    cyl((0, 0, 0.18), 0.17, 0.36, M("#7d7a74"), 10, r2=0.2)  # vaso de concreto
    cyl((0, 0, 0.35), 0.18, 0.02, M("#3a2a1c"), 10)
    leaf = [M("#2f6a3a"), M("#3f8a4a"), M("#26553a")]
    for k in range(13):
        a = k * 2.4
        h = R.uniform(0.6, 1.25)
        tilt = R.uniform(0.25, 0.75)
        cyl((math.cos(a) * 0.06, math.sin(a) * 0.06, 0.35 + h * 0.3), 0.008, h * 0.6, M("#3a5a2a"), 4,
            rot=(tilt * math.sin(a), -tilt * math.cos(a), 0))
        x = math.cos(a) * (0.06 + math.sin(tilt) * h * 0.55)
        y = math.sin(a) * (0.06 + math.sin(tilt) * h * 0.55)
        z = 0.35 + math.cos(tilt) * h * 0.6
        box((x, y, z), (0.28, 0.12, 0.012), leaf[k % 3], 0, rot=(R.uniform(-0.4, 0.4), R.uniform(-0.5, 0.2), a))


def sofa_couro():
    lt = M(LEATHER)
    box((0, 0.05, 0.25), (1.86, 0.9, 0.3), lt, 0.04)  # base
    for k in range(3):  # almofadas do assento
        box((-0.55 + k * 0.55, -0.05, 0.45), (0.54, 0.7, 0.14), M("#6a3a24"), 0.04)
    box((0, 0.42, 0.62), (1.86, 0.2, 0.55), lt, 0.05)  # encosto capitonê
    for k in range(9):
        for j in range(2):
            ball((-0.8 + k * 0.2, 0.315, 0.55 + j * 0.16), 0.012, M("#3a1c10"), 4)
    for s in (-1, 1):
        box((s * 0.9, 0.05, 0.5), (0.2, 0.9, 0.55), lt, 0.06)  # braços enrolados
        cyl((s * 0.9, 0.05, 0.78), 0.11, 0.9, lt, 10, rot=(PI / 2, 0, 0))
    for sx in (-1, 1):
        for sy in (-1, 1):
            cyl((sx * 0.85, 0.05 + sy * 0.38, 0.05), 0.035, 0.1, M(WOOD_D), 6, r2=0.025)


def luminaria_teto():
    cyl((0, 0, 0.47), 0.04, 0.03, M(BLACK), 8)
    cyl((0, 0, 0.32), 0.006, 0.28, M(BLACK), 4)
    cyl((0, 0, 0.1), 0.15, 0.18, M("#2a2d35"), 12, r2=0.04)
    ball((0, 0, 0.04), 0.05, M("#fff1c4", 3.0), 8)


def pilha_papeis():
    for k in range(6):
        box((R.uniform(-0.03, 0.03), R.uniform(-0.03, 0.03), 0.02 + k * 0.03), (0.42, 0.3, 0.025),
            M(["#c9a76a", PAPER, "#d6b67a", "#e8e1cf", "#b8925a", PAPER][k]), 0.003, rot=(0, 0, R.uniform(-0.2, 0.2)))


ALL = [mesa_detetive, maquina_escrever, abajur_banqueiro, arquivo_aco, quadro_cortica, cabideiro, telefone_antigo,
       rack_servidor, mesa_monitores, cadeira_gamer, cadeado, roteador, fliperama, mesa_cartas, miniatura_fortaleza,
       trofeu, bancada_lab, servidor_ia, estante_livros, balcao_bar, banqueta_bar, garrafas, microfone_estudio,
       mesa_som, mesa_escritorio, cadeira_escritorio, monitor, planta_vaso, sofa_couro, luminaria_teto, pilha_papeis]


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for fn in ALL:
        if args and fn.__name__ not in args:
            continue
        reset()
        R.seed(hash(fn.__name__) & 0xffff)
        fn()
        export(fn.__name__)


main()
