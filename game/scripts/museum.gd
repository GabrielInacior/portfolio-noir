extends Node3D
## Loja-museu de um projeto: ao entrar pela porta, o jogador troca da rua para um interior fechado,
## pequeno e LOTADO, com identidade própria (escritório de detetive, sala de servidores, fliperama,
## bar, estúdio, startup, laboratório de skills, prédio da carreira). Cada objeto examinável acende
## com contorno ao ser mirado e abre um painel do tipo certo (quadro, inspeção 3D, terminal,
## galeria, documento, fliperama jogável, skills, linha do tempo). Os NPCs são extra.
##
## Leve: uma sala de caixas, poucas luzes (emissão para neon e telas), nada da rua renderizado dentro.

signal left
signal examined(count: int, total: int)
signal action(entry: Dictionary)

const PolyFace := preload("res://scripts/museum_objects.gd")
const Dress := preload("res://scripts/museum_dress.gd")
const HOVER := preload("res://shaders/hover_outline.gdshader")
const PS1 := preload("res://scripts/ps1.gd")

var project: Dictionary = {}
var data: Dictionary = {}
var is_lab := false

var items: Array = []             # [{node, item, light, seen, pos}]
var _accent := Color("#ffc83d")
var _warm := Color("#ffb23d")
var _cool := Color("#4e9bff")
var _t := 0.0
var _seen := 0
var _exit_pos := Vector3.ZERO
var _tex_cache := {}
var _spin: Array = []
var _props_cache := {}
var _room_lights: Array = []
var _hover_mat: ShaderMaterial
var _hot_node: Node = null
var tickers: Array = []           # nós com _process próprio (telefone tocando etc.)

var W := 7.2
var D := 9.0
const H := 3.4


func setup(p: Dictionary, d: Dictionary, lab := false) -> void:
	project = p
	data = d
	is_lab = lab


func pid() -> String:
	if is_lab:
		return "_lab"
	return str(project.get("id", ""))


func _ready() -> void:
	var theme: Dictionary = data.get("theme", {})
	_accent = Color(str(theme.get("accent", "#ffc83d")))
	_warm = Color(str(theme.get("warm", "#ffb23d")))
	_cool = Color(str(theme.get("cool", "#4e9bff")))
	if pid() == "_carreira":
		D = 13.0
	_hover_mat = ShaderMaterial.new()
	_hover_mat.shader = HOVER
	_hover_mat.set_shader_parameter("color", _accent)
	var style := Dress.style_of(pid(), str(theme.get("room", "escritorio")))
	var look: Dictionary = Dress.LOOKS.get(style, Dress.LOOKS["startup"])
	if look.has("warm"):
		_warm = Color(look["warm"])
	_build_env(look)
	_build_shell(look)
	_place_items(style)
	Dress.dress(self, style)
	preload("res://scripts/lowpoly.gd").node(self)
	examined.emit(0, items.size())


# ───────────────────────────────── ambiente fechado
func _build_env(look: Dictionary) -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#05060c")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(look.get("ambient", "#3a3850"))
	e.ambient_light_energy = float(look.get("ambient_e", 2.0))
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = Color(look.get("fog", "#1c1a28"))
	e.fog_depth_begin = 4.0
	e.fog_depth_end = 20.0
	e.fog_density = 0.4
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = float(look.get("exposure", 1.25))
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.18
	e.adjustment_contrast = 1.1
	if not UI.is_mobile():
		e.glow_enabled = true
		e.glow_intensity = 0.7
		e.glow_bloom = 0.08
		e.glow_hdr_threshold = 1.1
	we.environment = e
	add_child(we)


func painted(tex: String, tint: Color, scale := 0.5) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/toon.gdshader")
	m.set_shader_parameter("albedo", tint)
	m.set_shader_parameter("shadow_tint", tint.darkened(0.55).lerp(_cool, 0.3))
	m.set_shader_parameter("use_tex", true)
	if not _tex_cache.has(tex):
		_tex_cache[tex] = load("res://assets/tex/%s.png" % tex)
	m.set_shader_parameter("albedo_tex", _tex_cache[tex])
	m.set_shader_parameter("tex_scale", scale)
	m.set_shader_parameter("tex_strength", 0.9)
	return m


func flat(col: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	if emit > 0.0:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	return m


func box(pos: Vector3, size: Vector3, mat: Material, parent: Node = null, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(mi)
	return mi


## Prop 3D (kit Blender) colocado na sala; frente do modelo = +z.
func prop(name: String, pos: Vector3, yaw := 0.0, scl := 1.0, parent: Node = null) -> Node3D:
	var path := "res://assets/props/%s.glb" % name
	if not ResourceLoader.exists(path):
		return null
	if not _props_cache.has(name):
		_props_cache[name] = load(path)
	var n: Node3D = (_props_cache[name] as PackedScene).instantiate()
	if OS.get_environment("PF_NOPS1") == "": PS1.node(n)
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * scl
	(parent if parent else self).add_child(n)
	return n


func light(pos: Vector3, col: Color, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	add_child(l)
	_room_lights.append(l)
	return l


# ───────────────────────────────── casca da sala: piso, paredes, teto, rodapé, porta, janela
func _build_shell(look: Dictionary) -> void:
	var wall_mat := painted(str(look["wall"]), Color(look["wall_tint"]), float(look.get("wall_scale", 1.0)))
	var floor_mat := painted(str(look["floor"]), Color(look["floor_tint"]), float(look.get("floor_scale", 0.6)))
	var ceil_mat := painted("concreto", Color(look.get("ceil", "#2a2632")), 0.5)
	var base_mat := flat(Color(look.get("trim", "#16121a")))
	box(Vector3(0, -0.05, 0), Vector3(W, 0.1, D), floor_mat)
	box(Vector3(0, H, 0), Vector3(W, 0.1, D), ceil_mat)
	box(Vector3(0, H / 2, -D / 2), Vector3(W, H, 0.2), wall_mat)
	box(Vector3(-W / 2, H / 2, 0), Vector3(0.2, H, D), wall_mat)
	box(Vector3(W / 2, H / 2, 0), Vector3(0.2, H, D), wall_mat)
	var fz := D / 2
	var side := (W - 1.8) / 2
	box(Vector3(-W / 2 + side / 2, H / 2, fz), Vector3(side, H, 0.2), wall_mat)
	box(Vector3(W / 2 - side / 2, H / 2, fz), Vector3(side, H, 0.2), wall_mat)
	box(Vector3(0, H - 0.35, fz), Vector3(1.8, 0.7, 0.2), wall_mat)
	# rodapé e roda-teto
	box(Vector3(0, 0.08, -D / 2 + 0.12), Vector3(W, 0.16, 0.05), base_mat)
	box(Vector3(0, H - 0.07, -D / 2 + 0.12), Vector3(W, 0.12, 0.08), base_mat)
	for x in [-W / 2 + 0.12, W / 2 - 0.12]:
		box(Vector3(x, 0.08, 0), Vector3(0.05, 0.16, D), base_mat)
		box(Vector3(x, H - 0.07, 0), Vector3(0.08, 0.12, D), base_mat)
	if look.get("wainscot", false):
		var wood := painted("painel_madeira", Color(look.get("wainscot_tint", "#5a3e2c")), 0.8)
		box(Vector3(0, 0.55, -D / 2 + 0.13), Vector3(W - 0.2, 1.1, 0.04), wood)
		for x in [-W / 2 + 0.13, W / 2 - 0.13]:
			box(Vector3(x, 0.55, 0), Vector3(0.04, 1.1, D - 0.2), wood)
		box(Vector3(0, 1.12, -D / 2 + 0.15), Vector3(W - 0.2, 0.05, 0.08), base_mat)
		for x in [-W / 2 + 0.15, W / 2 - 0.15]:
			box(Vector3(x, 1.12, 0), Vector3(0.08, 0.05, D - 0.2), base_mat)
	# porta de saída com batente de neon e SAIR
	for ox in [-0.92, 0.92]:
		box(Vector3(ox, 1.4, fz - 0.03), Vector3(0.07, 2.8, 0.07), flat(_accent, 3.0))
	box(Vector3(0, 2.8, fz - 0.03), Vector3(1.9, 0.07, 0.07), flat(_accent, 3.0))
	var exit := Label3D.new()
	exit.text = L.t("SAIR")
	exit.font = UI.font("title")
	exit.font_size = 64
	exit.pixel_size = 0.0038
	exit.modulate = _accent * 1.6
	exit.position = Vector3(0, 3.05, fz - 0.08)
	exit.rotation.y = PI
	exit.shaded = false
	exit.double_sided = true
	add_child(exit)
	_exit_pos = Vector3(0, 1.6, fz - 1.0)
	# luz principal da sala (cor do tema) e preenchimento frio ao fundo
	for lz in [-D / 4, D / 4]:
		light(Vector3(0, H - 0.5, lz), _warm, float(look.get("light_e", 2.2)), 6.5)
	light(Vector3(0, 1.8, -D / 2 + 0.9), _cool, 1.3, 6.0)
	# lavagem das paredes laterais (luz baixa e larga para a sala não afundar no preto)
	for sx in [-1.0, 1.0]:
		light(Vector3(sx * (W / 2 - 1.1), 2.4, 0), _warm.lerp(_cool, 0.3), 1.3, 6.0)
		if D > 10:
			light(Vector3(sx * (W / 2 - 1.1), 2.4, -D / 3), _warm, 1.2, 6.0)
			light(Vector3(sx * (W / 2 - 1.1), 2.4, D / 3), _warm, 1.2, 6.0)


# ───────────────────────────────── itens examináveis nas paredes e no centro
func _place_items(style: String) -> void:
	var list: Array = data.get("items", [])
	var wall_items := []
	var floor_items := []
	for it in list:
		if str(it.get("kind", "")) == "prop":
			floor_items.append(it)
		elif str(it.get("kind", "")) == "arcade":
			continue   # o fliperama jogável substitui o item de parede
		else:
			wall_items.append(it)
	if style == "lab":
		wall_items = []
	var slots := _wall_slots(style)
	var n := mini(wall_items.size(), slots.size())
	for i in n:
		var node := _make_item(wall_items[i], slots[i])
		add_entry(node, wall_items[i], slots[i]["pos"] + slots[i]["normal"] * 0.9)
	# o que sobrar vira a galeria (um quadro que abre todas as imagens restantes)
	var rest := wall_items.slice(n)
	if not rest.is_empty():
		var g := {"kind": "frame", "title": L.t("Mais da história"), "img": str(rest[0].get("img", "")), "panel": "gallery", "gallery": rest,
			"text": str(rest[0].get("text", "")), "verb": "VER"}
		var slot: Dictionary = Dress.extra_slot(self)
		var node2 := _make_item(g, slot)
		add_entry(node2, g, slot["pos"] + slot["normal"] * 0.9)
	# objetos 3D em pedestais (ilha central): até 3
	var spots := Dress.pedestal_spots(self, style)
	for i in mini(floor_items.size(), spots.size()):
		var it: Dictionary = floor_items[i].duplicate()
		it["panel"] = "inspect"
		it["verb"] = "INSPECIONAR"
		var node3 := _make_item(it, {"pos": spots[i], "normal": Vector3(0, 0, 1), "yaw": 0.0, "floor": true})
		add_entry(node3, it, spots[i] + Vector3(0, 1.1, 0))


## Registra um objeto examinável/acionável. item pode ter "panel" (exhibit, inspect, terminal,
## gallery, doc, arcade, skills, timeline, github) e "action" (phone, typewriter, drawer, switch).
func add_entry(node: Node3D, it: Dictionary, look_pos: Vector3) -> Dictionary:
	var l := OmniLight3D.new()
	l.position = look_pos + Vector3(0, 0.4, 0)
	l.light_color = _accent
	l.light_energy = 0.0
	l.omni_range = 2.6
	add_child(l)
	var e := {"node": node, "item": it, "light": l, "seen": false, "pos": look_pos}
	items.append(e)
	return e


func _wall_slots(style: String) -> Array:
	var out := []
	if style == "career":
		var sxc := W / 2 - 0.22
		var bzc := -D / 2 + 0.22
		for p in [Vector3(-2.3, 1.8, bzc), Vector3(2.3, 1.8, bzc)]:
			out.append({"pos": p, "normal": Vector3(0, 0, 1), "yaw": 0.0})
		for z in [-4.6, -3.2, -0.8, 0.8, 3.2, 4.6]:
			out.append({"pos": Vector3(-sxc, 1.8, z), "normal": Vector3(1, 0, 0), "yaw": PI / 2})
			out.append({"pos": Vector3(sxc, 1.8, z), "normal": Vector3(-1, 0, 0), "yaw": -PI / 2})
		return out
	var y := 1.8
	var bz := -D / 2 + 0.22
	var sx := W / 2 - 0.22
	var back := [Vector3(-2.3, y, bz), Vector3(0, y, bz), Vector3(2.3, y, bz)]
	var zs := [-D / 2 + 2.2, D / 2 - 3.0] if D < 10 else [-D / 2 + 2.2, -0.6, 3.0]
	var left := []
	var right := []
	for z in zs:
		left.append(Vector3(-sx, y, z))
		right.append(Vector3(sx, y, z))
	var walls := []
	if not Dress.back_reserved(style):
		for p in back:
			walls.append([p, Vector3(0, 0, 1)])
	for i in left.size():
		walls.append([left[i], Vector3(1, 0, 0)])
		walls.append([right[i], Vector3(-1, 0, 0)])
	for w in walls:
		var nrm: Vector3 = w[1]
		out.append({"pos": w[0], "normal": nrm, "yaw": atan2(nrm.x, nrm.z)})
	return out


const PROP_GLB := {"cadeira_barbeiro": "cadeira_barbeiro", "servidor": "servidor_ia", "cadeado": "cadeado", "microfone": "microfone_estudio", "monitor_cv": "monitor",
	"maquina": "maquina_escrever", "typewriter": "maquina_escrever", "telefone": "telefone_antigo", "livro": "pilha_livros",
	"trofeu": "trofeu", "roteador": "roteador", "carta": "mesa_cartas", "fliperama": "fliperama", "rack": "rack_servidor",
	"maquina_escrever": "maquina_escrever", "cortica": "quadro_cortica"}


func tex(path: String) -> Texture2D:
	if path == "" or not path.begins_with("res://"):
		return null
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[path]


func _make_item(it: Dictionary, slot: Dictionary) -> Node3D:
	var holder := Node3D.new()
	holder.position = slot["pos"]
	holder.rotation.y = slot["yaw"]
	add_child(holder)
	var kind := str(it.get("kind", "frame"))
	if not slot.get("floor", false):
		holder.scale = Vector3.ONE * {"screen": 0.62, "frame": 0.8, "poster": 0.82, "monitor": 0.9, "plaque": 0.85}.get(kind, 0.82)
	var t := tex(str(it.get("img", "")))
	match kind:
		"frame": PolyFace.framed(holder, t, _accent, _warm)
		"screen": PolyFace.screen(holder, t, _cool, 1.2)
		"monitor": PolyFace.monitor(holder, t, _accent)
		"poster": PolyFace.poster(holder, t, _accent)
		"plaque": PolyFace.plaque(holder, t, _accent)
		"prop":
			var glb: String = PROP_GLB.get(str(it.get("model", "")), "")
			box(Vector3(0, 0.45, 0), Vector3(0.62, 0.9, 0.62), flat(Color("#16121c")), holder)
			box(Vector3(0, 0.905, 0), Vector3(0.64, 0.02, 0.64), flat(Color("#0e0c14")), holder)
			for e in [[Vector3(0, 0.9, 0.32), Vector3(0.66, 0.025, 0.02)], [Vector3(0, 0.9, -0.32), Vector3(0.66, 0.025, 0.02)],
					[Vector3(0.32, 0.9, 0), Vector3(0.02, 0.025, 0.66)], [Vector3(-0.32, 0.9, 0), Vector3(0.02, 0.025, 0.66)]]:
				box(e[0], e[1], flat(_accent, 2.4), holder)
			if glb != "" and ResourceLoader.exists("res://assets/props/%s.glb" % glb):
				var big := glb in ["fliperama", "microfone_estudio", "servidor_ia", "rack_servidor", "quadro_cortica"]
				var pm := prop(glb, Vector3(0, 0.93, 0), 0.0, 0.45 if big else 0.9, holder)
				if pm:
					_spin.append(pm)
			else:
				var inner := Node3D.new()
				inner.position = Vector3(0, 0.93, 0)
				holder.add_child(inner)
				PolyFace.prop(inner, str(it.get("model", "caixa")), _accent, _warm)
				_spin.append(inner)
		_: PolyFace.framed(holder, t, _accent, _warm)
	# item sem imagem: a tela/quadro mostra o texto (título e história), nada de cor chapada
	if t == null and kind in ["monitor", "screen", "frame", "poster", "plaque"]:
		var card := Label3D.new()
		card.text = L.tx(it, "title").to_upper() + "

" + L.tx(it, "text")
		card.font = UI.font("type")
		card.font_size = 30
		card.pixel_size = 0.0024
		card.width = 380
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.modulate = _accent.lerp(Color.WHITE, 0.55) * 1.3
		card.position = Vector3(0, 0.1 if kind == "monitor" else 0.0, 0.135)
		card.width = 520 if kind in ["screen", "plaque"] else 400
		card.font_size = 30 if kind != "screen" else 34
		card.shaded = false
		holder.add_child(card)
	var lbl := Label3D.new()
	lbl.text = L.tx(it, "title").to_upper()
	lbl.font = UI.font("type")
	lbl.font_size = 40
	lbl.pixel_size = 0.0021
	lbl.modulate = UI.PAPER
	lbl.width = 900
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.position = Vector3(0, -0.95, 0.12) if not slot.get("floor", false) else Vector3(0, 0.62, 0.34)
	lbl.outline_size = 8
	lbl.outline_modulate = Color(0, 0, 0, 0.85)
	lbl.shaded = false
	lbl.double_sided = true
	holder.add_child(lbl)
	return holder


func exit_pos() -> Vector3:
	return _exit_pos


func spawn_pos() -> Vector3:
	return Vector3(0, 1.6, D / 2 - 1.4)


func bounds() -> Rect2:
	return Rect2(-W / 2 + 0.45, -D / 2 + 0.45, W - 0.9, D - 0.9)


func mark_seen(entry: Dictionary) -> void:
	if not entry["seen"]:
		entry["seen"] = true
		_seen += 1
		examined.emit(_seen, items.size())


## item mirado mais próximo à frente do jogador
func nearest(pos: Vector3, forward: Vector3) -> Dictionary:
	var best := {}
	var best_score := 0.0
	for e in items:
		var to: Vector3 = e["pos"] - pos
		to.y *= 0.6
		var d := to.length()
		if d > 3.0:
			continue
		var dir := to.normalized()
		var dot := dir.dot(forward)
		if dot < 0.6:
			continue
		var score := dot - d * 0.12
		if score > best_score:
			best_score = score
			best = e
	return best


func at_exit(pos: Vector3) -> bool:
	return pos.distance_to(Vector3(0, pos.y, D / 2)) < 1.5


## contorno pulsando no objeto mirado (material_overlay em todas as malhas do nó)
func set_hot(entry: Dictionary) -> void:
	var node: Node = entry.get("node") if not entry.is_empty() else null
	if node == _hot_node:
		return
	if _hot_node and is_instance_valid(_hot_node):
		_overlay(_hot_node, null)
	_hot_node = node
	if node:
		_overlay(node, _hover_mat)


func _overlay(n: Node, m: Material) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		# não contorna vidro nem rótulos
		if not (mi.material_override is StandardMaterial3D and (mi.material_override as StandardMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED):
			mi.material_overlay = m
	for c in n.get_children():
		_overlay(c, m)


func toggle_lights() -> bool:
	var on := true
	for l in _room_lights:
		(l as OmniLight3D).visible = not (l as OmniLight3D).visible
		on = (l as OmniLight3D).visible
	return on


func _process(dt: float) -> void:
	_t += dt
	for e in items:
		var l: OmniLight3D = e["light"]
		var target: float = 2.2 if e.get("_hot", false) else (0.5 if e["seen"] else 0.0)
		l.light_energy = lerpf(l.light_energy, target, clampf(dt * 6.0, 0, 1))
	for n in _spin:
		if is_instance_valid(n):
			(n as Node3D).rotate_y(dt * 0.5)
	for t in tickers:
		if t is Callable:
			(t as Callable).call(dt, _t)
