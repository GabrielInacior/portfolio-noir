"""Props de rua procedurais (Blender headless) no estilo limpo dos modelos da Meshy: formas simples,
cantos chanfrados, sombreamento suave, cores chapadas por material (sem textura). Saída GLB em
game/assets/props/ (só gera os que ainda não existem, a menos que passe nomes).

  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup -P tools/props/street_props_blender.py -- [nomes]
"""
import math
import os
import sys

import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "props")


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


_mats = {}


def mat(name, rgb, rough=0.6, metal=0.0, emit=0.0):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit > 0:
        b.inputs["Emission Color"].default_value = (*rgb, 1)
        b.inputs["Emission Strength"].default_value = emit
    _mats[name] = m
    return m


def finish(o, m, bevel=0.02, smooth=True):
    if bevel > 0:
        mod = o.modifiers.new("b", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
    o.data.materials.append(m)
    if smooth:
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.shade_auto_smooth(angle=math.radians(35))
    return o


def box(loc, size, m, bevel=0.02, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, m, bevel)


def cyl(loc, r, h, m, verts=16, bevel=0.01, rot=(0, 0, 0), r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h, location=loc, rotation=rot)
    return finish(bpy.context.active_object, m, bevel)


def sphere(loc, r, m, seg=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=r, location=loc)
    o = bpy.context.active_object
    return finish(o, m, 0)


def export(name):
    bpy.ops.object.select_all(action="SELECT")
    for o in bpy.context.selected_objects:
        bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    dst = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_apply=True)
    tris = sum(len(p.vertices) - 2 for p in bpy.context.active_object.data.polygons)
    print("OK %s tris=%d KB=%d" % (name, tris, os.path.getsize(dst) // 1024))


IRON = (0.05, 0.06, 0.09)


def poste():
    m = mat("ferro", IRON, 0.5, 0.6)
    cyl((0, 0, 0.25), 0.2, 0.5, m, 12, 0.03, r2=0.14)
    cyl((0, 0, 2.2), 0.07, 3.9, m, 10)
    cyl((0, 0, 4.15), 0.11, 0.1, m, 10)
    cyl((0, 0, 4.45), 0.24, 0.5, mat("vidro_poste", (1.0, 0.82, 0.55), 0.3, 0, 3.0), 6, 0.0, r2=0.17)
    cyl((0, 0, 4.78), 0.3, 0.16, m, 6, 0.02, r2=0.05)


def hidrante():
    red = mat("vermelho", (0.62, 0.06, 0.07), 0.45)
    cyl((0, 0, 0.05), 0.2, 0.1, red, 14)
    cyl((0, 0, 0.38), 0.14, 0.6, red, 14)
    sphere((0, 0, 0.7), 0.15, red)
    cyl((0, 0, 0.84), 0.04, 0.08, red, 8)
    for a in (0, math.pi):
        cyl((math.cos(a) * 0.17, math.sin(a) * 0.17, 0.48), 0.06, 0.12, red, 10, rot=(0, math.pi / 2, a))
    cyl((0, -0.17, 0.48), 0.075, 0.1, mat("latao", (0.75, 0.55, 0.2), 0.4, 0.8), 10, rot=(math.pi / 2, 0, 0))


def lixeira():
    g = mat("lixo", (0.18, 0.2, 0.24), 0.55, 0.5)
    cyl((0, 0, 0.45), 0.3, 0.9, g, 14, 0.01, r2=0.27)
    cyl((0, 0, 0.93), 0.33, 0.07, g, 14, 0.02)
    cyl((0, 0, 1.0), 0.06, 0.06, g, 8)
    for k in range(4):
        z = 0.15 + k * 0.22
        cyl((0, 0, z), 0.305, 0.03, mat("lixo_aro", (0.1, 0.11, 0.14), 0.5, 0.6), 14, 0)


def banco_praca():
    wood = mat("madeira_banco", (0.42, 0.25, 0.12), 0.7)
    for k in range(4):
        box((0, -0.15 + k * 0.12, 0.45), (1.8, 0.1, 0.04), wood, 0.01)
    for k in range(3):
        box((0, 0.3, 0.6 + k * 0.12), (1.8, 0.04, 0.09), wood, 0.01)
    m = mat("ferro", IRON, 0.5, 0.6)
    for x in (-0.75, 0.75):
        box((x, 0.0, 0.22), (0.06, 0.6, 0.44), m, 0.01)
        box((x, 0.3, 0.6), (0.06, 0.05, 0.4), m, 0.01)


def carro_sedan():
    body = mat("carro", (0.06, 0.07, 0.11), 0.25, 0.7)
    chrome = mat("cromo", (0.7, 0.72, 0.78), 0.2, 1.0)
    glass = mat("vidro_carro", (0.08, 0.12, 0.2), 0.05, 0.6)
    box((0, 0, 0.62), (1.85, 4.8, 0.62), body, 0.12)
    box((0, -0.25, 1.15), (1.6, 2.4, 0.55), body, 0.18)
    box((0, -0.25, 1.17), (1.62, 2.1, 0.42), glass, 0.12)
    box((0, 2.42, 0.55), (1.6, 0.08, 0.2), chrome, 0.03)
    box((0, -2.42, 0.6), (1.6, 0.08, 0.16), chrome, 0.03)
    tire = mat("pneu", (0.03, 0.03, 0.035), 0.9)
    for x in (-0.86, 0.86):
        for y in (-1.5, 1.45):
            cyl((x, y, 0.36), 0.36, 0.26, tire, 16, 0.03, rot=(0, math.pi / 2, 0))
            cyl((x * 1.03, y, 0.36), 0.2, 0.25, chrome, 12, 0.0, rot=(0, math.pi / 2, 0))


def banca_jornal():
    green = mat("banca", (0.1, 0.28, 0.2), 0.6)
    box((0, 0, 1.1), (2.4, 1.6, 2.2), green, 0.05)
    box((0, 0, 2.3), (2.8, 2.0, 0.2), green, 0.05)
    box((0, 0.85, 1.25), (2.0, 0.05, 1.2), mat("revistas", (0.85, 0.7, 0.4), 0.7), 0.0)
    for i in range(6):
        box((-0.8 + i * 0.32, 0.9, 1.2 + (i % 2) * 0.35), (0.26, 0.04, 0.32),
            mat("rev%d" % (i % 3), [(0.8, 0.2, 0.3), (0.2, 0.4, 0.8), (0.9, 0.75, 0.2)][i % 3], 0.7), 0.0)


def caixa_correio():
    blue = mat("correio", (0.08, 0.2, 0.45), 0.5, 0.3)
    box((0, 0, 0.75), (0.5, 0.45, 0.8), blue, 0.04)
    cyl((0, 0, 1.15), 0.25, 0.5, blue, 16, 0.0, rot=(math.pi / 2, 0, 0))
    m = mat("ferro", IRON, 0.5, 0.6)
    for x in (-0.18, 0.18):
        box((x, 0, 0.18), (0.06, 0.4, 0.36), m, 0.01)


def escada_incendio():
    m = mat("ferro", IRON, 0.5, 0.6)
    box((0, 0, 0.0), (2.6, 1.0, 0.05), m, 0.0)
    for x in (-1.28, 1.28):
        box((x, 0.48, 0.5), (0.04, 0.04, 1.0), m, 0.0)
    box((0, 0.48, 1.0), (2.6, 0.04, 0.04), m, 0.0)
    for k in range(13):
        box((-1.25 + k * 0.21, 0.48, 0.5), (0.02, 0.02, 1.0), m, 0.0)
    # escada inclinada até o andar de cima
    bpy.ops.object.empty_add(location=(0, 0, 0))
    for k in range(10):
        box((-0.6 + k * 0.14, -0.1, 0.15 + k * 0.29), (0.14, 0.7, 0.03), m, 0.0)
    box((0.03, -0.45, 1.55), (1.8, 0.04, 0.04), m, 0.0, rot=(0, -math.atan2(2.9, 1.4), 0))


def toldo():
    red = mat("toldo_a", (0.5, 0.08, 0.12), 0.8)
    wht = mat("toldo_b", (0.8, 0.76, 0.7), 0.8)
    for k in range(8):
        box((-1.14 + k * 0.325, -0.4, 0.0), (0.325, 0.9, 0.03), red if k % 2 == 0 else wht, 0.0, rot=(-0.45, 0, 0))
        box((-1.14 + k * 0.325, -0.83, -0.3), (0.325, 0.03, 0.22), red if k % 2 == 0 else wht, 0.0)


def caixas_papelao():
    c = mat("papelao", (0.55, 0.38, 0.2), 0.85)
    box((0, 0, 0.25), (0.7, 0.6, 0.5), c, 0.02)
    box((0.15, 0.05, 0.68), (0.5, 0.45, 0.36), c, 0.02, rot=(0, 0, 0.3))
    box((-0.5, 0.2, 0.2), (0.4, 0.4, 0.4), c, 0.02, rot=(0, 0, -0.2))


def cone_transito():
    o = mat("laranja", (0.95, 0.35, 0.05), 0.5)
    w = mat("faixa", (0.9, 0.9, 0.9), 0.4)
    box((0, 0, 0.02), (0.42, 0.42, 0.04), mat("preto", (0.03, 0.03, 0.04), 0.8), 0.01)
    cyl((0, 0, 0.36), 0.17, 0.66, o, 14, 0.0, r2=0.03)
    cyl((0, 0, 0.42), 0.115, 0.1, w, 14, 0.0, r2=0.1)


def caneca():
    c = mat("caneca", (0.85, 0.82, 0.75), 0.4)
    cyl((0, 0, 0.05), 0.045, 0.1, c, 14)


def pilha_livros():
    cols = [(0.45, 0.12, 0.12), (0.12, 0.25, 0.4), (0.3, 0.35, 0.15), (0.5, 0.35, 0.15)]
    for k in range(4):
        box((0.01 * k, 0, 0.035 + k * 0.07), (0.3 - k * 0.02, 0.22, 0.065), mat("livro%d" % k, cols[k], 0.7), 0.005, rot=(0, 0, 0.15 * (k % 2)))


ALL = {"poste": poste, "hidrante": hidrante, "lixeira": lixeira, "banco_praca": banco_praca, "carro_sedan": carro_sedan,
       "banca_jornal": banca_jornal, "caixa_correio": caixa_correio, "escada_incendio": escada_incendio,
       "toldo": toldo, "caixas_papelao": caixas_papelao, "cone_transito": cone_transito, "caneca": caneca,
       "pilha_livros": pilha_livros}

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for n in (argv or [k for k in ALL if not os.path.exists(os.path.join(OUT, k + ".glb"))]):
    reset()
    _mats.clear()
    ALL[n]()
    export(n)
