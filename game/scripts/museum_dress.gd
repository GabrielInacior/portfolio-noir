extends RefCounted
## Ambientação das lojas-museu: identidade de cada sala (materiais, luz), mobília LOTADA com
## história do dono, e sinalização de SKILLS em tudo (livros com títulos de tecnologias, pôsteres
## de stack, adesivos em racks e laptops, quadro branco com arquitetura, neons com nomes de
## tecnologias, telas com código, chuva Matrix e painéis de métricas). Também registra os objetos
## acionáveis (telefone, máquina de escrever, gaveta, interruptor, fliperamas jogáveis, telões).
##
## Coordenadas: sala W x D centrada na origem, porta no meio da parede +z, fundo em -z.

const MATRIX := preload("res://shaders/matrix_rain.gdshader")
const CODE := preload("res://shaders/code_scroll.gdshader")
const LED := preload("res://shaders/led_panel.gdshader")
const CHART := preload("res://shaders/chart_screen.gdshader")
const ATTRACT := preload("res://shaders/arcade_attract.gdshader")

## Visual de cada estilo de sala: parede, piso, tons e luz.
const LOOKS := {
	"detetive": {"wall": "papel_parede", "wall_tint": "#3e3a52", "floor": "madeira", "floor_tint": "#5a3c28", "ceil": "#221a16",
		"wainscot": true, "wainscot_tint": "#4a2e1e", "warm": "#ffb35a", "light_e": 2.6, "ambient": "#2c2420", "fog": "#1a1410", "exposure": 1.45},
	"cyber": {"wall": "metal", "wall_tint": "#3a4844", "wall_scale": 0.8, "floor": "ladrilho", "floor_tint": "#1c2422", "ceil": "#101414",
		"warm": "#bfffd8", "light_e": 1.8, "ambient": "#1e3a2c", "ambient_e": 1.9, "fog": "#06140e", "exposure": 1.50, "trim": "#0a0f0d"},
	"arcade": {"wall": "tijolo", "wall_tint": "#3a2a52", "floor": "azulejo", "floor_tint": "#3a3a5a", "floor_scale": 0.9, "ceil": "#16101e",
		"warm": "#ff9a6a", "light_e": 2.4, "ambient": "#24183a", "fog": "#120a1e", "exposure": 1.50},
	"bar": {"wall": "tijolo", "wall_tint": "#6a3036", "floor": "madeira", "floor_tint": "#3e2418", "ceil": "#1a1012",
		"wainscot": true, "wainscot_tint": "#2a1610", "warm": "#ff8ab8", "light_e": 2.5, "ambient": "#2a1420", "fog": "#180a12", "exposure": 1.50},
	"studio": {"wall": "acustico", "wall_tint": "#2e3646", "wall_scale": 1.4, "floor": "concreto", "floor_tint": "#3a3e48", "ceil": "#14161c",
		"warm": "#a8d8ff", "light_e": 2.5, "ambient": "#18202c", "fog": "#0c1018", "exposure": 1.50},
	"study": {"wall": "papel_parede", "wall_tint": "#3a4a3e", "floor": "madeira", "floor_tint": "#6a4a30", "ceil": "#1c1a16",
		"wainscot": true, "wainscot_tint": "#3a2a1c", "warm": "#ffd08a", "light_e": 2.7, "ambient": "#262420", "fog": "#14120e", "exposure": 1.45},
	"startup": {"wall": "concreto", "wall_tint": "#5a5e6c", "floor": "madeira", "floor_tint": "#7a5a3e", "ceil": "#22242c",
		"warm": "#ffe2b8", "light_e": 2.8, "ambient": "#2a2c38", "fog": "#12141c", "exposure": 1.45},
	"lab": {"wall": "concreto", "wall_tint": "#454a62", "floor": "ladrilho", "floor_tint": "#262a36", "ceil": "#14161e",
		"warm": "#d8e8ff", "light_e": 2.6, "ambient": "#2c3048", "fog": "#0c0e18", "exposure": 1.50},
	"career": {"wall": "concreto", "wall_tint": "#3a3e50", "floor": "carpete", "floor_tint": "#3a3046", "ceil": "#16161e",
		"warm": "#ffe0b0", "light_e": 2.7, "ambient": "#34344a", "fog": "#0e0e16", "exposure": 1.45},
}


static func style_of(id: String, room: String) -> String:
	match id:
		"rumor": return "detetive"
		"inaciocyber": return "cyber"
		"fortress": return "arcade"
		"labia": return "bar"
		"formataai": return "studio"
		"ankiana": return "study"
		"_lab": return "lab"
		"_carreira": return "career"
	return {"fliperama": "arcade", "bar": "bar", "estudio": "studio", "lab": "lab"}.get(room, "startup")


## estilos cuja parede do fundo é um cenário próprio (itens vão para as laterais)
static func back_reserved(style: String) -> bool:
	return style in ["cyber", "arcade", "bar", "lab", "career"]


static func extra_slot(m) -> Dictionary:
	return {"pos": Vector3(-2.5, 1.8, m.D / 2 - 0.22), "normal": Vector3(0, 0, -1), "yaw": PI}


static func pedestal_spots(m, style: String) -> Array:
	match style:
		"cyber": return [Vector3(-1.6, 0, 2.4), Vector3(1.6, 0, 2.4)]
		"arcade": return [Vector3(-1.7, 0, 2.6), Vector3(1.7, 0, 2.6)]
		"bar": return [Vector3(2.2, 0, 2.6)]
		"lab": return [Vector3(-1.6, 0, 2.6), Vector3(1.6, 0, 2.6)]
		"career": return []
	return [Vector3(-1.5, 0, 1.6), Vector3(1.5, 0, 1.6), Vector3(-1.5, 0, -0.3)]


# ═════════════════════════════════════════════ entrada
static func dress(m, style: String) -> void:
	var stack: Array = m.project.get("stack", [])
	match style:
		"detetive": _detetive(m, stack)
		"cyber": _cyber(m, stack)
		"arcade": _arcade(m, stack)
		"bar": _bar(m, stack)
		"studio": _studio(m, stack, false)
		"study": _studio(m, stack, true)
		"lab": _lab(m)
		"career": _career(m)
		_: _startup(m, stack)
	_common(m, style)


# ═════════════════════════════════════════════ peças reutilizáveis
static func label3d(m, text: String, pos: Vector3, yaw: float, size: int, col: Color, font := "title", parent: Node = null, px := 0.0035) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UI.font(font)
	l.font_size = size
	l.pixel_size = px
	l.modulate = col
	l.position = pos
	l.rotation.y = yaw
	l.shaded = false
	l.double_sided = false
	l.outline_size = 0
	(parent if parent else m).add_child(l)
	return l


## letreiro de neon com o nome de uma tecnologia (brilha no PC com glow; halo aditivo atrás)
static func neon(m, text: String, pos: Vector3, yaw: float, col: Color, size := 90) -> Label3D:
	text = L.t(text)
	var l := label3d(m, text, pos, yaw, size, col * 2.2, "title", null, 0.0032)
	var halo := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(maxf(0.6, text.length() * size * 0.0032 * 0.55), size * 0.0032 * 1.6)
	halo.mesh = q
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.albedo_color = Color(col, 0.18)
	halo.material_override = hm
	halo.position = pos + Vector3(sin(yaw), 0, cos(yaw)) * -0.02
	halo.rotation.y = yaw
	m.add_child(halo)
	return l


static func screen(m, pos: Vector3, yaw: float, size: Vector2, shader: Shader, params := {}, parent: Node = null) -> MeshInstance3D:
	var p: Node = parent if parent else m
	var bez: MeshInstance3D = m.box(pos - Vector3(sin(yaw), 0, cos(yaw)) * 0.03, Vector3(size.x + 0.08, size.y + 0.08, 0.05), m.flat(Color("#07080c")), p)
	bez.rotation.y = yaw
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var sm := ShaderMaterial.new()
	sm.shader = shader
	for k in params:
		sm.set_shader_parameter(k, params[k])
	mi.material_override = sm
	mi.position = pos
	mi.rotation.y = yaw
	p.add_child(mi)
	return mi


## estante com livros cujas lombadas são as tecnologias (cada livro um nome)
static func tech_shelf(m, pos: Vector3, yaw: float, techs: Array, width := 1.6, height := 2.0) -> Node3D:
	var h := Node3D.new()
	h.position = pos
	h.rotation.y = yaw
	m.add_child(h)
	var wood: Material = m.painted("madeira", Color("#4a3020"), 1.2)
	m.box(Vector3(0, height / 2, -0.17), Vector3(width, height, 0.04), m.flat(Color("#1c120c")), h)
	for sx in [-width / 2, width / 2]:
		m.box(Vector3(sx, height / 2, 0), Vector3(0.05, height, 0.36), wood, h)
	var shelves := 4
	var cols := [Color("#7a2a2a"), Color("#2a4a7a"), Color("#2a6a4a"), Color("#7a6a2a"), Color("#4a2a6a"), Color("#1e1e2a"), Color("#8a4a1a")]
	var k := 0
	for s in shelves:
		var y := 0.05 + s * (height / shelves)
		m.box(Vector3(0, y, 0), Vector3(width, 0.04, 0.36), wood, h)
		var x := -width / 2 + 0.06
		while x < width / 2 - 0.12:
			var t: String = str(techs[k % techs.size()]) if not techs.is_empty() else ""
			var bw := 0.07 + (t.length() % 4) * 0.012
			var bh := height / shelves - 0.12 - (k % 3) * 0.03
			var c: Color = cols[k % cols.size()]
			var tilt := 0.0 if k % 9 != 4 else 0.18
			var b: MeshInstance3D = m.box(Vector3(x + bw / 2, y + 0.02 + bh / 2, 0.02), Vector3(bw, bh, 0.24), m.flat(c), h, Vector3(0, 0, tilt))
			if t != "" and k % 2 == 0:
				var l := label3d(m, t.to_upper(), Vector3(0, 0, 0.125), 0, 26, Color("#f1e6c8"), "bold", b, 0.0018)
				l.rotation.z = PI / 2
			x += bw + 0.008
			k += 1
	return h


## pôster/placa de stack: placa escura com cabeçalho e lista de tecnologias
static func stack_poster(m, pos: Vector3, yaw: float, title: String, lines: Array, col: Color, w := 0.9, hgt := 1.2) -> Node3D:
	var h := Node3D.new()
	h.position = pos
	h.rotation.y = yaw
	m.add_child(h)
	m.box(Vector3(0, 0, -0.02), Vector3(w + 0.06, hgt + 0.06, 0.03), m.flat(col, 1.6), h)
	m.box(Vector3(0, 0, 0), Vector3(w, hgt, 0.03), m.flat(Color("#0d0f18")), h)
	label3d(m, title.to_upper(), Vector3(0, hgt / 2 - 0.12, 0.02), 0, 46, col * 1.8, "title", h, 0.0028)
	var y := hgt / 2 - 0.3
	for ln in lines.slice(0, 8):
		label3d(m, "▸ " + str(ln), Vector3(-w / 2 + 0.08, y, 0.02), 0, 30, Color("#e8ecf8"), "type", h, 0.0024).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		y -= 0.12
	return h


## adesivos de tecnologias (placas pequenas coloridas) sobre uma superfície
static func stickers(m, parent: Node3D, origin: Vector3, techs: Array, cols := 3, step := Vector2(0.16, 0.08)) -> void:
	var pal := [Color("#ff4fa3"), Color("#4e9bff"), Color("#5fd38a"), Color("#ffc83d"), Color("#b06bff"), Color("#ff7a3d")]
	for i in techs.size():
		var p := origin + Vector3((i % cols) * step.x, -(i / cols) * step.y, 0)
		var c: Color = pal[i % pal.size()]
		var s: MeshInstance3D = m.box(p, Vector3(step.x - 0.02, step.y - 0.015, 0.004), m.flat(c, 0.6), parent, Vector3(0, 0, ((i * 37) % 11 - 5) * 0.02))
		label3d(m, str(techs[i]).to_upper(), Vector3(0, 0, 0.004), 0, 20, Color("#0a0c14"), "bold", s, 0.0014)


## quadro branco com diagrama de arquitetura: caixas com nomes e setas entre elas
static func whiteboard(m, pos: Vector3, yaw: float, title: String, nodes: Array, edges: Array) -> Node3D:
	var h := Node3D.new()
	h.position = pos
	h.rotation.y = yaw
	m.add_child(h)
	m.box(Vector3(0, 0, -0.02), Vector3(1.9, 1.15, 0.04), m.flat(Color("#9aa0ac")), h)
	m.box(Vector3(0, 0, 0), Vector3(1.82, 1.07, 0.03), m.flat(Color("#e9ecef")), h)
	m.box(Vector3(0, -0.58, 0.05), Vector3(1.6, 0.03, 0.08), m.flat(Color("#6a707c")), h)
	label3d(m, title, Vector3(-0.82, 0.44, 0.02), 0, 34, Color("#1a2a6a"), "marker", h, 0.0024).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var pens := [Color("#1a3a9a"), Color("#c0262e"), Color("#1a7a3a"), Color("#222222")]
	for i in nodes.size():
		var n: Array = nodes[i]
		var p := Vector3(float(n[1]), float(n[2]), 0.02)
		var c: Color = pens[i % pens.size()]
		for e in [[Vector3(0, 0.07, 0), Vector3(0.36, 0.008, 0.002)], [Vector3(0, -0.07, 0), Vector3(0.36, 0.008, 0.002)],
				[Vector3(-0.18, 0, 0), Vector3(0.008, 0.14, 0.002)], [Vector3(0.18, 0, 0), Vector3(0.008, 0.14, 0.002)]]:
			m.box(p + e[0], e[1], m.flat(c), h)
		label3d(m, str(n[0]), p + Vector3(0, 0, 0.003), 0, 24, c, "marker", h, 0.0019)
	for e in edges:
		var a: Array = nodes[int(e[0])]
		var b: Array = nodes[int(e[1])]
		var pa := Vector3(float(a[1]), float(a[2]), 0.021)
		var pb := Vector3(float(b[1]), float(b[2]), 0.021)
		var mid := (pa + pb) / 2
		var d := pb - pa
		var ln: MeshInstance3D = m.box(mid, Vector3(maxf(d.length() - 0.38, 0.05), 0.007, 0.002), m.flat(Color("#333344")), h)
		ln.rotation.z = atan2(d.y, d.x)
	return h


## post-its na parede (cores) com palavras
static func postits(m, pos: Vector3, yaw: float, words: Array, cols := 4) -> void:
	var pal := [Color("#ffe86a"), Color("#ff9ad0"), Color("#9ae8ff"), Color("#b8ff9a"), Color("#ffb86a")]
	var h := Node3D.new()
	h.position = pos
	h.rotation.y = yaw
	m.add_child(h)
	for i in words.size():
		var p := Vector3((i % cols) * 0.2 - (cols - 1) * 0.1, -(i / cols) * 0.2, 0)
		var s: MeshInstance3D = m.box(p, Vector3(0.16, 0.16, 0.004), m.flat(pal[i % pal.size()]), h, Vector3(0, 0, ((i * 13) % 7 - 3) * 0.04))
		var l := label3d(m, str(words[i]), Vector3(0, 0, 0.004), 0, 22, Color("#222233"), "marker", s, 0.0016)
		l.width = 90
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


static func cable(m, a: Vector3, b: Vector3, col := Color("#101216"), r := 0.018) -> void:
	var mid := (a + b) / 2
	var d := b - a
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = d.length()
	cm.radial_segments = 5
	mi.mesh = cm
	mi.material_override = m.flat(col)
	mi.position = mid
	m.add_child(mi)
	mi.look_at_from_position(mid, b, Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT)
	mi.rotate_object_local(Vector3.RIGHT, PI / 2)


static func window_blinds(m, pos: Vector3, yaw: float, col: Color) -> void:
	# janela com persiana: frestas de luz âmbar (neon da rua) e faixas de luz no chão
	var h := Node3D.new()
	h.position = pos
	h.rotation.y = yaw
	m.add_child(h)
	m.box(Vector3(0, 0, -0.02), Vector3(1.5, 1.4, 0.05), m.flat(Color("#120e0c")), h)
	m.box(Vector3(0, 0, -0.04), Vector3(1.36, 1.26, 0.02), m.flat(col, 2.4), h)
	for i in 12:
		m.box(Vector3(0, -0.6 + i * 0.105, 0.01), Vector3(1.38, 0.06, 0.02), m.flat(Color("#2a1e14")), h, Vector3(0.5, 0, 0))
	# faixas de luz projetadas no chão
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.albedo_color = Color(col, 0.16)
	for i in 6:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(1.3, 0.12)
		q.mesh = qm
		q.material_override = fm
		q.rotation.x = -PI / 2
		q.position = Vector3(0, -pos.y + 0.02, 0.8 + i * 0.24)
		h.add_child(q)
	var l := OmniLight3D.new()
	l.position = Vector3(0, 0, 0.6)
	l.light_color = col
	l.light_energy = 1.2
	l.omni_range = 3.5
	h.add_child(l)


static func ceiling_fan(m, pos: Vector3) -> void:
	var h := Node3D.new()
	h.position = pos
	m.add_child(h)
	m.box(Vector3(0, 0.2, 0), Vector3(0.04, 0.4, 0.04), m.flat(Color("#2a2420")), h)
	var rot := Node3D.new()
	h.add_child(rot)
	m.box(Vector3(0, 0, 0), Vector3(0.18, 0.08, 0.18), m.flat(Color("#3a3028")), rot)
	for i in 4:
		var b: MeshInstance3D = m.box(Vector3(0.42, 0, 0), Vector3(0.7, 0.015, 0.12), m.flat(Color("#4a3624")), rot)
		var pivot := Node3D.new()
		rot.add_child(pivot)
		rot.remove_child(b)
		pivot.add_child(b)
		pivot.rotation.y = i * PI / 2
	m.tickers.append(func(dt: float, _t: float) -> void: rot.rotate_y(dt * 2.4))


static func trash_bin(m, pos: Vector3) -> void:
	m.box(pos + Vector3(0, 0.2, 0), Vector3(0.32, 0.4, 0.32), m.flat(Color("#3a3e46")))
	for i in 5:
		var p := pos + Vector3(((i * 7) % 5 - 2) * 0.05, 0.42 + (i % 2) * 0.04, ((i * 3) % 5 - 2) * 0.05)
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.06
		sm.height = 0.1
		sm.radial_segments = 6
		sm.rings = 3
		s.mesh = sm
		s.material_override = m.flat(Color("#e8e2d0"))
		s.position = p
		m.add_child(s)


static func desk(m, pos: Vector3, yaw: float, w := 1.5, dpt := 0.7, col := Color("#3a2a20")) -> Node3D:
	var h := Node3D.new()
	h.position = pos
	h.rotation.y = yaw
	m.add_child(h)
	m.box(Vector3(0, 0.74, 0), Vector3(w, 0.05, dpt), m.painted("madeira", col, 1.6), h)
	for x in [-w / 2 + 0.05, w / 2 - 0.05]:
		for z in [-dpt / 2 + 0.05, dpt / 2 - 0.05]:
			m.box(Vector3(x, 0.37, z), Vector3(0.05, 0.74, 0.05), m.flat(Color("#1a1410")), h)
	return h


static func code_monitor(m, parent: Node3D, pos: Vector3, seed: float, shader: Shader = null, params := {}) -> MeshInstance3D:
	m.box(pos + Vector3(0, -0.2, 0), Vector3(0.06, 0.18, 0.06), m.flat(Color("#141418")), parent)
	m.box(pos + Vector3(0, -0.29, 0), Vector3(0.22, 0.02, 0.16), m.flat(Color("#141418")), parent)
	var p := params.duplicate()
	p["seed"] = seed
	return screen(m, pos, 0.0, Vector2(0.56, 0.34), shader if shader else CODE, p, parent)


static func laptop(m, parent: Node3D, pos: Vector3, techs: Array, seed: float) -> void:
	m.box(pos, Vector3(0.36, 0.015, 0.25), m.flat(Color("#9aa0ac")), parent)
	var lid := Node3D.new()
	lid.position = pos + Vector3(0, 0.0, -0.12)
	lid.rotation.x = -0.25
	parent.add_child(lid)
	m.box(Vector3(0, 0.12, 0), Vector3(0.36, 0.24, 0.012), m.flat(Color("#8a909c")), lid)
	screen(m, Vector3(0, 0.12, 0.008), 0, Vector2(0.32, 0.2), CODE, {"seed": seed, "lines": 16.0}, lid)
	# adesivos na tampa (lado de fora, virado para trás)
	var back := Node3D.new()
	back.position = Vector3(-0.1, 0.18, -0.008)
	back.rotation.y = PI
	lid.add_child(back)
	stickers(m, back, Vector3.ZERO, techs.slice(0, 4), 2, Vector2(0.11, 0.05))


## objeto acionável simples: registra entrada com painel/ação
static func act(m, node: Node3D, look: Vector3, it: Dictionary) -> Dictionary:
	return m.add_entry(node, it, look)


# ═════════════════════════════════════════════ escritório de detetive (RUMOR)
static func _detetive(m, stack: Array) -> void:
	var D: float = m.D
	var W: float = m.W
	var dz := -D / 2 + 1.35
	m.prop("mesa_detetive", Vector3(0, 0, dz), 0.0, 1.05)
	var tw: Node3D = m.prop("maquina_escrever", Vector3(0.22, 0.86, dz + 0.05), 0.12)
	m.prop("abajur_banqueiro", Vector3(-0.7, 0.86, dz - 0.2), 0.4)
	var ph: Node3D = m.prop("telefone_antigo", Vector3(0.82, 0.86, dz - 0.18), -0.4)
	m.prop("pilha_papeis", Vector3(-0.32, 0.86, dz + 0.18), 0.3)
	m.prop("sd_pastas", Vector3(-0.95, 0.86, dz + 0.15), 0.3)
	m.prop("sd_cinzeiro", Vector3(0.9, 0.86, dz + 0.2))
	m.prop("caneca", Vector3(0.58, 0.86, dz + 0.24))
	m.prop("cadeira_escritorio", Vector3(0, 0, dz - 0.85))
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(-0.7, 1.25, dz - 0.2)
	lamp.light_color = Color("#ffcf7a")
	lamp.light_energy = 2.2
	lamp.omni_range = 3.2
	m.add_child(lamp)
	# arquivos de aço com gaveta que abre
	var arq: Node3D = m.prop("arquivo_aco", Vector3(-W / 2 + 0.4, 0, -D / 2 + 0.6), PI / 2)
	m.prop("arquivo_aco", Vector3(-W / 2 + 0.4, 0, -D / 2 + 1.3), PI / 2)
	m.prop("sd_caixa_arquivo", Vector3(-W / 2 + 0.45, 1.32, -D / 2 + 0.6), 0.2)
	# persiana com luz âmbar (parede esquerda)
	window_blinds(m, Vector3(-W / 2 + 0.12, 1.75, -0.4), PI / 2, Color("#ffb04a"))
	# estante de livros com títulos das tecnologias (parede direita)
	tech_shelf(m, Vector3(W / 2 - 0.25, 0, -0.4), -PI / 2, stack + ["Design de jogo", "Shaders", "Multiplayer", "Mixamo", "Node.js", "Godot"])
	# frente: cabideiro com sobretudo, quadro de cortiça, sofá, guarda-chuva
	m.prop("cabideiro", Vector3(-1.5, 0, D / 2 - 0.5))
	m.box(Vector3(-1.5, 1.35, D / 2 - 0.42), Vector3(0.42, 0.9, 0.14), m.flat(Color("#6a5236")))
	m.prop("quadro_cortica", Vector3(-2.6, 1.0, D / 2 - 0.2), PI)
	m.prop("sofa_couro", Vector3(2.5, 0, D / 2 - 0.65), PI)
	m.prop("sd_pizza", Vector3(2.4, 0.44, D / 2 - 0.7), 0.4)
	m.prop("sd_guarda_chuva", Vector3(-0.95, 0, D / 2 - 0.35), 0.3)
	trash_bin(m, Vector3(1.0, 0, dz + 0.1))
	m.prop("sd_papeis", Vector3(0.9, 0, dz + 0.9), 0.7)
	m.prop("sd_papeis", Vector3(-1.2, 0, 0.6), 2.0)
	m.prop("pilha_livros", Vector3(W / 2 - 0.4, 0, 1.0))
	m.prop("planta_vaso", Vector3(W / 2 - 0.4, 0, -D / 2 + 0.5))
	# tapete persa sob a mesa
	var rug := MeshInstance3D.new()
	var rq := QuadMesh.new()
	rq.size = Vector2(2.6, 1.9)
	rug.mesh = rq
	var rm := StandardMaterial3D.new()
	rm.albedo_texture = load("res://assets/tex/carpete.png")
	rm.albedo_color = Color("#7a2a26")
	rm.uv1_scale = Vector3(2, 1.5, 1)
	rug.material_override = rm
	rug.rotation.x = -PI / 2
	rug.position = Vector3(0, 0.012, dz - 0.2)
	m.add_child(rug)
	ceiling_fan(m, Vector3(0, m.H - 0.45, 0.4))
	neon(m, "DETETIVE PARTICULAR", Vector3(-W / 2 + 0.14, 2.75, -0.4), PI / 2, Color("#ff4f6a"), 64)
	neon(m, "GODOT · NODE · WEBSOCKET", Vector3(W / 2 - 0.14, 2.65, -0.4), -PI / 2, Color("#ffc83d"), 50)
	# ações: telefone toca, máquina digita, gaveta abre
	if ph:
		var ring := {"on": true}
		m.tickers.append(func(_dt: float, t: float) -> void:
			if ring["on"] and fmod(t, 4.0) < 1.2:
				ph.rotation.z = sin(t * 60.0) * 0.06
			else:
				ph.rotation.z = 0.0)
		var e := act(m, ph, ph.global_position + Vector3(0, 0.25, 0), {"title": "Telefone tocando", "action": "phone", "panel": "doc", "verb": "ATENDER",
			"doc_style": "phone", "text": "Alô, detetive? Aqui é o Prof. Ailson. A turma inteira jogou o RUMOR no celular hoje. Doze casos escritos à mão, servidor autoritativo em Node com WebSocket, e ninguém travou. Como você fez isso rodar em qualquer celular?"})
		e["ring"] = ring
	if tw:
		act(m, tw, tw.global_position + Vector3(0, 0.3, 0), {"title": "Máquina de escrever", "action": "typewriter", "panel": "doc", "verb": "DATILOGRAFAR",
			"doc_style": "typewriter", "text": "GABRIEL INÁCIO\nengenharia de software · games · IA\n\nCaso RUMOR: jogo de detetive multiplayer para a sala de aula. Godot no cliente, Node no servidor, 12 casos escritos à mão, 192 pistas com imagem."})
	if arq:
		var drawer: MeshInstance3D = m.box(Vector3(0, 0.95, 0.24), Vector3(0.42, 0.26, 0.04), m.flat(Color("#6a7480")), arq)
		act(m, arq, arq.global_position + Vector3(0.4, 1.0, 0), {"title": "Arquivo de casos", "action": "drawer", "panel": "doc", "verb": "ABRIR",
			"doc_style": "file", "drawer": drawer, "text": "FICHA DO CASO\n\nCliente: escolas e professores\nProblema: ensinar raciocínio e trabalho em equipe\nSolução: casos de detetive jogados no celular, com quadro compartilhado de pistas\nTecnologias: Godot 4, GDScript, Node.js, WebSocket, Blender, Mixamo\nStatus: no ar em rumor.inaciodev.online"})
	_switch(m, Vector3(1.05, 1.25, D / 2 - 0.12))


# ═════════════════════════════════════════════ sala de servidores (InacioCyber)
static func _cyber(m, stack: Array) -> void:
	var D: float = m.D
	var W: float = m.W
	var techs := ["Python", "Ollama", "Docker", "Postgres", "Electron", "WebSocket", "Linux", "Pentest", "LLM local", "Nmap"]
	# parede do fundo: 6 telas com os temas reais + 2 telas Matrix nas pontas
	var names := ["tema_vermelho", "tema_verde", "tema_azul", "tema_roxo", "tema_amarelo", "temas_modal"]
	for i in names.size():
		var path := "res://assets/museum/inaciocyber/%s.jpg" % names[i]
		var pos := Vector3(-1.4 + (i % 3) * 1.4, 2.05 + (1 - i / 3) * 0.78, -D / 2 + 0.16)
		m.box(pos + Vector3(0, 0, -0.03), Vector3(1.32, 0.74, 0.05), m.flat(Color("#06080a")))
		if ResourceLoader.exists(path):
			var q := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(1.26, 0.56)
			q.mesh = qm
			var mm := StandardMaterial3D.new()
			mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mm.albedo_texture = load(path)
			mm.albedo_color = Color(1.5, 1.5, 1.5)
			q.material_override = mm
			q.position = pos
			m.add_child(q)
	for sx in [-2.75, 2.75]:
		screen(m, Vector3(sx, 2.4, -D / 2 + 0.16), 0, Vector2(1.0, 1.4), MATRIX, {"seed": sx, "tint": Color("#39ff6a")})
	# mesa com 3 monitores de código e cadeira gamer
	var dz := -D / 2 + 1.1
	m.prop("mesa_monitores", Vector3(0, 0, dz), 0.0, 1.1)
	m.prop("cadeira_gamer", Vector3(0, 0, dz + 1.0), PI)
	var mon := Node3D.new()
	mon.position = Vector3(0, 1.2, dz - 0.05)
	m.add_child(mon)
	for i in 3:
		var mm2: MeshInstance3D = code_monitor(m, mon, Vector3(-0.62 + i * 0.62, 0, 0), float(i) * 3.3, MATRIX if i == 1 else CODE,
			{"tint": Color("#39ff6a")} if i == 1 else {"c1": Color("#39ff6a"), "c2": Color("#2b9e4a"), "c3": Color("#bfffd0"), "c4": Color("#ff3d5a")})
		mm2.rotation.y = (1 - i) * 0.25
	act(m, mon, mon.global_position + Vector3(0, 0, 0.6), {"title": "Terminal do agente", "panel": "terminal", "verb": "ACESSAR",
		"repo": "inaciocyber", "text": "README e atividade do repositório"})
	# racks lotados nas laterais, com LEDs piscando e adesivos de tecnologias
	var rack_z := [-D / 2 + 0.5, -0.4, 0.3, D / 2 - 1.5, D / 2 - 0.85]
	var k := 0
	for side in [-1, 1]:
		for z in rack_z:
			if side == 1 and z > D / 2 - 1.6:
				continue
			var rx: float = side * (W / 2 - 0.4)
			var r := Node3D.new()
			r.position = Vector3(rx, 0, z)
			r.rotation.y = -side * PI / 2
			m.add_child(r)
			m.box(Vector3(0, 1.0, 0), Vector3(0.6, 2.0, 0.7), m.flat(Color("#0c0f12")), r)
			screen(m, Vector3(0, 1.02, 0.36), 0, Vector2(0.5, 1.8), LED, {"seed": float(k) * 1.7, "units": 18.0}, r)
			var st := Node3D.new()
			st.position = Vector3(-0.26, 1.95, 0.36)
			r.add_child(st)
			stickers(m, st, Vector3.ZERO, [techs[k % techs.size()], techs[(k + 3) % techs.size()]], 2, Vector2(0.18, 0.06))
			k += 1
	# ilha central baixa: switches e roteador, cabos para todo lado
	m.prop("roteador", Vector3(1.4, 0.0, 0.0), 0.4)
	m.prop("servidor_ia", Vector3(-1.5, 0, -0.1), 0.3, 0.9)
	for i in 10:
		var a := Vector3(-W / 2 + 0.7, 0.03, -2.0 + i * 0.4)
		cable(m, a, Vector3(0.0 + (i % 3 - 1) * 0.15, 0.03, dz + 0.4), Color("#0e1a14") if i % 2 else Color("#1a0e10"))
	# eletrocalha no teto com cabos pendurados
	m.box(Vector3(-W / 2 + 0.6, m.H - 0.25, 0), Vector3(0.3, 0.08, D - 0.6), m.flat(Color("#2a3034")))
	m.box(Vector3(W / 2 - 0.6, m.H - 0.25, 0), Vector3(0.3, 0.08, D - 0.6), m.flat(Color("#2a3034")))
	for i in 6:
		var z := -D / 2 + 1.0 + i * 1.3
		cable(m, Vector3(-W / 2 + 0.6, m.H - 0.28, z), Vector3(-W / 2 + 0.45, 2.02, z + 0.1), Color("#1a2a22"), 0.012)
		cable(m, Vector3(W / 2 - 0.6, m.H - 0.28, z), Vector3(W / 2 - 0.45, 2.02, z + 0.1), Color("#2a1a1e"), 0.012)
	# telas Matrix na parede da frente, latas e pizza (madrugada de trabalho)
	screen(m, Vector3(-2.4, 1.9, D / 2 - 0.13), PI, Vector2(1.4, 1.0), MATRIX, {"seed": 7.0, "tint": Color("#39ff6a")})
	screen(m, Vector3(2.4, 1.9, D / 2 - 0.13), PI, Vector2(1.4, 1.0), CODE, {"seed": 9.0, "c1": Color("#39ff6a"), "c2": Color("#2b9e4a"), "c3": Color("#bfffd0"), "c4": Color("#ff3d5a")})
	m.prop("sd_latas", Vector3(0.7, 0, dz + 0.9))
	m.prop("sd_pizza", Vector3(-0.8, 0.0, dz + 1.3), 0.9)
	m.prop("sd_cabos", Vector3(0.4, 0, 1.2), 0.4)
	m.prop("caixas_papelao", Vector3(W / 2 - 0.5, 0, D / 2 - 0.5), 0.3, 0.7)
	# luz: verde dos racks, giroflex vermelho no teto
	for side in [-1, 1]:
		m.light(Vector3(side * (W / 2 - 1.2), 1.2, 0), Color("#39ff6a"), 1.2, 3.5)
	var beacon: OmniLight3D = m.light(Vector3(0, m.H - 0.3, D / 2 - 1.2), Color("#ff2a3a"), 1.0, 5.0)
	m.box(Vector3(0, m.H - 0.12, D / 2 - 1.2), Vector3(0.14, 0.1, 0.14), m.flat(Color("#ff2a3a"), 3.0))
	m.tickers.append(func(_dt: float, t: float) -> void: beacon.light_energy = 0.4 + 1.2 * maxf(0.0, sin(t * 3.0)))
	neon(m, "ACESSO AUTORIZADO", Vector3(0, m.H - 0.32, -D / 2 + 0.16), 0, Color("#39ff6a"), 60)
	neon(m, "BLACKWALL", Vector3(-W / 2 + 0.14, 2.6, 1.3), PI / 2, Color("#ff2a3a"), 80)
	_switch(m, Vector3(1.05, 1.25, D / 2 - 0.12))


# ═════════════════════════════════════════════ fliperama (Fortress Chaos e game dev)
static func _arcade(m, stack: Array) -> void:
	var D: float = m.D
	var W: float = m.W
	var games := [["snake", "COBRA NEON", Color("#5fd38a")], ["fortress", "DEFENDA A FORTALEZA", Color("#ff7a3d")], ["breakout", "QUEBRA TIJOLO", Color("#4e9bff")]]
	for i in games.size():
		var g: Array = games[i]
		var cab := cabinet(m, Vector3(-2.2 + i * 2.2, 0, -D / 2 + 0.55), 0.0, g[1], g[2])
		act(m, cab, cab.global_position + Vector3(0, 1.4, 0.7), {"title": g[1], "panel": "arcade", "game": g[0], "verb": "JOGAR",
			"text": "Um minijogo feito em Godot, rodando aqui dentro."})
	# mesa de cartas com a miniatura da fortaleza
	m.prop("mesa_cartas", Vector3(0, 0, 0.2), 0.0, 1.0)
	m.prop("miniatura_fortaleza", Vector3(0, 0.82, 0.15), 0.4, 1.0)
	m.prop("banqueta_bar", Vector3(-1.0, 0, 0.2))
	m.prop("banqueta_bar", Vector3(1.0, 0, 0.2))
	m.prop("sd_copos", Vector3(0.45, 0.82, 0.45))
	m.prop("sd_pizza", Vector3(-0.45, 0.82, 0.0), 0.3)
	# fliperamas decorativos e troféus nos cantos
	m.prop("fliperama", Vector3(-W / 2 + 0.5, 0, D / 2 - 0.6), 3 * PI / 4, 0.95)
	m.prop("fliperama", Vector3(W / 2 - 0.5, 0, D / 2 - 0.6), -3 * PI / 4, 0.95)
	m.prop("trofeu", Vector3(-W / 2 + 0.45, 0, -0.4), PI / 2, 1.6)
	tech_shelf(m, Vector3(W / 2 - 0.25, 0, -0.4), -PI / 2, stack + ["Tower defense", "Roguelite", "Pixel art", "Shaders", "Steam", "Android"], 1.4)
	stack_poster(m, Vector3(-W / 2 + 0.13, 2.0, -0.4), PI / 2, "Feito com", ["Godot 4", "GDScript", "Blender", "Pixel art à mão", "Steam e Android", "9 idiomas"], Color("#ff7a3d"), 0.8, 1.1)
	m.prop("sd_latas", Vector3(-0.9, 0, 2.0))
	m.prop("sd_papeis", Vector3(1.2, 0, 1.4))
	trash_bin(m, Vector3(W / 2 - 0.5, 0, 1.4))
	neon(m, "INSERT COIN", Vector3(0, m.H - 0.3, -D / 2 + 0.16), 0, Color("#ff4fa3"), 70)
	neon(m, "GAME DEV", Vector3(-W / 2 + 0.14, 2.8, 2.2), PI / 2, Color("#4e9bff"), 70)
	for c in [Color("#ff4fa3"), Color("#4e9bff")]:
		m.light(Vector3(0 if c == Color("#ff4fa3") else 2.0, 2.2, -D / 2 + 1.4), c, 1.0, 4.0)
	_switch(m, Vector3(1.05, 1.25, D / 2 - 0.12))


## gabinete de fliperama (construído para a tela ser exata): corpo, tela com demonstração, letreiro
static func cabinet(m, pos: Vector3, yaw: float, title: String, col: Color) -> Node3D:
	var h := Node3D.new()
	h.position = pos
	h.rotation.y = yaw
	m.add_child(h)
	var body: Material = m.flat(Color("#1a1428"))
	m.box(Vector3(0, 0.55, 0), Vector3(0.78, 1.1, 0.7), body, h)
	m.box(Vector3(0, 1.45, -0.1), Vector3(0.78, 0.8, 0.5), body, h)
	m.box(Vector3(0, 1.98, -0.05), Vector3(0.78, 0.26, 0.6), body, h)
	for sx in [-0.4, 0.4]:
		m.box(Vector3(sx, 1.05, 0.0), Vector3(0.03, 2.1, 0.72), m.flat(col, 2.5), h)
	# painel de controle inclinado com alavanca e botões
	var cp: MeshInstance3D = m.box(Vector3(0, 1.12, 0.3), Vector3(0.76, 0.06, 0.32), m.flat(Color("#120e1c")), h, Vector3(0.35, 0, 0))
	m.box(Vector3(-0.18, 0.08, 0), Vector3(0.03, 0.12, 0.03), m.flat(Color("#222")), cp)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.07
	ball.mesh = sm
	ball.material_override = m.flat(Color("#e23a4a"))
	ball.position = Vector3(-0.18, 0.15, 0)
	cp.add_child(ball)
	for i in 3:
		m.box(Vector3(0.05 + i * 0.09, 0.04, 0.02), Vector3(0.05, 0.03, 0.05), m.flat([Color("#ffc83d"), Color("#4e9bff"), Color("#5fd38a")][i], 1.5), cp)
	var scr := screen(m, Vector3(0, 1.48, 0.16), 0, Vector2(0.62, 0.5), ATTRACT, {"c1": col, "c2": Color("#4e9bff")}, h)
	scr.rotation.x = -0.18
	var mq := label3d(m, title, Vector3(0, 1.98, 0.26), 0, 44, col * 2.0, "title", h, 0.0026)
	mq.width = 280
	mq.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var l := OmniLight3D.new()
	l.position = Vector3(0, 1.5, 0.8)
	l.light_color = col
	l.light_energy = 1.0
	l.omni_range = 2.4
	h.add_child(l)
	return h


# ═════════════════════════════════════════════ bar (Lábia)
static func _bar(m, stack: Array) -> void:
	var D: float = m.D
	var W: float = m.W
	# prateleiras de garrafas retroiluminadas no fundo + balcão + banquetas
	var bz := -D / 2 + 0.2
	m.box(Vector3(0, 1.8, bz), Vector3(W - 1.2, 1.9, 0.06), m.flat(Color("#ff4fa3"), 0.9))
	var bottle_cols := [Color("#5a2a1a"), Color("#2a5a2a"), Color("#c89a3a"), Color("#3a2a5a"), Color("#9a2a3a"), Color("#d8d0b8")]
	for s in 3:
		var y := 1.05 + s * 0.6
		m.box(Vector3(0, y, bz + 0.12), Vector3(W - 1.2, 0.04, 0.26), m.flat(Color("#1a0e0c")))
		for i in 18:
			var x := -W / 2 + 0.8 + i * ((W - 1.6) / 17.0)
			var c: Color = bottle_cols[(i * 7 + s * 3) % bottle_cols.size()]
			var hb := 0.28 + ((i + s) % 3) * 0.05
			m.box(Vector3(x, y + 0.02 + hb / 2, bz + 0.13), Vector3(0.08, hb, 0.08), m.flat(c))
	m.prop("balcao_bar", Vector3(0, 0, -D / 2 + 1.5), 0.0, 1.4)
	m.box(Vector3(0, 0.12, -D / 2 + 1.95), Vector3(3.6, 0.04, 0.05), m.flat(Color("#ff4fa3"), 3.0))
	for x in [-1.4, -0.45, 0.5, 1.45]:
		m.prop("banqueta_bar", Vector3(x, 0, -D / 2 + 2.3))
	m.prop("sd_copos", Vector3(-0.6, 1.08, -D / 2 + 1.4), 0.5)
	m.prop("sd_garrafas_vazias", Vector3(1.0, 1.08, -D / 2 + 1.45))
	m.prop("sd_cinzeiro", Vector3(0.2, 1.08, -D / 2 + 1.35))
	m.prop("garrafas", Vector3(1.6, 1.08, -D / 2 + 1.4), 1.0)
	# mesinhas com cadeiras, palco com microfone e holofote, jukebox
	for p in [Vector3(1.9, 0, 0.6), Vector3(1.9, 0, 2.4)]:
		m.box(p + Vector3(0, 0.38, 0), Vector3(0.06, 0.76, 0.06), m.flat(Color("#141010")))
		m.box(p + Vector3(0, 0.77, 0), Vector3(0.7, 0.04, 0.7), m.painted("madeira", Color("#3a2014"), 1.5))
		m.prop("banqueta_bar", p + Vector3(-0.6, 0, 0), 0.0, 0.8)
		m.prop("sd_copos", p + Vector3(0.1, 0.79, 0))
	m.prop("microfone_estudio", Vector3(-2.3, 0.2, 2.0), PI / 2)
	m.box(Vector3(-2.3, 0.1, 2.0), Vector3(2.0, 0.2, 2.2), m.painted("madeira", Color("#2a1410"), 1.2))
	var spot := SpotLight3D.new()
	spot.position = Vector3(-2.3, m.H - 0.2, 2.0)
	spot.rotation.x = -PI / 2
	spot.light_color = Color("#ff6fae")
	spot.light_energy = 3.0
	spot.spot_angle = 30
	m.add_child(spot)
	var jb := Node3D.new()
	jb.position = Vector3(W / 2 - 0.45, 0, -0.6)
	jb.rotation.y = -PI / 2
	m.add_child(jb)
	m.box(Vector3(0, 0.75, 0), Vector3(0.8, 1.5, 0.5), m.flat(Color("#3a1a2a")), jb)
	screen(m, Vector3(0, 1.0, 0.26), 0, Vector2(0.6, 0.5), CHART, {"accent": Color("#ff4fa3"), "accent2": Color("#ffc83d"), "seed": 3.0}, jb)
	stack_poster(m, Vector3(-W / 2 + 0.13, 2.0, -0.6), PI / 2, "Na mesa", stack + ["Reconhecimento de voz", "IA local"], Color("#ff4fa3"), 0.8, 1.0)
	m.prop("sd_latas", Vector3(1.2, 0, 1.4))
	m.prop("sd_garrafas_vazias", Vector3(-1.0, 0, 3.4), 2.0)
	trash_bin(m, Vector3(W / 2 - 0.5, 0, D / 2 - 0.6))
	neon(m, "LÁBIA", Vector3(0, m.H - 0.32, -D / 2 + 0.25), 0, Color("#ff4fa3"), 110)
	neon(m, "FALE PARA JOGAR", Vector3(-W / 2 + 0.14, 2.8, 2.0), PI / 2, Color("#5bd0ff"), 54)
	_switch(m, Vector3(1.05, 1.25, D / 2 - 0.12))


# ═════════════════════════════════════════════ estúdio de voz / sala de estudos
static func _studio(m, stack: Array, study: bool) -> void:
	var D: float = m.D
	var W: float = m.W
	var dz := -D / 2 + 1.2
	var d := desk(m, Vector3(0, 0, dz), 0.0, 2.2, 0.8, Color("#2a2a30") if not study else Color("#5a3a22"))
	if not study:
		m.prop("mesa_som", Vector3(0, 0.77, dz), 0.0, 0.9)
		for sx in [-0.95, 0.95]:
			m.box(Vector3(sx, 0.98, dz - 0.15), Vector3(0.2, 0.36, 0.22), m.flat(Color("#141418")))
			var cone := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.07
			cm.bottom_radius = 0.07
			cm.height = 0.02
			cone.mesh = cm
			cone.material_override = m.flat(Color("#3a3a44"))
			cone.position = Vector3(sx, 0.95, dz - 0.03)
			cone.rotation.x = PI / 2
			m.add_child(cone)
		var mon := Node3D.new()
		mon.position = Vector3(0, 1.22, dz - 0.25)
		m.add_child(mon)
		screen(m, Vector3.ZERO, 0, Vector2(1.1, 0.5), CHART, {"accent": Color("#5bd0ff"), "accent2": Color("#ff6fae"), "seed": 1.0}, mon)
		m.prop("microfone_estudio", Vector3(-1.5, 0, dz + 1.2), PI / 4)
		m.prop("cadeira_escritorio", Vector3(0, 0, dz + 0.8), PI)
		neon(m, "NO AR", Vector3(0, m.H - 0.35, -D / 2 + 0.16), 0, Color("#ff2a3a"), 90)
	else:
		m.prop("abajur_banqueiro", Vector3(-0.8, 0.77, dz - 0.15), 0.4)
		m.prop("pilha_livros", Vector3(0.7, 0.77, dz))
		m.prop("cadeira_escritorio", Vector3(0, 0, dz + 0.8), PI)
		laptop(m, d, Vector3(0, 0.78, 0.05), stack, 4.0)
		postits(m, Vector3(0, 2.4, -D / 2 + 0.13), 0, ["Repetição espaçada", "Flashcards", "IA gera cartões", "Material 3", "Flutter", "Dart", "OpenAI", "Estatísticas"], 4)
		neon(m, "ESTUDE MELHOR", Vector3(0, m.H - 0.3, -D / 2 + 0.16), 0, Color("#5fd38a"), 70)
	laptop(m, d, Vector3(0.75 if not study else -0.6, 0.78, 0.15), stack, 2.0)
	m.prop("caneca", Vector3(-0.5, 0.77, dz + 0.25))
	m.prop("sd_cabos", Vector3(0.4, 0.0, dz + 0.5), 0.9)
	tech_shelf(m, Vector3(W / 2 - 0.25, 0, -0.4), -PI / 2, stack + ["Whisper", "GPT-4", "Prompt design", "Push", "AWS S3", "Node.js"])
	stack_poster(m, Vector3(-W / 2 + 0.13, 2.0, -0.4), PI / 2, "Stack", stack, Color(m._accent), 0.8, 1.1)
	m.prop("sofa_couro", Vector3(2.5, 0, D / 2 - 0.65), PI)
	m.prop("planta_vaso", Vector3(-W / 2 + 0.4, 0, D / 2 - 0.5))
	m.prop("sd_copos", Vector3(2.3, 0.45, D / 2 - 0.7))
	trash_bin(m, Vector3(-1.2, 0, dz + 0.3))
	if not study:
		# espuma acústica extra em blocos nas laterais
		for i in 10:
			m.box(Vector3(-W / 2 + 0.13, 2.7 + (i % 2) * 0.4, -D / 2 + 0.8 + (i / 2) * 0.5), Vector3(0.08, 0.36, 0.44), m.flat(Color("#1e2232")))
	_switch(m, Vector3(1.05, 1.25, D / 2 - 0.12))


# ═════════════════════════════════════════════ startup (projetos de software)
static func _startup(m, stack: Array) -> void:
	var D: float = m.D
	var W: float = m.W
	var id := str(m.project.get("id", ""))
	# duas mesas com monitores de código e laptops com adesivos
	for i in 2:
		var x := -1.5 + i * 3.0
		var d := desk(m, Vector3(x, 0, -D / 2 + 1.15), 0.0, 1.5, 0.7, Color("#6a4a30"))
		var mon := Node3D.new()
		mon.position = Vector3(0, 1.08, -0.18)
		d.add_child(mon)
		code_monitor(m, mon, Vector3(-0.32, 0, 0), float(i) * 2.0 + 1.0)
		code_monitor(m, mon, Vector3(0.32, 0, 0), float(i) * 2.0 + 2.0, CHART, {"accent": Color(m._accent), "accent2": Color("#ffc83d")})
		laptop(m, d, Vector3(0.45, 0.77, 0.15), stack, float(i) + 5.0)
		m.prop("cadeira_escritorio", Vector3(x, 0, -D / 2 + 1.9), PI)
		m.prop("caneca", Vector3(x - 0.5, 0.77, -D / 2 + 1.3))
	# telão de métricas na parede da frente + quadro branco com a arquitetura do projeto
	screen(m, Vector3(2.4, 1.85, D / 2 - 0.13), PI, Vector2(1.6, 0.95), CHART, {"accent": Color(m._accent), "accent2": Color("#ff6fae"), "seed": 5.0})
	var nodes := _arch_nodes(stack)
	whiteboard(m, Vector3(-W / 2 + 0.14, 1.75, -0.4), PI / 2, L.t("Arquitetura"), nodes[0], nodes[1])
	postits(m, Vector3(W / 2 - 0.13, 2.35, -0.4), -PI / 2, _postit_words(id, stack), 4)
	m.prop("planta_vaso", Vector3(-W / 2 + 0.4, 0, D / 2 - 0.5))
	m.prop("planta_vaso", Vector3(W / 2 - 0.4, 0, -D / 2 + 0.4))
	m.prop("sofa_couro", Vector3(-2.4, 0, D / 2 - 0.65), PI)
	m.prop("sd_pizza", Vector3(-2.3, 0.44, D / 2 - 0.7))
	m.prop("caixas_papelao", Vector3(W / 2 - 0.5, 0, 0.9), 0.4, 0.7)
	m.prop("rack_servidor", Vector3(W / 2 - 0.45, 0, -1.6), -PI / 2, 0.8)
	m.prop("sd_cabos", Vector3(0.2, 0, -D / 2 + 1.8), 0.4)
	trash_bin(m, Vector3(0.0, 0, -D / 2 + 0.6))
	# cafeteira em cima de um aparador
	m.box(Vector3(W / 2 - 0.4, 0.45, 2.0), Vector3(0.5, 0.9, 0.9), m.painted("madeira", Color("#4a3020"), 1.4))
	m.box(Vector3(W / 2 - 0.4, 1.08, 2.1), Vector3(0.3, 0.36, 0.26), m.flat(Color("#1a1a1e")))
	m.box(Vector3(W / 2 - 0.4, 1.0, 1.75), Vector3(0.18, 0.2, 0.18), m.flat(Color("#c8c0b0")))
	neon(m, str(m.project.get("title", "")).to_upper(), Vector3(0, m.H - 0.35, -D / 2 + 0.16), 0, Color(m._accent), 80)
	stack_poster(m, Vector3(-1.3, 1.9, D / 2 - 0.13), PI, "Stack", stack, Color(m._accent), 0.8, 1.05)
	_switch(m, Vector3(1.05, 1.25, D / 2 - 0.12))


static func _arch_nodes(stack: Array) -> Array:
	var s := stack.duplicate()
	while s.size() < 5:
		s.append(["API", "Banco", "Fila", "Cliente", "Cache"][s.size() % 5])
	var nodes := [[L.t("Cliente"), -0.55, 0.15], [str(s[0]), -0.55, -0.25], [str(s[1]), 0.05, 0.15], [str(s[2]), 0.05, -0.25], [str(s[3]), 0.6, 0.0]]
	var edges := [[0, 2], [1, 2], [2, 3], [2, 4], [3, 4]]
	return [nodes, edges]


static func _postit_words(id: String, stack: Array) -> Array:
	var base := {"buscavagas": ["17 fontes", "Embeddings", "Redis", "Kanban", "WebSocket", "Ranking", "IA local", "Docker"],
		"orbix": ["RLS", "Multi-tenant", "OTP", "NestJS", "Flutter", "Monorepo", "Finanças", "SaaS"],
		"airmessage": ["WhatsApp", "Campanhas", "2FA", "Flutter", "Stripe", "AWS", "Fastify", "CRM"],
		"atende360": ["Nuxt 4", "SSR", "SEO", "S3", "CMS", "Vue 3", "Node", "Postgres"]}
	return base.get(id, stack.slice(0, 8))


# ═════════════════════════════════════════════ LAB de skills (Sobre mim)
static func _lab(m) -> void:
	var D: float = m.D
	var W: float = m.W
	var skills: Dictionary = Data.profile.get("skills", {})
	# parede do fundo: GRADE DE TECNOLOGIAS por categoria (examinável: abre o painel de skills)
	var wall := Node3D.new()
	wall.position = Vector3(0, 0, -D / 2 + 0.14)
	m.add_child(wall)
	m.box(Vector3(0, 1.75, -0.02), Vector3(W - 0.6, 2.6, 0.03), m.flat(Color("#0c0e16")), wall)
	var pal := [Color("#ff4fa3"), Color("#4e9bff"), Color("#5fd38a"), Color("#ffc83d"), Color("#b06bff"), Color("#ff7a3d"), Color("#5bd0ff"), Color("#ff3d5a")]
	var ci := 0
	var cats := skills.keys()
	var colw := (W - 0.9) / maxf(1, cats.size())
	for cat in cats:
		var x := -W / 2 + 0.45 + colw * (ci + 0.5)
		var col: Color = pal[ci % pal.size()]
		var hl := label3d(m, L.t(str(cat)).to_upper(), Vector3(x, 2.9, 0.01), 0, 26, col * 1.9, "title", wall, 0.0024)
		hl.width = int(colw / 0.0024)
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var y := 2.65
		for t in (skills[cat] as Array).slice(0, 9):
			m.box(Vector3(x, y, 0.0), Vector3(colw - 0.05, 0.17, 0.012), m.flat(col.darkened(0.55), 0.5), wall)
			var tl := label3d(m, str(t), Vector3(x, y, 0.008), 0, 20, Color("#eef2ff"), "bold", wall, 0.0019)
			tl.width = int((colw - 0.08) / 0.0019)
			tl.autowrap_mode = TextServer.AUTOWRAP_OFF
			y -= 0.2
		ci += 1
	neon(m, "STACK QUE EU DOMINO", Vector3(0, 3.15, -D / 2 + 0.15), 0, Color("#5bd0ff"), 60)
	act(m, wall, Vector3(0, 1.6, -D / 2 + 1.2), {"title": "Tecnologias que eu domino", "panel": "skills", "verb": "EXPLORAR",
		"text": "Toque numa tecnologia para ver os projetos em que ela foi usada."})
	# parede esquerda: linha do tempo da carreira (examinável)
	var tl := Node3D.new()
	tl.position = Vector3(-W / 2 + 0.14, 0, -0.6)
	tl.rotation.y = PI / 2
	m.add_child(tl)
	m.box(Vector3(0, 1.75, -0.01), Vector3(3.2, 1.6, 0.02), m.flat(Color("#0e1018")), tl)
	m.box(Vector3(0, 1.75, 0.0), Vector3(3.0, 0.02, 0.01), m.flat(Color("#ffc83d"), 2.0), tl)
	var exp: Array = Data.profile.get("experience", [])
	for i in mini(exp.size(), 5):
		var x := -1.3 + i * (2.6 / maxf(1, mini(exp.size(), 5) - 1))
		m.box(Vector3(x, 1.75, 0.005), Vector3(0.06, 0.06, 0.01), m.flat(Color("#ffc83d"), 3.0), tl)
		var up := 1.0 if i % 2 == 0 else -1.0
		var cl := label3d(m, str(exp[i].get("company", "")), Vector3(x, 1.75 + up * 0.32, 0.01), 0, 24, Color("#ffc83d") * 1.6, "title", tl, 0.0022)
		cl.width = 300
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label3d(m, str(exp[i].get("period", "")), Vector3(x, 1.75 + up * 0.16, 0.01), 0, 18, Color("#cfd6ee"), "type", tl, 0.0019)
	label3d(m, L.t("CARREIRA"), Vector3(0, 2.42, 0.01), 0, 40, Color("#eef2ff"), "title", tl, 0.0026)
	act(m, tl, Vector3(-W / 2 + 1.1, 1.6, -0.6), {"title": "Linha do tempo", "panel": "timeline", "verb": "VER", "text": ""})
	# parede direita: foto e cartão de contato
	var pc := Node3D.new()
	pc.position = Vector3(W / 2 - 0.14, 0, -0.6)
	pc.rotation.y = -PI / 2
	m.add_child(pc)
	var photo: Texture2D = m.tex("res://assets/profile/foto.jpg") if ResourceLoader.exists("res://assets/profile/foto.jpg") else null
	if photo == null:
		for p in ["res://assets/foto_gabriel.png", "res://assets/foto_gabriel.jpg"]:
			if ResourceLoader.exists(p):
				photo = load(p)
				break
	m.box(Vector3(-0.7, 1.9, -0.01), Vector3(1.0, 1.2, 0.03), m.flat(Color("#ffc83d"), 1.5), pc)
	if photo:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.92, 1.12)
		q.mesh = qm
		var pm := StandardMaterial3D.new()
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.albedo_texture = photo
		q.material_override = pm
		q.position = Vector3(-0.7, 1.9, 0.01)
		pc.add_child(q)
	label3d(m, "GABRIEL INÁCIO", Vector3(0.55, 2.3, 0.01), 0, 46, Color("#ffc83d") * 1.6, "title", pc, 0.0026)
	var role := label3d(m, L.t("Engenheiro de software full-stack · games · IA"), Vector3(0.55, 2.06, 0.01), 0, 22, Color("#e8ecf8"), "type", pc, 0.002)
	role.width = 420
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.box(Vector3(0.55, 1.5, -0.005), Vector3(1.0, 0.6, 0.02), m.flat(Color("#141826")), pc)
	label3d(m, "LinkedIn · GitHub · E-mail", Vector3(0.55, 1.5, 0.01), 0, 22, Color("#5bd0ff") * 1.5, "bold", pc, 0.002)
	act(m, pc, Vector3(W / 2 - 1.1, 1.6, -0.6), {"title": "Contato", "panel": "contact", "verb": "CONECTAR", "text": ""})
	# mesa do meio: monitores com código, servidor de IA, livros técnicos
	var dz := 0.9
	var d := desk(m, Vector3(0, 0, dz), 0.0, 2.0, 0.8, Color("#2a2a34"))
	var mon := Node3D.new()
	mon.position = Vector3(0, 1.08, -0.2)
	d.add_child(mon)
	code_monitor(m, mon, Vector3(-0.35, 0, 0), 1.0)
	code_monitor(m, mon, Vector3(0.35, 0, 0), 2.0, MATRIX, {"tint": Color("#5bd0ff")})
	var all_techs := []
	for cat in cats:
		all_techs.append_array(skills[cat])
	laptop(m, d, Vector3(0.7, 0.77, -0.1), all_techs.slice(10, 16), 3.0)
	m.prop("servidor_ia", Vector3(-W / 2 + 0.5, 0, D / 2 - 0.7), PI / 4, 0.9)
	tech_shelf(m, Vector3(W / 2 - 0.25, 0, D / 2 - 1.7), -PI / 2, all_techs, 1.4)
	neon(m, "CLAUDE · AGENTES · IA LOCAL", Vector3(-W / 2 + 0.14, 2.95, -0.6), PI / 2, Color("#ff4fa3"), 44)
	neon(m, "GODOT · BLENDER", Vector3(W / 2 - 0.14, 2.95, -0.6), -PI / 2, Color("#5fd38a"), 50)
	m.prop("sd_cabos", Vector3(0.6, 0, dz - 0.6), 0.4)
	m.prop("caneca", Vector3(-0.6, 0.77, dz))
	# parede da frente: como eu trabalho com IA (quadro branco) e rack com LEDs
	whiteboard(m, Vector3(-2.2, 1.75, D / 2 - 0.14), PI, L.t("Como eu trabalho com IA"),
		[[L.t("Ideia"), -0.6, 0.15], ["Claude Code", -0.05, 0.15], [L.t("Agentes"), 0.55, 0.15], [L.t("Testes"), -0.3, -0.25], ["Deploy", 0.35, -0.25]],
		[[0, 1], [1, 2], [1, 3], [3, 4], [2, 4]])
	var r := Node3D.new()
	r.position = Vector3(2.6, 0, D / 2 - 0.5)
	r.rotation.y = PI
	m.add_child(r)
	m.box(Vector3(0, 1.0, 0), Vector3(0.6, 2.0, 0.7), m.flat(Color("#0c0f12")), r)
	screen(m, Vector3(0, 1.02, 0.36), 0, Vector2(0.5, 1.8), LED, {"seed": 4.0, "units": 18.0}, r)
	var st := Node3D.new()
	st.position = Vector3(-0.26, 1.95, 0.36)
	r.add_child(st)
	stickers(m, st, Vector3.ZERO, ["Ollama", "Docker", "Postgres", "Redis"], 2, Vector2(0.18, 0.06))
	m.prop("planta_vaso", Vector3(-W / 2 + 0.45, 0, -D / 2 + 0.5))
	m.prop("planta_vaso", Vector3(W / 2 - 0.45, 0, -D / 2 + 0.5))
	m.prop("pilha_livros", Vector3(1.4, 0, dz + 0.6))
	m.prop("sd_latas", Vector3(-1.2, 0, dz + 0.7))
	_switch(m, Vector3(1.05, 1.25, D / 2 - 0.12))


# ═════════════════════════════════════════════ prédio da carreira (empresas lado a lado)
static func _career(m) -> void:
	var D: float = m.D
	var W: float = m.W
	# divisórias de vidro entre as "salas" de cada empresa (ao longo do corredor)
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.6, 0.8, 1.0, 0.1)
	for z in [-D / 2 + 4.3, -D / 2 + 8.6]:
		for sx in [-1, 1]:
			m.box(Vector3(sx * (W / 2 - 1.2), 1.3, z), Vector3(2.2, 2.6, 0.04), glass)
			m.box(Vector3(sx * (W / 2 - 1.2), 2.62, z), Vector3(2.2, 0.05, 0.08), m.flat(Color("#2a2e3a")))
	var zones := [["SYS EVOLUTION", Color("#4e9bff"), -D / 2 + 2.1], ["SYS EVOLUTION · SYSGUIDE", Color("#ff6fae"), -D / 2 + 6.4], ["LOOP · UNESP · FREELA", Color("#5fd38a"), D / 2 - 2.3]]
	var zi := 0
	for zn in zones:
		var z: float = zn[2]
		var dx := -1.85 if zi % 2 == 0 else 1.85
		zi += 1
		neon(m, zn[0], Vector3(0, m.H - 0.35, z - 1.9) if z < 0 else Vector3(0, m.H - 0.35, z + 1.95), 0 if z < 0 else PI, zn[1], 56)
		var d := desk(m, Vector3(dx, 0, z), -signf(dx) * PI / 2, 1.6, 0.7, Color("#4a3a2c"))
		var mon := Node3D.new()
		mon.position = Vector3(0, 1.08, -0.15)
		d.add_child(mon)
		code_monitor(m, mon, Vector3(-0.32, 0, 0), z, CODE)
		code_monitor(m, mon, Vector3(0.32, 0, 0), z + 1.0, CHART, {"accent": zn[1], "accent2": Color("#ffc83d")})
		m.prop("cadeira_escritorio", Vector3(dx * 0.55, 0, z), -signf(dx) * PI / 2 + PI)
		m.prop("planta_vaso", Vector3(-dx * 1.0, 0, z + 1.4))
	m.prop("rack_servidor", Vector3(-W / 2 + 0.45, 0, -D / 2 + 5.0), PI / 2, 0.85)
	m.prop("rack_servidor", Vector3(-W / 2 + 0.45, 0, -D / 2 + 5.7), PI / 2, 0.85)
	m.prop("sd_cabos", Vector3(-1.6, 0, -D / 2 + 5.4), 0.4)
	m.prop("caixas_papelao", Vector3(W / 2 - 0.5, 0, D / 2 - 0.5), 0.3, 0.7)
	_switch(m, Vector3(1.05, 1.25, D / 2 - 0.12))
	_career_islands(m, zones)


## Ilhas de exposição no meio do corredor, uma por empresa, com os objetos do trabalho feito lá e um
## spot de destaque. Preenche o vão central (antes vazio) e conta a história de cada fase.
static func _career_islands(m, zones: Array) -> void:
	var D: float = m.D
	var wood: StandardMaterial3D = m.flat(Color("#2b2320"))
	var trim: StandardMaterial3D = m.flat(Color("#c9a45c"), 0.0)
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.7, 0.85, 1.0, 0.12)
	glass.roughness = 0.1
	var centers := [-D / 2 + 2.6, -D / 2 + 6.6, D / 2 - 2.9]
	for i in 3:
		var z: float = centers[i]
		var col: Color = zones[i][1]
		var base := Node3D.new()
		base.position = Vector3(0, 0, z)
		m.add_child(base)
		# pedestal largo com tampo de vidro e friso dourado
		m.box(Vector3(0, 0.42, 0), Vector3(1.5, 0.84, 0.9), wood, base)
		m.box(Vector3(0, 0.85, 0), Vector3(1.56, 0.03, 0.96), trim, base)
		m.box(Vector3(0, 1.12, 0), Vector3(1.5, 0.5, 0.9), glass, base)
		var strip: MeshInstance3D = m.box(Vector3(0, 0.05, 0.46), Vector3(1.5, 0.03, 0.02), m.flat(col, 2.2), base)
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		match i:
			0:
				# licitações: pilhas de editais, caixa de arquivo e monitor com a tabela de milhões de linhas
				m.prop("pilha_papeis", Vector3(-0.45, 0.87, 0.05), 0.2, 0.9, base)
				m.prop("sd_pastas", Vector3(-0.1, 0.87, 0.2), -0.4, 0.8, base)
				m.prop("sd_caixa_arquivo", Vector3(0.5, 0.87, 0.15), 0.1, 0.55, base)
				var mon := Node3D.new()
				mon.position = Vector3(0.25, 0.87, -0.2)
				base.add_child(mon)
				code_monitor(m, mon, Vector3.ZERO, 3.0, CHART, {"accent": col, "accent2": Color("#ffc83d")})
				label3d(m, "EDITAIS · MILHÕES DE LINHAS", Vector3(0, 0.62, 0.47), 0, 20, Color("#e8e2d0"), "type", base)
			1:
				# SysGuide: servidor de vídeo, câmera de streaming, notebook (Rust + Tauri) e microfone (Whisper)
				m.prop("servidor_ia", Vector3(-0.5, 0.87, 0.0), 0.3, 0.5, base)
				m.prop("microfone_estudio", Vector3(0.55, 0.87, 0.2), -0.5, 0.55, base)
				_tripod_cam(m, base, Vector3(0.6, 0.87, -0.25), col)
				laptop(m, base, Vector3(0.0, 0.87, 0.12), ["Rust", "Tauri", "Whisper", "LLM local"], 1.7)
				label3d(m, "STREAMING · RUST + TAURI · WHISPER", Vector3(0, 0.62, 0.47), 0, 20, Color("#e8e2d0"), "type", base)
			2:
				# Loop, UNESP e freelas: livros, diploma, notebook e caneca
				m.prop("pilha_livros", Vector3(-0.5, 0.87, 0.1), 0.6, 0.7, base)
				m.prop("caneca", Vector3(0.55, 0.87, 0.25), 0.0, 1.0, base)
				laptop(m, base, Vector3(0.05, 0.87, 0.05), ["C#", "WPF", "Python", "Vue"], 2.9)
				var frame: MeshInstance3D = m.box(Vector3(0.45, 1.05, -0.3), Vector3(0.36, 0.28, 0.02), m.flat(Color("#e8e2d0")), base)
				frame.rotation.x = -0.25
				label3d(m, "PESQUISA · DESKTOP · FREELAS", Vector3(0, 0.62, 0.47), 0, 20, Color("#e8e2d0"), "type", base)
		# spot de destaque sobre a ilha (uma luz por ilha, sem sombra)
		var sp := SpotLight3D.new()
		sp.position = Vector3(0, m.H - 0.2, z)
		sp.rotation_degrees = Vector3(-90, 0, 0)
		sp.light_color = col.lerp(Color("#ffe6c0"), 0.55)
		sp.light_energy = 1.5
		sp.spot_range = 4.0
		sp.spot_angle = 30.0
		sp.shadow_enabled = false
		m.add_child(sp)


static func _tripod_cam(m, parent: Node3D, pos: Vector3, col: Color) -> void:
	var leg: StandardMaterial3D = m.flat(Color("#1a1c22"))
	for k in 3:
		var a := TAU * k / 3.0
		var l: MeshInstance3D = m.box(pos + Vector3(cos(a) * 0.07, 0.11, sin(a) * 0.07), Vector3(0.012, 0.24, 0.012), leg, parent)
		l.rotation = Vector3(sin(a) * 0.3, 0, -cos(a) * 0.3)
	m.box(pos + Vector3(0, 0.26, 0), Vector3(0.14, 0.09, 0.1), m.flat(Color("#23262e")), parent)
	var lens: MeshInstance3D = m.box(pos + Vector3(0, 0.26, 0.08), Vector3(0.06, 0.06, 0.06), m.flat(Color("#0c0d10")), parent)
	lens.rotation.x = 0.0
	var rec: MeshInstance3D = m.box(pos + Vector3(0.05, 0.32, 0.03), Vector3(0.015, 0.015, 0.015), m.flat(Color("#ff3344"), 4.0), parent)
	rec.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ═════════════════════════════════════════════ comuns: interruptor, poeira, relógio, telão GitHub
static func _switch(m, pos: Vector3) -> void:
	var sw: MeshInstance3D = m.box(pos, Vector3(0.1, 0.16, 0.03), m.flat(Color("#e8e2d0")))
	sw.rotation.y = PI
	var tog: MeshInstance3D = m.box(Vector3(0, 0.02, -0.025), Vector3(0.03, 0.05, 0.02), m.flat(Color("#c8bfa8")), sw)
	act(m, sw, pos + Vector3(0, 0, -0.6), {"title": "Interruptor", "action": "switch", "verb": "LIGAR / DESLIGAR", "toggle": tog})


static func _common(m, style: String) -> void:
	m.prop("sd_relogio", Vector3(-1.9, 2.95, -m.D / 2 + 0.14))
	# telão do GitHub (README, estrelas, último commit, linguagens) nas lojas de projeto
	var id := str(m.project.get("id", ""))
	if id != "" and not m.is_lab and style != "career":
		var GH := load("res://scripts/gh_screen.gd")
		var s: Node3D = GH.new()
		s.repo_id = id
		s.accent = m._accent
		var pos := Vector3(1.2, 1.95, m.D / 2 - 0.13) if style != "startup" else Vector3(-2.6, 2.6, m.D / 2 - 0.13)
		if style == "detetive":
			pos = Vector3(2.4, 2.0, m.D / 2 - 0.13)
		s.position = pos
		s.rotation.y = PI
		m.add_child(s)
		act(m, s, pos + Vector3(0, -0.3, -0.9), {"title": "GitHub ao vivo", "panel": "terminal", "repo": id, "verb": "LER README", "text": ""})
	var p := CPUParticles3D.new()
	p.amount = 24 if not UI.is_mobile() else 10
	p.lifetime = 7.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(m.W / 2, m.H / 2, m.D / 2)
	p.position = Vector3(0, m.H / 2, 0)
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.04
	p.initial_velocity_max = 0.12
	p.scale_amount_min = 0.02
	p.scale_amount_max = 0.04
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color(m._warm, 0.16)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p.material_override = dm
	m.add_child(p)
