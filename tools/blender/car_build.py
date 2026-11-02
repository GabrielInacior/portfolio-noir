"""Carros noir low-poly estilo PS1 (Blender headless). Gera game/assets/vehicles/*.glb.

Uso: blender -b --factory-startup -P tools/blender/car_build.py
Modelos: sedã anos 50 (detetive), táxi, cupê (muscle) e van, com variações de cor. Corpo por SEÇÕES
lofadas (para-lamas arredondados de verdade, capô, porta-malas), cabine com vidros escuros, para-choques
e calotas cromados, grade, faróis e lanternas emissivos (material separado, casa com os reflexos do
asfalto). Textura única de paleta pintada 64x64 (filtro nearest no jogo). Frente do carro em -Z.
"""
import bpy, bmesh, math, os, random

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "game", "assets", "vehicles")
os.makedirs(OUT, exist_ok=True)
CELL = 8          # paleta 8x8 células
N = 8
random.seed(3)

# ─────────────── paleta (cada célula com leve gradiente e ruído pintado)
PAL = {
	"maroon": (0.42, 0.08, 0.10), "teal": (0.07, 0.30, 0.33), "cream": (0.78, 0.71, 0.55), "black": (0.06, 0.06, 0.08),
	"crimson": (0.62, 0.06, 0.09), "grey": (0.40, 0.42, 0.46), "navy": (0.08, 0.12, 0.26), "yellow": (0.95, 0.72, 0.10),
	"chrome": (0.80, 0.82, 0.88), "glass": (0.05, 0.08, 0.13), "tire": (0.05, 0.05, 0.06), "grille": (0.10, 0.10, 0.12),
	"head": (1.0, 0.94, 0.75), "tail": (0.95, 0.12, 0.14), "white": (0.92, 0.92, 0.90), "under": (0.03, 0.03, 0.04),
	"glass_hi": (0.18, 0.26, 0.40), "rust": (0.30, 0.16, 0.10),
}
NAMES = list(PAL.keys())


def cell_uv(name):
	i = NAMES.index(name)
	cx, cy = i % N, i // N
	return ((cx + 0.5) / N, 1.0 - (cy + 0.5) / N)


def build_palette():
	size = N * CELL
	img = bpy.data.images.new("car_palette", size, size, alpha=False)
	px = [0.0] * (size * size * 4)
	for i, nm in enumerate(NAMES):
		cx, cy = i % N, i // N
		r, g, b = PAL[nm]
		for y in range(CELL):
			for x in range(CELL):
				k = 1.0 + (0.5 - y / CELL) * 0.18 + random.uniform(-0.04, 0.04)   # gradiente de cima para baixo + ruído
				X = cx * CELL + x
				Y = size - 1 - (cy * CELL + y)
				o = (Y * size + X) * 4
				px[o:o + 4] = [min(1.0, r * k), min(1.0, g * k), min(1.0, b * k), 1.0]
	img.pixels = px
	img.filepath_raw = os.path.join(OUT, "car_palette.png")
	img.file_format = "PNG"
	img.save()
	return img


def material(name, img, emit=None):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	nt = m.node_tree
	bsdf = nt.nodes.get("Principled BSDF")
	tex = nt.nodes.new("ShaderNodeTexImage")
	tex.image = img
	tex.interpolation = "Closest"
	nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
	bsdf.inputs["Roughness"].default_value = 0.9
	if emit is not None:
		bsdf.inputs["Emission Color"].default_value = (*emit, 1.0)
		bsdf.inputs["Emission Strength"].default_value = 1.2
	return m


# ─────────────── geometria
def loft(bm, sections, color_fn, closed_ends=True):
	"""sections: [(z, [(x,y)...] metade direita de baixo-centro até cima-centro)] -> anel espelhado."""
	rings = []
	for z, half in sections:
		pts = [(x, y) for x, y in half]
		ring = pts + [(-x, y) for x, y in reversed(pts[1:-1])]
		rings.append([bm.verts.new((x, y, z)) for x, y in ring])
	faces = []
	for a, b in zip(rings, rings[1:]):
		n = len(a)
		for i in range(n):
			f = bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
			faces.append(f)
	if closed_ends:
		faces.append(bm.faces.new(list(reversed(rings[0]))))
		faces.append(bm.faces.new(rings[-1]))
	for f in faces:
		f.normal_update()
		color_fn(f)
	return faces


def box(bm, cx, cy, cz, sx, sy, sz, col):
	vs = []
	for dx in (-1, 1):
		for dy in (-1, 1):
			for dz in (-1, 1):
				vs.append(bm.verts.new((cx + dx * sx / 2, cy + dy * sy / 2, cz + dz * sz / 2)))
	idx = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
	out = []
	for q in idx:
		f = bm.faces.new([vs[i] for i in q])
		f.normal_update()
		f[bm.faces.layers.int.get("col") or bm.faces.layers.int.new("col")] = NAMES.index(col)
		out.append(f)
	# normais para fora
	bmesh.ops.recalc_face_normals(bm, faces=out)
	return out


def cyl(bm, cx, cy, cz, r, w, col, cap_col=None, sides=10):
	"""cilindro deitado no eixo X (roda / farol traseiro)"""
	res = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=sides, radius1=r, radius2=r, depth=w)
	vs = res["verts"]
	bmesh.ops.rotate(bm, verts=vs, cent=(0, 0, 0), matrix=__import__("mathutils").Matrix.Rotation(math.pi / 2, 3, "Y"))
	bmesh.ops.translate(bm, verts=vs, vec=(cx, cy, cz))
	lay = bm.faces.layers.int.get("col") or bm.faces.layers.int.new("col")
	fs = {f for v in vs for f in v.link_faces}
	for f in fs:
		f.normal_update()
		side = abs(f.normal.x) < 0.5
		f[lay] = NAMES.index(col if side or cap_col is None else cap_col)
	return list(fs)


def disc_z(bm, cx, cy, cz, r, col, sides=10, face=-1):
	"""disco virado para frente (-Z) ou trás (+Z): farol/lanterna"""
	res = bmesh.ops.create_circle(bm, cap_ends=True, segments=sides, radius=r)
	vs = res["verts"]
	if face < 0:
		bmesh.ops.rotate(bm, verts=vs, cent=(0, 0, 0), matrix=__import__("mathutils").Matrix.Rotation(math.pi, 3, "X"))
	bmesh.ops.translate(bm, verts=vs, vec=(cx, cy, cz))
	lay = bm.faces.layers.int.get("col") or bm.faces.layers.int.new("col")
	for f in {f for v in vs for f in v.link_faces}:
		f[lay] = NAMES.index(col)


def body_section(w, ybot, ymid, ytop, round_=0.12):
	"""metade direita de uma seção do corpo (de baixo-centro até cima-centro)"""
	return [(0.0, ybot), (w - round_, ybot), (w, ybot + round_), (w, ymid), (w - round_ * 0.8, ytop - 0.02), (0.0, ytop)]


def cabin_section(wb, wt, yb, yt):
	return [(0.0, yb), (wb, yb), (wt, yt - 0.04), (wt - 0.08, yt), (0.0, yt)]


def make_car(kind, paint):
	bm = bmesh.new()
	lay = bm.faces.layers.int.new("col")

	def paint_fn(col):
		def f(face):
			face[lay] = NAMES.index(col)
		return f

	def cabin_fn(face):
		# teto na cor da pintura; laterais, para-brisa e vidro traseiro escuros
		face[lay] = NAMES.index(paint if face.normal.y > 0.75 else "glass")

	W = 0.95
	if kind in ("sedan", "taxi"):
		L = 2.55
		secs = []
		for z, ws, hs in [(-L, 0.80, 0.80), (-L + 0.12, 0.92, 0.92), (-L + 0.45, 1.0, 1.0), (-1.4, 1.03, 1.02), (-0.9, 0.99, 1.0),
				(0.4, 0.99, 1.0), (1.2, 1.03, 1.03), (L - 0.4, 1.0, 0.99), (L - 0.12, 0.93, 0.93), (L, 0.82, 0.84)]:
			secs.append((z, body_section(W * ws, 0.30, 0.78 * hs, 0.98 * hs)))
		loft(bm, secs, paint_fn(paint))
		cab = [(-0.75, cabin_section(0.84, 0.70, 0.96, 1.18)), (-0.45, cabin_section(0.85, 0.74, 0.96, 1.52)),
			(0.75, cabin_section(0.85, 0.74, 0.96, 1.52)), (1.25, cabin_section(0.84, 0.70, 0.96, 1.16))]
		loft(bm, cab, cabin_fn)
		wz = 1.55
	elif kind == "coupe":
		L = 2.6
		secs = []
		for z, ws, hs in [(-L, 0.84, 0.76), (-L + 0.14, 0.95, 0.88), (-L + 0.6, 1.0, 0.94), (-1.2, 1.04, 0.95), (0.2, 1.0, 0.95),
				(1.3, 1.06, 0.97), (L - 0.3, 1.02, 0.96), (L, 0.88, 0.86)]:
			secs.append((z, body_section(W * ws, 0.26, 0.70 * hs, 0.90 * hs)))
		loft(bm, secs, paint_fn(paint))
		cab = [(0.0, cabin_section(0.84, 0.66, 0.86, 1.02)), (0.35, cabin_section(0.85, 0.72, 0.86, 1.32)),
			(1.1, cabin_section(0.85, 0.72, 0.86, 1.30)), (1.85, cabin_section(0.86, 0.74, 0.86, 0.95))]
		loft(bm, cab, cabin_fn)
		# faixas de corrida no capô
		box(bm, 0.18, 0.885, -1.4, 0.12, 0.02, 2.2, "white")
		box(bm, -0.18, 0.885, -1.4, 0.12, 0.02, 2.2, "white")
		wz = 1.6
	else:  # van
		L = 2.45
		secs = []
		for z, ws, hs in [(-L, 0.86, 0.82), (-L + 0.15, 0.97, 0.94), (-1.7, 1.0, 1.0), (L - 0.15, 1.0, 1.0), (L, 0.94, 0.97)]:
			secs.append((z, body_section(W * ws * 1.02, 0.34, 1.0 * hs, 1.10 * hs, 0.16)))
		loft(bm, secs, paint_fn(paint))
		cab = [(-1.75, cabin_section(0.96, 0.9, 1.08, 1.2)), (-1.3, cabin_section(0.97, 0.92, 1.08, 2.05)),
			(L - 0.05, cabin_section(0.97, 0.92, 1.08, 2.05))]
		def van_fn(face):
			# janelas só na frente e na primeira janela lateral; resto pintado
			z = sum(v.co.z for v in face.verts) / len(face.verts)
			side_win = abs(face.normal.x) > 0.6 and -1.4 < z < -0.4
			front = face.normal.z < -0.5
			face[lay] = NAMES.index("glass" if (side_win or front) and face.normal.y < 0.75 else paint)
		loft(bm, cab, van_fn)
		# porta lateral (sulco) e faixa
		box(bm, 0.985, 1.25, 0.6, 0.02, 0.8, 1.2, "grille")
		wz = 1.5

	# para-choques cromados, grade e luzes
	fz = -L - 0.06
	rz = L + 0.06
	box(bm, 0, 0.44, fz, 1.95, 0.16, 0.12, "chrome")
	box(bm, 0, 0.44, rz, 1.95, 0.16, 0.12, "chrome")
	box(bm, 0, 0.66, -L - 0.005, 0.95, 0.24, 0.04, "grille")
	for k in range(5):
		box(bm, -0.36 + k * 0.18, 0.66, -L - 0.03, 0.03, 0.22, 0.03, "chrome")
	hy = 0.74 if kind != "van" else 0.86
	for sx in (-0.66, 0.66):
		disc_z(bm, sx, hy, -L - 0.03, 0.13, "head", 10, -1)
		box(bm, sx, 0.70 if kind != "van" else 0.82, L + 0.02, 0.26, 0.12, 0.04, "tail")
	# rodas com calota
	for sx in (-0.88, 0.88):
		for sz in (-wz, wz):
			cyl(bm, sx, 0.36, sz, 0.36, 0.24, "tire", "tire", 12)
			cyl(bm, sx * 1.02, 0.36, sz, 0.20, 0.25, "chrome", "chrome", 10)
	# assoalho escuro (não ver o céu por baixo)
	box(bm, 0, 0.30, 0, 1.7, 0.04, L * 1.9, "under")
	if kind == "taxi":
		box(bm, 0, 1.62, 0.15, 0.6, 0.16, 0.28, "yellow")
		box(bm, 0, 1.62, 0.15, 0.5, 0.1, 0.3, "head")
		# faixa xadrez na lateral
		for k in range(12):
			c = "black" if k % 2 == 0 else "white"
			for sx in (-1, 1):
				box(bm, sx * 0.965, 0.66, -1.3 + k * 0.22, 0.02, 0.1, 0.22, c)
	return bm


def to_object(bm, name, img):
	mesh = bpy.data.meshes.new(name)
	lay = bm.faces.layers.int.get("col")
	uvl = bm.loops.layers.uv.new("UVMap")
	for f in bm.faces:
		u, v = cell_uv(NAMES[f[lay]])
		for lp in f.loops:
			lp[uvl].uv = (u, v)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	bm.to_mesh(mesh)
	bm.free()
	ob = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(ob)
	paint = material("car_paint", img)
	head = material("car_light_head", img, (1.0, 0.92, 0.7))
	tail = material("car_light_tail", img, (1.0, 0.1, 0.12))
	mesh.materials.append(paint)
	mesh.materials.append(head)
	mesh.materials.append(tail)
	# faces de luz recebem os materiais emissivos (pela cor da célula)
	hu = cell_uv("head")
	tu = cell_uv("tail")
	uv = mesh.uv_layers.active.data
	for poly in mesh.polygons:
		c = uv[poly.loop_indices[0]].uv
		if abs(c[0] - hu[0]) < 1e-4 and abs(c[1] - hu[1]) < 1e-4:
			poly.material_index = 1
		elif abs(c[0] - tu[0]) < 1e-4 and abs(c[1] - tu[1]) < 1e-4:
			poly.material_index = 2
	for p in mesh.polygons:
		p.use_smooth = False
	return ob


def export(ob, name):
	bpy.ops.object.select_all(action="DESELECT")
	ob.select_set(True)
	bpy.context.view_layer.objects.active = ob
	path = os.path.join(OUT, name + ".glb")
	bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format="GLB", export_apply=True,
		export_image_format="AUTO", export_yup=False)
	tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
	print("CARRO", name, "tris", tris, "kb", os.path.getsize(path) // 1024)


bpy.ops.wm.read_factory_settings(use_empty=True)
img = build_palette()
VARIANTS = [("sedan", "maroon"), ("sedan", "teal"), ("sedan", "cream"), ("taxi", "yellow"),
	("coupe", "black"), ("coupe", "crimson"), ("van", "grey"), ("van", "navy")]
for kind, paint in VARIANTS:
	name = "car_%s_%s" % (kind, paint)
	ob = to_object(make_car(kind, paint), name, img)
	export(ob, name)
	bpy.data.objects.remove(ob)
print("FIM")
