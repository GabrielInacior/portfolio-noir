"""Carros noir a partir de modelos prontos (licenças CC0/CC-BY, créditos em docs/CREDITOS.md).

Uso: blender -b --factory-startup -P tools/blender/car_import.py
Fontes em tools/blender/car_sources/*.glb (baixadas do Poly Pizza). Para cada variação:
  importa, gira para a frente ficar em -Z no Godot (+Y no Blender), escala para o comprimento real,
  reduz polígonos se precisar, troca as cores para a paleta noir, junta tudo numa malha só e
  exporta para game/assets/vehicles/<nome>.glb com dois tipos de material que o ps1.gd entende:
  "vc" (cor por vértice, luz por vértice) e "glow_*" (faróis, lanternas e giroflex, sem luz).
"""
import bpy, bmesh, math, os
from mathutils import Vector, Matrix

HERE = os.path.dirname(__file__)
SRC = os.path.join(HERE, "car_sources")
OUT = os.path.join(HERE, "..", "..", "game", "assets", "vehicles")
os.makedirs(OUT, exist_ok=True)


def hx(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


GLASS = "#121a2a"
CHROME = "#b9bec8"
TIRE = "#101014"
TRIM = "#2a2c33"
GLOW = {"head": "#fff1c8", "tail": "#ff2633", "amber": "#ffab2e", "blue": "#3d7bff", "white": "#f4f6ff",
        "red": "#ff2a3a", "taxi": "#ffe27a"}

# regras por fonte: (trecho do nome do material em minúsculas) -> cor ("PAINT" usa a pintura da variação)
SOURCES = {
    "q_car": {"file": "q_car.glb", "rot": 180, "length": 4.6, "ratio": 1.0,
              "map": [("windows", GLASS), ("blue", "PAINT"), ("grey", TRIM), ("black", TIRE)],
              "glow": [("headlights", "head"), ("taillights", "tail")]},
    "q_police": {"file": "q_police.glb", "rot": 180, "length": 4.7, "ratio": 1.0,
                 "map": [("windows", GLASS), ("white", "#e6e6ea"), ("black", "#14161d"), ("grey", TRIM)],
                 "glow": [("headlights", "head"), ("taillights", "tail"), ("whitelights", "white"), ("bluelights", "blue")]},
    "charger": {"file": "charger.glb", "rot": 180, "length": 5.2, "ratio": 0.33,
                "map": [("glass", GLASS), ("red_chasis", "PAINT"), ("roof_black", "#17181d"), ("metalic", CHROME),
                        ("really_black", "#08080a"), ("tire", TIRE), ("grey", "#8d939e"), ("black", "#0c0c10")],
                "glow": [("red_light", "tail")]},
    "retro": {"file": "retrocar.glb", "rot": 180, "length": 4.4, "ratio": 1.0,
              "map": [("glass", GLASS), ("body", "PAINT"), ("bumper", "#1b1c22"), ("rim", "#9aa0ab"), ("tires", TIRE),
                      ("underchassis", "#0c0c10")],
              "glow": [("signal", "amber")]},
    "van": {"file": "van_generic.glb", "rot": -90, "length": 5.0, "ratio": 0.8,
            "map": [("glass", GLASS), ("bodywork", "PAINT"), ("plastic", TRIM), ("details", "#6d7280"),
                    ("plate", "#d9d6c8"), ("kidney", "#2c2e35"), ("wheel", TIRE)],
            "glow": [("front_lights_down", "amber"), ("front_lights", "head"), ("back_lights", "tail")]},
}

VARIANTS = [
    ("car_sedan_maroon", "q_car", "#5e1418", None),
    ("car_sedan_teal", "q_car", "#123f45", None),
    ("car_sedan_cream", "q_car", "#c9b994", None),
    ("car_sedan_black", "q_car", "#15161c", None),
    ("car_taxi_yellow", "q_car", "#f0b419", "taxi"),
    ("car_police", "q_police", None, "police"),
    ("car_muscle_crimson", "charger", "#8a0f17", "headlamps"),
    ("car_muscle_black", "charger", "#121318", "headlamps"),
    ("car_wagon_green", "retro", "#1f3a2a", "lamps"),
    ("car_wagon_brown", "retro", "#4a3122", "lamps"),
    ("car_van_grey", "van", "#6b6f78", None),
    ("car_van_navy", "van", "#18223f", None),
]


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mesh_objects():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def mat_base(m):
    if m and m.use_nodes:
        b = m.node_tree.nodes.get("Principled BSDF")
        if b:
            return tuple(b.inputs["Base Color"].default_value[:3])
    return (0.5, 0.5, 0.5)


def glow_mat(kind):
    name = "glow_" + kind
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (*hx(GLOW[kind]), 1.0)
        b.inputs["Emission Color"].default_value = (*hx(GLOW[kind]), 1.0)
        b.inputs["Emission Strength"].default_value = 2.0
    return m


def vc_mat():
    m = bpy.data.materials.get("vc")
    if m is None:
        m = bpy.data.materials.new("vc")
        m.use_nodes = True
        nt = m.node_tree
        a = nt.nodes.new("ShaderNodeVertexColor")
        a.layer_name = "Col"
        nt.links.new(a.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    return m


def pick(rules, name):
    n = name.lower()
    for key, val in rules:
        if key in n:
            return val
    return None


def add_box(c, s, col=None, glow=None):
    bpy.ops.mesh.primitive_cube_add(location=c)
    o = bpy.context.active_object
    o.scale = (s[0] / 2, s[1] / 2, s[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    m = bpy.data.materials.new("extra")
    m.use_nodes = True
    if glow:
        o.data.materials.append(glow_mat(glow))
    else:
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*hx(col), 1.0)
        o.data.materials.append(m)
    return o


def build(name, src_key, paint, extra):
    reset()
    spec = SOURCES[src_key]
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, spec["file"]))
    objs = mesh_objects()
    # aplica transformações e junta
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.context.scene.objects:
        if o.type != "MESH":
            continue
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.make_single_user(object=True, obdata=True)
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    car = bpy.context.active_object
    # frente para +Y no Blender (vira -Z no Godot)
    car.rotation_mode = "XYZ"   # o glTF importa em quatérnio; sem isso a rotação abaixo é ignorada
    car.rotation_euler = (0, 0, math.radians(spec["rot"]))
    bpy.ops.object.transform_apply(rotation=True)
    # escala pelo comprimento (eixo Y) e base no chão, centrado
    bb = [car.matrix_world @ Vector(c) for c in car.bound_box]
    mn = Vector((min(p.x for p in bb), min(p.y for p in bb), min(p.z for p in bb)))
    mx = Vector((max(p.x for p in bb), max(p.y for p in bb), max(p.z for p in bb)))
    s = spec["length"] / (mx.y - mn.y)
    car.location = (-(mn.x + mx.x) / 2 * s, -(mn.y + mx.y) / 2 * s, -mn.z * s)
    car.scale = (s, s, s)
    bpy.ops.object.transform_apply(location=True, scale=True)
    # extras desenhados aqui (luminoso do táxi, faixa xadrez), já em coordenadas finais
    if extra == "taxi":
        bb = [Vector(c) for c in car.bound_box]
        top = max(p.z for p in bb)
        parts = [add_box((0, -0.15, top + 0.11), (0.62, 0.26, 0.2), glow="taxi"),
                 add_box((0, -0.15, top + 0.005), (0.7, 0.32, 0.03), col="#1a1a1e")]
        for k in range(10):
            for side in (-1, 1):
                x = side * (max(p.x for p in bb) + 0.004)
                parts.append(add_box((x, -1.6 + k * 0.32, 0.62), (0.01, 0.16, 0.08), col="#111111" if k % 2 else "#f2f2f2"))
        bpy.ops.object.select_all(action="DESELECT")
        for p in parts:
            p.select_set(True)
        car.select_set(True)
        bpy.context.view_layer.objects.active = car
        bpy.ops.object.join()
        car = bpy.context.active_object
    if extra in ("headlamps", "lamps"):
        # o modelo não tem material de farol: quatro faróis redondos (caixas) na frente
        bb = [Vector(c) for c in car.bound_box]
        fy = max(p.y for p in bb)
        w = max(p.x for p in bb)
        h = max(p.z for p in bb)
        parts = []
        if extra == "headlamps":
            for x in (-w + 0.28, -w + 0.52, w - 0.52, w - 0.28):
                parts.append(add_box((x, fy - 0.05, h * 0.42), (0.17, 0.08, 0.15), glow="head"))
        else:
            ry = min(p.y for p in bb)
            for x in (-w + 0.3, w - 0.3):
                parts.append(add_box((x, fy - 0.03, h * 0.40), (0.26, 0.07, 0.14), glow="head"))
                parts.append(add_box((x, ry + 0.03, h * 0.45), (0.24, 0.07, 0.16), glow="tail"))
        bpy.ops.object.select_all(action="DESELECT")
        for q in parts:
            q.select_set(True)
        car.select_set(True)
        bpy.context.view_layer.objects.active = car
        bpy.ops.object.join()
        car = bpy.context.active_object
    # reduz polígonos (preserva limites de material)
    if spec["ratio"] < 1.0:
        mod = car.modifiers.new("dec", "DECIMATE")
        mod.ratio = spec["ratio"]
        mod.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = car
        bpy.ops.object.modifier_apply(modifier="dec")
    # cores: cada face recebe a cor da regra do seu material; brilhos viram glow_*
    me = car.data
    colors = []
    glow_idx = {}
    for i, m in enumerate(me.materials):
        mname = m.name if m else ""
        g = pick(spec["glow"], mname)
        if g:
            glow_idx[i] = g
            colors.append(None)
            continue
        if mname.startswith("glow_"):
            glow_idx[i] = mname[5:]
            colors.append(None)
            continue
        r = pick(spec["map"], mname)
        if r == "PAINT":
            colors.append(hx(paint))
        elif r:
            colors.append(hx(r))
        else:
            colors.append(mat_base(m))
    attr = me.color_attributes.get("Col") or me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    zs = [v.co.z for v in me.vertices]
    zmin, zmax = min(zs), max(zs)
    for p in me.polygons:
        base = colors[p.material_index]
        if base is None:
            continue
        # leve gradiente de altura e escurecer o que olha para baixo (dá volume sem textura)
        for li in p.loop_indices:
            v = me.vertices[me.loops[li].vertex_index]
            h = (v.co.z - zmin) / max(0.001, zmax - zmin)
            k = 0.78 + 0.3 * h
            if p.normal.z < -0.3:
                k *= 0.55
            attr.data[li].color = (min(1, base[0] * k), min(1, base[1] * k), min(1, base[2] * k), 1.0)
    me.color_attributes.active_color = attr
    # troca os materiais: 0 = "vc", demais = glow_<tipo>
    kinds = sorted(set(glow_idx.values()))
    new_mats = [vc_mat()] + [glow_mat(k) for k in kinds]
    remap = {}
    for i in range(len(me.materials)):
        remap[i] = (1 + kinds.index(glow_idx[i])) if i in glow_idx else 0
    idx = [remap[p.material_index] for p in me.polygons]
    me.materials.clear()
    for m in new_mats:
        me.materials.append(m)
    for p, j in zip(me.polygons, idx):
        p.material_index = j
        p.use_smooth = False
    bpy.ops.object.select_all(action="DESELECT")
    car.select_set(True)
    car.name = name
    dst = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_apply=True, export_yup=True,
                              export_vertex_color="ACTIVE", use_selection=True, export_materials="EXPORT",
                              export_texcoords=False, export_tangents=False)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    print("CAR_OK %s tris=%d KB=%d mats=%s" % (name, tris, os.path.getsize(dst) // 1024, [m.name for m in me.materials]))


for v in VARIANTS:
    build(*v)
