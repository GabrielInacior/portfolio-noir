extends Node3D
## Bairro noir em primeira pessoa: avenida, cruzamento, beco e praça. Cada projeto é uma loja com
## letreiro de neon, vitrine com a colagem do projeto e porta para o interior (loja-museu).
## VIVO: carros passando com faróis refletindo no asfalto molhado, gente andando e conversando,
## vapor dos bueiros, respingos de chuva, neons com falhas, janelas que acendem e apagam, TVs nas
## vitrines, placas balançando, pombos.
## LEVE: geometria estática fundida por pedaço de quarteirão (poucos draw calls, poucas luzes por
## objeto), props repetidos em MultiMesh, luz falsa por emissão/decal, poucas OmniLight reais com
## corte por distância, e modo leve automático no celular.

const Player := preload("res://scripts/player.gd")
const Npc := preload("res://scripts/npc.gd")
const NoirChar := preload("res://scripts/scene3d/noir_character.gd")

var player: Player
var kiosks: Array = []        # [{pos, project, light, ring, neon, visited}]
var npcs: Array = []
var map_rects: Array = []     # ruas para o minimapa [Rect2 em x,z]
var map_labels: Array = []    # [{p: Vector2(x,z), t}]
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _light := false           # modo leve (celular)
var _neon_mats: Array = []
var _neon_signs: Array = []
var _halos: Array = []
var _flicker: Array = []
var _broken: Array = []       # letreiros com falha (piscam de verdade)
var _cars: Array = []
var _walkers: Array = []
var _wins: Array = []         # janelas vivas (acendem/apagam)
var _swing: Array = []        # placas e fios balançando
var _tvs: Array = []          # telas de vitrine
var _fans: Array = []
var _birds: Array = []
var _batch := {}              # chave -> {mat, st}
var _mat_cache := {}
var _tex_cache := {}
var _prop_cache := {}
var _multi := {}              # nome do prop -> [Transform3D]

signal visited_changed(count: int, total: int)
signal near_changed(project: Dictionary)

# ── traçado (x, z); z negativo é "para frente" a partir do início
const AVE_X := 4.5            # meia largura do asfalto da avenida
const SIDE := 2.5             # largura da calçada
const FAC := 7.0              # linha das fachadas da avenida (x = ±7)
const CROSS_Z := -42.0        # centro da rua transversal
const CROSS_HW := 4.0         # meia largura do asfalto da transversal
const ALLEY_Z := -20.0        # centro do beco (lado direito)
const ALLEY_END := 26.0
const PLAZA := Rect2(-66, -56, 18, 28)   # x, z, w, d
const AVE_END := -72.0
const AVE_START := 8.0
const CROSS_END := 48.0


func _ready() -> void:
	_rng.seed = 20260501
	_light = UI.is_mobile()
	_build_env()
	_build_skyline()
	_build_ground()
	_build_blocks()
	_place_shops()
	_build_plaza()
	_build_landmark()
	_street_props()
	_commit_batches()
	_commit_multi()
	_build_life()
	_rain()
	_spawn_player()


# ═════════════════════════════════════════════ ambiente, céu, pós
func _build_env() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var pm := PanoramaSkyMaterial.new()
	pm.panorama = load("res://assets/sky_night.png")
	pm.energy_multiplier = 1.1
	sky.sky_material = pm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#4a4478")
	e.ambient_light_energy = 1.7
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = Color("#2a1d46")
	e.fog_sky_affect = 0.15
	e.fog_depth_begin = 14.0
	e.fog_depth_end = 80.0
	e.fog_density = 1.0
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.45
	e.tonemap_white = 4.0
	if not _light:
		# brilho do neon (glow) só no PC
		e.glow_enabled = true
		e.glow_intensity = 0.9
		e.glow_strength = 1.1
		e.glow_bloom = 0.08
		e.glow_hdr_threshold = 1.0
		e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
		for i in 7:
			e.set_glow_level(i, i >= 1 and i <= 4)
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.2
	e.adjustment_contrast = 1.12
	e.adjustment_brightness = 0.98
	we.environment = e
	add_child(we)
	# lua fria e fraca: a cena vive do neon (contraste quente/frio). Sombra só no PC.
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("#7f90d0")
	moon.light_energy = 0.35
	moon.rotation_degrees = Vector3(-48, 128, 0)
	moon.shadow_enabled = not _light
	moon.directional_shadow_max_distance = 36.0
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(moon)
	# vinheta (pós barato, uma textura por cima da tela)
	var cl := CanvasLayer.new()
	cl.layer = -1
	add_child(cl)
	var vg := TextureRect.new()
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(0, 0, 0, 0))
	gr.set_color(1, Color(0.02, 0.0, 0.06, 0.62))
	gr.add_point(0.55, Color(0, 0, 0, 0.0))
	gt.gradient = gr
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 1.05)
	gt.width = 256
	gt.height = 256
	vg.texture = gt
	vg.stretch_mode = TextureRect.STRETCH_SCALE
	vg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(vg)


# ═════════════════════════════════════════════ materiais
func _mat(col: Color, emit := 0.0, unshaded := false, rough := 0.92) -> StandardMaterial3D:
	var key := "m%s|%.2f|%s|%.2f" % [col.to_html(), emit, unshaded, rough]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	_mat_cache[key] = m
	return m


func _painted(name: String, tint := Color.WHITE, rough := 0.9, metal := 0.0, scale := 1.0) -> StandardMaterial3D:
	var key := "p%s|%s|%.2f|%.2f|%.2f" % [name, tint.to_html(), rough, metal, scale]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	if not _tex_cache.has(name):
		_tex_cache[name] = load("res://assets/tex/%s.png" % name)
	m.albedo_texture = _tex_cache[name]
	m.albedo_color = tint
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = 0.7
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mat_cache[key] = m
	return m


func _tex_mat(tex: Texture2D, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if emit > 0.0:
		m.emission_enabled = true
		m.emission_texture = tex
		m.emission_energy_multiplier = emit
	return m


func _add_mat(col: Color, a: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(col, a)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	return m


# ═════════════════════════════════════════════ geometria fundida (poucos draw calls)
## Caixa estática somada a um lote por material e pedaço de 16 m (cada lote recebe só as luzes perto).
func _sbox(pos: Vector3, size: Vector3, mat: Material, yaw := 0.0) -> void:
	var cell := Vector2i(floori(pos.x / 16.0), floori(pos.z / 16.0))
	var key := "%d|%d,%d" % [mat.get_instance_id(), cell.x, cell.y]
	if not _batch.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batch[key] = {"mat": mat, "st": st, "n": 0}
	var b: Dictionary = _batch[key]
	var st: SurfaceTool = b["st"]
	var basis := Basis(Vector3.UP, yaw)
	var h := size * 0.5
	var faces := [
		[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)], [Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)], [Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)], [Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)]]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var c := n * h
		var uu := u * h
		var vv := v * h
		var pts := [c - uu - vv, c + uu - vv, c + uu + vv, c - uu + vv]
		var wn := basis * n
		var idx := [0, 1, 2, 0, 2, 3]
		for i in idx:
			st.set_normal(wn)
			st.add_vertex(pos + basis * pts[i])
	b["n"] = int(b["n"]) + 1


## Quadrado emissivo (janela, reflexo) com cor por vértice: todas as janelas num lote só.
func _squad(center: Vector3, size: Vector2, normal: Vector3, col: Color, key_mat: Material) -> void:
	var cell := Vector2i(floori(center.x / 32.0), floori(center.z / 32.0))
	var key := "q%d|%d,%d" % [key_mat.get_instance_id(), cell.x, cell.y]
	if not _batch.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batch[key] = {"mat": key_mat, "st": st, "n": 0}
	var st: SurfaceTool = _batch[key]["st"]
	var u := normal.cross(Vector3.UP).normalized()
	if u.length() < 0.1:
		u = Vector3.RIGHT
	var v := u.cross(normal).normalized()
	var hu := u * size.x * 0.5
	var hv := v * size.y * 0.5
	var pts := [center - hu - hv, center + hu - hv, center + hu + hv, center - hu + hv]
	for i in [0, 2, 1, 0, 3, 2]:
		st.set_color(col)
		st.set_normal(normal)
		st.add_vertex(pts[i])


func _commit_batches() -> void:
	for k in _batch:
		var b: Dictionary = _batch[k]
		var mesh: ArrayMesh = (b["st"] as SurfaceTool).commit()
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = b["mat"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if not _light and str(k).begins_with("q") == false else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	_batch.clear()


func _vcol_mat(emit: float) -> StandardMaterial3D:
	var key := "vc%.2f" % emit
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(emit, emit, emit)
	_mat_cache[key] = m
	return m


# ═════════════════════════════════════════════ props da Meshy (MultiMesh)
func _prop_mesh(name: String) -> Mesh:
	if _prop_cache.has(name):
		return _prop_cache[name]
	var path := "res://assets/props/%s.glb" % name
	var mesh: Mesh = null
	if ResourceLoader.exists(path):
		var sc: Node = (load(path) as PackedScene).instantiate()
		for mi in sc.find_children("*", "MeshInstance3D", true, false):
			mesh = (mi as MeshInstance3D).mesh
			break
		sc.free()
	_prop_cache[name] = mesh
	return mesh


func _prop(name: String, pos: Vector3, yaw := 0.0, scl := 1.0) -> void:
	if not _multi.has(name):
		_multi[name] = []
	(_multi[name] as Array).append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scl), pos))


## Um prop solto (para os que se mexem ou recebem luz própria)
func _prop_node(name: String, pos: Vector3, yaw := 0.0, scl := 1.0) -> Node3D:
	var mesh := _prop_mesh(name)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation.y = yaw
	mi.scale = Vector3.ONE * scl
	add_child(mi)
	return mi


func _commit_multi() -> void:
	for name in _multi:
		var mesh := _prop_mesh(name)
		var xs: Array = _multi[name]
		if mesh == null or xs.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xs.size()
		for i in xs.size():
			mm.set_instance_transform(i, xs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	_multi.clear()


# ═════════════════════════════════════════════ skyline (barato: MultiMesh, sem sombra)
func _build_skyline() -> void:
	var boxes := []
	var wins := []
	for ring in range(0, 3):
		var dist := 95.0 + ring * 22.0
		for i in range(0, 46):
			var a := TAU * i / 46.0 + ring * 0.07
			var c := Vector3(cos(a) * dist, 0, sin(a) * dist - 30.0)
			var h := _rng.randf_range(22.0, 60.0) + ring * 10.0
			var w := _rng.randf_range(9.0, 15.0)
			boxes.append([c, Vector3(w, h, w), a])
			var rows := int(h / 3.2)
			for r in range(1, rows):
				for k in 4:
					if _rng.randf() < 0.32:
						var off := Vector3(-sin(a), 0, cos(a)) * ((k - 1.5) * w / 4.5)
						var face := c - Vector3(cos(a), 0, sin(a)) * (w / 2 + 0.05)
						wins.append(Transform3D(Basis(Vector3.UP, -a + PI / 2), face + off + Vector3(0, r * 3.2, 0)))
	var bm := MultiMesh.new()
	bm.transform_format = MultiMesh.TRANSFORM_3D
	var bx := BoxMesh.new()
	bx.size = Vector3.ONE
	bm.mesh = bx
	bm.instance_count = boxes.size()
	for i in boxes.size():
		var b: Array = boxes[i]
		bm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, -b[2]).scaled(b[1]), b[0] + Vector3(0, b[1].y / 2, 0)))
	var bmi := MultiMeshInstance3D.new()
	bmi.multimesh = bm
	bmi.material_override = _mat(Color("#0d0f22"), 0.0, false, 1.0)
	bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bmi)
	var wm := MultiMesh.new()
	wm.transform_format = MultiMesh.TRANSFORM_3D
	wm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 1.1)
	wm.mesh = q
	wm.instance_count = wins.size()
	var cols := [Color("#ffcf8f"), Color("#8fb4ff"), Color("#ff8fc8"), Color("#ffe7b0"), Color("#9ff0ff")]
	for i in wins.size():
		wm.set_instance_transform(i, wins[i])
		wm.set_instance_color(i, cols[_rng.randi() % cols.size()] * _rng.randf_range(0.5, 1.2))
	var wmi := MultiMeshInstance3D.new()
	wmi.multimesh = wm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	wmi.material_override = m
	wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wmi)
	# antenas com luz vermelha piscando no alto dos prédios distantes (vida no horizonte)
	for i in 8:
		var a := TAU * i / 8.0 + 0.3
		var p := Vector3(cos(a) * 100.0, _rng.randf_range(48, 70), sin(a) * 100.0 - 30.0)
		var dot := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		dot.mesh = sm
		dot.material_override = _mat(Color("#ff3048"), 4.0, true)
		dot.position = p
		add_child(dot)
		_flicker.append({"node": dot, "seed": _rng.randf() * TAU, "blink": true})


# ═════════════════════════════════════════════ chão: asfalto, calçadas, faixas, bueiros, poças
func _build_ground() -> void:
	var road := _painted("asfalto", Color("#a8acd0"), 0.22, 0.25, 0.18)
	var walk := _painted("calcada", Color("#8a90b8"), 0.6, 0.0, 0.45)
	var curb := _mat(Color("#2a3048"), 0.0, false, 0.6)
	# avenida
	_sbox(Vector3(0, -0.05, (AVE_START + AVE_END) / 2), Vector3(AVE_X * 2, 0.1, AVE_START - AVE_END), road)
	for sx in [-1, 1]:
		var cx: float = sx * (AVE_X + SIDE / 2)
		for seg in [[AVE_START, CROSS_Z + CROSS_HW + SIDE], [CROSS_Z - CROSS_HW - SIDE, AVE_END]]:
			var z0: float = seg[0]
			var z1: float = seg[1]
			_sbox(Vector3(cx, 0.08, (z0 + z1) / 2), Vector3(SIDE, 0.26, z0 - z1), walk)
			_sbox(Vector3(sx * (AVE_X + 0.07), 0.12, (z0 + z1) / 2), Vector3(0.14, 0.34, z0 - z1), curb)
	# transversal
	_sbox(Vector3(0, -0.05, CROSS_Z), Vector3(CROSS_END * 2, 0.1, CROSS_HW * 2), road)
	for sz in [-1, 1]:
		var cz: float = CROSS_Z + sz * (CROSS_HW + SIDE / 2)
		for seg in [[-CROSS_END, -AVE_X - SIDE], [AVE_X + SIDE, CROSS_END]]:
			var x0: float = seg[0]
			var x1: float = seg[1]
			_sbox(Vector3((x0 + x1) / 2, 0.08, cz), Vector3(x1 - x0, 0.26, SIDE), walk)
			_sbox(Vector3((x0 + x1) / 2, 0.12, CROSS_Z + sz * (CROSS_HW + 0.07)), Vector3(x1 - x0, 0.34, 0.14), curb)
		# quinas da calçada no cruzamento
		for sx in [-1, 1]:
			_sbox(Vector3(sx * (AVE_X + SIDE / 2), 0.08, cz), Vector3(SIDE, 0.26, SIDE), walk)
	# beco (paralelepípedo escuro, sem calçada)
	_sbox(Vector3((FAC + ALLEY_END) / 2, 0.0, ALLEY_Z), Vector3(ALLEY_END - FAC, 0.12, 4.0), _painted("calcada", Color("#3c4058"), 0.5, 0.2, 0.9))
	# faixas: linha central amarela tracejada, faixa de pedestre no cruzamento
	var line := _mat(Color("#c9a640"), 0.25, false, 0.5)
	var z := AVE_START - 2.0
	while z > AVE_END + 2:
		if absf(z - CROSS_Z) > CROSS_HW + 1.0:
			_sbox(Vector3(0, 0.005, z), Vector3(0.16, 0.02, 1.4), line)
		z -= 3.2
	var x := -CROSS_END + 2.0
	while x < CROSS_END - 2:
		if absf(x) > AVE_X + 1.0:
			_sbox(Vector3(x, 0.005, CROSS_Z), Vector3(1.4, 0.02, 0.16), line)
		x += 3.2
	var zebra := _mat(Color("#c8cbd8"), 0.0, false, 0.5)
	for i in range(-3, 4):
		_sbox(Vector3(i * 1.2, 0.006, CROSS_Z + CROSS_HW + 1.2), Vector3(0.6, 0.02, 1.8), zebra)
		_sbox(Vector3(i * 1.2, 0.006, CROSS_Z - CROSS_HW - 1.2), Vector3(0.6, 0.02, 1.8), zebra)
		_sbox(Vector3(AVE_X + 1.2, 0.006, CROSS_Z + i * 1.1), Vector3(1.8, 0.02, 0.55), zebra)
		_sbox(Vector3(-AVE_X - 1.2, 0.006, CROSS_Z + i * 1.1), Vector3(1.8, 0.02, 0.55), zebra)
	# poças escuras e brilhantes (pegam o reflexo pintado)
	var puddle := StandardMaterial3D.new()
	puddle.albedo_color = Color("#05070f")
	puddle.roughness = 0.02
	puddle.metallic = 0.9
	puddle.metallic_specular = 1.0
	for i in 26:
		var pz := _rng.randf_range(AVE_END + 4, AVE_START - 3)
		var px := _rng.randf_range(-AVE_X + 0.8, AVE_X - 0.8)
		if _rng.randf() < 0.35:
			pz = CROSS_Z + _rng.randf_range(-3, 3)
			px = _rng.randf_range(-40, 40)
		_sbox(Vector3(px, 0.005, pz), Vector3(_rng.randf_range(0.8, 2.4), 0.01, _rng.randf_range(0.6, 1.8)), puddle, _rng.randf() * PI)
	# bueiros com vapor
	for p in [Vector3(-1.8, 0, -10), Vector3(2.2, 0, -31), Vector3(-14, 0, CROSS_Z - 1.5), Vector3(18, 0, CROSS_Z + 1.2), Vector3(1.5, 0, -58), Vector3(15, 0, ALLEY_Z)]:
		var mh := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.45
		cy.bottom_radius = 0.45
		cy.height = 0.04
		mh.mesh = cy
		mh.material_override = _painted("metal", Color("#3a3e52"), 0.4, 0.6, 2.0)
		mh.position = p + Vector3(0, 0.01, 0)
		add_child(mh)
		_steam(p)
	map_rects = [Rect2(-AVE_X - SIDE, AVE_END, (AVE_X + SIDE) * 2, AVE_START - AVE_END),
		Rect2(-CROSS_END, CROSS_Z - CROSS_HW - SIDE, CROSS_END * 2, (CROSS_HW + SIDE) * 2),
		Rect2(FAC, ALLEY_Z - 2.0, ALLEY_END - FAC, 4.0), PLAZA]


func _steam(p: Vector3) -> void:
	var s := CPUParticles3D.new()
	s.amount = 10 if _light else 22
	s.lifetime = 3.2
	s.position = p + Vector3(0, 0.1, 0)
	s.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	s.emission_sphere_radius = 0.3
	s.direction = Vector3(0.15, 1, 0)
	s.spread = 14
	s.gravity = Vector3(0.25, 0.35, 0)
	s.initial_velocity_min = 0.5
	s.initial_velocity_max = 1.0
	s.scale_amount_min = 0.8
	s.scale_amount_max = 1.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(1, 1.6))
	s.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.0))
	grad.add_point(0.2, Color(1, 1, 1, 0.22))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	s.color_ramp = grad
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	s.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color("#c9c6e8")
	m.albedo_texture = _soft_dot()
	s.material_override = m
	add_child(s)


var _dot_tex: Texture2D
func _soft_dot() -> Texture2D:
	if _dot_tex:
		return _dot_tex
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	_dot_tex = gt
	return gt


# ═════════════════════════════════════════════ quarteirões: prédios ao longo de cada fachada
## Segmentos de fachada: [início, fim, normal]. A loja ocupa um vão; o resto é prédio comum.
var _shop_slots: Array = []   # [{pos, normal, project}]


func _build_blocks() -> void:
	var segs := [
		# avenida esquerda (fachada x=-7, olha +x) e direita (x=+7, olha -x)
		[Vector3(-FAC, 0, AVE_START), Vector3(-FAC, 0, CROSS_Z + CROSS_HW + SIDE), Vector3(1, 0, 0)],
		[Vector3(-FAC, 0, CROSS_Z - CROSS_HW - SIDE), Vector3(-FAC, 0, AVE_END), Vector3(1, 0, 0)],
		[Vector3(FAC, 0, AVE_START), Vector3(FAC, 0, ALLEY_Z + 2.0), Vector3(-1, 0, 0)],
		[Vector3(FAC, 0, ALLEY_Z - 2.0), Vector3(FAC, 0, CROSS_Z + CROSS_HW + SIDE), Vector3(-1, 0, 0)],
		[Vector3(FAC, 0, CROSS_Z - CROSS_HW - SIDE), Vector3(FAC, 0, AVE_END), Vector3(-1, 0, 0)],
		# transversal: lado norte (z=-35.5, olha -z) e sul (z=-48.5, olha +z)
		[Vector3(-PLAZA.end.x * -1 - 0.0 + PLAZA.end.x, 0, 0), Vector3.ZERO, Vector3.ZERO],
	]
	segs.pop_back()
	var zn := CROSS_Z + CROSS_HW + SIDE
	var zs := CROSS_Z - CROSS_HW - SIDE
	segs.append([Vector3(PLAZA.end.x, 0, zn), Vector3(-FAC, 0, zn), Vector3(0, 0, -1)])
	segs.append([Vector3(FAC, 0, zn), Vector3(CROSS_END, 0, zn), Vector3(0, 0, -1)])
	segs.append([Vector3(PLAZA.end.x, 0, zs), Vector3(-FAC, 0, zs), Vector3(0, 0, 1)])
	segs.append([Vector3(FAC, 0, zs), Vector3(CROSS_END, 0, zs), Vector3(0, 0, 1)])
	# beco: paredes norte e sul, fundo
	segs.append([Vector3(FAC, 0, ALLEY_Z + 2.0), Vector3(ALLEY_END, 0, ALLEY_Z + 2.0), Vector3(0, 0, -1)])
	segs.append([Vector3(FAC, 0, ALLEY_Z - 2.0), Vector3(ALLEY_END, 0, ALLEY_Z - 2.0), Vector3(0, 0, 1)])
	# fim da transversal à direita (parede com outdoor) e começo da avenida (atrás do jogador)
	segs.append([Vector3(CROSS_END, 0, zn), Vector3(CROSS_END, 0, zs), Vector3(-1, 0, 0)])
	segs.append([Vector3(-FAC, 0, AVE_START), Vector3(FAC, 0, AVE_START), Vector3(0, 0, -1)])
	for s in segs:
		_facade_row(s[0], s[1], s[2])
	# fundo do beco (loja do InacioCyber fica aqui, é um prédio próprio)
	_building(Vector3(ALLEY_END + 3.0, 0, ALLEY_Z), Vector3(-1, 0, 0), 6.0, 4.4, true)


func _facade_row(a: Vector3, b: Vector3, normal: Vector3) -> void:
	var length := a.distance_to(b)
	var dir := (b - a).normalized()
	var t := 0.0
	while t < length - 0.5:
		var w := minf(_rng.randf_range(6.0, 9.0), length - t)
		var mid := a + dir * (t + w / 2)
		_building(mid, normal, w, 0.0, false)
		t += w


## Um prédio: corpo pintado (tijolo/concreto/pedra), térreo escuro, cornija, janelas acesas,
## escada de incêndio e aparelhos de ar em alguns, caixa d'água no teto.
func _building(face_center: Vector3, normal: Vector3, w: float, h_force := 0.0, is_end := false) -> void:
	var h := h_force if h_force > 0.0 else _rng.randf_range(9.0, 19.0)
	if is_end:
		h = 14.0
	var depth := 8.0
	var yaw := atan2(normal.x, normal.z)
	var body_c := face_center - normal * (depth / 2)
	var tex: String = ["tijolo", "fachada", "concreto"][_rng.randi() % 3]
	var tint := Color("#7a7eaa").lerp(Color("#8a6890"), _rng.randf()).darkened(_rng.randf_range(0.05, 0.3))
	_sbox(body_c + Vector3(0, h / 2, 0), Vector3(w, h, depth), _painted(tex, tint, 0.9, 0.0, 0.35), yaw)
	# térreo mais escuro com faixa de pedra e cornija no alto
	var right := Vector3(normal.z, 0, -normal.x)
	_sbox(face_center + normal * 0.06 + Vector3(0, 1.75, 0), Vector3(w - 0.1, 3.5, 0.14), _painted("concreto", Color("#22263a"), 0.8, 0.0, 0.5), yaw)
	_sbox(face_center + normal * 0.18 + Vector3(0, 3.55, 0), Vector3(w, 0.22, 0.4), _mat(Color("#191d2e")), yaw)
	_sbox(face_center + normal * 0.22 + Vector3(0, h - 0.2, 0), Vector3(w + 0.2, 0.4, 0.5), _mat(Color("#14182a")), yaw)
	# janelas: moldura escura e vidro aceso (cor por vértice, um lote só); algumas "vivas"
	var rows := int((h - 4.6) / 2.6)
	var cols := int(w / 2.2)
	for r in rows:
		for c in cols:
			var off := (c - (cols - 1) / 2.0) * 2.2
			var y := 5.0 + r * 2.6
			var wp := face_center + right * off + Vector3(0, y, 0) + normal * 0.04
			_sbox(wp - normal * 0.0, Vector3(1.25, 1.55, 0.06), _mat(Color("#0c0f1c")), yaw)
			var lit := _rng.randf()
			if lit < 0.45:
				var wc: Color = [Color("#ffcf8f"), Color("#ffb070"), Color("#8fb4ff"), Color("#ff8fc8"), Color("#a8f0ff")][_rng.randi() % 5]
				wc = wc * _rng.randf_range(0.6, 1.15)
				if lit < 0.06 and _wins.size() < 40:
					_live_window(wp + normal * 0.03, normal, wc)
				else:
					_squad(wp + normal * 0.035, Vector2(1.0, 1.3), normal, wc, _vcol_mat(1.0))
					# persiana: meia janela com faixas
					if _rng.randf() < 0.3:
						_squad(wp + normal * 0.04 + Vector3(0, 0.35, 0), Vector2(1.0, 0.55), normal, wc * 0.35, _vcol_mat(1.0))
			else:
				_squad(wp + normal * 0.035, Vector2(1.0, 1.3), normal, Color("#141a30"), _vcol_mat(1.0))
	# escada de incêndio e ar-condicionado
	if not is_end and h > 11.0 and _rng.randf() < 0.45:
		for k in range(1, mini(4, rows)):
			_prop("escada_incendio", face_center + normal * 0.7 + right * (w * 0.22) + Vector3(0, 3.6 + (k - 1) * 3.0, 0), yaw + PI)
	if _rng.randf() < 0.5:
		var ac := face_center + normal * 0.35 + right * _rng.randf_range(-w / 3, w / 3) + Vector3(0, 4.4 + _rng.randi_range(0, 2) * 2.6, 0)
		_sbox(ac, Vector3(0.9, 0.6, 0.55), _painted("metal", Color("#6a7088"), 0.5, 0.4, 2.0), yaw)
		if _fans.size() < 10:
			var fan := MeshInstance3D.new()
			var fm := CylinderMesh.new()
			fm.top_radius = 0.22
			fm.bottom_radius = 0.22
			fm.height = 0.02
			fan.mesh = fm
			fan.material_override = _mat(Color("#20232f"))
			fan.position = ac + normal * 0.29
			fan.rotation = Vector3(PI / 2, yaw, 0)
			add_child(fan)
			_fans.append(fan)
		# pingos do ar-condicionado
	# caixa d'água / chaminé no teto
	if _rng.randf() < 0.4:
		_sbox(body_c + Vector3(_rng.randf_range(-2, 2), h + 1.0, 0), Vector3(1.6, 2.0, 1.6), _mat(Color("#1c1a24")), yaw)


func _live_window(p: Vector3, normal: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.3)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	mi.material_override = m
	mi.position = p
	mi.rotation.y = atan2(normal.x, normal.z)
	add_child(mi)
	_wins.append({"m": m, "col": col, "next": _rng.randf_range(2, 14), "on": true})


# ═════════════════════════════════════════════ lojas dos projetos
func _place_shops() -> void:
	var by_id := {}
	for p in Data.projects:
		by_id[str(p.get("id", ""))] = p
	var zn := CROSS_Z + CROSS_HW + SIDE
	var zs := CROSS_Z - CROSS_HW - SIDE
	var spots := [
		["rumor", Vector3(-FAC, 0, -6.0), Vector3(1, 0, 0)],
		["buscavagas", Vector3(-FAC, 0, -17.0), Vector3(1, 0, 0)],
		["orbix", Vector3(-FAC, 0, -28.0), Vector3(1, 0, 0)],
		["formataai", Vector3(FAC, 0, -7.0), Vector3(-1, 0, 0)],
		["labia", Vector3(FAC, 0, -29.0), Vector3(-1, 0, 0)],
		["inaciocyber", Vector3(ALLEY_END, 0, ALLEY_Z), Vector3(-1, 0, 0)],
		["fortress", Vector3(-22.0, 0, zn), Vector3(0, 0, -1)],
		["airmessage", Vector3(-26.0, 0, zs), Vector3(0, 0, 1)],
		["ankiana", Vector3(22.0, 0, zn), Vector3(0, 0, -1)],
		["sitembm", Vector3(20.0, 0, zs), Vector3(0, 0, 1)],
	]
	for s in spots:
		if by_id.has(s[0]):
			_shop(s[1], s[2], by_id[s[0]])
	# o LAB (Sobre mim) é o prédio no fim da avenida; contato é a cabine na praça
	_shop(Vector3(0, 0, AVE_END + 0.0), Vector3(0, 0, 1), {"id": "sobre", "title": "LAB · SOBRE MIM", "neon": "#ffffff", "special": "about"}, true)


## Fachada de loja local (frente para +z local): porta, vitrine com a colagem, letreiro de neon
## com halo, toldo, luz colorida tingindo parede e chão, reflexo no asfalto, anel de interação.
func _shop(face: Vector3, normal: Vector3, project: Dictionary, grand := false) -> void:
	var neon := Color(str(project.get("neon", "#ffc83d")))
	var holder := Node3D.new()
	holder.position = face + normal * 0.02
	holder.rotation.y = atan2(normal.x, normal.z)
	add_child(holder)
	var W := 5.6 if not grand else 9.0
	var dark := _mat(Color("#0b0e18"), 0.0, false, 0.6)
	# moldura da loja (pilastras e verga) e fundo do vão
	_lbox(holder, Vector3(-W / 2 + 0.2, 1.75, 0.15), Vector3(0.4, 3.5, 0.3), _painted("concreto", Color("#30344c"), 0.8, 0.0, 0.6))
	_lbox(holder, Vector3(W / 2 - 0.2, 1.75, 0.15), Vector3(0.4, 3.5, 0.3), _painted("concreto", Color("#30344c"), 0.8, 0.0, 0.6))
	_lbox(holder, Vector3(0, 3.3, 0.18), Vector3(W, 0.5, 0.36), dark)
	# porta (à esquerda) com vidro escuro e luz quente vazando
	var door_x := -W / 2 + 1.25
	_lbox(holder, Vector3(door_x, 1.2, 0.02), Vector3(1.2, 2.4, 0.06), _mat(Color("#1a1410")))
	_lbox(holder, Vector3(door_x, 1.35, 0.06), Vector3(0.9, 1.7, 0.02), _mat(Color("#ffb860"), 1.3, true))
	_lbox(holder, Vector3(door_x + 0.35, 1.15, 0.1), Vector3(0.05, 0.3, 0.05), _mat(Color("#c8a050"), 0.6))
	# vitrine com a colagem do projeto (ou a capa)
	var vw := W - 2.6
	var vx := door_x + 0.75 + vw / 2
	var tex: Texture2D = null
	var id := str(project.get("id", ""))
	for path in ["res://assets/data/collages/%s.png" % id, "res://assets/covers/%s" % str(project.get("cover", ""))]:
		if path.ends_with(".png") and ResourceLoader.exists(path):
			tex = load(path)
			break
	var disp := MeshInstance3D.new()
	var dq := QuadMesh.new()
	dq.size = Vector2(vw - 0.2, 2.0)
	disp.mesh = dq
	disp.material_override = _tex_mat(tex, 0.75) if tex else _mat(neon.darkened(0.6), 0.5, true)
	disp.position = Vector3(vx, 1.55, 0.09)
	holder.add_child(disp)
	if not grand and _tvs.size() < 6:
		_tvs.append({"m": disp.material_override, "seed": _rng.randf() * 10.0})
	# vidro e moldura de neon fino ao redor da vitrine
	_lbox(holder, Vector3(vx, 1.55, 0.13), Vector3(vw, 2.3, 0.02), _glass())
	for y in [0.4, 2.7]:
		_lbox(holder, Vector3(vx, y, 0.17), Vector3(vw + 0.1, 0.05, 0.05), _neon_mat(neon))
	for xx in [vx - vw / 2, vx + vw / 2]:
		_lbox(holder, Vector3(xx, 1.55, 0.17), Vector3(0.05, 2.35, 0.05), _neon_mat(neon))
	# halo só nas bordas (os tubos), sem lavar a colagem
	for y in [0.4, 2.7]:
		_lhalo(holder, Vector3(vx, y, 0.16), Vector2(vw + 0.8, 0.5), neon, 0.5)
	for xx in [vx - vw / 2, vx + vw / 2]:
		_lhalo(holder, Vector3(xx, 1.55, 0.16), Vector2(0.5, 2.8), neon, 0.5)
	# letreiro: placa escura e letras de neon com halo; o grande leva um segundo letreiro vertical
	var sign := Label3D.new()
	sign.text = str(project.get("title", "")).to_upper()
	sign.font = UI.font("title")
	sign.font_size = 230 if not grand else 300
	sign.pixel_size = 0.0048 if not grand else 0.006
	sign.modulate = Color(neon.r * 1.6, neon.g * 1.6, neon.b * 1.6)
	sign.position = Vector3(0, 4.15, 0.32)
	sign.shaded = false
	sign.double_sided = true
	sign.outline_size = 14
	sign.outline_modulate = Color(neon, 0.35)
	holder.add_child(sign)
	_neon_signs.append(sign)
	if _rng.randf() < 0.35:
		_broken.append({"node": sign, "seed": _rng.randf() * 8.0})
	_lbox(holder, Vector3(0, 4.15, 0.12), Vector3(W * 0.95, 0.9, 0.22), dark)
	_lhalo(holder, Vector3(0, 4.15, 0.38), Vector2(W * 1.1, 1.6), neon, 0.6)
	# placa de bandeira perpendicular (balança no vento) com o nome curto
	if not grand:
		var flag := Node3D.new()
		flag.position = Vector3(W / 2 - 0.3, 5.6, 0.9)
		holder.add_child(flag)
		_lbox(flag, Vector3(0, -0.55, 0), Vector3(0.08, 1.1, 0.8), dark)
		var fl := Label3D.new()
		fl.text = str(project.get("title", ""))[0]
		fl.font = UI.font("title")
		fl.font_size = 150
		fl.pixel_size = 0.004
		fl.modulate = Color(neon.r * 1.5, neon.g * 1.5, neon.b * 1.5)
		fl.position = Vector3(0.06, -0.55, 0)
		fl.rotation.y = PI / 2
		fl.shaded = false
		fl.double_sided = true
		flag.add_child(fl)
		_swing.append({"node": flag, "seed": _rng.randf() * TAU, "amp": 0.06})
	# toldo (Meshy) sobre a vitrine
	if not grand:
		var aw := _prop_mesh("toldo")
		if aw:
			var an := MeshInstance3D.new()
			an.mesh = aw
			an.position = Vector3(vx, 2.85, 0.6)
			an.scale = Vector3.ONE * (vw / 2.6)
			holder.add_child(an)
	# luz colorida real tingindo parede e chão (corta com a distância)
	var l := OmniLight3D.new()
	l.position = Vector3(0, 2.6, 1.6)
	l.light_color = neon
	l.light_energy = 2.8 if not grand else 4.0
	l.omni_range = 7.5 if not grand else 11.0
	l.distance_fade_enabled = true
	l.distance_fade_begin = 28.0
	l.distance_fade_length = 10.0
	l.shadow_enabled = false
	holder.add_child(l)
	# luz falsa no chão (decal aditivo) e reflexo alongado no asfalto molhado
	_lhalo(holder, Vector3(0, 0.03, 1.8), Vector2(W * 1.3, 4.0), neon, 0.38, true)
	_lhalo(holder, Vector3(-0.8, 0.035, 5.2), Vector2(1.0, 7.0), neon, 0.3, true)
	_lhalo(holder, Vector3(1.2, 0.035, 5.6), Vector2(0.7, 6.0), neon, 0.22, true)
	# luz da vitrine também tinge a parede ao lado (falsa, emissiva)
	_lhalo(holder, Vector3(0, 2.0, 0.1), Vector2(W * 1.6, 4.5), neon, 0.12)
	# anel no chão que acende perto
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.95
	tm.outer_radius = 1.15
	ring.mesh = tm
	ring.material_override = _mat(neon, 3.0, true)
	ring.position = Vector3(door_x + 0.6, 0.08, 1.6)
	ring.visible = false
	holder.add_child(ring)
	var rp := holder.to_global(ring.position)
	kiosks.append({"pos": rp, "project": project, "light": l, "ring": ring, "base_energy": l.light_energy,
		"neon": neon, "visited": false})
	map_labels.append({"p": Vector2(rp.x, rp.z), "t": str(project.get("title", "")), "c": neon})


func _lbox(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _lhalo(parent: Node3D, pos: Vector3, size: Vector2, col: Color, a: float, floor := false) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := _add_mat(col, a)
	m.albedo_texture = _soft_dot()
	mi.material_override = m
	mi.position = pos
	if floor:
		mi.rotation.x = -PI / 2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	_halos.append(m)


func _neon_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col.r * 2.2, col.g * 2.2, col.b * 2.2)
	_neon_mats.append(m)
	return m


func _glass() -> StandardMaterial3D:
	if _mat_cache.has("glass"):
		return _mat_cache["glass"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#0c1526", 0.18)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic = 0.7
	m.metallic_specular = 1.0
	_mat_cache["glass"] = m
	return m


# ═════════════════════════════════════════════ praça: fonte, árvores, bancos, outdoor, cabine
func _build_plaza() -> void:
	var c := Vector3(PLAZA.position.x + PLAZA.size.x / 2, 0, PLAZA.position.y + PLAZA.size.y / 2)
	_sbox(c + Vector3(0, 0.1, 0), Vector3(PLAZA.size.x, 0.2, PLAZA.size.y), _painted("calcada", Color("#4c5272"), 0.7, 0.0, 0.35))
	# degraus da praça (sobe 3 degraus a partir da transversal)
	for i in 3:
		_sbox(Vector3(PLAZA.end.x - 0.5 - i * 0.6, 0.06 + i * 0.06, CROSS_Z), Vector3(0.6, 0.12 + i * 0.12, CROSS_HW * 2 + SIDE * 2), _painted("concreto", Color("#44486a"), 0.7, 0.0, 0.5))
	# fonte com água iluminada
	var stone := _painted("concreto", Color("#5a5e7e"), 0.7, 0.0, 0.6)
	var base := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 2.6
	cy.bottom_radius = 2.8
	cy.height = 0.6
	base.mesh = cy
	base.material_override = stone
	base.position = c + Vector3(0, 0.5, 0)
	add_child(base)
	var water := MeshInstance3D.new()
	var wcy := CylinderMesh.new()
	wcy.top_radius = 2.35
	wcy.bottom_radius = 2.35
	wcy.height = 0.05
	water.mesh = wcy
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color("#123a5a")
	wm.emission_enabled = true
	wm.emission = Color("#2a8fd0")
	wm.emission_energy_multiplier = 0.9
	wm.roughness = 0.0
	wm.metallic = 0.8
	water.material_override = wm
	water.position = c + Vector3(0, 0.78, 0)
	add_child(water)
	var col := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.25
	cc.bottom_radius = 0.4
	cc.height = 1.8
	col.mesh = cc
	col.material_override = stone
	col.position = c + Vector3(0, 1.5, 0)
	add_child(col)
	var jet := CPUParticles3D.new()
	jet.amount = 40 if not _light else 18
	jet.lifetime = 1.2
	jet.position = c + Vector3(0, 2.4, 0)
	jet.direction = Vector3(0, 1, 0)
	jet.spread = 25
	jet.initial_velocity_min = 2.2
	jet.initial_velocity_max = 3.0
	jet.gravity = Vector3(0, -6, 0)
	var dm := SphereMesh.new()
	dm.radius = 0.04
	dm.height = 0.08
	jet.mesh = dm
	jet.material_override = _mat(Color("#9fdcff"), 1.5, true)
	add_child(jet)
	var fl := OmniLight3D.new()
	fl.position = c + Vector3(0, 1.0, 0)
	fl.light_color = Color("#3aa8ff")
	fl.light_energy = 2.2
	fl.omni_range = 7.0
	fl.distance_fade_enabled = true
	fl.distance_fade_begin = 30.0
	add_child(fl)
	# árvores estilizadas (copa facetada) e bancos ao redor
	for k in 6:
		var a := TAU * k / 6.0 + 0.4
		var p := c + Vector3(cos(a) * 6.8, 0, sin(a) * 10.5)
		_tree(p)
		_prop("banco_praca", c + Vector3(cos(a + 0.5) * 4.6, 0.2, sin(a + 0.5) * 6.0), -a - 0.5 + PI / 2)
	for k in 4:
		_prop("poste", c + Vector3((k % 2 - 0.5) * 12.0, 0.2, (k / 2 - 0.5) * 20.0), 0.0)
	# outdoor grande com a foto do Gabriel na parede oeste
	_photo_billboard(Vector3(PLAZA.position.x + 0.3, 0, c.z), Vector3(1, 0, 0))
	# cabine telefônica = CONTATO
	_phone_booth(c + Vector3(5.5, 0.2, -9.0))
	map_labels.append({"p": Vector2(c.x, c.z), "t": "PRAÇA", "c": Color("#9fdcff")})


func _tree(p: Vector3) -> void:
	_sbox(p + Vector3(0, 1.4, 0), Vector3(0.28, 2.8, 0.28), _mat(Color("#2a1e18")))
	var crown := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.6
	sm.height = 2.8
	sm.radial_segments = 7
	sm.rings = 4
	crown.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#1e4a3a")
	m.roughness = 1.0
	crown.material_override = m
	crown.position = p + Vector3(0, 3.6, 0)
	add_child(crown)
	_swing.append({"node": crown, "seed": _rng.randf() * TAU, "amp": 0.03})


func _photo_billboard(face: Vector3, normal: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = face
	holder.rotation.y = atan2(normal.x, normal.z)
	add_child(holder)
	_lbox(holder, Vector3(0, 6.5, 0.1), Vector3(7.6, 5.2, 0.2), _mat(Color("#0a0d18")))
	if ResourceLoader.exists("res://assets/foto_gabriel.png"):
		var ph := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(3.4, 4.4)
		ph.mesh = q
		ph.material_override = _tex_mat(load("res://assets/foto_gabriel.png"), 0.65)
		ph.position = Vector3(-1.8, 6.5, 0.22)
		holder.add_child(ph)
	var nm := Label3D.new()
	nm.text = "GABRIEL\nINÁCIO"
	nm.font = UI.font("title")
	nm.font_size = 220
	nm.pixel_size = 0.004
	nm.modulate = Color(1.6, 1.25, 0.4)
	nm.position = Vector3(1.9, 7.2, 0.25)
	nm.shaded = false
	holder.add_child(nm)
	var rl := Label3D.new()
	rl.text = "GAME DEV · IA · ARQUITETURA"
	rl.font = UI.font("type")
	rl.font_size = 70
	rl.pixel_size = 0.004
	rl.modulate = Color(1.6, 0.6, 1.1)
	rl.position = Vector3(1.9, 5.3, 0.25)
	rl.shaded = false
	holder.add_child(rl)
	for y in [3.9, 9.1]:
		_lbox(holder, Vector3(0, y, 0.3), Vector3(7.8, 0.06, 0.06), _neon_mat(Color("#ffc83d")))
	_lhalo(holder, Vector3(0, 6.5, 0.4), Vector2(9.5, 7.0), Color("#ffc83d"), 0.25)
	var l := SpotLight3D.new()
	l.position = Vector3(0, 10.5, 2.5)
	l.rotation.x = -1.2
	l.light_color = Color("#ffe0a8")
	l.light_energy = 6.0
	l.spot_range = 10.0
	l.spot_angle = 40.0
	holder.add_child(l)


func _phone_booth(p: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = p
	holder.rotation.y = PI / 2
	add_child(holder)
	var red := _mat(Color("#8a1622"), 0.0, false, 0.5)
	_lbox(holder, Vector3(0, 1.25, 0), Vector3(1.1, 2.5, 1.1), red)
	_lbox(holder, Vector3(0, 1.3, 0.56), Vector3(0.8, 1.8, 0.02), _mat(Color("#ffd28a"), 1.4, true))
	var lb := Label3D.new()
	lb.text = "CONTATO"
	lb.font = UI.font("title")
	lb.font_size = 120
	lb.pixel_size = 0.003
	lb.modulate = Color(0.6, 2.0, 1.0)
	lb.position = Vector3(0, 2.75, 0.6)
	lb.shaded = false
	lb.double_sided = true
	holder.add_child(lb)
	_neon_signs.append(lb)
	_lhalo(holder, Vector3(0, 2.75, 0.65), Vector2(2.2, 0.9), Color("#5fd38a"), 0.7)
	var l := OmniLight3D.new()
	l.position = Vector3(0, 2.2, 1.4)
	l.light_color = Color("#5fd38a")
	l.light_energy = 2.0
	l.omni_range = 6.0
	holder.add_child(l)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.95
	tm.outer_radius = 1.15
	ring.mesh = tm
	ring.material_override = _mat(Color("#5fd38a"), 3.0, true)
	ring.position = Vector3(0, 0.05, 1.6)
	ring.visible = false
	holder.add_child(ring)
	var rp := holder.to_global(ring.position)
	var proj := {"id": "contato", "title": "CONTATO", "neon": "#5fd38a", "special": "contact"}
	kiosks.append({"pos": rp, "project": proj, "light": l, "ring": ring, "base_energy": 2.0, "neon": Color("#5fd38a"), "visited": false})
	map_labels.append({"p": Vector2(rp.x, rp.z), "t": "CONTATO", "c": Color("#5fd38a")})


# ═════════════════════════════════════════════ marco no fim da avenida e outdoor à direita
func _build_landmark() -> void:
	# prédio alto do LAB atrás da loja grande, com letreiro vertical
	_sbox(Vector3(0, 13, AVE_END - 5), Vector3(14, 26, 10), _painted("fachada", Color("#3a3e60"), 0.9, 0.0, 0.3))
	var v := Label3D.new()
	v.text = "L\nA\nB"
	v.font = UI.font("title")
	v.font_size = 300
	v.pixel_size = 0.006
	v.modulate = Color(0.8, 1.6, 2.2)
	v.position = Vector3(5.8, 14, AVE_END + 0.3)
	v.shaded = false
	add_child(v)
	_neon_signs.append(v)
	var h := Node3D.new()
	h.position = Vector3(5.8, 14, AVE_END + 0.4)
	add_child(h)
	_lhalo(h, Vector3.ZERO, Vector2(3.0, 11.0), Color("#7fd0ff"), 0.4)
	# outdoor gigante no fim da transversal (direita): anúncio do RUMOR
	var bh := Node3D.new()
	bh.position = Vector3(CROSS_END - 0.3, 0, CROSS_Z)
	bh.rotation.y = -PI / 2
	add_child(bh)
	_lbox(bh, Vector3(0, 8, 0), Vector3(9, 5, 0.3), _mat(Color("#0a0d18")))
	var cover := "res://assets/covers/rumor.png"
	if ResourceLoader.exists(cover):
		var ad := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(8.4, 4.4)
		ad.mesh = q
		ad.material_override = _tex_mat(load(cover), 0.8)
		ad.position = Vector3(0, 8, 0.17)
		bh.add_child(ad)
	_lhalo(bh, Vector3(0, 8, 0.3), Vector2(11, 7), Color("#ffc83d"), 0.25)


# ═════════════════════════════════════════════ props de rua (MultiMesh) e postes com luz
func _street_props() -> void:
	# postes: um a cada ~11 m nos dois lados; só alguns com OmniLight real, os outros emissivos
	var lamp_i := 0
	var z := AVE_START - 4.0
	while z > AVE_END + 3:
		if absf(z - CROSS_Z) > CROSS_HW + SIDE + 1.0:
			for sx in [-1, 1]:
				_street_lamp(Vector3(sx * (AVE_X + 0.55), 0.2, z + (0.0 if sx < 0 else 5.5)), lamp_i % 2 == 0)
				lamp_i += 1
		z -= 11.0
	var x := -CROSS_END + 6.0
	while x < CROSS_END - 4:
		if absf(x) > AVE_X + SIDE + 2.0:
			_street_lamp(Vector3(x, 0.2, CROSS_Z + CROSS_HW + 0.55), lamp_i % 3 == 0)
			_street_lamp(Vector3(x + 5.5, 0.2, CROSS_Z - CROSS_HW - 0.55), lamp_i % 3 == 1)
			lamp_i += 1
		x += 12.0
	# lâmpada pendurada no beco (luz verde de sinal + vapor)
	_street_lamp(Vector3(16.0, 0.0, ALLEY_Z + 1.7), true, Color("#7fffb0"))
	# hidrantes, lixeiras, caixas de correio, bancas, caixas, cones
	for p in [Vector3(-5.2, 0.2, -12), Vector3(5.3, 0.2, -24), Vector3(-5.2, 0.2, -52), Vector3(5.2, 0.2, -62), Vector3(-30, 0.2, CROSS_Z + 5.1)]:
		_prop("hidrante", p, _rng.randf() * TAU)
	for p in [Vector3(-6.4, 0.2, -2), Vector3(6.4, 0.2, -14), Vector3(-6.4, 0.2, -33), Vector3(6.4, 0.2, -55), Vector3(14, 0.06, ALLEY_Z - 1.4), Vector3(19, 0.06, ALLEY_Z + 1.3), Vector3(-36, 0.2, CROSS_Z - 5.5), Vector3(32, 0.2, CROSS_Z + 5.5)]:
		_prop("lixeira", p, _rng.randf() * TAU)
	for p in [Vector3(-5.4, 0.2, -21), Vector3(5.4, 0.2, -46.5)]:
		_prop("caixa_correio", p, PI / 2)
	_prop("banca_jornal", Vector3(-5.6, 0.2, -38.5), PI / 2)
	for p in [Vector3(12, 0.06, ALLEY_Z - 1.2), Vector3(22, 0.06, ALLEY_Z + 1.2), Vector3(23.5, 0.06, ALLEY_Z - 1.0), Vector3(-6.2, 0.2, -63)]:
		_prop("caixas_papelao", p, _rng.randf() * TAU)
	for p in [Vector3(-2.5, 0.0, -64), Vector3(-1.5, 0.0, -65), Vector3(-3.5, 0.0, -65.5)]:
		_prop("cone_transito", p, _rng.randf() * TAU)
	# carros estacionados (encostados no meio-fio)
	for p in [Vector3(-3.3, 0.0, -13.5), Vector3(3.3, 0.0, -25.0), Vector3(-3.3, 0.0, -56.0), Vector3(30.0, 0.0, CROSS_Z - 2.6), Vector3(-34.0, 0.0, CROSS_Z + 2.6)]:
		var yaw := 0.0 if absf(p.z - CROSS_Z) > 3.0 else PI / 2
		_prop("carro_sedan", p, yaw + (PI if p.x > 0 and yaw == 0.0 else 0.0))


func _street_lamp(p: Vector3, real_light: bool, col := Color("#ffcf99")) -> void:
	_prop("poste", p, 0.0)
	var top := p + Vector3(0, 4.25, 0)
	# miolo quente emissivo + halo + feixe + luz falsa no chão
	var bulb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	bulb.mesh = sm
	bulb.material_override = _mat(Color(col.r * 2.5, col.g * 2.5, col.b * 2.5), 0.0, true)
	bulb.position = top
	add_child(bulb)
	var h := Node3D.new()
	h.position = top
	add_child(h)
	_lhalo(h, Vector3.ZERO, Vector2(1.6, 1.6), col, 0.5)
	(h.get_child(0) as MeshInstance3D).material_override.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_beam(top, col)
	var g := Node3D.new()
	g.position = p + Vector3(0, 0.04, 0)
	add_child(g)
	_lhalo(g, Vector3.ZERO, Vector2(6.0, 6.0), col, 0.3, true)
	# reflexo alongado do poste no asfalto molhado (faixa vertical para a rua)
	_lhalo(g, Vector3(-signf(p.x) * 1.8, 0.0, 0.0) if absf(p.z - CROSS_Z) > 6.0 else Vector3(0, 0, -signf(p.z - CROSS_Z) * 1.8), Vector2(0.8, 5.5) if absf(p.z - CROSS_Z) > 6.0 else Vector2(5.5, 0.8), col, 0.22, true)
	if real_light and not (_light and _rng.randf() < 0.5):
		var l := OmniLight3D.new()
		l.position = top - Vector3(0, 0.3, 0)
		l.light_color = col
		l.light_energy = 1.7
		l.omni_range = 9.0
		l.distance_fade_enabled = true
		l.distance_fade_begin = 32.0
		l.distance_fade_length = 10.0
		l.shadow_enabled = false
		add_child(l)
		_flicker.append({"light": l, "base": 1.7, "seed": _rng.randf() * TAU})


func _beam(top: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 1.9
	cm.height = 4.1
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(col, 0.045)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = top - Vector3(0, 2.05, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ═════════════════════════════════════════════ vida: carros, pedestres, pombos, névoa
func _build_life() -> void:
	# carros circulando: faixa da direita da avenida (ida e volta) e da transversal
	var lanes := [
		[Vector3(2.2, 0, AVE_START + 30), Vector3(2.2, 0, AVE_END - 30)],
		[Vector3(-2.2, 0, AVE_END - 30), Vector3(-2.2, 0, AVE_START + 30)],
		[Vector3(-CROSS_END - 25, 0, CROSS_Z - 2.0), Vector3(CROSS_END + 25, 0, CROSS_Z - 2.0)],
		[Vector3(CROSS_END + 25, 0, CROSS_Z + 2.0), Vector3(-CROSS_END - 25, 0, CROSS_Z + 2.0)],
	]
	var ncar := 2 if _light else 4
	for i in ncar:
		var ln: Array = lanes[i % lanes.size()]
		_spawn_car(ln[0], ln[1], float(i) * 0.37)
	# pedestres andando pela calçada e duplas paradas conversando
	var routes := [
		[Vector3(-5.8, 0.2, 4), Vector3(-5.8, 0.2, -34)], [Vector3(5.8, 0.2, -36), Vector3(5.8, 0.2, 2)],
		[Vector3(-5.8, 0.2, -50), Vector3(-5.8, 0.2, -70)], [Vector3(-40, 0.2, CROSS_Z + 5.0), Vector3(-8, 0.2, CROSS_Z + 5.0)],
		[Vector3(10, 0.2, CROSS_Z - 5.0), Vector3(44, 0.2, CROSS_Z - 5.0)], [Vector3(-60, 0.3, -32), Vector3(-52, 0.3, -52)],
	]
	var nwalk := 3 if _light else routes.size()
	var cast_ids := ["detetive", "lena", "bartender", "hacker"]
	for i in nwalk:
		var r: Array = routes[i]
		_spawn_walker(r[0], r[1], cast_ids[i % cast_ids.size()], _rng.randf())
	if not _light:
		_spawn_idle(Vector3(-5.9, 0.2, -9.5), PI / 2, "lena")
		_spawn_idle(Vector3(-5.9, 0.2, -10.6), PI / 2 + PI, "detetive")
		_spawn_idle(Vector3(-55.0, 0.3, -38.0), 0.4, "hacker")
	# pombos no chão da praça (voam quando o jogador chega perto)
	for i in (4 if _light else 9):
		var b := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.18, 0.14, 0.3)
		b.mesh = pm
		b.material_override = _mat(Color("#6a6e86"))
		var home := Vector3(PLAZA.position.x + 4 + _rng.randf() * 10, 0.3, PLAZA.position.y + 6 + _rng.randf() * 16)
		b.position = home
		add_child(b)
		_birds.append({"node": b, "home": home, "fly": 0.0, "seed": _rng.randf() * TAU})
	# névoa baixa em cartões (volume barato) nas pontas das ruas
	for p in [Vector3(0, 1.2, AVE_END + 6), Vector3(-30, 1.2, CROSS_Z), Vector3(30, 1.2, CROSS_Z), Vector3(18, 1.0, ALLEY_Z), Vector3(0, 1.2, -24)]:
		var f := Node3D.new()
		f.position = p
		add_child(f)
		for k in 3:
			var mi := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(18, 3.2)
			mi.mesh = q
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_texture = _soft_dot()
			m.albedo_color = Color("#6a58a8", 0.10)
			m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
			mi.material_override = m
			mi.position = Vector3(k * 2.0 - 2.0, k * 0.3, k * 1.5)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			f.add_child(mi)


func _spawn_car(a: Vector3, b: Vector3, phase: float) -> void:
	var car := Node3D.new()
	add_child(car)
	var body := MeshInstance3D.new()
	body.mesh = _prop_mesh("carro_sedan")
	body.rotation.y = PI   # o modelo do Blender olha para -z; os faróis ficam em +z
	car.add_child(body)
	# faróis (emissivos + halo + feixe no chão) e lanternas vermelhas
	var dir := (b - a).normalized()
	for sx in [-0.62, 0.62]:
		var hl := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.11
		sm.height = 0.18
		hl.mesh = sm
		hl.material_override = _mat(Color(2.5, 2.3, 1.8), 0.0, true)
		hl.position = Vector3(sx, 0.72, 2.25)
		car.add_child(hl)
		var tl := MeshInstance3D.new()
		tl.mesh = sm
		tl.material_override = _mat(Color(2.6, 0.2, 0.25), 0.0, true)
		tl.position = Vector3(sx, 0.78, -2.3)
		car.add_child(tl)
	_lhalo(car, Vector3(0, 0.72, 2.4), Vector2(2.4, 0.9), Color("#fff2d0"), 0.35)
	_lhalo(car, Vector3(0, 0.04, 6.0), Vector2(3.0, 7.0), Color("#fff2d0"), 0.16, true)
	_lhalo(car, Vector3(0, 0.04, -3.4), Vector2(2.2, 2.4), Color("#ff3040"), 0.16, true)
	if not _light:
		var l := OmniLight3D.new()
		l.position = Vector3(0, 1.0, 4.0)
		l.light_color = Color("#fff0d0")
		l.light_energy = 2.4
		l.omni_range = 8.0
		l.distance_fade_enabled = true
		l.distance_fade_begin = 30.0
		car.add_child(l)
	_cars.append({"node": car, "a": a, "b": b, "t": phase, "speed": _rng.randf_range(7.0, 10.0) / a.distance_to(b)})


func _make_person(id: String) -> Node3D:
	var ch := NoirChar.new()
	add_child(ch)
	ch.setup({"id": id, "rim": ["#ff3d8a", "#4ec9ff", "#ffc83d", "#7fffb0"][_rng.randi() % 4]})
	return ch


func _spawn_walker(a: Vector3, b: Vector3, id: String, phase: float) -> void:
	var ch := _make_person(id)
	ch.position = a
	if ch.has_method("play"):
		ch.call("play", "walking")
	_walkers.append({"node": ch, "a": a, "b": b, "t": phase, "speed": 1.25 / a.distance_to(b), "back": false})


func _spawn_idle(p: Vector3, yaw: float, id: String) -> void:
	var ch := _make_person(id)
	ch.position = p
	ch.rotation.y = yaw
	if ch.has_method("play"):
		ch.call("play", ["falando", "pensando", "idle"][_rng.randi() % 3])


func _rain() -> void:
	var p := CPUParticles3D.new()
	p.amount = 520 if not _light else 220
	p.lifetime = 0.9
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(14, 0.5, 14)
	p.direction = Vector3(0.12, -1, 0)
	p.spread = 1.5
	p.initial_velocity_min = 17.0
	p.initial_velocity_max = 21.0
	p.gravity = Vector3(0, -9, 0)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.45, 0.012)
	p.mesh = bm
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color("#b8c8f8", 0.4)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p.material_override = dm
	add_child(p)
	_rain_node = p
	# respingos no chão (anéis rápidos ao redor do jogador)
	var s := CPUParticles3D.new()
	s.amount = 90 if not _light else 30
	s.lifetime = 0.35
	s.local_coords = false
	s.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	s.emission_box_extents = Vector3(8, 0.01, 8)
	s.direction = Vector3(0, 1, 0)
	s.spread = 60
	s.initial_velocity_min = 0.6
	s.initial_velocity_max = 1.2
	s.gravity = Vector3(0, -6, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.02
	sm.height = 0.04
	s.mesh = sm
	s.material_override = _mat(Color("#cfdcff"), 1.2, true)
	add_child(s)
	_splash_node = s


var _rain_node: CPUParticles3D
var _splash_node: CPUParticles3D


# ═════════════════════════════════════════════ jogador
func _spawn_player() -> void:
	player = Player.new()
	add_child(player)
	player.position = Vector3(0, 1.6, 4.0)
	var m := 0.55
	player.walk_rects = [
		Rect2(-FAC + m, AVE_END + m, (FAC - m) * 2, AVE_START - AVE_END - m * 2),
		Rect2(-CROSS_END + m, CROSS_Z - CROSS_HW - SIDE + m, (CROSS_END - m) * 2, (CROSS_HW + SIDE - m) * 2),
		Rect2(FAC - 1.0, ALLEY_Z - 2.0 + m, ALLEY_END - FAC + 1.0 - m, 4.0 - m * 2),
		Rect2(PLAZA.position.x + m, PLAZA.position.y + m, PLAZA.size.x - m + 1.0, PLAZA.size.y - m * 2),
	]


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


# ═════════════════════════════════════════════ animação de tudo
func _process(dt: float) -> void:
	_t += dt
	for f in _flicker:
		if f.has("blink"):
			(f["node"] as Node3D).visible = fmod(_t + float(f["seed"]), 1.6) < 0.9
			continue
		var k := 1.0
		if fmod(_t + float(f["seed"]), 4.5) < 0.25:
			k = 0.35 if sin(_t * 42.0) > 0 else 1.0
		(f["light"] as OmniLight3D).light_energy = float(f["base"]) * k
	for m in _neon_mats:
		var base: Color = (m as StandardMaterial3D).albedo_color
		var pulse := 1.0 + sin(_t * 3.0 + float(m.get_instance_id() % 7)) * 0.08
		(m as StandardMaterial3D).albedo_color = Color(base.r, base.g, base.b) * (pulse / maxf(0.0001, (m.get_meta("p", 1.0))))
		m.set_meta("p", pulse)
	# letreiros com falha: apagam por instantes, às vezes gaguejando
	for b in _broken:
		var s: Label3D = b["node"]
		var ph := fmod(_t + float(b["seed"]), 7.0)
		s.visible = not (ph < 0.12 or (ph > 0.3 and ph < 0.36) or (ph > 3.1 and ph < 3.5 and sin(_t * 60.0) > 0))
	# TVs/vitrines: brilho oscilando como tela ligada
	for tv in _tvs:
		var m: StandardMaterial3D = tv["m"]
		m.emission_energy_multiplier = 0.65 + sin(_t * 7.0 + float(tv["seed"])) * 0.06 + (0.2 if fmod(_t + float(tv["seed"]), 5.0) < 0.08 else 0.0)
	# janelas vivas
	for w in _wins:
		w["next"] = float(w["next"]) - dt
		if float(w["next"]) <= 0.0:
			w["on"] = not bool(w["on"])
			w["next"] = _rng.randf_range(3.0, 16.0)
			(w["m"] as StandardMaterial3D).albedo_color = w["col"] if w["on"] else Color("#141a30")
	for s in _swing:
		var n: Node3D = s["node"]
		n.rotation.z = sin(_t * 1.3 + float(s["seed"])) * float(s["amp"])
	for f in _fans:
		(f as Node3D).rotate_object_local(Vector3.UP, dt * 9.0)
	for c in _cars:
		c["t"] = fmod(float(c["t"]) + dt * float(c["speed"]), 1.0)
		var a: Vector3 = c["a"]
		var b: Vector3 = c["b"]
		var n: Node3D = c["node"]
		n.position = a.lerp(b, float(c["t"]))
		n.rotation.y = atan2((b - a).x, (b - a).z)
	for w in _walkers:
		var a: Vector3 = w["a"]
		var b: Vector3 = w["b"]
		w["t"] = float(w["t"]) + dt * float(w["speed"])
		if float(w["t"]) >= 1.0:
			w["t"] = 0.0
			w["a"] = b
			w["b"] = a
			continue
		var n: Node3D = w["node"]
		n.position = a.lerp(b, float(w["t"]))
		n.rotation.y = atan2((b - a).x, (b - a).z)
	if player:
		var pp := player.global_position
		if _rain_node:
			_rain_node.global_position = Vector3(pp.x, 12.0, pp.z - 4.0)
		if _splash_node:
			_splash_node.global_position = Vector3(pp.x, 0.05, pp.z - 3.0)
		for bd in _birds:
			var n: Node3D = bd["node"]
			var home: Vector3 = bd["home"]
			if pp.distance_to(home) < 4.0:
				bd["fly"] = 1.0
			if float(bd["fly"]) > 0.0:
				bd["fly"] = float(bd["fly"]) - dt * 0.15
				n.position = home + Vector3(sin(_t * 2.0 + float(bd["seed"])) * 3.0, (1.0 - float(bd["fly"])) * 9.0 + 0.3, cos(_t * 2.0 + float(bd["seed"])) * 3.0)
			else:
				n.position = home + Vector3(0, absf(sin(_t * 6.0 + float(bd["seed"]))) * 0.03, 0)
				n.rotation.y = float(bd["seed"]) + sin(_t * 0.7 + float(bd["seed"])) * 0.8
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
