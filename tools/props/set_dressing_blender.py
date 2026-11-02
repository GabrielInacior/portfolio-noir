"""Kit de objetos de cena (set dressing) em Blender headless, no estilo dos props do kit: formas suaves,
chanfro arredondado, cores chapadas, sombreamento suave. Saída game/assets/props/sd_<nome>.glb.

  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup -P tools/props/set_dressing_blender.py
"""
import math
import os
import random

import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "props")
R = random.Random(7)
_m = {}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _m.clear()


def mat(name, rgb, rough=0.6, metal=0.0, emit=0.0, alpha=1.0):
    if name in _m:
        return _m[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*rgb, 1)
        b.inputs["Emission Strength"].default_value = emit
    _m[name] = m
    return m


def fin(o, m, bevel=0.01, smooth=True):
    if bevel:
        md = o.modifiers.new("b", "BEVEL")
        md.width = bevel
        md.segments = 2
    o.data.materials.append(m)
    if smooth:
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.shade_auto_smooth(angle=math.radians(35))
    return o


def box(loc, size, m, bevel=0.01, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    return fin(o, m, bevel)


def cyl(loc, r, h, m, v=14, bevel=0.005, rot=(0, 0, 0), r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=v, radius=r, depth=h, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=v, radius1=r, radius2=r2, depth=h, location=loc, rotation=rot)
    return fin(bpy.context.active_object, m, bevel)


def ball(loc, r, m, seg=8, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=r, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    # amassado: empurra vértices ao acaso (papel, saco)
    for vtx in o.data.vertices:
        vtx.co *= 1.0 + R.uniform(-0.18, 0.18)
    return fin(o, m, 0)


def export(name):
    bpy.ops.object.select_all(action="SELECT")
    for o in bpy.context.selected_objects:
        bpy.context.view_layer.objects.active = o
        for md in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=md.name)
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    dst = os.path.join(OUT, "sd_%s.glb" % name)
    bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_apply=True)
    print("OK sd_%s KB=%d" % (name, os.path.getsize(dst) // 1024))


PAPER = (0.86, 0.83, 0.74)


def papeis_amassados():
    for i in range(6):
        ball((R.uniform(-0.4, 0.4), R.uniform(-0.4, 0.4), 0.04), 0.045, mat("papel", PAPER, 0.9), scale=(1, 1, 0.8))
    for i in range(4):
        box((R.uniform(-0.4, 0.4), R.uniform(-0.4, 0.4), 0.003), (0.21, 0.29, 0.004), mat("folha", (0.9, 0.88, 0.8), 0.9), 0.0, (0, 0, R.uniform(0, 3)))


def pilha_pastas():
    cols = [(0.75, 0.6, 0.35), (0.6, 0.45, 0.25), (0.8, 0.68, 0.42)]
    for k in range(7):
        box((R.uniform(-0.02, 0.02), R.uniform(-0.02, 0.02), 0.012 + k * 0.022), (0.32, 0.24, 0.02), mat("pasta%d" % (k % 3), cols[k % 3], 0.8), 0.004, (0, 0, R.uniform(-0.15, 0.15)))
    box((0.0, -0.13, 0.08), (0.06, 0.005, 0.1), mat("etiqueta", (0.85, 0.2, 0.2), 0.7), 0.0)


def caixa_arquivo():
    c = mat("papelao_arq", (0.62, 0.48, 0.3), 0.85)
    box((0, 0, 0.15), (0.4, 0.3, 0.3), c, 0.01)
    box((0, 0, 0.31), (0.42, 0.32, 0.04), mat("tampa_arq", (0.55, 0.42, 0.26), 0.85), 0.01)
    box((0, 0.155, 0.17), (0.18, 0.005, 0.06), mat("rotulo", (0.95, 0.93, 0.85), 0.8), 0.0)


def copos_cafe():
    for i, (x, y) in enumerate([(0, 0), (0.12, 0.05), (-0.1, 0.08)]):
        cyl((x, y, 0.06), 0.04, 0.12, mat("copo", (0.92, 0.9, 0.86), 0.6), 14, 0.003, r2=0.05)
        cyl((x, y, 0.075), 0.047, 0.03, mat("luva_copo", (0.55, 0.35, 0.2), 0.8), 14, 0.0, r2=0.049)


def cinzeiro():
    g = mat("cinzeiro", (0.25, 0.27, 0.3), 0.3, 0.8)
    cyl((0, 0, 0.015), 0.08, 0.03, g, 16, 0.006)
    for i in range(4):
        a = R.uniform(0, 6.28)
        cyl((math.cos(a) * 0.04, math.sin(a) * 0.04, 0.034), 0.006, 0.05, mat("bituca", (0.9, 0.85, 0.75), 0.8), 6, 0.0, rot=(math.pi / 2, 0, a))


def garrafas_vazias():
    cols = [(0.12, 0.35, 0.18), (0.4, 0.22, 0.08), (0.55, 0.6, 0.62)]
    for i in range(3):
        x = -0.1 + i * 0.1
        m = mat("vidro%d" % i, cols[i], 0.1, 0.2)
        cyl((x, 0, 0.1), 0.035, 0.2, m, 12, 0.004)
        cyl((x, 0, 0.23), 0.012, 0.07, m, 10, 0.0, r2=0.012)
    cyl((0.22, 0.05, 0.035), 0.035, 0.2, mat("vidro0", cols[0]), 12, 0.004, rot=(math.pi / 2, 0, 0.4))


def cabos():
    m = mat("cabo", (0.05, 0.05, 0.06), 0.6)
    for k in range(3):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.12 + k * 0.03, minor_radius=0.012, location=(R.uniform(-0.1, 0.1), R.uniform(-0.1, 0.1), 0.012))
        fin(bpy.context.active_object, m, 0)
    box((0.25, 0.0, 0.02), (0.18, 0.06, 0.04), mat("extensao", (0.85, 0.85, 0.82), 0.5), 0.008)


def postits():
    cols = [(1.0, 0.9, 0.3), (1.0, 0.5, 0.65), (0.5, 0.9, 1.0), (0.6, 1.0, 0.5)]
    for i in range(8):
        box((R.uniform(-0.5, 0.5), 0.0, R.uniform(-0.3, 0.3)), (0.08, 0.004, 0.08), mat("post%d" % (i % 4), cols[i % 4], 0.8), 0.0, (0, R.uniform(-0.2, 0.2), 0))


def relogio_parede():
    cyl((0, 0, 0), 0.18, 0.04, mat("relogio_aro", (0.15, 0.12, 0.1), 0.5), 24, 0.008, rot=(math.pi / 2, 0, 0))
    cyl((0, -0.022, 0), 0.16, 0.005, mat("relogio_face", (0.93, 0.9, 0.82), 0.6), 24, 0.0, rot=(math.pi / 2, 0, 0))
    box((0.0, -0.028, 0.05), (0.012, 0.004, 0.1), mat("ponteiro", (0.05, 0.05, 0.05)), 0.0)
    box((0.04, -0.03, 0.0), (0.08, 0.004, 0.01), mat("ponteiro", (0.05, 0.05, 0.05)), 0.0)


def caixa_pizza():
    box((0, 0, 0.025), (0.4, 0.4, 0.05), mat("pizza_caixa", (0.78, 0.66, 0.48), 0.85), 0.005)
    box((0, 0.0, 0.052), (0.3, 0.3, 0.004), mat("pizza_logo", (0.75, 0.15, 0.12), 0.7), 0.0)


def saco_lixo():
    m = mat("saco", (0.05, 0.055, 0.07), 0.25)
    ball((0, 0, 0.28), 0.3, m, scale=(1, 0.9, 0.95))
    cyl((0, 0, 0.58), 0.05, 0.12, m, 8, 0.0, r2=0.02)


def lata():
    for i in range(3):
        cyl((R.uniform(-0.2, 0.2), R.uniform(-0.2, 0.2), 0.033), 0.033, 0.12, mat("lata%d" % i, [(0.8, 0.1, 0.1), (0.1, 0.4, 0.8), (0.9, 0.8, 0.2)][i], 0.3, 0.8), 12, 0.003, rot=(math.pi / 2, 0, R.uniform(0, 3)))


def guarda_chuva():
    m = mat("guarda", (0.08, 0.08, 0.1), 0.4)
    cyl((0, 0, 0.45), 0.012, 0.9, m, 8, 0.0)
    cyl((0, 0, 0.55), 0.1, 0.65, m, 8, 0.0, r2=0.02)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.04, minor_radius=0.01, location=(0.04, 0, 0.95), rotation=(math.pi / 2, 0, 0))
    fin(bpy.context.active_object, mat("cabo_guarda", (0.35, 0.2, 0.1), 0.6), 0)


def bicicleta():
    m = mat("bici", (0.6, 0.12, 0.15), 0.3, 0.6)
    t = mat("pneu_bici", (0.04, 0.04, 0.05), 0.9)
    for y in (-0.5, 0.5):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.32, minor_radius=0.025, location=(0, y, 0.34), rotation=(0, math.pi / 2, 0))
        fin(bpy.context.active_object, t, 0)
    cyl((0, 0, 0.55), 0.02, 0.95, m, 8, 0.0, rot=(math.pi / 2, 0, 0))
    cyl((0, -0.2, 0.5), 0.02, 0.5, m, 8, 0.0, rot=(0.6, 0, 0))
    box((0, 0.45, 0.85), (0.5, 0.03, 0.03), m, 0.0)
    box((0, -0.25, 0.8), (0.1, 0.2, 0.04), mat("selim", (0.05, 0.05, 0.05), 0.6), 0.01)


def mesa_bar_rua():
    m = mat("mesa_metal", (0.2, 0.22, 0.26), 0.4, 0.7)
    cyl((0, 0, 0.72), 0.35, 0.03, m, 20, 0.006)
    cyl((0, 0, 0.36), 0.03, 0.72, m, 10, 0.0)
    cyl((0, 0, 0.02), 0.22, 0.03, m, 16, 0.0)
    for a in (0, math.pi):
        x, y = math.cos(a) * 0.6, math.sin(a) * 0.6
        cyl((x, y, 0.45), 0.2, 0.03, m, 16, 0.0)
        cyl((x, y, 0.22), 0.02, 0.45, m, 8, 0.0)


ALL = {"papeis": papeis_amassados, "pastas": pilha_pastas, "caixa_arquivo": caixa_arquivo, "copos": copos_cafe,
       "cinzeiro": cinzeiro, "garrafas_vazias": garrafas_vazias, "cabos": cabos, "postits": postits,
       "relogio": relogio_parede, "pizza": caixa_pizza, "saco_lixo": saco_lixo, "latas": lata,
       "guarda_chuva": guarda_chuva, "bicicleta": bicicleta, "mesa_bar_rua": mesa_bar_rua}
for n, fn in ALL.items():
    reset()
    fn()
    export(n)
