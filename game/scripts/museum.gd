extends Node3D
## Loja-museu de um projeto: ao entrar pela porta, o jogador troca da rua para um interior fechado
## e temático (escritório de detetive, fliperama, sala de segurança, bar, estúdio, laboratório),
## cheio de objetos 3D examináveis. Cada objeto (quadro com print, telão, monitor, prop, placa,
## fliperama) acende ao ser mirado e abre um MODAL noir com título, texto da história, imagem,
## stack e link. É aqui que a história de cada projeto é contada. Os NPCs são extra.
##
## Leve: uma sala de caixas, poucas luzes (emissão para o neon), nada da rua renderizado dentro.

signal left                       # jogador saiu pela porta (volta para a rua)
signal examined(count: int, total: int)

const PolyFace := preload("res://scripts/museum_objects.gd")

var project: Dictionary = {}
var data: Dictionary = {}         # {theme, items}
var is_lab := false

var items: Array = []             # [{node, item, light, seen}]
var _accent := Color("#ffc83d")
var _warm := Color("#ffb23d")
var _cool := Color("#4e9bff")
var _t := 0.0
var _seen := 0
var _exit_pos := Vector3.ZERO
var _tex_cache := {}


func setup(p: Dictionary, d: Dictionary, lab := false) -> void:
	project = p
	data = d
	is_lab = lab


func _ready() -> void:
	var theme: Dictionary = data.get("theme", {})
	_accent = Color(str(theme.get("accent", "#ffc83d")))
	_warm = Color(str(theme.get("warm", "#ffb23d")))
	_cool = Color(str(theme.get("cool", "#4e9bff")))
	_build_env()
	_build_room(str(theme.get("room", "escritorio")), str(theme.get("floor", "carpete")), str(theme.get("wall", "concreto")))
	_place_items()


# ───────────────────────────────── ambiente fechado (sem céu; luz de interior)
func _build_env() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#05060c")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = _cool.darkened(0.55)
	e.ambient_light_energy = 0.7
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = _cool.darkened(0.6)
	e.fog_depth_begin = 6.0
	e.fog_depth_end = 26.0
	e.fog_density = 1.0
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.2
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.14
	e.adjustment_contrast = 1.08
	we.environment = e
	add_child(we)


func _painted(tex: String, tint: Color, scale := 0.5, rough := 0.95) -> ShaderMaterial:
	# material pincelado (toon.gdshader com textura triplanar, como a cidade)
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


func _flat(col: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.95
	if emit > 0.0:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	return m


func _box(pos: Vector3, size: Vector3, mat: Material, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(mi)
	return mi


# ───────────────────────────────── a sala: 4 paredes, piso, teto, porta de saída
const ROOM_W := 10.0
const ROOM_D := 12.0
const ROOM_H := 3.6


func _build_room(room: String, floor_tex: String, wall_tex: String) -> void:
	var wall_tint := Color("#2a3048").lerp(_cool, 0.12).darkened(0.25)
	var floor_mat := _painted(floor_tex, Color("#5a5260") if floor_tex == "madeira" else Color("#4a4458"), 0.5, 0.9)
	var wall_mat := _painted(wall_tex, wall_tint, 0.4)
	var ceil_mat := _flat(Color("#0c0e18"))
	# piso e teto
	_box(Vector3(0, -0.05, 0), Vector3(ROOM_W, 0.1, ROOM_D), floor_mat)
	_box(Vector3(0, ROOM_H, 0), Vector3(ROOM_W, 0.1, ROOM_D), ceil_mat)
	# paredes (fundo, frente com porta, laterais)
	_box(Vector3(0, ROOM_H / 2, -ROOM_D / 2), Vector3(ROOM_W, ROOM_H, 0.2), wall_mat)
	_box(Vector3(-ROOM_W / 2, ROOM_H / 2, 0), Vector3(0.2, ROOM_H, ROOM_D), wall_mat)
	_box(Vector3(ROOM_W / 2, ROOM_H / 2, 0), Vector3(0.2, ROOM_H, ROOM_D), wall_mat)
	# parede da frente com vão de porta no meio
	var fz := ROOM_D / 2
	_box(Vector3(-3.1, ROOM_H / 2, fz), Vector3(ROOM_W - 6.2, ROOM_H, 0.2), wall_mat)
	_box(Vector3(3.1, ROOM_H / 2, fz), Vector3(ROOM_W - 6.2, ROOM_H, 0.2), wall_mat)
	_box(Vector3(0, ROOM_H - 0.4, fz), Vector3(1.8, 0.8, 0.2), wall_mat)
	# batente de neon na porta (saída), com letreiro SAIR
	for ox in [-0.95, 0.95]:
		_box(Vector3(ox, 1.5, fz - 0.02), Vector3(0.08, 3.0, 0.08), _flat(_accent, 3.0))
	_box(Vector3(0, 3.0, fz - 0.02), Vector3(1.9, 0.08, 0.08), _flat(_accent, 3.0))
	var exit := Label3D.new()
	exit.text = "SAIR"
	exit.font = UI.font("title")
	exit.font_size = 70
	exit.pixel_size = 0.004
	exit.modulate = _accent
	exit.position = Vector3(0, 2.7, fz - 0.06)
	exit.shaded = false
	exit.double_sided = true
	add_child(exit)
	_exit_pos = Vector3(0, 1.6, fz - 1.2)
	# tapete/caminho central
	_box(Vector3(0, 0.02, 0), Vector3(2.2, 0.02, ROOM_D - 1.5), _flat(_accent.darkened(0.7)))
	# luzes de teto quentes (poucas) + barra fria atrás
	for lz in [-3.5, 1.0]:
		var l := OmniLight3D.new()
		l.position = Vector3(0, ROOM_H - 0.5, lz)
		l.light_color = _warm
		l.light_energy = 2.2
		l.omni_range = 9.0
		l.shadow_enabled = false
		add_child(l)
		_box(Vector3(0, ROOM_H - 0.15, lz), Vector3(1.4, 0.08, 0.5), _flat(_warm, 2.5))
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 2.0, -ROOM_D / 2 + 1.0)
	fill.light_color = _cool
	fill.light_energy = 1.4
	fill.omni_range = 10.0
	add_child(fill)
	# toque de ambiente conforme a sala
	_dress_room(room)
	# poeira no ar (volume de luz)
	_dust()


func _dress_room(room: String) -> void:
	match room:
		"escritorio":
			# mesa, cadeira, abajur quente num canto
			_box(Vector3(-3.4, 0.4, -4.2), Vector3(2.2, 0.1, 1.1), _painted("madeira", Color("#6a4a30"), 0.6))
			_box(Vector3(-3.4, 0.2, -4.2), Vector3(0.1, 0.4, 0.1), _flat(Color("#1a1420")))
			PolyFace.lamp(self, Vector3(-4.1, 0.45, -4.5), _warm)
			PolyFace.chair(self, Vector3(-3.4, 0, -3.3), Color("#2a1c16"))
		"fliperama":
			PolyFace.arcade(self, Vector3(-4.0, 0, -3.0), _accent, 0.3)
			PolyFace.arcade(self, Vector3(-4.0, 0, -0.5), _cool, -0.3)
			PolyFace.arcade(self, Vector3(4.0, 0, -3.0), _warm, PI + 0.3)
		"lab":
			# bancada com servidores piscando
			_box(Vector3(3.6, 0.5, -3.0), Vector3(1.6, 1.0, 2.6), _painted("metal", Color("#2a3040"), 0.6))
			PolyFace.server_rack(self, Vector3(3.9, 0.0, -3.0), _accent)
			PolyFace.server_rack(self, Vector3(3.9, 0.0, -1.2), _cool)
		"bar":
			# balcão com garrafas iluminadas
			_box(Vector3(3.3, 0.6, -2.0), Vector3(2.0, 1.2, 3.4), _painted("madeira", Color("#3a241a"), 0.6))
			_box(Vector3(3.3, 1.25, -2.0), Vector3(2.2, 0.1, 3.6), _painted("madeira", Color("#5a3a26"), 0.6))
			for i in 6:
				_box(Vector3(4.0, 1.5 + (i % 2) * 0.1, -3.4 + i * 0.5), Vector3(0.12, 0.5, 0.12),
					_flat([_accent, _cool, _warm][i % 3], 1.6))
			PolyFace.lamp(self, Vector3(4.0, 1.3, -0.2), _accent)
		"estudio":
			_box(Vector3(-3.6, 0.0, -4.0), Vector3(0.1, 2.4, 0.1), _flat(Color("#1a1420")))
			PolyFace.mic_stand(self, Vector3(-3.6, 0, -4.0), _accent)
			# painel acústico na parede
			for i in 20:
				_box(Vector3(-ROOM_W / 2 + 0.2, 1.0 + (i % 5) * 0.4, -4.5 + (i / 5) * 0.5),
					Vector3(0.1, 0.34, 0.34), _flat(Color("#241a2a")))


func _dust() -> void:
	var p := CPUParticles3D.new()
	p.amount = 28
	p.lifetime = 7.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(ROOM_W / 2, ROOM_H / 2, ROOM_D / 2)
	p.position = Vector3(0, ROOM_H / 2, 0)
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.15
	p.scale_amount_min = 0.02
	p.scale_amount_max = 0.05
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color(_warm, 0.14)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p.material_override = dm
	add_child(p)


# ───────────────────────────────── itens examináveis nas paredes e na sala
func _place_items() -> void:
	var list: Array = data.get("items", [])
	var n := list.size()
	# distribui ao longo das duas paredes laterais e da parede do fundo
	var slots := _wall_slots(n)
	for i in n:
		var it: Dictionary = list[i]
		var slot: Dictionary = slots[i]
		var node := _make_item(it, slot)
		var light := OmniLight3D.new()
		light.position = slot["pos"] + slot["normal"] * 0.6 + Vector3(0, 0.3, 0)
		light.light_color = _accent
		light.light_energy = 0.0
		light.omni_range = 3.0
		light.shadow_enabled = false
		add_child(light)
		items.append({"node": node, "item": it, "light": light, "seen": false, "pos": slot["pos"] + slot["normal"] * 0.9})
	examined.emit(0, n)


## posições e orientações de cada item, encostados nas paredes, na altura dos olhos.
func _wall_slots(n: int) -> Array:
	var out := []
	var walls := [
		{"normal": Vector3(1, 0, 0), "x": -ROOM_W / 2 + 0.25, "span": ROOM_D - 2.5, "axis": "z"},   # parede esquerda
		{"normal": Vector3(-1, 0, 0), "x": ROOM_W / 2 - 0.25, "span": ROOM_D - 2.5, "axis": "z"},   # parede direita
		{"normal": Vector3(0, 0, 1), "z": -ROOM_D / 2 + 0.25, "span": ROOM_W - 2.5, "axis": "x"},   # fundo
	]
	# ordem de preenchimento: fundo primeiro (destaque), depois laterais
	var order := [2, 0, 1]
	var per := [3, 4, 4]
	var idx := 0
	for wi in order:
		var w: Dictionary = walls[wi]
		var cnt: int = mini(per[order.find(wi)], n - idx)
		for k in cnt:
			var t := (k + 1.0) / (cnt + 1.0)
			var along := lerpf(-w["span"] / 2.0, w["span"] / 2.0, t)
			var pos: Vector3
			if w["axis"] == "z":
				pos = Vector3(w["x"], 1.65, along)
			else:
				pos = Vector3(along, 1.65, w["z"])
			out.append({"pos": pos, "normal": w["normal"], "yaw": atan2(w["normal"].x, w["normal"].z)})
			idx += 1
			if idx >= n:
				return out
	return out


func _tex(path: String) -> Texture2D:
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
	var tex := _tex(str(it.get("img", "")))
	match kind:
		"frame": PolyFace.framed(holder, tex, _accent, _warm)
		"screen": PolyFace.screen(holder, tex, _cool, 1.2)
		"monitor": PolyFace.monitor(holder, tex, _accent)
		"poster": PolyFace.poster(holder, tex, _accent)
		"plaque": PolyFace.plaque(holder, tex, _accent)
		"arcade": PolyFace.arcade_wall(holder, _accent)
		"prop": PolyFace.prop(holder, str(it.get("model", "caixa")), _accent, _warm)
		_: PolyFace.framed(holder, tex, _accent, _warm)
	# plaquinha com o título embaixo
	var lbl := Label3D.new()
	lbl.text = str(it.get("title", "")).to_upper()
	lbl.font = UI.font("type")
	lbl.font_size = 40
	lbl.pixel_size = 0.0022
	lbl.modulate = UI.PAPER
	lbl.position = Vector3(0, -0.95, 0.12)
	lbl.outline_size = 8
	lbl.outline_modulate = Color(0, 0, 0, 0.8)
	lbl.shaded = false
	lbl.double_sided = true
	holder.add_child(lbl)
	return holder


func exit_pos() -> Vector3:
	return _exit_pos


func spawn_pos() -> Vector3:
	return Vector3(0, 1.6, ROOM_D / 2 - 1.8)


func mark_seen(entry: Dictionary) -> void:
	if not entry["seen"]:
		entry["seen"] = true
		_seen += 1
		examined.emit(_seen, items.size())


## item mirado mais próximo à frente do jogador (para o realce e o [E] examinar)
func nearest(pos: Vector3, forward: Vector3) -> Dictionary:
	var best := {}
	var best_score := 0.0
	for e in items:
		var to: Vector3 = e["pos"] - pos
		var d := to.length()
		if d > 3.2:
			continue
		var dir := to.normalized()
		var dot := dir.dot(forward)
		if dot < 0.55:
			continue
		var score := dot - d * 0.12
		if score > best_score:
			best_score = score
			best = e
	return best


func at_exit(pos: Vector3) -> bool:
	return pos.distance_to(Vector3(0, pos.y, ROOM_D / 2)) < 1.6


func _process(dt: float) -> void:
	_t += dt
	# realce do item mirado (luz sobe), leve respiração dos outros
	for e in items:
		var l: OmniLight3D = e["light"]
		var target: float = 2.6 if e.get("_hot", false) else (0.6 if e["seen"] else 0.0)
		l.light_energy = lerpf(l.light_energy, target, clampf(dt * 6.0, 0, 1))
