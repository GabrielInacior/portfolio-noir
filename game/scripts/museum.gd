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
var _spin: Array = []             # objetos em pedestal girando devagar


func setup(p: Dictionary, d: Dictionary, lab := false) -> void:
	project = p
	data = d
	is_lab = lab


func _ready() -> void:
	var theme: Dictionary = data.get("theme", {})
	_accent = Color(str(theme.get("accent", "#ffc83d")))
	_warm = Color(str(theme.get("warm", "#ffb23d")))
	# sala de segurança: luz de trabalho branco-azulada; o verde fica só no neon e nas telas
	if str(project.get("id", "")) == "inaciocyber":
		_warm = Color("#cfe0ff")
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
	e.ambient_light_color = Color("#3a3850").lerp(_cool, 0.2)
	e.ambient_light_energy = 0.9
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = Color("#1c1a28").lerp(_cool, 0.15)
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


var _props_cache := {}


## Prop 3D da Meshy (game/assets/props) colocado na sala; frente do modelo = +z.
func _p(name: String, pos: Vector3, yaw := 0.0, scl := 1.0) -> Node3D:
	var path := "res://assets/props/%s.glb" % name
	if not ResourceLoader.exists(path):
		return null
	if not _props_cache.has(name):
		_props_cache[name] = load(path)
	var n: Node3D = (_props_cache[name] as PackedScene).instantiate()
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * scl
	add_child(n)
	return n


func _build_room(room: String, floor_tex: String, wall_tex: String) -> void:
	var wall_tint := Color("#6a6680").lerp(_cool, 0.08)
	var floor_mat := _painted(floor_tex, Color("#9a8a80") if floor_tex == "madeira" else Color("#8a8498"), 0.5, 0.9)
	var wall_mat := _painted(wall_tex, wall_tint, 1.1)
	var ceil_mat := _painted("concreto", Color("#3a3648"), 0.5)
	var base_mat := _flat(Color("#1c1622"))
	_box(Vector3(0, -0.05, 0), Vector3(ROOM_W, 0.1, ROOM_D), floor_mat)
	_box(Vector3(0, ROOM_H, 0), Vector3(ROOM_W, 0.1, ROOM_D), ceil_mat)
	_box(Vector3(0, ROOM_H / 2, -ROOM_D / 2), Vector3(ROOM_W, ROOM_H, 0.2), wall_mat)
	_box(Vector3(-ROOM_W / 2, ROOM_H / 2, 0), Vector3(0.2, ROOM_H, ROOM_D), wall_mat)
	_box(Vector3(ROOM_W / 2, ROOM_H / 2, 0), Vector3(0.2, ROOM_H, ROOM_D), wall_mat)
	var fz := ROOM_D / 2
	_box(Vector3(-3.1, ROOM_H / 2, fz), Vector3(ROOM_W - 6.2, ROOM_H, 0.2), wall_mat)
	_box(Vector3(3.1, ROOM_H / 2, fz), Vector3(ROOM_W - 6.2, ROOM_H, 0.2), wall_mat)
	_box(Vector3(0, ROOM_H - 0.4, fz), Vector3(1.8, 0.8, 0.2), wall_mat)
	# rodapé e roda-teto (acabamento de sala de verdade)
	_box(Vector3(0, 0.09, -ROOM_D / 2 + 0.12), Vector3(ROOM_W, 0.18, 0.06), base_mat)
	_box(Vector3(0, ROOM_H - 0.08, -ROOM_D / 2 + 0.12), Vector3(ROOM_W, 0.12, 0.1), base_mat)
	for x in [-ROOM_W / 2 + 0.12, ROOM_W / 2 - 0.12]:
		_box(Vector3(x, 0.09, 0), Vector3(0.06, 0.18, ROOM_D), base_mat)
		_box(Vector3(x, ROOM_H - 0.08, 0), Vector3(0.1, 0.12, ROOM_D), base_mat)
	if room in ["escritorio", "bar"]:
		var wood := _painted("painel_madeira", Color("#7a5a44"), 0.8)
		_box(Vector3(0, 0.6, -ROOM_D / 2 + 0.13), Vector3(ROOM_W - 0.2, 1.2, 0.05), wood)
		for x in [-ROOM_W / 2 + 0.13, ROOM_W / 2 - 0.13]:
			_box(Vector3(x, 0.6, 0), Vector3(0.05, 1.2, ROOM_D - 0.2), wood)
		_box(Vector3(0, 1.22, -ROOM_D / 2 + 0.16), Vector3(ROOM_W - 0.2, 0.06, 0.1), base_mat)
		for x in [-ROOM_W / 2 + 0.16, ROOM_W / 2 - 0.16]:
			_box(Vector3(x, 1.22, 0), Vector3(0.1, 0.06, ROOM_D - 0.2), base_mat)
	# porta de saída com batente de neon e SAIR
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
	exit.rotation.y = PI
	exit.shaded = false
	exit.double_sided = true
	add_child(exit)
	_exit_pos = Vector3(0, 1.6, fz - 1.2)
	# janela para a rua (à direita da porta): noite e o letreiro da loja
	_street_window(Vector3(3.0, 1.75, fz - 0.12))
	# tapete no centro
	var rug := MeshInstance3D.new()
	var rq := QuadMesh.new()
	rq.size = Vector2(4.2, 6.0)
	rug.mesh = rq
	var rm := StandardMaterial3D.new()
	rm.albedo_texture = load("res://assets/tex/carpete.png")
	rm.albedo_color = Color("#4a3038").lerp(_accent, 0.12)
	rm.uv1_scale = Vector3(2, 3, 1)
	rug.material_override = rm
	rug.rotation.x = -PI / 2
	rug.position = Vector3(0, 0.012, 0.6)
	add_child(rug)
	# luminárias de teto (Meshy) com luz quente; luz fria ao fundo
	for lz in [-2.6, 2.2]:
		_p("luminaria_teto", Vector3(0, ROOM_H - 0.55, lz))
		var l := OmniLight3D.new()
		l.position = Vector3(0, ROOM_H - 0.8, lz)
		l.light_color = _warm
		l.light_energy = 2.4
		l.omni_range = 8.0
		add_child(l)
		var glow := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.14
		sm.height = 0.2
		glow.mesh = sm
		glow.material_override = _flat(_warm.lightened(0.3), 4.0)
		glow.position = Vector3(0, ROOM_H - 0.78, lz)
		add_child(glow)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 2.0, -ROOM_D / 2 + 1.0)
	fill.light_color = _cool
	fill.light_energy = 1.6
	fill.omni_range = 9.0
	add_child(fill)
	_dress_room(room)
	_clutter()
	_dust()


func _street_window(pos: Vector3) -> void:
	var frame := _flat(Color("#141018"))
	_box(pos, Vector3(2.2, 1.7, 0.1), frame)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(2.0, 1.5)
	q.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = load("res://assets/sky_night.png")
	m.uv1_scale = Vector3(0.25, 0.5, 1)
	m.uv1_offset = Vector3(0.3, 0.35, 0)
	q.material_override = m
	q.position = pos + Vector3(0, 0, -0.06)
	q.rotation.y = PI
	add_child(q)
	for k in 3:
		_box(pos + Vector3(-0.66 + k * 0.66, 0, -0.07), Vector3(0.04, 1.5, 0.03), frame)
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0, 0, -1.2)
	l.light_color = _accent
	l.light_energy = 1.4
	l.omni_range = 5.0
	add_child(l)


func _dress_room(room: String) -> void:
	var id := str(project.get("id", ""))
	match room:
		"escritorio":
			if id == "rumor":
				# escritório de detetive: mesa de frente para a porta, máquina de escrever, abajur, telefone
				_p("mesa_detetive", Vector3(0, 0, -2.6), 0.0, 1.15)
				_p("maquina_escrever", Vector3(0.25, 0.92, -2.55), 0.15)
				_p("abajur_banqueiro", Vector3(-0.75, 0.92, -2.85), 0.4)
				_p("telefone_antigo", Vector3(0.9, 0.92, -2.85), -0.4)
				_p("pilha_papeis", Vector3(-0.35, 0.92, -2.3), 0.3)
				_p("caneca", Vector3(0.65, 0.92, -2.25))
				_p("cadeira_escritorio", Vector3(0, 0, -3.6), 0.0)
				_p("quadro_cortica", Vector3(-2.6, 1.0, ROOM_D / 2 - 0.25), PI)
				_desk_lamp_light(Vector3(-0.75, 1.3, -2.85))
			else:
				for x in [-1.6, 1.6]:
					_p("mesa_escritorio", Vector3(x, 0, -2.6), 0.0, 1.2)
					_p("monitor", Vector3(x, 0.9, -2.75), 0.0)
					_p("cadeira_escritorio", Vector3(x, 0, -3.6), 0.0)
					_p("pilha_papeis", Vector3(x + 0.5, 0.9, -2.4), 0.6)
			_p("arquivo_aco", Vector3(-4.3, 0, -5.3), PI / 2)
			_p("estante_livros", Vector3(4.1, 0, -5.4), 0.0)
			_p("cabideiro", Vector3(-4.2, 0, 5.2), 0.0)
			_p("sofa_couro", Vector3(3.4, 0, 4.6), PI)
			_p("planta_vaso", Vector3(4.4, 0, 1.7))
		"fliperama":
			_p("fliperama", Vector3(-4.2, 0, -5.0), PI / 4)
			_p("fliperama", Vector3(4.2, 0, -5.0), -PI / 4)
			_p("fliperama", Vector3(-4.2, 0, 5.0), 3 * PI / 4)
			_p("mesa_cartas", Vector3(0, 0, -1.6), 0.0, 1.1)
			_p("miniatura_fortaleza", Vector3(0, 0.84, -1.7), 0.4, 1.1)
			_p("banqueta_bar", Vector3(-1.1, 0, -1.6))
			_p("banqueta_bar", Vector3(1.1, 0, -1.6))
			_p("trofeu", Vector3(3.9, 0, 4.7), 0.0, 2.0)
			_p("estante_livros", Vector3(4.3, 0, 1.7), -PI / 2)
		"lab":
			_p("mesa_monitores", Vector3(0, 0, -3.0), 0.0, 1.2)
			_p("cadeira_gamer", Vector3(0, 0, -1.8), PI)
			_p("rack_servidor", Vector3(-4.2, 0, -5.2), 0.0)
			_p("rack_servidor", Vector3(-3.4, 0, -5.2), 0.0)
			_p("servidor_ia", Vector3(4.2, 0, -5.2), 0.0)
			_p("bancada_lab", Vector3(3.6, 0, 4.6), PI)
			_p("roteador", Vector3(3.3, 1.0, 4.5), PI)
			_p("planta_vaso", Vector3(-4.3, 0, 4.8))
			_p("estante_livros", Vector3(-4.3, 0, 1.7), PI / 2)
			if id == "inaciocyber":
				_theme_wall()
		"bar":
			_p("balcao_bar", Vector3(0, 0, -4.2), 0.0, 1.6)
			_p("garrafas", Vector3(-0.8, 1.1, -4.3))
			_p("garrafas", Vector3(0.9, 1.1, -4.3), 1.0)
			for x in [-1.5, 0.0, 1.5]:
				_p("banqueta_bar", Vector3(x, 0, -3.1))
			_p("estante_livros", Vector3(4.2, 0, -5.4), 0.0)
			_p("microfone_estudio", Vector3(-3.8, 0, 4.4), 3 * PI / 4)
			_p("sofa_couro", Vector3(3.4, 0, 4.6), PI)
		"estudio":
			_p("mesa_escritorio", Vector3(0, 0, -3.0), 0.0, 1.3)
			_p("mesa_som", Vector3(0, 0.98, -3.0), 0.0, 1.0)
			_p("cadeira_escritorio", Vector3(0, 0, -2.0), PI)
			_p("microfone_estudio", Vector3(-1.9, 0, -1.4), PI / 4)
			_p("monitor", Vector3(1.0, 0.98, -3.2), -0.3)
			_p("estante_livros", Vector3(4.1, 0, -5.4))
			_p("sofa_couro", Vector3(3.4, 0, 4.6), PI)
			_p("planta_vaso", Vector3(-4.3, 0, 4.8))
			for i in 16:
				_box(Vector3(-ROOM_W / 2 + 0.16, 2.6 + (i % 2) * 0.42, -4.6 + (i / 2) * 0.5), Vector3(0.1, 0.38, 0.4), _flat(Color("#241a2a")))


func _clutter() -> void:
	_p("caixas_papelao", Vector3(4.2, 0, -3.9), 0.4, 0.8)
	_p("pilha_livros", Vector3(-4.3, 0, -3.95), 0.5)
	_p("planta_vaso", Vector3(-4.4, 0, -0.3 + 1.5), 0.0, 0.9)
	_p("caneca", Vector3(4.15, 0.0, 4.0))


func _desk_lamp_light(pos: Vector3) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = Color("#ffcf7a")
	l.light_energy = 1.8
	l.omni_range = 3.5
	add_child(l)


## InacioCyber: seis monitores acima da mesa, cada um com um tema da interface (vermelho, verde,
## azul, roxo, amarelo e o seletor de temas).
var _theme_screens: Array = []


func _theme_wall() -> void:
	var names := ["tema_vermelho", "tema_verde", "tema_azul", "tema_roxo", "tema_amarelo", "temas_modal"]
	for i in names.size():
		var path := "res://assets/museum/inaciocyber/%s.jpg" % names[i]
		if not ResourceLoader.exists(path):
			continue
		var col := i % 3
		var row := i / 3
		var pos := Vector3(-1.5 + col * 1.5, 2.25 + (1 - row) * 0.72, -ROOM_D / 2 + 0.3)
		_box(pos + Vector3(0, 0, -0.04), Vector3(1.42, 0.8, 0.06), _flat(Color("#0a0c12")))
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(1.36, 0.6)
		q.mesh = qm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_texture = load(path)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		q.material_override = m
		q.position = pos
		add_child(q)
		_theme_screens.append(m)


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
	var wall_items := []
	var floor_items := []
	for it in list:
		if str(it.get("kind", "")) == "prop":
			floor_items.append(it)
		else:
			wall_items.append(it)
	var slots := _wall_slots(wall_items.size())
	var all := []
	for i in wall_items.size():
		all.append([wall_items[i], slots[i]])
	# objetos 3D em pedestais nas bordas do tapete
	var spots := [Vector3(-2.3, 0, 0.9), Vector3(2.3, 0, 0.9), Vector3(-2.3, 0, 3.1), Vector3(2.3, 0, 3.1)]
	for i in mini(floor_items.size(), spots.size()):
		all.append([floor_items[i], {"pos": spots[i], "normal": Vector3(0, 0, 1), "yaw": 0.0, "floor": true}])
	for pair in all:
		var it: Dictionary = pair[0]
		var slot: Dictionary = pair[1]
		var node := _make_item(it, slot)
		var light := OmniLight3D.new()
		light.position = slot["pos"] + slot["normal"] * 0.6 + Vector3(0, 1.0 if slot.get("floor", false) else 0.3, 0)
		light.light_color = _accent
		light.light_energy = 0.0
		light.omni_range = 3.0
		light.shadow_enabled = false
		add_child(light)
		var look_at: Vector3 = slot["pos"] + (Vector3(0, 1.2, 0) if slot.get("floor", false) else slot["normal"] * 0.9)
		items.append({"node": node, "item": it, "light": light, "seen": false, "pos": look_at})
	examined.emit(0, items.size())


## Até três itens por parede, a 3 m um do outro (nada se sobrepõe). Fundo primeiro (destaque);
## no InacioCyber o fundo é a parede de monitores, então os itens vão para as laterais.
func _wall_slots(n: int) -> Array:
	var out := []
	var back := [Vector3(-3.0, 1.75, -ROOM_D / 2 + 0.25), Vector3(0, 1.75, -ROOM_D / 2 + 0.25), Vector3(3.0, 1.75, -ROOM_D / 2 + 0.25)]
	var left := [Vector3(-ROOM_W / 2 + 0.25, 1.75, -3.4), Vector3(-ROOM_W / 2 + 0.25, 1.75, -0.4), Vector3(-ROOM_W / 2 + 0.25, 1.75, 2.8)]
	var right := [Vector3(ROOM_W / 2 - 0.25, 1.75, -3.4), Vector3(ROOM_W / 2 - 0.25, 1.75, -0.4), Vector3(ROOM_W / 2 - 0.25, 1.75, 2.8)]
	var walls := []
	var use_back := str(project.get("id", "")) != "inaciocyber"
	if use_back:
		walls.append([back, Vector3(0, 0, 1)])
	walls.append([left, Vector3(1, 0, 0)])
	walls.append([right, Vector3(-1, 0, 0)])
	# preenche alternando as paredes para equilibrar a sala
	var k := 0
	while out.size() < n and k < 3:
		for w in walls:
			if out.size() >= n:
				break
			var pts: Array = w[0]
			var order := [1, 0, 2]
			if k < pts.size():
				var pos: Vector3 = pts[order[k]]
				var nrm: Vector3 = w[1]
				out.append({"pos": pos, "normal": nrm, "yaw": atan2(nrm.x, nrm.z)})
		k += 1
	while out.size() < n:
		out.append({"pos": Vector3(-ROOM_W / 2 + 0.25, 1.75, 4.6), "normal": Vector3(1, 0, 0), "yaw": PI / 2})
	return out


## Modelo 3D (Meshy) para cada nome de objeto do manifesto da loja
const PROP_GLB := {"servidor": "servidor_ia", "cadeado": "cadeado", "microfone": "microfone_estudio", "monitor_cv": "monitor",
	"maquina": "maquina_escrever", "typewriter": "maquina_escrever", "telefone": "telefone_antigo", "livro": "pilha_livros",
	"trofeu": "trofeu", "roteador": "roteador", "carta": "mesa_cartas", "fliperama": "fliperama"}


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
	if not slot.get("floor", false):
		holder.scale = Vector3.ONE * {"screen": 0.6, "frame": 0.82, "poster": 0.85, "monitor": 0.95, "plaque": 0.9}.get(kind, 0.85)
	var tex := _tex(str(it.get("img", "")))
	match kind:
		"frame": PolyFace.framed(holder, tex, _accent, _warm)
		"screen": PolyFace.screen(holder, tex, _cool, 1.2)
		"monitor": PolyFace.monitor(holder, tex, _accent)
		"poster": PolyFace.poster(holder, tex, _accent)
		"plaque": PolyFace.plaque(holder, tex, _accent)
		"arcade": PolyFace.arcade_wall(holder, _accent)
		"prop":
			var glb: String = PROP_GLB.get(str(it.get("model", "")), "")
			if glb != "" and ResourceLoader.exists("res://assets/props/%s.glb" % glb):
				# pedestal escuro com faixa de neon e o objeto em cima, girando devagar
				_box(Vector3(0, 0.45, 0), Vector3(0.7, 0.9, 0.7), _flat(Color("#16121c")), holder)
				_box(Vector3(0, 0.9, 0), Vector3(0.76, 0.04, 0.76), _flat(_accent, 2.0), holder)
				var pm := _p(glb, Vector3.ZERO)
				if pm:
					remove_child(pm)
					holder.add_child(pm)
					var big := glb in ["fliperama", "microfone_estudio", "servidor_ia"]
					pm.position = Vector3(0, 0.0 if big else 0.92, 0)
					if big:
						holder.get_child(0).visible = false
						holder.get_child(1).visible = false
					_spin.append(pm)
			else:
				PolyFace.prop(holder, str(it.get("model", "caixa")), _accent, _warm)
		_: PolyFace.framed(holder, tex, _accent, _warm)
	# plaquinha com o título embaixo
	var lbl := Label3D.new()
	lbl.text = str(it.get("title", "")).to_upper()
	lbl.font = UI.font("type")
	lbl.font_size = 40
	lbl.pixel_size = 0.0022
	lbl.modulate = UI.PAPER
	lbl.position = Vector3(0, -0.95, 0.12) if not slot.get("floor", false) else Vector3(0, 0.2, 0.45)
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
	for n in _spin:
		(n as Node3D).rotate_y(dt * 0.5)
	# telas do InacioCyber tremulando como monitor de verdade
	for i in _theme_screens.size():
		var m: StandardMaterial3D = _theme_screens[i]
		var k := 1.6 + sin(_t * 9.0 + i) * 0.05 + (0.3 if fmod(_t + i * 1.7, 6.0) < 0.06 else 0.0)
		m.albedo_color = Color(k, k, k)
