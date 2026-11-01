extends Node3D
## Cidade noir em primeira pessoa, estilo pincelado (toon + contorno, céu pintado). Uma rua curta
## com prédios dos dois lados; cada projeto é uma vitrine com letreiro de neon, capa na vitrine e
## reflexo pintado na poça. Ao fundo, um skyline de janelas acesas. Performance: GL Compatibility,
## materiais unshaded/emissivos para o neon, poucas luzes reais, chuva e poeira em CPUParticles.

const Player := preload("res://scripts/player.gd")
const Npc := preload("res://scripts/npc.gd")

var player: Player
var kiosks: Array = []        # [{pos, project, light, ring, neon, visited}]
var npcs: Array = []
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _neon_mats: Array = []
var _neon_signs: Array = []
var _halos: Array = []
var _flicker: Array = []

signal visited_changed(count: int, total: int)
signal near_changed(project: Dictionary)


func _ready() -> void:
	_rng.seed = 20260501
	_build_env()
	_build_skyline()
	_build_street()
	_place_kiosks()
	_spawn_player()


# ───────────────────────────────────────────────── ambiente, céu pintado
func _build_env() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	# céu pintado (panorama): só desenhado no fundo, luz ambiente de cor fixa (barato no celular)
	var sky := Sky.new()
	var pm := PanoramaSkyMaterial.new()
	pm.panorama = load("res://assets/sky_night.png")
	pm.energy_multiplier = 1.0
	sky.sky_material = pm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#2a2140")
	e.ambient_light_energy = 1.1
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = Color("#241a3a")
	e.fog_sky_affect = 0.0
	e.fog_depth_begin = 18.0
	e.fog_depth_end = 70.0
	e.fog_density = 1.0
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.25
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.18
	e.adjustment_contrast = 1.1
	we.environment = e
	add_child(we)
	# lua fria, fraca: a cena vive do neon; sombra só no desktop
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("#8ea0d8")
	moon.light_energy = 0.4
	moon.rotation_degrees = Vector3(-50, 128, 0)
	moon.shadow_enabled = not UI.is_mobile()
	moon.directional_shadow_max_distance = 40.0
	add_child(moon)


# ───────────────────────────────────────────────── skyline ao fundo (barato)
func _build_skyline() -> void:
	# silhuetas de prédios distantes com janelas acesas via MultiMesh (um só draw call)
	var wins: Array = []
	for ring in range(0, 3):
		var dist := 55.0 + ring * 18.0
		for i in range(-9, 10):
			var bx := i * 7.0 + _rng.randf_range(-2, 2)
			var bh := _rng.randf_range(12, 34)
			var bw := _rng.randf_range(4, 8)
			var silo := _mat(Color("#0a0e1e").lerp(Color("#161b30"), ring / 3.0))
			var b := _box(Vector3(bx, bh / 2, -dist), Vector3(bw, bh, 2), silo)
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# janelas
			var cols := int(bw / 1.2)
			var rows := int(bh / 1.6)
			for r in range(1, rows):
				for c in range(cols):
					if _rng.randf() > 0.4:
						continue
					var wx := bx - bw / 2 + 0.6 + c * 1.2
					wins.append(Vector3(wx, r * 1.6, -dist + 1.05))
	_window_mm(wins)
	# halos de neon distantes (quads emissivos coloridos no horizonte)
	for i in 8:
		var col: Color = [Color("#ff3d7f"), Color("#4e9bff"), Color("#ffc83d"), Color("#b06bff")][i % 4]
		_flat(Vector3(_rng.randf_range(-40, 40), _rng.randf_range(6, 20), -58 - _rng.randf_range(0, 20)),
			Vector3(_rng.randf_range(2, 5), _rng.randf_range(0.4, 1.2), 0.1), col, 3.5)


func _window_mm(points: Array) -> void:
	if points.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var qm := QuadMesh.new()
	qm.size = Vector2(0.7, 0.9)
	mm.use_colors = true
	mm.mesh = qm
	mm.instance_count = points.size()
	var warm := Color("#ffcf8f")
	var cold := Color("#8fb4ff")
	for i in points.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, points[i]))
		mm.set_instance_color(i, warm.lerp(cold, _rng.randf()) * _rng.randf_range(0.5, 1.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.emission_enabled = true
	m.emission_energy_multiplier = 1.4
	m.vertex_color_is_srgb = true
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# ───────────────────────────────────────────────── materiais e caixas
func _mat(col: Color, emit := 0.0, unshaded := false, rough := 0.92) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = 0.0
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	return m


func _tex_mat(tex: Texture2D, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if emit > 0.0:
		m.emission_enabled = true
		m.emission_texture = tex
		m.emission_energy_multiplier = emit
	return m


var _tex_cache := {}

## Material pincelado tileável (parede, tijolo, asfalto), com triplanar para repetir sem esticar.
func _painted(name: String, tint := Color.WHITE, rough := 0.9, metal := 0.0, scale := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if not _tex_cache.has(name):
		_tex_cache[name] = load("res://assets/tex/%s.png" % name)
	m.albedo_texture = _tex_cache[name]
	m.albedo_color = tint
	m.roughness = rough
	m.metallic = metal
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


## Halo aditivo atrás do neon (glow barato no Compatibility): quad emissivo transparente.
func _halo(pos: Vector3, size: Vector2, col: Color, yaw: float, energy := 1.0) -> void:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(col, 0.35 * energy)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = yaw
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_halos.append(m)


## Vidro da vitrine: escuro, reflexivo, semitransparente (deixa ver o interior discreto).
func _glass_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#0c1526", 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	m.metallic = 0.6
	m.emission_enabled = true
	m.emission = Color("#1a2c4a")
	m.emission_energy_multiplier = 0.2
	return m


## Reflexo alongado e esmaecido do neon no asfalto molhado (faixa vertical borrada).
func _reflection(pos: Vector3, width: float, length: float, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(width, length)
	mi.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(col, 0.22)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = pos
	mi.rotation = Vector3(-PI / 2, 0, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _box(pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _flat(pos: Vector3, size: Vector3, col: Color, emit: float, rot_y := 0.0) -> MeshInstance3D:
	var mi := _box(pos, size, _mat(col, emit, true))
	mi.rotation.y = rot_y
	return mi


# ───────────────────────────────────────────────── rua e prédios
func _build_street() -> void:
	var length := 70.0
	# asfalto molhado: textura pincelada escura, metálico alto = pega o reflexo do neon
	var road_mat := _painted("asfalto", Color.WHITE, 0.22, 0.55, 3.0)
	_box(Vector3(0, -0.05, -length / 2 + 6), Vector3(9, 0.1, length), road_mat)
	# calçada com textura e meio-fio
	var side_mat := _painted("parede", Color("#3a4260"), 0.7, 0.0, 2.0)
	for sx in [-5.6, 5.6]:
		_box(Vector3(sx, 0.08, -length / 2 + 6), Vector3(2.4, 0.26, length), side_mat)
		_box(Vector3(sx + (0.9 if sx < 0 else -0.9) * 1.3, 0.16, -length / 2 + 6), Vector3(0.14, 0.42, length), _mat(Color("#161d30")))
	var line_mat := _mat(Color("#3a3a24"), 0.25)
	for i in range(-2, 24):
		_box(Vector3(0, 0.02, -i * 3.0), Vector3(0.16, 0.02, 1.1), line_mat)
	for z in range(0, 12):
		_building(Vector3(-8.5, 0, -z * 6.0 - 1), 1)
		_building(Vector3(8.5, 0, -z * 6.0 - 1), -1)
	_box(Vector3(0, 7, -length + 6), Vector3(22, 16, 1), _mat(Color("#0c1120")))
	for z in [-3.0, -15.0, -27.0, -39.0]:
		_lamp(Vector3(-4.6, 0, z))
		_lamp(Vector3(4.6, 0, z + 6))
	_billboard_photo()
	_rain()
	_street_dust()


func _building(base: Vector3, facing: int) -> void:
	var h := _rng.randf_range(10.0, 17.0)
	var w := _rng.randf_range(5.4, 6.0)
	var depth := 6.0
	# fachada pincelada escura: tijolo ou concreto, levemente tingida de azul/roxo
	var tint := Color("#2a3252").lerp(Color("#3a2c42"), _rng.randf()).darkened(0.35)
	var wall_tex := "tijolo" if _rng.randf() > 0.5 else "parede"
	_box(base + Vector3(0, h / 2, 0), Vector3(w, h, depth), _painted(wall_tex, tint, 0.95, 0.0, 1.6))
	var face_x := base.x - facing * (w / 2 + 0.02)
	# térreo mais escuro (base da loja) com toldo
	_box(Vector3(face_x + facing * 0.2, 1.3, base.z), Vector3(0.12, 2.6, w - 0.6), _painted("parede", Color("#1a2036"), 0.9, 0.0, 1.2))
	var awning := _box(Vector3(face_x + facing * -0.8, 2.7, base.z), Vector3(1.6, 0.1, w - 0.8), _mat([Color("#4a1a26"), Color("#163040"), Color("#2e2710")][_rng.randi() % 3], 0.0))
	awning.rotation.z = facing * 0.18
	# janelas acesas nos andares (emissivas, com halo fraco)
	var rows := int(h / 1.9)
	for r in range(2, rows):
		for c in range(-1, 2):
			if _rng.randf() > 0.5:
				continue
			var wcol: Color = [Color("#ffcf8f"), Color("#8fb4ff"), Color("#ff9fd0")][_rng.randi() % 3]
			var wz := base.z + c * 1.7 + _rng.randf_range(-0.2, 0.2)
			_flat(Vector3(face_x, r * 1.9, wz), Vector3(0.08, 0.95, 1.0), wcol, _rng.randf_range(0.7, 1.4))


func _lamp(pos: Vector3) -> void:
	_box(pos + Vector3(0, 2.4, 0), Vector3(0.12, 4.8, 0.12), _mat(Color("#161d30")))
	var head := _mat(Color("#ffd9a0"), 3.0, true)
	_box(pos + Vector3(0, 4.7, 0), Vector3(0.5, 0.2, 0.5), head)
	# feixe/halo de luz (cone translúcido emissivo, barato)
	_beam(pos + Vector3(0, 4.5, 0), Color("#ffcf99"))
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0, 4.3, 0)
	l.light_color = Color("#ffcf99")
	l.light_energy = 1.8
	l.omni_range = 8.0
	l.shadow_enabled = false
	add_child(l)
	# reflexo no chão molhado
	_flat(pos + Vector3(0, 0.03, 0), Vector3(0.7, 0.01, 2.2), Color("#ffcf99"), 0.5)
	_flicker.append({"light": l, "base": 1.8, "seed": _rng.randf() * TAU})


func _beam(pos: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.1
	cm.bottom_radius = 2.0
	cm.height = 4.4
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(col, 0.05)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = pos - Vector3(0, 2.2, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _rain() -> void:
	var p := CPUParticles3D.new()
	p.amount = 360 if not UI.is_mobile() else 200
	p.lifetime = 1.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(9, 0.5, 32)
	p.position = Vector3(0, 13, -20)
	p.direction = Vector3(0.12, -1, 0)
	p.spread = 1.5
	p.initial_velocity_min = 17.0
	p.initial_velocity_max = 21.0
	p.gravity = Vector3(0, -9, 0)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.014, 0.42, 0.014)
	p.mesh = bm
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color("#a8c0f0", 0.45)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p.material_override = dm
	add_child(p)


func _street_dust() -> void:
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 6.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(5, 2, 20)
	p.position = Vector3(0, 2, -16)
	p.direction = Vector3(1, 0.2, 0)
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.4
	p.scale_amount_min = 0.02
	p.scale_amount_max = 0.06
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color("#9fb6e8", 0.12)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p.material_override = dm
	add_child(p)


# ───────────────────────────────────────────────── outdoor com a foto do Gabriel
func _billboard_photo() -> void:
	if not ResourceLoader.exists("res://assets/foto_gabriel.png"):
		return
	# grande outdoor iluminado na parede do fundo, perto da entrada
	var frame := _box(Vector3(-8.2, 5.5, -7.0), Vector3(0.3, 4.2, 3.2), _mat(Color("#0a0e1a"), 0.1))
	var tex := load("res://assets/foto_gabriel.png")
	var tr := _box(Vector3(-8.0, 5.6, -7.0), Vector3(0.08, 3.2, 2.4), _tex_mat(tex, 0.6))
	var name := Label3D.new()
	name.text = "GABRIEL INÁCIO"
	name.font = UI.font("title")
	name.font_size = 90
	name.pixel_size = 0.006
	name.modulate = Color("#ffc83d")
	name.position = Vector3(-7.95, 3.5, -7.0)
	name.rotation.y = PI / 2
	name.shaded = false
	name.double_sided = true
	add_child(name)
	var role := Label3D.new()
	role.text = "DEV FULL-STACK"
	role.font = UI.font("type")
	role.font_size = 48
	role.pixel_size = 0.006
	role.modulate = Color("#ff6fae")
	role.position = Vector3(-7.95, 3.0, -7.0)
	role.rotation.y = PI / 2
	role.shaded = false
	role.double_sided = true
	add_child(role)
	var l := OmniLight3D.new()
	l.position = Vector3(-6.5, 5.5, -7.0)
	l.light_color = Color("#ffd9a0")
	l.light_energy = 1.4
	l.omni_range = 6.0
	add_child(l)


# ───────────────────────────────────────────────── vitrines dos projetos
func _place_kiosks() -> void:
	var projs: Array = Data.projects
	for i in projs.size():
		var side := -1 if i % 2 == 0 else 1
		var z := -6.0 - float(i / 2) * 6.0 - (3.0 if side > 0 else 0.0)
		_marker(Vector3(side * 4.9, 0, z), side, projs[i])
	_marker(Vector3(-4.9, 0, -2.0), -1, {"id": "sobre", "title": "SOBRE MIM", "neon": "#ffffff", "special": "about"})
	_marker(Vector3(4.9, 0, -2.0), 1, {"id": "contato", "title": "CONTATO", "neon": "#5fd38a", "special": "contact"})


func _marker(pos: Vector3, side: int, project: Dictionary) -> void:
	var neon := Color(str(project.get("neon", "#ffc83d")))
	var front := pos + Vector3(side * -0.9, 0, 0)   # face voltada para a rua
	var sign_yaw := -PI / 2 * side
	var fx := front.x + side * -0.02               # plano da vitrine, um tiquinho à frente
	# fachada escura e texturizada da loja
	_box(pos + Vector3(0, 1.8, 0), Vector3(0.5, 3.6, 3.4), _painted("parede", Color("#1c2238"), 0.9, 0.0, 1.4))
	# recuo da vitrine: vidro escuro com a capa do projeto atrás (interior visível, discreto)
	var cover := str(project.get("cover", ""))
	var cpath := "res://assets/covers/" + cover
	if cover.ends_with(".png") and ResourceLoader.exists(cpath):
		var scr := _box(Vector3(front.x + side * 0.12, 1.5, front.z), Vector3(0.06, 1.7, 2.3), _tex_mat(load(cpath), 0.55))
		scr.rotation.y = 0.0
	else:
		_flat(Vector3(front.x + side * 0.12, 1.5, front.z), Vector3(0.06, 1.7, 2.3), neon.darkened(0.2), 0.4)
	# vidro da vitrine (reflexo frio, semitransparente)
	var glass := _box(Vector3(fx, 1.5, front.z), Vector3(0.04, 1.9, 2.5), _glass_mat())
	glass.rotation.y = 0.0
	# tubos de neon finos na moldura da vitrine (não painel chapado)
	for off in [Vector3(0, 2.5, 0), Vector3(0, 0.55, 0)]:
		var t := _flat(Vector3(fx, off.y, front.z), Vector3(0.05, 0.05, 2.5), neon, 3.0)
		_neon_mats.append(t.material_override)
	for oz in [-1.3, 1.3]:
		_flat(Vector3(fx, 1.5, front.z + oz), Vector3(0.05, 2.0, 0.05), neon, 3.0)
	_halo(Vector3(fx + side * 0.06, 1.5, front.z), Vector2(2.9, 2.5), neon, sign_yaw, 0.7)
	# letreiro de neon do nome, num quadro escuro acima da porta (letras finas emissivas + halo)
	_box(Vector3(fx, 3.15, front.z), Vector3(0.12, 0.7, 2.6), _mat(Color("#0a0e1a")))
	var sign := Label3D.new()
	sign.text = str(project.get("title", "")).to_upper()
	sign.font = UI.font("title")
	sign.font_size = 150
	sign.pixel_size = 0.0028
	sign.modulate = neon
	sign.position = Vector3(fx + side * 0.08, 3.18, front.z)
	sign.rotation.y = sign_yaw
	sign.shaded = false
	sign.double_sided = true
	sign.outline_size = 0
	add_child(sign)
	_neon_signs.append(sign)
	_halo(Vector3(fx + side * 0.05, 3.18, front.z), Vector2(2.6, 0.9), neon, sign_yaw, 1.0)
	# luz colorida tingindo a parede ao redor
	var l := OmniLight3D.new()
	l.position = front + Vector3(side * -0.4, 2.6, 0)
	l.light_color = neon
	l.light_energy = 2.4
	l.omni_range = 6.5
	l.shadow_enabled = false
	add_child(l)
	# reflexo alongado e borrado do neon no asfalto molhado, esticando para a rua
	_reflection(Vector3(front.x + side * -1.6, 0.03, front.z), 1.1, 4.5, neon)
	_reflection(front + Vector3(side * -0.6, 0.035, 0), 0.5, 2.8, neon.lightened(0.2))
	# anel no chão que acende perto
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.05
	tm.outer_radius = 1.3
	ring.mesh = tm
	ring.material_override = _mat(neon, 3.0, true)
	ring.position = front + Vector3(side * -0.9, 0.06, 0)
	ring.rotation.x = PI / 2
	ring.visible = false
	add_child(ring)
	kiosks.append({"pos": ring.position, "project": project, "light": l, "ring": ring,
		"base_energy": 2.6, "neon": neon, "visited": false})
	# NPC guia dos projetos de jogo e do "sobre"
	if project.get("special", "") == "about" or str(project.get("kind", "")) == "game":
		_guide_npc(front + Vector3(side * -1.6, 0, 0.6), side, project)


func _guide_npc(pos: Vector3, side: int, project: Dictionary) -> void:
	var n := Npc.new()
	n.position = pos
	n.look_yaw = PI / 2 * side
	n.setup(project)
	add_child(n)
	npcs.append(n)


# ───────────────────────────────────────────────── jogador
func _spawn_player() -> void:
	player = Player.new()
	add_child(player)
	player.position = Vector3(0, 1.6, 2.5)


func walk_to(target: Vector3) -> void:
	if player:
		player.auto_walk_to(target)


func visited_count() -> int:
	var c := 0
	for k in kiosks:
		if k.get("visited", false) and not k["project"].has("special"):
			c += 1
	return c


func total_projects() -> int:
	var c := 0
	for k in kiosks:
		if not k["project"].has("special"):
			c += 1
	return c


func mark_visited(project: Dictionary) -> void:
	for k in kiosks:
		if k["project"] == project and not k["visited"]:
			k["visited"] = true
			visited_changed.emit(visited_count(), total_projects())


# ───────────────────────────────────────────────── vida
func _process(dt: float) -> void:
	_t += dt
	for f in _flicker:
		var k := 1.0
		if fmod(_t + float(f["seed"]), 4.5) < 0.25:
			k = 0.4 if sin(_t * 42.0) > 0 else 1.0
		(f["light"] as OmniLight3D).light_energy = float(f["base"]) * k
	for m in _neon_mats:
		(m as StandardMaterial3D).emission_energy_multiplier = 3.0 + sin(_t * 3.0 + m.get_instance_id() % 7) * 0.6
	# leve cintilação do letreiro (flicker de neon velho)
	for s in _neon_signs:
		var fl := 1.0
		if fmod(_t + (s.get_instance_id() % 10) * 0.7, 6.0) < 0.18:
			fl = 0.5 if sin(_t * 50.0) > 0 else 1.0
		(s as Label3D).modulate.a = fl
	if not player:
		return
	var near: Dictionary = {}
	var best := 3.2
	for k in kiosks:
		var d: float = player.global_position.distance_to(k["pos"])
		var on: bool = d < 3.2
		(k["ring"] as Node3D).visible = on
		if on:
			(k["ring"] as Node3D).scale = Vector3.ONE * (1.0 + sin(_t * 4.0) * 0.06)
			if d < best:
				best = d
				near = k
	player.set_target(near)
	near_changed.emit(near.get("project", {}))
