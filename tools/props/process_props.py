"""Processa os GLB crus da Meshy para o jogo: escala real (altura em metros), origem no chão e no
centro, limite de triângulos, textura reduzida (512 ou 256) em JPEG dentro do GLB.

  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup -P tools/props/process_props.py -- [nomes...]
Entrada tools/props/raw/<nome>.glb, saída game/assets/props/<nome>.glb.
"""
import json
import os
import sys

import bpy
import bmesh

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
RAW = os.path.join(HERE, "raw")
OUT = os.path.join(ROOT, "game", "assets", "props")
os.makedirs(OUT, exist_ok=True)
PROPS = json.load(open(os.path.join(HERE, "props_list.json"), encoding="utf8"))

# altura real (m) de cada prop; o maior lado vira a referência quando marcado com "w:"
HEIGHT = {
    "mesa_detetive": 0.8, "maquina_escrever": 0.28, "abajur_banqueiro": 0.45, "arquivo_aco": 1.35,
    "quadro_cortica": "w:1.6", "cabideiro": 1.85, "telefone_antigo": 0.2, "rack_servidor": 2.0,
    "mesa_monitores": 1.25, "cadeira_gamer": 1.3, "cadeado": 0.18, "roteador": 0.25, "fliperama": 1.8,
    "mesa_cartas": 0.8, "miniatura_fortaleza": 0.5, "trofeu": 0.45, "bancada_lab": 1.0, "servidor_ia": 1.9,
    "estante_livros": 2.1, "balcao_bar": 1.1, "banqueta_bar": 0.8, "garrafas": 0.35, "microfone_estudio": 1.6,
    "mesa_som": "w:1.2", "mesa_escritorio": 0.76, "cadeira_escritorio": 1.1, "monitor": 0.5,
    "planta_vaso": 1.3, "sofa_couro": 0.85, "luminaria_teto": 0.5, "pilha_papeis": 0.2, "caneca": 0.11,
    "pilha_livros": 0.3, "poste": 4.6, "hidrante": 0.8, "lixeira": 1.0, "banco_praca": 0.85,
    "carro_sedan": "w:4.8", "banca_jornal": 2.6, "caixa_correio": 1.2, "escada_incendio": 3.2,
    "toldo": "w:2.6", "caixas_papelao": 0.9, "cone_transito": 0.7,
}
SMALL = {"caneca", "cadeado", "roteador", "telefone_antigo", "pilha_papeis", "pilha_livros", "garrafas", "trofeu", "cone_transito"}

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
names = argv or [n for n in PROPS if os.path.exists(os.path.join(RAW, n + ".glb"))]

for name in names:
    src = os.path.join(RAW, name + ".glb")
    if not os.path.exists(src):
        print("sem", name)
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        continue
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    # aplica transformações (Meshy às vezes traz rotação/escala no nó)
    for o in list(bpy.context.scene.objects):
        if o != ob and o.type != "MESH":
            pass
    ob.parent = None
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # limite de triângulos
    target = int(PROPS[name].get("poly", 1500))
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    tris = sum(len(f.verts) - 2 for f in bm.faces)
    bm.free()
    if tris > target * 1.25:
        mod = ob.modifiers.new("dec", "DECIMATE")
        mod.ratio = target / tris
        bpy.ops.object.modifier_apply(modifier="dec")
    # escala real e origem no chão/centro
    xs = [v.co.x for v in ob.data.vertices]
    ys = [v.co.y for v in ob.data.vertices]
    zs = [v.co.z for v in ob.data.vertices]
    h = HEIGHT.get(name, 1.0)
    if isinstance(h, str):
        want = float(h[2:])
        s = want / max(max(xs) - min(xs), max(ys) - min(ys), 1e-4)
    else:
        s = float(h) / max(max(zs) - min(zs), 1e-4)
    cx, cy, cz = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, min(zs)
    for v in ob.data.vertices:
        v.co.x = (v.co.x - cx) * s
        v.co.y = (v.co.y - cy) * s
        v.co.z = (v.co.z - cz) * s
    # textura menor
    px = 256 if name in SMALL else 512
    for img in bpy.data.images:
        if img.size[0] > px:
            img.scale(px, px)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    tris = sum(len(f.verts) - 2 for f in bm.faces)
    bm.free()
    dst = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", use_selection=False, export_image_format="JPEG",
                              export_jpeg_quality=82, export_apply=True, export_animations=False)
    print("OK %s tris=%d tex=%d KB=%d" % (name, tris, px, os.path.getsize(dst) // 1024))
