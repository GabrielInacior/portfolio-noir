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
const LowPoly := preload("res://scripts/lowpoly.gd")

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
var traffic := Traffic.new()
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
var _roof_signs := 0

signal visited_changed(count: int, total: int)
signal near_changed(project: Dictionary)

# ── traçado (x, z); z negativo é "para frente" a partir do início
## carros noir a partir de modelos prontos CC0/CC-BY recoloridos (tools/blender/car_import.py; créditos em docs/CREDITOS.md)
const CARS := ["car_sedan_maroon", "car_sedan_teal", "car_sedan_cream", "car_sedan_black", "car_taxi_yellow", "car_police", "car_muscle_crimson", "car_muscle_black", "car_wagon_green", "car_wagon_brown", "car_van_grey", "car_van_navy"]
const AVE_X := 4.5            # meia largura do asfalto da avenida
const SIDE := 2.5             # largura da calçada
const FAC := 7.0              # linha das fachadas da avenida (x = ±7)
const CROSS_Z := -42.0        # centro da rua transversal
const CROSS_HW := 4.0         # meia largura do asfalto da transversal
const ALLEY_Z := -20.0        # centro do beco (lado direito)
const ALLEY_END := 26.0
## fim do beco alargado num pátio (a fachada da loja do InacioCyber tem 5,6 m e o beco só 4 m: antes as
## pilastras, o letreiro e o toldo ficavam espremidos dentro das paredes)
const POCKET_X := 20.5
const POCKET_HW := 3.6
const PLAZA := Rect2(-66, -56, 18, 28)   # x, z, w, d
const AVE_END := -72.0
const AVE_START := 8.0
const CROSS_END := 48.0


const Merge := preload("res://scripts/render/merge.gd")
const Noir := preload("res://scripts/render/noir.gd")


## Montagem fatiada: com `sliced` ligado (o jogo real), a cidade se monta em fatias de ~12 ms por quadro (sem desenhar o 3D enquanto monta: o carregador cobre a tela)
## e avisa o progresso à página; sem ele (sondas de desenvolvimento) tudo roda no mesmo quadro.
signal built
var sliced := false
var is_built := false
var _t_slice := 0
## orçamento de cada fatia da montagem (ms); ?slice=N para comparar (40 ms não mediu melhor que 12 no celular)
var _slice_us := 12000
var _pct := 0.0
var _t_texload := 0
## tempos por parte da montagem (µs), impressos no log PFT (perfil do carregamento)
var _tacc := {}


func _tk(key: String, t0: int) -> void:
	_tacc[key] = int(_tacc.get(key, 0)) + Time.get_ticks_usec() - t0


func _tdump(keys: Array) -> void:
	if not sliced:
		return
	var parts: Array = []
	for k in keys:
		parts.append("%s %d" % [k, int(_tacc.get(k, 0)) / 1000])
	print("PFT tempos (ms): " + ", ".join(parts))


func _slice() -> void:
	if not sliced:
		return
	if Time.get_ticks_usec() - _t_slice > _slice_us:
		await get_tree().process_frame
		_t_slice = Time.get_ticks_usec()


## marca de tempo de uma subetapa (log PFT, só na montagem fatiada)
func _pft(what: String) -> void:
	if sliced:
		print("PFT %5d ms        %s" % [Time.get_ticks_msec(), what])


## progresso 0..1 e etapa legível; a página (boot.js) desenha a barra e o texto
func _prog(p: float, stage: String) -> void:
	_pct = p
	if OS.has_feature("web") and sliced:
		JavaScriptBridge.eval("window.pfProgress&&window.pfProgress(%d,%s)" % [int(p * 100.0), JSON.stringify(stage)], true)
	if sliced:
		print("PFT %5d ms  %3d%%  %s" % [Time.get_ticks_msec(), int(p * 100.0), stage])
		await get_tree().process_frame
		_t_slice = Time.get_ticks_usec()


func _ready() -> void:
	add_to_group("pf_lang_tex")
	_rng.seed = 20260501
	if OS.has_feature("web"):
		var sl := int(str(JavaScriptBridge.eval("(location.search.match(/[?&]slice=([0-9]+)/)||[])[1]||''", true)))
		if sl > 0:
			_slice_us = sl * 1000
	_t_slice = Time.get_ticks_usec()
	# modo leve: celular, GPU fraca ou perfil "batata" (ver UI.quality); corta luzes reais, metade dos
	# anúncios de prédio, menos carros/pedestres, chuva menor e distâncias de desenho menores
	_light = UI.is_mobile() or UI.quality() == 0
	await _prog(0.01, "Lighting the neon")
	_build_env()
	await _prog(0.04, "Raising the skyline")
	_build_skyline()
	await _prog(0.07, "Paving the streets")
	_build_ground()
	await _prog(0.10, "Building the blocks")
	_build_blocks()
	await _prog(0.16, "Opening the shops")
	# imagens grandes decodificadas pelo navegador (render/fast_tex.gd): normalmente já chegaram
	var t_img := Time.get_ticks_msec()
	await FastTex.wait_lang(get_tree(), "en" if L.lang == "en" else "pt")
	_pft("imagens do navegador (espera %d ms)" % (Time.get_ticks_msec() - t_img))
	await _place_shops()
	print("PFT shops: tex load = %d ms" % (_t_texload / 1000))
	await _prog(0.34, "Laying the plaza")
	_build_plaza()
	_build_landmark()
	await _prog(0.40, "Placing street props")
	_street_props()
	_dress_alley()
	await _prog(0.46, "Hanging billboards")
	_build_billboards()
	_pft("outdoors")
	_tdump(["outdoor_textura"])
	if OS.get_environment("NOADS") == "":
		await _slice()
		_build_ads()
		_pft("anúncios")
		_tdump(["anuncio_paginas", "anuncio_telhados"])
	await _prog(0.54, "Wiring the signs")
	_build_wayfinding()
	_build_extras()
	await _prog(0.60, "Gluing the city")
	_build_door_markers()
	_commit_batches()
	_commit_multi()
	await _prog(0.66, "Bringing it to life")
	_build_life()
	await _prog(0.74, "Starting the rain")
	_rain()
	_spawn_player()
	await _prog(0.78, "Optimizing the geometry")
	# teto de segmentos nas primitivas e partículas sem sombra (ver lowpoly.gd)
	await LowPoly.node(self, _slice)
	_pft("lowpoly")
	await LowPoly.cull_by_size(self, _near(), _mid(), _slice)
	_pft("cull_by_size")
	# fusão das malhas estáticas por célula+material (de ~3.700 nós para algumas centenas de draw calls)
	if OS.get_environment("NOMERGE") == "":
		var ex: Array = []
		for c in _cars:
			ex.append(c["node"])
		for w in _walkers:
			ex.append(w["node"])
		for b in _birds:
			ex.append(b["node"])
		for sw in _swing:
			ex.append(sw["node"])
		for f in _fans:
			ex.append(f)
		for sl in _searchlights:
			ex.append(sl["n"])
		for f in _flicker:
			if f.has("node"):
				ex.append(f["node"])
		for b in _broken:
			ex.append(b["node"])
		for k in kiosks:
			ex.append(k["ring"])
		for n in npcs:
			ex.append(n)
		if _rain_node:
			ex.append(_rain_node)
		if _splash_node:
			ex.append(_splash_node)
		var dm: Array = _neon_mats.duplicate()
		for w in _wins:
			dm.append(w["m"])
		for tv in _tvs:
			dm.append(tv["m"])
		for tv in _ad_tvs:
			dm.append(tv["mat"])
		for bl in _blinkers:
			dm.append(bl["m"])
		# mundo noir: materiais viram o shader próprio ANTES da fusão (cor/emissão/rugosidade por vértice
		# deixam a fusão juntar muito mais); os que o jogo anima seguem sincronizados por quadro
		if Noir.enabled():
			for k in kiosks:
				(k["ring"] as Node).set_meta("noir_skip", true)
			Noir.convert_tree(self)
			_pft("noir convert_tree")
			var dmc: Array = []
			for m in dm:
				if m in _neon_mats:
					# neon: o pulso roda no shader (sem mexer em material por quadro)
					var nm: Material = Noir.conv(m)
					if nm is ShaderMaterial:
						Noir.set_p(nm, "pulse_seed", float(m.get_instance_id() % 7))
						dmc.append(nm)
						continue
				Noir.track(m)
				dmc.append(Noir.conv(m))
			dm = dmc
		Merge._slow = OS.get_environment("PF_MERGESLOW") != "" or (OS.has_feature("web") and UI.js_flag("/[?&]mergeslow=1/.test(location.search)?1:0"))
		Merge._gpu_read = OS.get_environment("PF_MERGEGPU") != "" or (OS.has_feature("web") and UI.js_flag("/[?&]mergegpu=1/.test(location.search)?1:0"))
		var r: Dictionary = await Merge.merge(self, ex, _near(), _mid(), dm, _slice)
		print("MERGE cidade: %d malhas -> %d" % [r["in"], r["out"]])
		_pft("merge")
	if Noir.enabled():
		# luz por objeto como no Compatibility (ver noir.gd); o que anda leva as luzes mais perto da câmera
		var moving: Array = []
		for c in _cars:
			moving.append(c["node"])
		for w in _walkers:
			moving.append(w["node"])
		for b in _birds:
			moving.append(b["node"])
		for sw in _swing:
			moving.append(sw["node"])
		for sl in _searchlights:
			moving.append(sl["n"])
		moving.append_array(_fans)
		moving.append_array(npcs)
		Noir.assign_sets(self, moving)
		_pft("assign_sets")
	print("PFT nodes: mesh=%d label=%d mm=%d light=%d part=%d" % [find_children("*", "MeshInstance3D", true, false).size(), find_children("*", "Label3D", true, false).size(), find_children("*", "MultiMeshInstance3D", true, false).size(), find_children("*", "Light3D", true, false).size(), find_children("*", "CPUParticles3D", true, false).size()])
	await _warm_up()
	is_built = true
	built.emit()


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
	# no navegador a sombra direcional custa caro demais no WebGL (passada extra); só no app nativo
	moon.shadow_enabled = not _light and not OS.has_feature("web") and UI.quality() == 2
	moon.directional_shadow_max_distance = 26.0
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
	# superfícies (paredes, piso, calçada, asfalto): texel nítido estilo PS1 (texturas de 128 px, rodada 4)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
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


## Ajusta a UV para a imagem PREENCHER a superfície sem esticar (corta o excesso, centralizado).
func _cover(m: StandardMaterial3D, tex: Texture2D, w: float, h: float) -> StandardMaterial3D:
	if tex == null:
		return m
	var r_img := float(tex.get_width()) / maxf(1.0, tex.get_height())
	var r_surf := w / maxf(0.001, h)
	if r_img > r_surf:
		var su := r_surf / r_img
		m.uv1_scale = Vector3(su, 1, 1)
		m.uv1_offset = Vector3((1.0 - su) / 2.0, 0, 0)
	else:
		var sv := r_img / r_surf
		m.uv1_scale = Vector3(1, sv, 1)
		m.uv1_offset = Vector3(0, (1.0 - sv) / 2.0, 0)
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
	if _ghost:
		return
	if _clip_alley:
		# paredes do beco (yaw 0 ou PI: largura no eixo x): corta no começo do pátio
		var x0 := pos.x - size.x / 2.0
		if x0 >= POCKET_X - 0.01:
			return
		if pos.x + size.x / 2.0 > POCKET_X:
			if size.x < 2.0:
				return
			pos = Vector3((x0 + POCKET_X) / 2.0, pos.y, pos.z)
			size = Vector3(POCKET_X - x0, size.y, size.z)
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
		var idx := [0, 2, 1, 0, 3, 2]   # horário = frente no Godot
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


## Janela com interior falso (atlas 4x4 de quartos/cozinhas/TV), cor por vértice dá o brilho.
func _wquad(center: Vector3, size: Vector2, normal: Vector3, cell: int, col: Color) -> void:
	if _ghost or _clipped(center.x, size.x / 2.0):
		return
	var m := _win_mat()
	var c2 := Vector2i(floori(center.x / 32.0), floori(center.z / 32.0))
	var key := "w|%d,%d" % [c2.x, c2.y]
	if not _batch.has(key):
		var st0 := SurfaceTool.new()
		st0.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batch[key] = {"mat": m, "st": st0, "n": 0}
	var st: SurfaceTool = _batch[key]["st"]
	var u := normal.cross(Vector3.UP).normalized()
	var v := Vector3.UP
	var hu := -u * size.x * 0.5
	var hv := v * size.y * 0.5
	var pts := [center - hu - hv, center + hu - hv, center + hu + hv, center - hu + hv]
	var cx := (cell % 4) / 4.0
	var cy := (cell / 4) / 4.0
	var uvs := [Vector2(cx + 0.01, cy + 0.24), Vector2(cx + 0.24, cy + 0.24), Vector2(cx + 0.24, cy + 0.01), Vector2(cx + 0.01, cy + 0.01)]
	for i in [0, 2, 1, 0, 3, 2]:
		st.set_color(col)
		st.set_uv(uvs[i])
		st.set_normal(normal)
		st.add_vertex(pts[i])


func _win_mat() -> StandardMaterial3D:
	if _mat_cache.has("win"):
		return _mat_cache["win"]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = load("res://assets/tex/janelas_atlas.png")
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache["win"] = m
	return m


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


# ═════════════════════════════════════════════ props do kit Blender (MultiMesh)
func _prop_mesh(name: String) -> Mesh:
	if _prop_cache.has(name):
		return _prop_cache[name]
	var path := "res://assets/props/%s.glb" % name
	if name.begins_with("car_"):
		path = "res://assets/vehicles/%s.glb" % name
	var mesh: Mesh = null
	if ResourceLoader.exists(path):
		var sc: Node = (load(path) as PackedScene).instantiate()
		for mi in sc.find_children("*", "MeshInstance3D", true, false):
			mesh = (mi as MeshInstance3D).mesh
			break
		sc.free()
	load("res://scripts/ps1.gd").mesh(mesh)
	_prop_cache[name] = mesh
	return mesh


func _prop(name: String, pos: Vector3, yaw := 0.0, scl := 1.0) -> void:
	if _ghost:
		return
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
			# recuo no topo (volume) e, em alguns, letreiro de neon no telhado
			boxes.append([c + Vector3(0, h, 0), Vector3(w * 0.6, h * 0.18, w * 0.6), a])
			if ring == 0 and _rng.randf() < 0.22 and _roof_signs < 9:
				_roof_signs += 1
				var lb := Label3D.new()
				lb.text = ["HOTEL", "NOODLES", "24H", "CINEMA", "RÁDIO", "BAR", "JAZZ", "DINER", "MOTEL"][_roof_signs - 1]
				lb.font = UI.font("title")
				lb.font_size = 400
				lb.pixel_size = 0.03
				var cc: Color = [Color("#ff3d8a"), Color("#4ec9ff"), Color("#ffc83d"), Color("#7fffb0")][_rng.randi() % 4]
				lb.modulate = Color(cc.r * 1.8, cc.g * 1.8, cc.b * 1.8)
				lb.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
				lb.position = c + Vector3(0, h * 1.18 + 3.0, 0)
				lb.shaded = false
				add_child(lb)
				_neon_signs.append(lb)
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
		var bx2: Array = boxes[i]
		bm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, -bx2[2]).scaled(bx2[1]), bx2[0] + Vector3(0, bx2[1].y / 2, 0)))
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
	_sbox(Vector3((POCKET_X + ALLEY_END) / 2, 0.0, ALLEY_Z), Vector3(ALLEY_END - POCKET_X, 0.12, POCKET_HW * 2), _painted("calcada", Color("#3c4058"), 0.5, 0.2, 0.9))
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
		Rect2(FAC, ALLEY_Z - 2.0, ALLEY_END - FAC, 4.0), Rect2(POCKET_X, ALLEY_Z - POCKET_HW, ALLEY_END - POCKET_X, POCKET_HW * 2), PLAZA]


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
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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


var _reserved: Array = []    # fachadas de loja (Vector3): sem escada/ar-condicionado na frente do letreiro


func _near_shop(p: Vector3) -> bool:
	for q in _reserved:
		if Vector2(p.x - q.x, p.z - q.z).length() < 5.0:
			return true
	return false


func _build_blocks() -> void:
	var zn0 := CROSS_Z + CROSS_HW + SIDE
	var zs0 := CROSS_Z - CROSS_HW - SIDE
	_reserved = [Vector3(-FAC, 0, -6.0), Vector3(-FAC, 0, -17.0), Vector3(-FAC, 0, -28.0), Vector3(FAC, 0, -7.0),
		Vector3(FAC, 0, -29.0), Vector3(-22.0, 0, zn0), Vector3(-26.0, 0, zs0), Vector3(22.0, 0, zn0), Vector3(20.0, 0, zs0),
		Vector3(-40.0, 0, zs0), Vector3(34.0, 0, zn0), Vector3(0, 0, AVE_END)]
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
	segs.append([Vector3(FAC, 0, ALLEY_Z + 2.0), Vector3(ALLEY_END, 0, ALLEY_Z + 2.0), Vector3(0, 0, -1), true])
	segs.append([Vector3(FAC, 0, ALLEY_Z - 2.0), Vector3(ALLEY_END, 0, ALLEY_Z - 2.0), Vector3(0, 0, 1), true])
	# fim da transversal à direita (parede com outdoor) e começo da avenida (atrás do jogador)
	segs.append([Vector3(CROSS_END, 0, zn), Vector3(CROSS_END, 0, zs), Vector3(-1, 0, 0)])
	segs.append([Vector3(-FAC, 0, AVE_START), Vector3(FAC, 0, AVE_START), Vector3(0, 0, -1)])
	# praça: prédios nos lados norte, sul e oeste (o outdoor fica na fachada oeste)
	segs.append([Vector3(PLAZA.position.x, 0, PLAZA.end.y), Vector3(PLAZA.end.x, 0, PLAZA.end.y), Vector3(0, 0, -1)])
	segs.append([Vector3(PLAZA.position.x, 0, PLAZA.position.y), Vector3(PLAZA.end.x, 0, PLAZA.position.y), Vector3(0, 0, 1)])
	segs.append([Vector3(PLAZA.position.x, 0, PLAZA.end.y), Vector3(PLAZA.position.x, 0, PLAZA.position.y), Vector3(1, 0, 0)])
	# fecha as quinas entre a transversal e a praça
	segs.append([Vector3(PLAZA.end.x, 0, PLAZA.end.y), Vector3(PLAZA.end.x, 0, zn), Vector3(-1, 0, 0)])
	segs.append([Vector3(PLAZA.end.x, 0, zs), Vector3(PLAZA.end.x, 0, PLAZA.position.y), Vector3(-1, 0, 0)])
	for s in segs:
		# paredes do beco: o trecho do pátio do fim é cortado (geometria fora), sem mudar o sorteio do resto da cidade
		_clip_alley = s.size() > 3
		_facade_row(s[0], s[1], s[2])
		_clip_alley = false
	# fundo do beco (loja do InacioCyber fica aqui, é um prédio próprio)
	# o prédio antigo do fundo (atrás da loja, mais longe) vira "fantasma": consome o mesmo sorteio, não aparece
	_ghost = true
	_building(Vector3(ALLEY_END + 3.0, 0, ALLEY_Z), Vector3(-1, 0, 0), 6.0, 4.4, true)
	_ghost = false
	_build_pocket()


## Pátio no fim do beco (a fachada da loja do InacioCyber tem 5,6 m e o beco só 4 m: as pilastras, o letreiro e
## o toldo ficavam dentro das paredes). Sorteio próprio (o resto da cidade fica idêntico), sem janelas vivas,
## ventiladores, ar-condicionado ou escada; entra no fim da lista de prédios (anúncios dos outros não mudam).
var _clip_alley := false
var _ghost := false
var _quiet := false
var _fan_n := 0
var _ghost_bin := Node3D.new()


func _host(n: Node) -> void:
	if _ghost:
		_ghost_bin.add_child(n)
	else:
		add_child(n)


func _clipped(x: float, half: float) -> bool:
	return _clip_alley and x + half > POCKET_X


func _build_pocket() -> void:
	var main_rng := _rng
	_rng = RandomNumberGenerator.new()
	_rng.seed = 26_2026
	_quiet = true
	_facade_row(Vector3(POCKET_X, 0, ALLEY_Z + POCKET_HW), Vector3(POCKET_X, 0, ALLEY_Z + 2.0), Vector3(1, 0, 0))
	_facade_row(Vector3(POCKET_X, 0, ALLEY_Z - 2.0), Vector3(POCKET_X, 0, ALLEY_Z - POCKET_HW), Vector3(1, 0, 0))
	_facade_row(Vector3(POCKET_X, 0, ALLEY_Z + POCKET_HW), Vector3(ALLEY_END, 0, ALLEY_Z + POCKET_HW), Vector3(0, 0, -1))
	_facade_row(Vector3(POCKET_X, 0, ALLEY_Z - POCKET_HW), Vector3(ALLEY_END, 0, ALLEY_Z - POCKET_HW), Vector3(0, 0, 1))
	_building(Vector3(ALLEY_END, 0, ALLEY_Z), Vector3(-1, 0, 0), POCKET_HW * 2 + 0.4, 4.4, true)
	_quiet = false
	_rng = main_rng


func _exit_tree() -> void:
	if is_instance_valid(_ghost_bin):
		_ghost_bin.free()


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
	var bent := {"face": face_center, "normal": normal, "w": w, "h": h, "busy": _near_shop(face_center), "end": is_end}
	if _ghost or (_clip_alley and face_center.x - w / 2.0 >= POCKET_X - 0.01):
		bent["ghost"] = true   # anúncios e telhado deste prédio não aparecem (contadores seguem iguais)
	elif _clipped(face_center.x, w / 2.0):
		# prédio cortado pelo pátio: anúncios e telhado no que sobrou da fachada
		var x0 := face_center.x - w / 2.0
		bent["w_full"] = w
		bent["w"] = POCKET_X - x0
		bent["face"] = Vector3((x0 + POCKET_X) / 2.0, face_center.y, face_center.z)
	if _quiet:
		bent["alt"] = true
	_bldgs.append(bent)
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
			# moldura e peitoril pintados, vidro com o interior falso do atlas
			_sbox(wp, Vector3(1.3, 1.6, 0.06), _mat(Color("#1a1d2c")), yaw)
			_sbox(wp + normal * 0.1 + Vector3(0, -0.84, 0), Vector3(1.45, 0.1, 0.24), _mat(Color("#3a3e56")), yaw)
			var lit := _rng.randf()
			var cell := _rng.randi() % 16
			if lit < 0.5:
				var wc := Color(1, 1, 1) * _rng.randf_range(0.75, 1.25)
				if lit < 0.06 and _wins.size() < 40 and not _quiet:
					_live_window(wp + normal * 0.03, normal, wc, cell)
				else:
					_wquad(wp + normal * 0.035, Vector2(1.1, 1.4), normal, cell, wc)
			else:
				# apagada: o quarto mal se vê (luz da rua)
				_wquad(wp + normal * 0.035, Vector2(1.1, 1.4), normal, cell, Color(0.12, 0.12, 0.2))
	# escada de incêndio e ar-condicionado
	var busy := _near_shop(face_center)
	if not is_end and not busy and h > 11.0 and _rng.randf() < 0.45 and not _quiet:
		for k in range(1, mini(4, rows)):
			if _ghost or _clipped((face_center + right * (w * 0.22)).x, 1.0):
				continue
			_prop("escada_incendio", face_center + normal * 0.7 + right * (w * 0.22) + Vector3(0, 3.6 + (k - 1) * 3.0, 0), yaw + PI)
	if not busy and _rng.randf() < 0.5 and not _quiet:
		var ac := face_center + normal * 0.35 + right * _rng.randf_range(-w / 3, w / 3) + Vector3(0, 4.4 + _rng.randi_range(0, 2) * 2.6, 0)
		_sbox(ac, Vector3(0.9, 0.6, 0.55), _painted("metal", Color("#6a7088"), 0.5, 0.4, 2.0), yaw)
		if _fan_n < 10:
			_fan_n += 1
			var fan := MeshInstance3D.new()
			var fm := CylinderMesh.new()
			fm.top_radius = 0.22
			fm.bottom_radius = 0.22
			fm.height = 0.02
			fan.mesh = fm
			fan.material_override = _mat(Color("#20232f"))
			fan.position = ac + normal * 0.29
			fan.rotation = Vector3(PI / 2, yaw, 0)
			if _ghost or _clipped(fan.position.x, 0.3):
				fan.free()
			else:
				add_child(fan)
				_fans.append(fan)
		# pingos do ar-condicionado
	# caixa d'água / chaminé no teto
	if _rng.randf() < 0.4:
		_sbox(body_c + Vector3(_rng.randf_range(-2, 2), h + 1.0, 0), Vector3(1.6, 2.0, 1.6), _mat(Color("#1c1a24")), yaw)


func _live_window(p: Vector3, normal: Vector3, col: Color, cell := 0) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 1.4)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = load("res://assets/tex/janelas_atlas.png")
	m.uv1_scale = Vector3(0.23, 0.23, 1)
	m.uv1_offset = Vector3((cell % 4) / 4.0 + 0.01, (cell / 4) / 4.0 + 0.01, 0)
	m.albedo_color = col
	mi.material_override = m
	mi.position = p
	mi.rotation.y = atan2(normal.x, normal.z)
	if _ghost or _clipped(p.x, 0.55):
		_ghost_bin.add_child(mi)
	else:
		add_child(mi)
	_wins.append({"m": m, "col": col, "next": _rng.randf_range(2, 14), "on": true})


# ═════════════════════════════════════════════ lojas dos projetos
func _place_shops() -> void:  # coroutine (fatiada)
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
		["atende360", Vector3(20.0, 0, zs), Vector3(0, 0, 1)],
		["barbercore", Vector3(-40.0, 0, zs), Vector3(0, 0, 1)],
	]
	for s in spots:
		if by_id.has(s[0]):
			_shop(s[1], s[2], by_id[s[0]])
			await _slice()
	_pft("lojas: fachadas")
	_tdump(["loja_total", "loja_ate_letreiro", "loja_letreiros", "loja_toldo_panfletos_luz"])
	for g in [["rumor", Vector3(-5.6, 0.2, -9.0), PI / 2], ["fortress", Vector3(-25.0, 0.2, CROSS_Z + 4.6), PI],
			["inaciocyber", Vector3(23.0, 0.06, ALLEY_Z + 1.2), -PI / 2]]:
		if by_id.has(g[0]):
			_guide_npc(g[1], g[2], by_id[g[0]])
	_guide_npc(Vector3(2.5, 0.2, AVE_END + 2.6), PI + 0.4, {"id": "sobre", "title": "LAB · SOBRE MIM", "neon": "#ffffff", "special": "about"})
	_pft("lojas: guias (personagens)")
	# prédio da CARREIRA (empresas e projetos profissionais) no fim da transversal à direita
	_shop(Vector3(34.0, 0, zn), Vector3(0, 0, -1), {"id": "carreira", "title": "CARREIRA", "neon": "#5bd0ff", "special": "career"})
	# o LAB (Sobre mim) é o prédio no fim da avenida; contato é a cabine na praça
	_shop(Vector3(0, 0, AVE_END + 0.0), Vector3(0, 0, 1), {"id": "sobre", "title": "LAB · SOBRE MIM", "neon": "#ffffff", "special": "about"}, true)


## Fachada de loja local (frente para +z local): porta, vitrine com a colagem, letreiro de neon
## com halo, toldo, luz colorida tingindo parede e chão, reflexo no asfalto, anel de interação.
func _shop(face: Vector3, normal: Vector3, project: Dictionary, grand := false) -> void:
	var t_shop := Time.get_ticks_usec()
	var neon := Color(str(project.get("neon", "#ffc83d")))
	var holder := Node3D.new()
	# 16 cm à frente da fachada: o painel de concreto do térreo (14 cm de espessura) cobria a vitrine e a porta
	holder.position = face + normal * 0.16
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
	_door(holder, Vector3(door_x, 0, 0.02), "porta_loja", neon)
	# vitrine com a colagem do projeto (ou a capa)
	var vw := W - 2.6
	var vx := door_x + 0.75 + vw / 2
	var tex: Texture2D = null
	var id := str(project.get("id", ""))
	for path in ["res://assets/data/collages/%s.png" % id, "res://assets/covers/%s" % str(project.get("cover", ""))]:
		if path.ends_with(".png") and FastTex.exists(path):
			var tl0 := Time.get_ticks_usec()
			tex = FastTex.get_tex(path)
			_t_texload += Time.get_ticks_usec() - tl0
			break
	var disp := MeshInstance3D.new()
	var dq := QuadMesh.new()
	dq.size = Vector2(vw - 0.2, 2.0)
	disp.mesh = dq
	disp.material_override = _cover(_tex_mat(tex, 0.75), tex, vw - 0.2, 2.0) if tex else _mat(neon.darkened(0.6), 0.5, true)
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
	# fila de ícones das tecnologias do projeto na verga, centralizada (tools/museum/tech_strips.py)
	var sp := "res://assets/tech_strips/%s.png" % id
	if ResourceLoader.exists(sp):
		var stex: Texture2D = load(sp)
		var sh := 0.44
		var swd := minf(sh * float(stex.get_width()) / float(stex.get_height()), W * 0.8)
		sh = swd * float(stex.get_height()) / float(stex.get_width())
		var sq := MeshInstance3D.new()
		var sqm := QuadMesh.new()
		sqm.size = Vector2(swd, sh)
		sq.mesh = sqm
		var smat := StandardMaterial3D.new()
		smat.albedo_texture = stex
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		smat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		smat.emission_enabled = true
		smat.emission_texture = stex
		smat.emission_energy_multiplier = 0.5
		sq.material_override = smat
		sq.position = Vector3(0, 3.3, 0.37)
		holder.add_child(sq)
	_tk("loja_ate_letreiro", t_shop)
	var t_lbl := Time.get_ticks_usec()
	# letreiro: placa escura e letras de neon com halo; o grande leva um segundo letreiro vertical
	var sign := Label3D.new()
	sign.text = str(project.get("title", "")).to_upper()
	sign.font = UI.font("title")
	sign.font_size = 230 if not grand else 300
	sign.pixel_size = 0.0048 if not grand else 0.006
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var tw := sign.font.get_string_size(sign.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sign.font_size).x * sign.pixel_size
	if tw > W * 0.86:
		sign.font_size = int(sign.font_size * W * 0.86 / tw)
	sign.modulate = Color(neon.r * 1.6, neon.g * 1.6, neon.b * 1.6)
	sign.position = Vector3(0, 4.15, 0.32)
	sign.shaded = false
	sign.double_sided = true
	sign.outline_size = 14
	sign.outline_modulate = Color(neon, 0.35)
	holder.add_child(sign)
	_neon_signs.append(sign)
	# selo "PROJETO" encostado no canto superior direito do nome (acompanha o tamanho do letreiro)
	var tw2 := sign.font.get_string_size(sign.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sign.font_size).x * sign.pixel_size
	var th2 := sign.font_size * sign.pixel_size * 0.72
	var badge := Label3D.new()
	badge.text = L.t("PROJETO")
	badge.font = UI.font("bold")
	badge.font_size = maxi(40, int(sign.font_size * 0.26))
	badge.pixel_size = sign.pixel_size
	badge.shaded = false
	badge.double_sided = true
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var bw := badge.font.get_string_size(badge.text, HORIZONTAL_ALIGNMENT_LEFT, -1, badge.font_size).x * badge.pixel_size
	var bx := minf(tw2 / 2.0 + bw * 0.15, W * 0.475)
	badge.position = Vector3(bx, 4.15 + th2 * 0.5 + 0.02, 0.35)
	badge.modulate = Color(2.2, 2.2, 2.4)
	badge.outline_size = 8
	badge.outline_modulate = Color(neon, 0.6)
	holder.add_child(badge)
	_lbox(holder, Vector3(bx - bw / 2.0, 4.15 + th2 * 0.5 + 0.02 + badge.font_size * badge.pixel_size * 0.38, 0.3),
		Vector3(bw + 0.1, badge.font_size * badge.pixel_size * 0.95, 0.04), _mat(neon.darkened(0.55), 0.3))
	_tk("loja_letreiros", t_lbl)
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
	var t_rest := Time.get_ticks_usec()
	# toldo sobre a vitrine
	if not grand:
		_awning(holder, vx, vw + 0.3, 3.02, neon)
	if not grand:
		_flyers(holder, Vector3(-W / 2 - 1.05, 1.55, 0.0), project)
		_neon_arrow(holder, Vector3(-W / 2 - 1.05, 2.95, 0.04), PI, neon, str(project.get("title", "")))
		_floor_arrow(holder, Vector3(door_x, 0.035, 3.3), neon)
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
	# bem na frente da porta: centrado no vão, ~0,8 m da soleira, raio que não entra na parede
	tm.inner_radius = 0.5
	tm.outer_radius = 0.62
	ring.mesh = tm
	ring.material_override = _mat(neon, 3.0, true)
	ring.position = Vector3(door_x, 0.23, 0.85)   # calçada tem 0,21 m
	ring.visible = false
	holder.add_child(ring)
	var rp := holder.to_global(ring.position)
	kiosks.append({"pos": rp, "project": project, "light": l, "ring": ring, "base_energy": l.light_energy,
		"neon": neon, "visited": false, "marker": holder.to_global(Vector3(door_x, 2.95, 0.6)), "normal": holder.global_transform.basis.z})
	map_labels.append({"p": Vector2(rp.x, rp.z), "t": str(project.get("title", "")), "c": neon})
	_tk("loja_toldo_panfletos_luz", t_rest)
	_tk("loja_total", t_shop)


func _guide_npc(pos: Vector3, yaw: float, project: Dictionary) -> void:
	var n := Npc.new()
	n.position = pos
	n.look_yaw = yaw
	n.setup(project)
	add_child(n)
	npcs.append(n)


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
		_street_lamp(c + Vector3((k % 2 - 0.5) * 12.0, 0.2, (k / 2 - 0.5) * 20.0), k % 2 == 0)
	# poças grandes na praça pegando o reflexo da fonte e dos postes
	var pud := StandardMaterial3D.new()
	pud.albedo_color = Color("#05070f")
	pud.roughness = 0.02
	pud.metallic = 0.9
	for k in 6:
		_sbox(c + Vector3(_rng.randf_range(-7, 7), 0.21, _rng.randf_range(-12, 12)), Vector3(_rng.randf_range(1.2, 2.6), 0.01, _rng.randf_range(0.8, 1.8)), pud, _rng.randf() * PI)
	var fg := Node3D.new()
	fg.position = c + Vector3(0, 0.23, 0)
	add_child(fg)
	_lhalo(fg, Vector3.ZERO, Vector2(10, 10), Color("#3aa8ff"), 0.22, true)
	# outdoor grande com a foto do Gabriel na parede oeste
	_photo_billboard(Vector3(PLAZA.position.x + 1.4, 0, c.z), Vector3(1, 0, 0))
	# cabine telefônica = CONTATO
	_phone_booth(c + Vector3(5.5, 0.2, -9.0))
	map_labels.append({"p": Vector2(c.x, c.z), "t": L.t("PRAÇA"), "c": Color("#9fdcff")})


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
	# estrutura de metal que segura a placa longe da parede
	for sx in [-3.2, 3.2]:
		_lbox(holder, Vector3(sx, 3.6, -0.6), Vector3(0.14, 7.2, 0.14), _mat(Color("#14161e")))
		_lbox(holder, Vector3(sx, 6.5, -0.6), Vector3(0.1, 0.1, 1.4), _mat(Color("#14161e")))
	if ResourceLoader.exists("res://assets/foto_gabriel.png"):
		var ph := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(3.4, 4.4)
		ph.mesh = q
		var ftex: Texture2D = load("res://assets/foto_gabriel.png")
		ph.material_override = _cover(_tex_mat(ftex, 0.65), ftex, 3.4, 4.4)
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
	rl.text = L.t("GAME DEV · IA · ARQUITETURA")
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
	for hx in [-2.8, 0.0, 2.8]:
		_lbox(holder, Vector3(hx, 3.7, 0.9), Vector3(0.3, 0.2, 0.3), _mat(Color("#14161e")))
		_lbox(holder, Vector3(hx, 3.82, 0.85), Vector3(0.22, 0.06, 0.22), _mat(Color(2.4, 2.0, 1.4), 0.0, true))
		var bm := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.1
		cm.bottom_radius = 1.2
		cm.height = 2.8
		cm.cap_top = false
		cm.cap_bottom = false
		bm.mesh = cm
		bm.material_override = _add_mat(Color("#ffe0a8"), 0.06)
		bm.position = Vector3(hx, 5.2, 0.55)
		bm.rotation.x = 0.35
		holder.add_child(bm)
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
	lb.text = L.t("CONTATO")
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
	tm.inner_radius = 0.5
	tm.outer_radius = 0.62
	ring.mesh = tm
	ring.material_override = _mat(Color("#5fd38a"), 3.0, true)
	ring.position = Vector3(0, 0.23, 0.85)
	ring.visible = false
	holder.add_child(ring)
	var rp := holder.to_global(ring.position)
	var proj := {"id": "contato", "title": "CONTATO", "neon": "#5fd38a", "special": "contact"}
	kiosks.append({"pos": rp, "project": proj, "light": l, "ring": ring, "base_energy": 2.0, "neon": Color("#5fd38a"), "visited": false,
		"marker": holder.to_global(Vector3(0, 3.2, 0.6)), "normal": holder.global_transform.basis.z})
	map_labels.append({"p": Vector2(rp.x, rp.z), "t": L.t("CONTATO"), "c": Color("#5fd38a")})


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
		var atex: Texture2D = load(cover)
		ad.material_override = _cover(_tex_mat(atex, 0.8), atex, 8.4, 4.4)
		ad.position = Vector3(0, 8, 0.17)
		bh.add_child(ad)
	_lhalo(bh, Vector3(0, 8, 0.3), Vector2(11, 7), Color("#ffc83d"), 0.25)


# ═════════════════════════════════════════════ beco: varal de lâmpadas, neons laterais, seta
func _dress_alley() -> void:
	var zn := ALLEY_Z + 1.95
	var zs := ALLEY_Z - 1.95
	# varal de lâmpadas atravessando o beco em zigue-zague (emissivas, um lote só)
	var bulb := _mat(Color(2.4, 1.7, 0.9), 0.0, true)
	var wire := _mat(Color("#0a0a10"))
	for k in 4:
		var x0 := FAC + 2.0 + k * 3.6
		var a := Vector3(x0, 4.6, zn)
		var b := Vector3(x0 + 1.8, 4.6, zs)
		for i in 9:
			var t := i / 8.0
			var p := a.lerp(b, t) - Vector3(0, sin(t * PI) * 0.6, 0)
			_sbox(p, Vector3(0.12, 0.16, 0.12), bulb)
			if i < 8:
				var q := a.lerp(b, (i + 1) / 8.0) - Vector3(0, sin((i + 1) / 8.0 * PI) * 0.6, 0)
				_sbox((p + q) / 2, Vector3(0.02, 0.02, p.distance_to(q)), wire, atan2((q - p).x, (q - p).z))
	# luz quente fraca do varal + luz magenta de um letreiro lateral
	for x in [FAC + 6.0, FAC + 14.0]:
		var l := OmniLight3D.new()
		l.position = Vector3(x, 4.0, ALLEY_Z)
		l.light_color = Color("#ffb46a")
		l.light_energy = 1.4
		l.omni_range = 6.5
		l.distance_fade_enabled = true
		l.distance_fade_begin = 26.0
		add_child(l)
	var signs := [["BAR 24H", Color("#ff3d8a"), Vector3(FAC + 9.0, 3.4, zn), PI], ["HOTEL", Color("#4ec9ff"), Vector3(FAC + 13.0, 6.0, zs), 0.0],
		["CYBER →", Color("#e2384f"), Vector3(FAC + 4.0, 2.9, zs), 0.0]]
	for sg in signs:
		var h := Node3D.new()
		h.position = sg[2]
		h.rotation.y = sg[3]
		add_child(h)
		_lbox(h, Vector3(0, 0, 0.05), Vector3(2.4, 0.8, 0.1), _mat(Color("#0a0d18")))
		var lb := Label3D.new()
		lb.text = sg[0]
		lb.font = UI.font("title")
		lb.font_size = 160
		lb.pixel_size = 0.004
		var c: Color = sg[1]
		lb.modulate = Color(c.r * 1.7, c.g * 1.7, c.b * 1.7)
		lb.position = Vector3(0, 0, 0.13)
		lb.shaded = false
		h.add_child(lb)
		_neon_signs.append(lb)
		if sg[0] == "HOTEL":
			_broken.append({"node": lb, "seed": 1.3})
		_lhalo(h, Vector3(0, 0, 0.18), Vector2(3.4, 1.6), c, 0.55)
		_lhalo(h, Vector3(0, -sg[2].y + 0.06, 1.4), Vector2(3.0, 2.4), c, 0.3, true)
		var l := OmniLight3D.new()
		l.position = Vector3(0, 0, 1.2)
		l.light_color = c
		l.light_energy = 1.8
		l.omni_range = 5.0
		l.distance_fade_enabled = true
		l.distance_fade_begin = 24.0
		h.add_child(l)
	# entulho: caçamba e sacos de lixo
	_sbox(Vector3(FAC + 11.0, 0.7, zs + 0.8), Vector3(2.2, 1.4, 1.2), _painted("metal", Color("#2e5a46"), 0.5, 0.4, 1.0))
	_sbox(Vector3(FAC + 11.0, 1.45, zs + 0.8), Vector3(2.3, 0.1, 1.3), _mat(Color("#1d3a2d")), 0.0)
	for i in 4:
		var bag := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.35
		sm.height = 0.55
		sm.radial_segments = 8
		sm.rings = 4
		bag.mesh = sm
		bag.material_override = _mat(Color("#121418"), 0.0, false, 0.25)
		bag.position = Vector3(FAC + 13.0 + i * 0.5, 0.28, zs + 0.5 + (i % 2) * 0.4)
		add_child(bag)


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
	_prop("banca_jornal", Vector3(-5.9, 0.2, -61.0), PI / 2, 0.75)
	for p in [Vector3(12, 0.06, ALLEY_Z - 1.2), Vector3(22, 0.06, ALLEY_Z + 1.2), Vector3(23.5, 0.06, ALLEY_Z - 1.0), Vector3(-6.2, 0.2, -63)]:
		_prop("caixas_papelao", p, _rng.randf() * TAU)
	for p in [Vector3(-2.5, 0.0, -64), Vector3(-1.5, 0.0, -65), Vector3(-3.5, 0.0, -65.5)]:
		_prop("cone_transito", p, _rng.randf() * TAU)
	# vida de calçada: sacos de lixo, latas, papéis, bicicleta encostada, mesas de bar na calçada
	for p in [Vector3(-6.5, 0.2, -1.2), Vector3(-6.5, 0.2, -0.6), Vector3(6.5, 0.2, -13.3), Vector3(13.5, 0.06, ALLEY_Z - 1.5),
			Vector3(20.0, 0.06, ALLEY_Z + 1.5), Vector3(-36.5, 0.2, CROSS_Z - 5.6), Vector3(6.5, 0.2, -54.6)]:
		_prop("sd_saco_lixo", p, _rng.randf() * TAU, _rng.randf_range(0.8, 1.1))
	for p in [Vector3(-5.6, 0.2, -4.0), Vector3(5.0, 0.2, -20.0), Vector3(16.0, 0.06, ALLEY_Z), Vector3(-20, 0.2, CROSS_Z + 4.9)]:
		_prop("sd_latas", p, _rng.randf() * TAU)
	for p in [Vector3(-3.0, 0.0, -18.0), Vector3(2.0, 0.0, -35.0), Vector3(-12.0, 0.0, CROSS_Z + 1.0), Vector3(-56.0, 0.2, -46.0)]:
		_prop("sd_papeis", p, _rng.randf() * TAU, 1.4)
	_prop("sd_bicicleta", Vector3(6.4, 0.2, -16.5), 0.0)
	_prop("sd_bicicleta", Vector3(-6.4, 0.2, -45.5 + 0.0), PI / 2 + 0.1)
	# mesinhas de bar na calçada em frente à Lábia
	for p in [Vector3(5.6, 0.2, -27.6), Vector3(5.6, 0.2, -31.0)]:
		_prop("sd_mesa_bar_rua", p, 0.0)
	# carros estacionados: vagas rentes ao meio-fio (faixa de estacionamento, fora das faixas de
	# rolamento); cada vaga é conferida contra os corredores do trânsito e descartada se invadir
	_setup_traffic_lanes()
	var park_x := AVE_X - 1.05
	var park_z := CROSS_HW - 0.95
	for p in [Vector3(-park_x, 0.0, -13.5), Vector3(park_x, 0.0, -25.0), Vector3(-park_x, 0.0, -56.0),
			Vector3(park_x, 0.0, -8.0), Vector3(-park_x, 0.0, -31.0),
			Vector3(30.0, 0.0, CROSS_Z - park_z), Vector3(-34.0, 0.0, CROSS_Z + park_z), Vector3(22.0, 0.0, CROSS_Z + park_z)]:
		var yaw := 0.0 if absf(p.z - CROSS_Z) > 3.0 else PI / 2
		if not traffic.valid_parking(p, yaw):
			push_warning("vaga descartada (invade faixa): %s" % p)
			continue
		_prop(CARS[_rng.randi() % CARS.size()], p, yaw + (PI if p.x > 0 and yaw == 0.0 else 0.0))


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
	# carros circulando: só nas faixas do Traffic (sem física; nunca atravessam outro carro)
	_setup_traffic_lanes()
	var ncar := 4 if _light else 8
	for i in ncar:
		_spawn_car(i % traffic.lanes.size(), float(i / traffic.lanes.size()) * 34.0 + 6.0 * (i % traffic.lanes.size()))
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
		_spawn_idle(Vector3(-55.0, 0.3, -38.0), 0.4, "hacker", "idle")
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


## Faixas de rolamento (uma por sentido), afastadas da faixa de estacionamento junto ao meio-fio.
var _lanes_ready := false


func _setup_traffic_lanes() -> void:
	if _lanes_ready:
		return
	_lanes_ready = true
	var lx := 1.25
	var lz := 1.25
	traffic.add_lane(Vector3(lx, 0, AVE_START + 30), Vector3(lx, 0, AVE_END - 30), "ave")
	traffic.add_lane(Vector3(-lx, 0, AVE_END - 30), Vector3(-lx, 0, AVE_START + 30), "ave")
	traffic.add_lane(Vector3(-CROSS_END - 25, 0, CROSS_Z - lz), Vector3(CROSS_END + 25, 0, CROSS_Z - lz), "cross")
	traffic.add_lane(Vector3(CROSS_END + 25, 0, CROSS_Z + lz), Vector3(-CROSS_END - 25, 0, CROSS_Z + lz), "cross")
	traffic.set_box(Rect2(-AVE_X, CROSS_Z - CROSS_HW, AVE_X * 2, CROSS_HW * 2))


func _spawn_car(lane: int, s: float) -> void:
	var car := Node3D.new()
	add_child(car)
	var body := MeshInstance3D.new()
	var cname: String = CARS[_rng.randi() % CARS.size()]
	body.mesh = _prop_mesh(cname)
	if cname.contains("taxi"):
		var tt := _ad_tex(_ad_pick("taxi", 0))
		if tt:
			var top := Node3D.new()
			top.position = Vector3(0, 1.82, -0.2)
			car.add_child(top)
			_lbox(top, Vector3.ZERO, Vector3(0.95, 0.34, 0.2), _mat(Color("#101320")))
			for sg in [1.0, -1.0]:
				var tq := _ad_quad(top, tt, Vector3(0, 0, 0.11 * sg), Vector2(0.9, 0.3), 1.1)
				tq.rotation.y = 0.0 if sg > 0 else PI
			top.rotation.y = PI / 2
	elif cname.contains("van"):
		var vt := _ad_tex(_ad_pick("van", _rng.randi() % 3))
		if vt:
			for sg in [1.0, -1.0]:
				var vq := _ad_quad(car, vt, Vector3(1.04 * sg, 1.25, -0.2), Vector2(3.4, 1.36), 0.4)
				vq.rotation.y = PI / 2 * sg
	body.rotation.y = PI   # o modelo do Blender olha para -z; os faróis ficam em +z
	car.add_child(body)
	# faróis e lanternas emissivos vêm no próprio modelo; aqui só o halo, o feixe no chão e a luz
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
	var clen := 5.3
	if body.mesh:
		var bb := body.mesh.get_aabb()
		clen = maxf(bb.size.z, bb.size.x)
	if not traffic.add_car(car, lane, s, clen):
		car.queue_free()
		return
	_cars.append({"node": car})


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


func _spawn_idle(p: Vector3, yaw: float, id: String, anim := "") -> void:
	var ch := _make_person(id)
	ch.position = p
	ch.rotation.y = yaw
	if ch.has_method("play"):
		ch.call("play", anim if anim != "" else ["falando", "idle"][_rng.randi() % 2])


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
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	# respingo é um ponto: losango de 8 triângulos (a esfera padrão tinha ~4 mil por partícula e
	# era o maior custo da rua inteira)
	var sm := SphereMesh.new()
	sm.radius = 0.02
	sm.height = 0.04
	sm.radial_segments = 4
	sm.rings = 1
	s.mesh = sm
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.material_override = _mat(Color("#cfdcff"), 1.2, true)
	add_child(s)
	_splash_node = s


var _rain_node: CPUParticles3D
var _splash_node: CPUParticles3D


# ═════════════════════════════════════════════ jogador
## alcance de desenho por classe de tamanho (peças pequenas somem cedo); sem placa de vídeo é ainda menor
func _near() -> float:
	return 9.0 if UI.software() else (18.0 if _light else 24.0)


func _mid() -> float:
	return 16.0 if UI.software() else (32.0 if _light else 42.0)


## Aquecimento de shaders: no primeiro desenho o driver compila um programa por material (sem cache de
## shader, na primeira visita, isso era um único congelamento de 30 s). Aqui cada material único aparece
## num quadradinho diante da câmera, poucos por quadro, com a cidade escondida; o carregador mostra a
## porcentagem real e a thread nunca fica parada mais que um programa.
## issue_only: só pede os programas (testado antes da fusão com os shaders em paralelo: sem ganho medido)
func _warm_up(issue_only := false) -> void:
	# um quadradinho por PROGRAMA (não por material): cópias do mesmo shader, ou StandardMaterial3D com as
	# mesmas flags, compartilham o programa; antes eram ~425 materiais, agora ~20 programas
	var Census := preload("res://scripts/render/census.gd")
	var seen := {}
	var items: Array = []
	var add_item := func(m: Material, inst: bool) -> void:
		if m == null:
			return
		var key := Census._mat_key(m) + ("|I" if inst else "")
		if not seen.has(key):
			seen[key] = true
			items.append([m, inst])
	for n in find_children("*", "GeometryInstance3D", true, false):
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var mi := n as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				add_item.call(mi.material_override if mi.material_override else mi.get_active_material(i), false)
		elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null:
			var mm := n as MultiMeshInstance3D
			add_item.call(mm.material_override if mm.material_override else mm.multimesh.mesh.surface_get_material(0), true)
	# programas das LOJAS também (as lojas montam ao entrar; sem isto a 1ª porta congelava compilando)
	# rodada 5: esses programas (só existem dentro das lojas) aquecem DEPOIS, com a tela de entrada já na frente
	# (warm_late, numa viewport fora da vista); ?latewarm=0 volta a aquecer tudo aqui
	var late := not UI.js_flag("/[?&]latewarm=0/.test(location.search)?1:0") and OS.get_environment("PF_LATEWARM") != "0"
	for sp in ["code_scroll", "chart_screen", "led_panel", "matrix_rain", "arcade_attract", "face_atlas", "hover_outline", "outline", "toon_noir"]:
		var path := "res://shaders/%s.gdshader" % sp
		if ResourceLoader.exists(path):
			var wm := ShaderMaterial.new()
			wm.shader = load(path)
			if late and sliced:
				_late_warm.append(Noir.conv(wm))
			else:
				items.append([Noir.conv(wm), false])
	for kind in Noir.SHADERS:
		var nm := ShaderMaterial.new()
		nm.shader = Noir.SHADERS[kind]
		nm.set_shader_parameter("noir_lights", Noir.lights_texture())
		items.append([nm, false])
		items.append([nm, true])
	var vp := get_viewport() as SubViewport
	if not sliced or vp == null or player == null or player.cam == null:
		return
	# visita repetida: o driver já guarda os programas compilados (cache de disco do navegador) e a mesma
	# versão do jogo na mesma placa de vídeo não precisa do aquecimento
	var warm_key := ""
	if OS.has_feature("web"):
		warm_key = str(JavaScriptBridge.eval("(function(){try{return window.pfBuild||''}catch(e){return ''}})()", true))
		var done_key: Variant = JavaScriptBridge.eval("(function(){try{return localStorage.getItem('pf_warm')||''}catch(e){return ''}})()", true)
		if warm_key != "" and str(done_key) == warm_key:
			print("PFT warm-up dispensado (visita repetida)")
			return
	var old_mode := vp.render_target_update_mode
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	visible = false
	var holder := Node3D.new()
	get_parent().add_child(holder)
	var cam := player.cam
	var fwd := -cam.global_transform.basis.z
	holder.global_position = cam.global_position + fwd * 1.5
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var mmq := MultiMesh.new()
	mmq.transform_format = MultiMesh.TRANSFORM_3D
	mmq.mesh = quad
	mmq.instance_count = 1
	var total := items.size()
	var slow := 0
	var take_n := 64 if issue_only else 6
	var prof := {}
	var t_all := Time.get_ticks_usec()
	# duas voltas: 1) com luzes de teste por perto (variante de shader com luz omni, spot e direcional);
	# 2) sem luz (variante dos objetos longe dos postes). A primeira cena real não compila mais nada.
	var tl: Array = []
	# mundo noir: nenhum material usa luz do motor, então não há variante com luz para aquecer
	# mundo noir: a cidade não usa luz do motor, mas as LOJAS usam (toon, StandardMaterial com luz):
	# a 1ª volta, com luzes de teste, aquece só os sabores de material das lojas
	var all_items := items
	var lit_items: Array = []
	# no celular a loja aquece quando o jogador entra (atrás do véu), não no carregador
	# lojas no mundo noir (Noir.shop_noir): nenhuma variante com luz do motor sobra para aquecer
	if Noir.enabled() and not Noir.shop_noir() and not UI.is_mobile():
		var plain := StandardMaterial3D.new()
		plain.roughness = 0.9
		var texd := StandardMaterial3D.new()
		texd.albedo_texture = load("res://assets/tex/carpete.png")
		texd.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		var texm := texd.duplicate() as StandardMaterial3D
		texm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var glass := StandardMaterial3D.new()
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.albedo_color = Color(0.1, 0.1, 0.2, 0.3)
		var pv := StandardMaterial3D.new()
		pv.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		pv.vertex_color_use_as_albedo = true
		pv.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		pv.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		var pvt := pv.duplicate() as StandardMaterial3D
		pvt.vertex_color_use_as_albedo = false
		pvt.albedo_texture = texd.albedo_texture
		var face := pvt.duplicate() as StandardMaterial3D
		face.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		var toon := ShaderMaterial.new()
		toon.shader = load("res://shaders/toon.gdshader")
		# a fusão das lojas troca a cor do material por cor de vértice: essas variantes também
		var plain_vc := plain.duplicate() as StandardMaterial3D
		plain_vc.vertex_color_use_as_albedo = true
		plain_vc.vertex_color_is_srgb = true
		var tex_vc := texd.duplicate() as StandardMaterial3D
		tex_vc.vertex_color_use_as_albedo = true
		tex_vc.vertex_color_is_srgb = true
		var emis_vc := StandardMaterial3D.new()
		emis_vc.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		emis_vc.emission_enabled = true
		emis_vc.vertex_color_use_as_albedo = true
		emis_vc.vertex_color_is_srgb = true
		for m in [plain, texd, texm, glass, pv, pvt, face, toon, plain_vc, tex_vc, emis_vc]:
			m.set_meta("noir_skip_conv", true)
			lit_items.append([m, false])
	var rounds := 2 if (not Noir.enabled() or not lit_items.is_empty()) else 1
	if issue_only:
		rounds = 1
	for rnd in rounds:
		if Noir.enabled():
			items = lit_items if (rnd == 0 and rounds == 2) else all_items
			total = items.size()
		if rnd == 0 and rounds == 2:
			var lo := OmniLight3D.new()
			lo.light_energy = 0.01
			lo.omni_range = 6.0
			var ls := SpotLight3D.new()
			ls.light_energy = 0.01
			ls.spot_range = 6.0
			var ld := DirectionalLight3D.new()
			ld.light_energy = 0.01
			ld.shadow_enabled = false
			for l in [lo, ls, ld]:
				l.set_meta("noir_keep", true)   # luz real de verdade (aquece as variantes com luz das lojas)
				holder.add_child(l)
				tl.append(l)
		elif rnd == 1:
			for l in tl:
				l.queue_free()
		var i := 0
		while i < total:
			var t0 := Time.get_ticks_usec()
			var batch := 0
			var nodes: Array = []
			# poucos por quadro enquanto os shaders forem lentos; mais quando já estão em cache
			var take := clampi(take_n, 1, 64)
			while batch < take and i < total:
				var it: Array = items[i]
				i += 1
				batch += 1
				var node: GeometryInstance3D
				if it[1]:
					var mmi := MultiMeshInstance3D.new()
					mmi.multimesh = mmq
					node = mmi
				else:
					node = MeshInstance3D.new()
					(node as MeshInstance3D).mesh = quad
				node.material_override = it[0]
				node.position = Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.2), 0)
				holder.add_child(node)
				nodes.append(node)
			await get_tree().process_frame
			var dt := (Time.get_ticks_usec() - t0) / 1000
			slow = 1 if dt > 90 else 0
			# programas em cache (visita repetida): lotes crescem; compilando: um por quadro
			take_n = 1 if dt > 90 else (take_n * 2 if dt < 40 else take_n)
			if OS.get_environment("WARM_PROFILE") != "":
				var mt: Material = (nodes[0] as GeometryInstance3D).material_override
				var desc := mt.get_class()
				if mt is ShaderMaterial and (mt as ShaderMaterial).shader:
					desc += " " + (mt as ShaderMaterial).shader.resource_path.get_file()
				elif mt is StandardMaterial3D:
					var sm := mt as StandardMaterial3D
					desc += " shade=%d tr=%d emis=%s tex=%s vc=%s cull=%d" % [sm.shading_mode, sm.transparency, sm.emission_enabled, sm.albedo_texture != null, sm.vertex_color_use_as_albedo, sm.cull_mode]
				if nodes[0] is MultiMeshInstance3D:
					desc += " MM"
				var e: Array = prof.get(desc, [0, 0])
				e[0] += batch
				e[1] += dt
				prof[desc] = e
			for nd in nodes:
				nd.queue_free()
			if not issue_only and (i / 8 != (i - batch) / 8 or i >= total):
				await _prog(0.82 + 0.16 * float(rnd * total + i) / maxf(1.0, float(rounds * total)), "Warming up shaders")
	holder.queue_free()
	var keys := prof.keys()
	keys.sort_custom(func(x, y) -> bool: return prof[x][1] > prof[y][1])
	for k in keys.slice(0, 14):
		print("PFTPROF %5d ms  x%-3d %s" % [prof[k][1], prof[k][0], k])
	print("PFT warm-up%s: %d materiais, %d ms" % [" (só pedidos, antes da fusão)" if issue_only else "", total, (Time.get_ticks_usec() - t_all) / 1000])
	visible = true
	vp.render_target_update_mode = old_mode
	if warm_key != "" and not issue_only:
		JavaScriptBridge.eval("try{localStorage.setItem('pf_warm',%s)}catch(e){}" % JSON.stringify(warm_key), true)


## Aquecimento tardio (programas das lojas): um quadradinho por vez numa viewport de 16x16 que olha para
## 500 m abaixo da cidade (mesmo mundo, mesma névoa e luzes: a variante compilada é a que a loja vai usar).
## Roda com a tela de entrada na frente; se o ENTRAR vier antes, segue fora da vista.
var _late_warm: Array = []


func warm_late() -> void:
	if _late_warm.is_empty():
		return
	var t0 := Time.get_ticks_msec()
	var vp := SubViewport.new()
	vp.size = Vector2i(16, 16)
	vp.world_3d = get_viewport().find_world_3d()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.audio_listener_enable_3d = false
	vp.gui_disable_input = true
	var cam := Camera3D.new()
	cam.far = 4.0
	vp.add_child(cam)
	get_parent().add_child(vp)
	cam.current = true
	cam.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, -500, 0))
	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	var n := 0
	for m in _late_warm:
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = m
		get_parent().add_child(mi)
		mi.global_position = Vector3(0, -500, -1.5)
		await get_tree().process_frame
		await get_tree().process_frame
		mi.queue_free()
		n += 1
	_late_warm.clear()
	vp.queue_free()
	print("PFT aquecimento tardio: %d programas em %d ms" % [n, Time.get_ticks_msec() - t0])


func _spawn_player() -> void:
	player = Player.new()
	add_child(player)
	player.position = Vector3(0, 1.6, 4.0)
	var m := 0.55
	player.walk_rects = [
		Rect2(-FAC + m, AVE_END + m, (FAC - m) * 2, AVE_START - AVE_END - m * 2),
		Rect2(-CROSS_END + m, CROSS_Z - CROSS_HW - SIDE + m, (CROSS_END - m) * 2, (CROSS_HW + SIDE - m) * 2),
		Rect2(FAC - 1.0, ALLEY_Z - 2.0 + m, ALLEY_END - FAC + 1.0 - m, 4.0 - m * 2),
		Rect2(POCKET_X + m, ALLEY_Z - POCKET_HW + m, ALLEY_END - POCKET_X - m * 2, (POCKET_HW - m) * 2),
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
			if _markers and k.has("marker_i"):
				var c := _markers.multimesh.get_instance_color(int(k["marker_i"]))
				_markers.multimesh.set_instance_color(int(k["marker_i"]), Color(c.r, c.g, c.b, 0.0))
			visited_changed.emit(visited_count(), total_projects())


# ═════════════════════════════════════════════ animação de tudo
## interruptores de teste A/B (window.pfAB no navegador): nofx, notraffic, noads, nowalkers, noproc
var ab := {}


func _tick_fx(dt: float) -> void:
	for f in _flicker:
		if f.has("blink"):
			(f["node"] as Node3D).visible = fmod(_t + float(f["seed"]), 1.6) < 0.9
			continue
		var k := 1.0
		if fmod(_t + float(f["seed"]), 4.5) < 0.25:
			k = 0.35 if sin(_t * 42.0) > 0 else 1.0
		(f["light"] as OmniLight3D).light_energy = float(f["base"]) * k
	for m in (_neon_mats if not Noir.enabled() else []):
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
			(w["m"] as StandardMaterial3D).albedo_color = w["col"] if w["on"] else Color(0.12, 0.12, 0.2)
	for s in _swing:
		var n: Node3D = s["node"]
		n.rotation.z = sin(_t * 1.3 + float(s["seed"])) * float(s["amp"])
	for f in _fans:
		(f as Node3D).rotate_object_local(Vector3.UP, dt * 9.0)


func _process(dt: float) -> void:
	if not is_built:
		return
	_t += dt
	if ab.has("noproc"):
		return
	if not ab.has("nofx"):
		_tick_fx(dt)
	if not ab.has("notraffic"):
		traffic.step(dt, player.global_position if player else null)
	if not ab.has("noads"):
		_tick_ads(dt)
	for w in (_walkers if not ab.has("nowalkers") else []):
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
		var rg: Node3D = k["ring"]
		rg.visible = true
		if not k.has("_rmat"):
			var rm: StandardMaterial3D = ((rg as MeshInstance3D).material_override as StandardMaterial3D).duplicate()
			(rg as MeshInstance3D).material_override = rm
			k["_rmat"] = rm
			_door_hint(k)
		var pulse := 0.5 + 0.5 * sin(_t * (5.0 if on else 2.4) + float(k["pos"].x))
		var base := 0.35 if bool(k.get("visited", false)) else 1.0
		# anel discreto no chão (o marcador de cima é o que se vê de longe); mais forte só bem perto
		(k["_rmat"] as StandardMaterial3D).emission_energy_multiplier = base * (1.0 + pulse * (3.0 if on else 0.8))
		rg.scale = Vector3.ONE * (1.0 + pulse * (0.12 if on else 0.06))
		if k.has("_hint"):
			(k["_hint"] as Node3D).visible = not on
		if on and d < best:
			best = d
			near = k
	player.set_target(near)
	near_changed.emit(near.get("project", {}))


# ═════════════════════════════════════════════ rodada 7: portas, toldos, panfletos, setas, outdoors, placas
## Porta modelada (kit em props_kit.py / door_kit) ou montada aqui: batente em relevo, soleira, vidro
## com luz quente, puxador; nunca a textura da parede.
func _door(parent: Node3D, pos: Vector3, kind: String, accent := Color("#ffc83d")) -> void:
	var d := Node3D.new()
	d.position = pos
	parent.add_child(d)
	var frame := _mat(Color("#2a1f18"), 0.0, false, 0.6)
	_lbox(d, Vector3(0, 1.22, 0), Vector3(1.32, 2.5, 0.12), frame)             # batente
	_lbox(d, Vector3(0, 0.02, 0.1), Vector3(1.4, 0.05, 0.3), _mat(Color("#55504a")))  # soleira
	match kind:
		"porta_loja":
			_lbox(d, Vector3(0, 1.18, 0.06), Vector3(1.1, 2.3, 0.05), _mat(Color("#3a2a1e"), 0.0, false, 0.5))
			_lbox(d, Vector3(0, 1.45, 0.09), Vector3(0.84, 1.45, 0.02), _mat(Color("#ffb860"), 1.1, true))  # vidro aceso
			_lbox(d, Vector3(0, 0.35, 0.09), Vector3(0.9, 0.4, 0.02), _mat(Color("#4a3626")))      # chapa de chute
			_lbox(d, Vector3(0.4, 1.1, 0.13), Vector3(0.04, 0.45, 0.04), _mat(Color("#c8a050"), 0.4))  # puxador
			var ab := Label3D.new()
			ab.text = L.t("ABERTO")
			ab.font = UI.font("title")
			ab.font_size = 70
			ab.pixel_size = 0.0035
			ab.modulate = Color(accent.r * 1.5, accent.g * 1.5, accent.b * 1.5)
			ab.position = Vector3(0, 1.75, 0.105)
			ab.shaded = false
			d.add_child(ab)
		"porta_metal":
			_lbox(d, Vector3(0, 1.18, 0.06), Vector3(1.1, 2.3, 0.05), _painted("metal", Color("#5a6070"), 0.5, 0.4, 2.0))
			for y in [0.5, 1.2, 1.9]:
				_lbox(d, Vector3(0, y, 0.09), Vector3(1.0, 0.04, 0.02), _mat(Color("#3a3e48")))
			_lbox(d, Vector3(0.42, 1.05, 0.12), Vector3(0.18, 0.05, 0.05), _mat(Color("#9aa0ac"), 0.2))
		_:  # porta de prédio: madeira com painéis e bandeira de vidro em cima
			_lbox(d, Vector3(0, 1.08, 0.06), Vector3(1.1, 2.1, 0.05), _mat(Color("#4a2f1e"), 0.0, false, 0.6))
			for y in [0.55, 1.45]:
				for x in [-0.25, 0.25]:
					_lbox(d, Vector3(x, y, 0.09), Vector3(0.38, 0.62, 0.02), _mat(Color("#5e3c26")))
			_lbox(d, Vector3(0, 2.3, 0.07), Vector3(1.1, 0.26, 0.03), _mat(Color("#ffcf8a"), 0.9, true))
			_lbox(d, Vector3(0.42, 1.05, 0.12), Vector3(0.06, 0.06, 0.06), _mat(Color("#c8a050"), 0.4))
			var nr := Label3D.new()
			nr.text = str(100 + _rng.randi_range(1, 899))
			nr.font = UI.font("type")
			nr.font_size = 60
			nr.pixel_size = 0.003
			nr.modulate = Color("#1a120a")
			nr.position = Vector3(0, 2.3, 0.09)
			d.add_child(nr)


## Toldo listrado preso na parede (borda de trás na fachada) e inclinado para a frente e para baixo.
func _awning(parent: Node3D, cx: float, width: float, top: float, accent: Color) -> void:
	var depth := 1.25
	var drop := 0.55
	var ang := atan2(drop, depth)
	var slope := sqrt(depth * depth + drop * drop)
	var stripes := int(width / 0.36)
	var sw := width / stripes
	var a := _mat(accent.darkened(0.25), 0.0, false, 0.8)
	var b := _mat(Color("#e8e0cc"), 0.0, false, 0.8)
	for k in stripes:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(sw, 0.03, slope)
		mi.mesh = bm
		mi.material_override = a if k % 2 == 0 else b
		mi.position = Vector3(cx - width / 2 + sw * (k + 0.5), top - drop / 2, 0.02 + depth / 2)
		mi.rotation.x = ang
		parent.add_child(mi)
		# saia (aba vertical) na frente
		var fr := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(sw, 0.22, 0.02)
		fr.mesh = fm
		fr.material_override = mi.material_override
		fr.position = Vector3(mi.position.x, top - drop - 0.1, 0.02 + depth)
		parent.add_child(fr)
	# barra de fixação na parede e braços
	_lbox(parent, Vector3(cx, top + 0.02, 0.05), Vector3(width + 0.06, 0.06, 0.08), _mat(Color("#20232c")))
	for x in [cx - width / 2 + 0.05, cx + width / 2 - 0.05]:
		var arm := MeshInstance3D.new()
		var am := BoxMesh.new()
		am.size = Vector3(0.03, 0.03, slope)
		arm.mesh = am
		arm.material_override = _mat(Color("#20232c"))
		arm.position = Vector3(x, top - drop / 2 - 0.02, 0.02 + depth / 2)
		arm.rotation.x = ang
		parent.add_child(arm)


## Panfletos e cartazes colados na parede ao lado da porta: prints reais do projeto (ou os anúncios
## de design da loja), sobrepostos, tortos, alguns com canto dobrado; nítidos e iluminados pela cena.
func _flyers(parent: Node3D, center: Vector3, project: Dictionary) -> void:
	var id := str(project.get("id", ""))
	var pics: Array = []
	# miniaturas (384 px) em vez dos prints cheios: poupa dezenas de MB de VRAM na rua
	for i in 5:
		var fp := "res://assets/flyers/%s_%d.jpg" % [id, i]
		if FastTex.exists(fp):
			pics.append(fp)
	pics.sort()
	if pics.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var spots := [Vector2(-0.32, 0.45), Vector2(0.3, 0.38), Vector2(-0.25, -0.25), Vector2(0.33, -0.3), Vector2(0.02, 0.05)]
	for i in mini(spots.size(), maxi(3, pics.size())):
		var tex: Texture2D = FastTex.get_tex(pics[i % pics.size()])
		if tex == null:
			continue
		var r := float(tex.get_width()) / maxf(1.0, tex.get_height())
		var h := 0.62 if r < 1.0 else 0.44
		var w := clampf(h * r, 0.36, 0.78)
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(w, w / r)
		mi.mesh = q
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m.roughness = 0.95
		m.emission_enabled = true          # leve, só para ler no escuro; o resto vem da luz da rua
		m.emission_texture = tex
		m.emission_energy_multiplier = 0.18
		mi.material_override = m
		mi.position = center + Vector3(spots[i].x, spots[i].y, 0.02 + i * 0.004)
		mi.rotation.z = rng.randf_range(-0.12, 0.12)
		parent.add_child(mi)
		# fita/grampo no topo
		_lbox(parent, mi.position + Vector3(0, w / r / 2 - 0.02, 0.006), Vector3(0.1, 0.03, 0.004), _mat(Color("#d9d2b8")))


## Seta de neon com o nome do projeto (aponta para a porta). ang = direção da ponta no plano da parede.
func _neon_arrow(parent: Node3D, pos: Vector3, ang: float, col: Color, label: String) -> void:
	var h := Node3D.new()
	h.position = pos
	h.rotation.z = ang  # 0 = ponta para cima, PI = para baixo (para a porta)
	parent.add_child(h)
	var nm := _neon_mat(col)
	_lbox(h, Vector3(0, 0, 0.02), Vector3(0.05, 0.75, 0.05), nm)
	for sx in [-1, 1]:
		var hd := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 0.32, 0.05)
		hd.mesh = bm
		hd.material_override = nm
		hd.position = Vector3(sx * 0.1, 0.3, 0.02)
		hd.rotation.z = sx * 0.75
		h.add_child(hd)
	_lhalo(h, Vector3(0, 0.1, 0.03), Vector2(0.6, 1.1), col, 0.35)
	var t := Label3D.new()
	t.text = label.to_upper() + " >>"
	t.font = UI.font("title")
	t.font_size = 90
	t.pixel_size = 0.0035
	t.modulate = Color(col.r * 1.5, col.g * 1.5, col.b * 1.5)
	t.position = pos + Vector3(0, 0.6, 0.05)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.shaded = false
	var tw := t.font.get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, t.font_size).x * t.pixel_size
	if tw > 1.6:
		t.font_size = int(t.font_size * 1.6 / tw)
	parent.add_child(t)


## Seta pintada no chão da calçada apontando para a porta.
func _floor_arrow(parent: Node3D, pos: Vector3, col: Color) -> void:
	var m := _add_mat(col, 0.55)
	for k in 3:
		var d := Node3D.new()
		d.position = pos + Vector3(0, 0, -k * 0.55)
		parent.add_child(d)
		for sx in [-1, 1]:
			var mi := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(0.09, 0.42)
			mi.mesh = q
			mi.material_override = m
			mi.rotation = Vector3(-PI / 2, 0, sx * 0.8)
			mi.position = Vector3(sx * 0.13, 0.0, 0.0)
			d.add_child(mi)


## Outdoor físico: placa com arte gerada na proporção exata (tools/deploy/billboards.py), moldura,
## estrutura presa na parede e holofotes. Recebe a luz e a névoa da cena (material com luz).
func _billboard(art: String, face: Vector3, normal: Vector3, w: float, h: float, y: float, side := 0.0, spot := false) -> void:
	var path := "res://assets/billboards/%s_%s.png" % [art, "en" if L.lang == "en" else "pt"]
	if not FastTex.exists(path):
		return
	var t_l := Time.get_ticks_usec()
	var tex: Texture2D = FastTex.get_tex(path)
	_tk("outdoor_textura", t_l)
	var holder := Node3D.new()
	var right := Vector3(normal.z, 0, -normal.x)
	holder.position = face + normal * 0.5 + right * side
	holder.rotation.y = atan2(normal.x, normal.z)
	add_child(holder)
	var dark := _mat(Color("#0a0d18"))
	_lbox(holder, Vector3(0, y, 0), Vector3(w + 0.3, h + 0.3, 0.18), dark)
	for sx in [-w * 0.35, w * 0.35]:   # braços até a parede
		_lbox(holder, Vector3(sx, y, -0.3), Vector3(0.1, 0.1, 0.5), _mat(Color("#14161e")))
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.roughness = 0.9
	m.emission_enabled = true
	m.emission_texture = tex
	m.emission_energy_multiplier = 0.32   # retroiluminado fraco; a luz da cena faz o resto
	mi.material_override = m
	mi.position = Vector3(0, y, 0.1)
	holder.add_child(mi)
	# holofotes em cima (corpo emissivo + feixe aditivo; luz real só nos maiores)
	var n := maxi(2, int(w / 2.6))
	for k in n:
		var hx := -w / 2 + w * (k + 0.5) / n
		_lbox(holder, Vector3(hx, y + h / 2 + 0.25, 0.6), Vector3(0.26, 0.16, 0.26), _mat(Color("#14161e")))
		_lbox(holder, Vector3(hx, y + h / 2 + 0.17, 0.55), Vector3(0.18, 0.04, 0.18), _mat(Color(2.4, 2.0, 1.4), 0.0, true))
		_lbox(holder, Vector3(hx, y + h / 2 + 0.1, 0.35), Vector3(0.04, 0.04, 0.5), _mat(Color("#14161e")))
	_lhalo(holder, Vector3(0, y + h * 0.2, 0.2), Vector2(w * 1.05, h * 0.9), Color("#ffe0a8"), 0.07)
	if spot and not _light:
		var l := SpotLight3D.new()
		l.position = Vector3(0, y + h / 2 + 1.2, 1.6)
		l.rotation.x = -1.15
		l.light_color = Color("#ffe0a8")
		l.light_energy = 4.0
		l.spot_range = h + 4.0
		l.spot_angle = 42.0
		l.distance_fade_enabled = true
		l.distance_fade_begin = 40.0
		l.distance_fade_length = 10.0
		holder.add_child(l)


func _build_billboards() -> void:
	var zn := CROSS_Z + CROSS_HW + SIDE
	var zs := CROSS_Z - CROSS_HW - SIDE
	# vistos da entrada e de cada esquina, acima dos letreiros das lojas
	_billboard("bb_nome", Vector3(FAC, 0, -13.5), Vector3(-1, 0, 0), 12.0, 3.0, 9.6, 0.0, true)
	_billboard("bb_web", Vector3(-FAC, 0, -22.0), Vector3(1, 0, 0), 9.0, 3.0, 9.8)
	_billboard("bb_game", Vector3(-FAC, 0, -55.0), Vector3(1, 0, 0), 9.0, 3.0, 9.4)
	_billboard("bb_ai", Vector3(FAC, 0, -57.0), Vector3(-1, 0, 0), 9.0, 3.0, 9.4)
	_billboard("bb_arch", Vector3(-31.0, 0, zn), Vector3(0, 0, -1), 9.0, 3.0, 9.2)
	_billboard("bb_numeros", Vector3(31.0, 0, zs), Vector3(0, 0, 1), 8.0, 4.5, 9.6, 0.0, true)
	_billboard("bb_contato", Vector3(-57.0, 0, PLAZA.end.y), Vector3(0, 0, -1), 7.5, 2.5, 8.0)
	_billboard("bb_nome169", Vector3(14.0, 0, zn), Vector3(0, 0, -1), 7.2, 4.05, 9.4)
	# totens de rua com a foto (ponto de ônibus / calçada), em pé no chão
	for t in [[Vector3(-5.3, 0.2, 1.5), PI / 2], [Vector3(5.3, 0.2, CROSS_Z - 7.5), -PI / 2], [Vector3(-50.0, 0.2, -36.0), 0.0]]:
		_totem("bb_ponto", t[0], t[1])


## Totem de rua em pé (base no chão, painel retroiluminado dos dois lados).
func _totem(art: String, p: Vector3, yaw: float) -> void:
	var path := "res://assets/billboards/%s_%s.png" % [art, "en" if L.lang == "en" else "pt"]
	if not FastTex.exists(path):
		return
	var t_l := Time.get_ticks_usec()
	var tex: Texture2D = FastTex.get_tex(path)
	_tk("outdoor_textura", t_l)
	var h := Node3D.new()
	h.position = p
	h.rotation.y = yaw
	add_child(h)
	_lbox(h, Vector3(0, 0.08, 0), Vector3(1.4, 0.16, 0.6), _mat(Color("#20232c")))
	_lbox(h, Vector3(0, 1.4, 0), Vector3(1.3, 2.4, 0.22), _mat(Color("#14161e")))
	for side in [1, -1]:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.13, 2.0)
		mi.mesh = q
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m.emission_enabled = true
		m.emission_texture = tex
		m.emission_energy_multiplier = 0.55
		mi.material_override = m
		mi.position = Vector3(0, 1.42, side * 0.115)
		mi.rotation.y = 0.0 if side > 0 else PI
		h.add_child(mi)


## Placas de orientação FÍSICAS (regra do usuário): poste fincado com base, lâminas com borda clara,
## texto nítido nos dois lados, cada uma apontando para o destino; placas de nome de rua; totem de mapa.
func _sign_post(p: Vector3, dests: Array, street := "") -> void:
	var h := Node3D.new()
	h.position = p
	add_child(h)
	var steel := _mat(Color("#5a6070"), 0.0, false, 0.5)
	_lbox(h, Vector3(0, 0.04, 0), Vector3(0.36, 0.08, 0.36), _mat(Color("#2a2d36")))
	_lbox(h, Vector3(0, 1.75, 0), Vector3(0.09, 3.5, 0.09), steel)
	_lbox(h, Vector3(0, 3.55, 0), Vector3(0.13, 0.1, 0.13), steel)
	var y := 3.2
	for dd in dests:
		var target: Vector3 = dd[1]
		var col: Color = dd[2]
		var dirv := Vector3(target.x - p.x, 0, target.z - p.z)
		var blade := Node3D.new()
		blade.position = Vector3(0, y, 0)
		blade.rotation.y = atan2(-dirv.z, dirv.x)   # lâmina estende para +x local = direção do destino
		h.add_child(blade)
		_lbox(blade, Vector3(0.78, 0, 0), Vector3(1.5, 0.3, 0.05), _mat(Color("#e8ecf8")))       # borda refletiva
		_lbox(blade, Vector3(0.78, 0, 0), Vector3(1.44, 0.24, 0.06), _mat(Color("#121a36")))     # placa azul-noite
		_lbox(blade, Vector3(1.47, 0, 0), Vector3(0.04, 0.24, 0.065), _mat(col, 1.2))             # ponta colorida
		for side in [1, -1]:
			var t := Label3D.new()
			t.text = str(dd[0]).to_upper() + "  >"
			t.font = UI.font("title")
			t.font_size = 64
			t.pixel_size = 0.0034
			t.modulate = Color(1.0, 1.0, 1.0)
			t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var fs := t.font.get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, t.font_size).x * t.pixel_size
			if fs > 1.32:
				t.font_size = int(t.font_size * 1.32 / fs)
			t.position = Vector3(0.75, 0, side * 0.034)
			t.rotation.y = 0.0 if side > 0 else PI
			if side < 0:
				t.text = "<  " + str(dd[0]).to_upper()
			blade.add_child(t)
		# parafusos
		for bx in [0.12, 1.4]:
			_lbox(blade, Vector3(bx, 0, 0.035), Vector3(0.03, 0.03, 0.02), _mat(Color("#9aa0ac")))
		y -= 0.36
	if street != "":
		var st := Node3D.new()
		st.position = Vector3(0, 3.7, 0)
		h.add_child(st)
		_lbox(st, Vector3(0, 0, 0), Vector3(1.2, 0.24, 0.04), _mat(Color("#1f6a3a")))
		for side in [1, -1]:
			var t2 := Label3D.new()
			t2.text = L.t(street)
			t2.font = UI.font("title")
			t2.font_size = 60
			t2.pixel_size = 0.0034
			t2.position = Vector3(0, 0, side * 0.024)
			t2.rotation.y = 0.0 if side > 0 else PI
			t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			st.add_child(t2)


func _place_pos(id: String) -> Vector3:
	for k in kiosks:
		if str(k["project"].get("id", "")) == id:
			return k["pos"]
	return Vector3.ZERO


func _build_wayfinding() -> void:
	var D := func(id: String, label: String, col: String) -> Array: return [label, _place_pos(id), Color(col)]
	var lab := ["LAB · SOBRE MIM" if L.lang != "en" else "LAB · ABOUT ME", Vector3(0, 0, AVE_END), Color("#ffffff")]
	var car := ["CARREIRA" if L.lang != "en" else "CAREER", _place_pos("carreira"), Color("#5bd0ff")]
	var cont := ["CONTATO" if L.lang != "en" else "CONTACT", Vector3(PLAZA.position.x + 9, 0, -40.0), Color("#ff4fa3")]
	var projs := ["PROJETOS" if L.lang != "en" else "PROJECTS", Vector3(0, 0, -20.0), Color("#ffc83d")]
	# entrada
	_sign_post(Vector3(-5.6, 0.2, 4.0), [D.call("rumor", "RUMOR", "#ffc83d"), D.call("formataai", "FormataAI", "#ff6fae"),
		D.call("inaciocyber", "InacioCyber", "#39ff9b"), lab], "AV. DOS PROJETOS")
	# boca do beco
	_sign_post(Vector3(5.6, 0.2, ALLEY_Z + 3.2), [D.call("inaciocyber", "InacioCyber", "#39ff9b"), D.call("labia", "Lábia", "#ff3d7f")], "BECO DA SEGURANÇA")
	# esquinas do cruzamento
	_sign_post(Vector3(-5.6, 0.2, CROSS_Z + CROSS_HW + 0.9), [D.call("fortress", "Fortress Chaos", "#ff7a3d"), cont,
		D.call("barbercore", "BarberCore", "#c9a227"), D.call("airmessage", "AirMessage", "#5bd0ff")], "RUA DOS GAMES")
	_sign_post(Vector3(5.6, 0.2, CROSS_Z + CROSS_HW + 0.9), [car, D.call("ankiana", "AnkiAna", "#5fd38a"), D.call("atende360", "Atende 360", "#00bcd4")], "RUA DA CARREIRA")
	_sign_post(Vector3(-5.6, 0.2, CROSS_Z - CROSS_HW - 0.9), [lab, D.call("orbix", "OrbixHub", "#4e9bff"), D.call("buscavagas", "BuscaVagas", "#4e9bff")], "RUA SOBRE MIM")
	_sign_post(Vector3(5.6, 0.2, CROSS_Z - CROSS_HW - 0.9), [lab, car, projs, D.call("atende360", "Atende 360", "#00bcd4")])
	# entrada da praça
	_sign_post(Vector3(PLAZA.end.x + 1.0, 0.2, CROSS_Z + 3.0), [cont, D.call("fortress", "Fortress Chaos", "#ff7a3d")], "PRAÇA DO CONTATO")
	# totens "você está aqui" com o mapa do bairro (desenhado das ruas reais)
	_map_totem(Vector3(4.6, 0.2, 2.5), -PI / 2)
	_map_totem(Vector3(PLAZA.end.x - 2.0, 0.2, -38.0), PI / 2)


func _map_totem(p: Vector3, yaw: float) -> void:
	var img := Image.create(256, 384, false, Image.FORMAT_RGBA8)
	img.fill(Color("#0b1022"))
	var minx := -70.0
	var maxx := 50.0
	var minz := -76.0
	var maxz := 10.0
	var to_px := func(x: float, z: float) -> Vector2i:
		return Vector2i(int(16 + (x - minx) / (maxx - minx) * 224), int(60 + (z - minz) / (maxz - minz) * 300))
	for rr in map_rects:
		var rc: Rect2 = rr
		var a: Vector2i = to_px.call(rc.position.x, rc.position.y)
		var b: Vector2i = to_px.call(rc.end.x, rc.end.y)
		img.fill_rect(Rect2i(mini(a.x, b.x), mini(a.y, b.y), maxi(2, absi(b.x - a.x)), maxi(2, absi(b.y - a.y))), Color("#3a4a7a"))
	for k in kiosks:
		var kp: Vector3 = k["pos"]
		var c: Vector2i = to_px.call(kp.x, kp.z)
		img.fill_rect(Rect2i(c.x - 4, c.y - 4, 9, 9), k["neon"])
	var me: Vector2i = to_px.call(p.x, p.z)
	img.fill_rect(Rect2i(me.x - 6, me.y - 6, 13, 13), Color("#ffffff"))
	img.fill_rect(Rect2i(me.x - 3, me.y - 3, 7, 7), Color("#e2384f"))
	var tex := ImageTexture.create_from_image(img)
	var h := Node3D.new()
	h.position = p
	h.rotation.y = yaw
	add_child(h)
	_lbox(h, Vector3(0, 0.08, 0), Vector3(1.3, 0.16, 0.5), _mat(Color("#20232c")))
	_lbox(h, Vector3(0, 1.3, 0), Vector3(1.2, 2.2, 0.18), _mat(Color("#14161e")))
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.04, 1.56)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.emission_enabled = true
	m.emission_texture = tex
	m.emission_energy_multiplier = 0.7
	mi.material_override = m
	mi.position = Vector3(0, 1.2, 0.095)
	h.add_child(mi)
	var t := Label3D.new()
	t.text = "VOCÊ ESTÁ AQUI" if L.lang != "en" else "YOU ARE HERE"
	t.font = UI.font("title")
	t.font_size = 70
	t.pixel_size = 0.0034
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.modulate = Color("#ffc83d")
	t.position = Vector3(0, 2.2, 0.1)
	t.shaded = false
	h.add_child(t)


## Mais vida ligada ao trabalho dele na rua: café "dev" (food truck), banca com revistas de tecnologia,
## mural grafitado com stacks, portas de prédio e de serviço, caixas de entrega.
func _build_extras() -> void:
	# portas de prédio nos trechos livres de fachada e portas de serviço no beco
	for d in [[Vector3(-FAC, 0, -11.5), Vector3(1, 0, 0)], [Vector3(-FAC, 0, -22.5), Vector3(1, 0, 0)],
			[Vector3(FAC, 0, -13.5), Vector3(-1, 0, 0)], [Vector3(FAC, 0, -24.2), Vector3(-1, 0, 0)],
			[Vector3(-FAC, 0, -60.0), Vector3(1, 0, 0)], [Vector3(FAC, 0, -64.0), Vector3(-1, 0, 0)]]:
		var hd := Node3D.new()
		hd.position = d[0] + d[1] * 0.16
		hd.rotation.y = atan2(d[1].x, d[1].z)
		add_child(hd)
		_door(hd, Vector3.ZERO, "porta_predio")
	for d in [[Vector3(12.0, 0, ALLEY_Z + 1.95), Vector3(0, 0, -1)], [Vector3(19.0, 0, ALLEY_Z - 1.95), Vector3(0, 0, 1)]]:
		var hm := Node3D.new()
		hm.position = d[0] + d[1] * 0.05
		hm.rotation.y = atan2(d[1].x, d[1].z)
		add_child(hm)
		_door(hm, Vector3.ZERO, "porta_metal")
	_food_truck(Vector3(-2.4, 0.0, -66.5), 0.15)
	# caixas de entrega empilhadas nas portas
	for p in [Vector3(-6.3, 0.2, -10.6), Vector3(6.3, 0.2, -12.6), Vector3(-6.2, 0.2, -59.0)]:
		_prop("caixas_papelao", p, _rng.randf() * TAU, 0.7)
	_mural(Vector3((POCKET_X + ALLEY_END) / 2.0 - 0.3, 0, ALLEY_Z + POCKET_HW - 0.1), Vector3(0, 0, -1), 4.2)


## Food truck "CAFÉ DEV" parado no fim da avenida.
func _food_truck(p: Vector3, yaw: float) -> void:
	var h := Node3D.new()
	h.position = p
	h.rotation.y = yaw
	add_child(h)
	var body := _mat(Color("#c84a3a"), 0.0, false, 0.5)
	_lbox(h, Vector3(0, 1.35, 0), Vector3(3.6, 2.2, 1.9), body)
	_lbox(h, Vector3(0, 2.5, 0), Vector3(3.7, 0.12, 2.0), _mat(Color("#e8e0cc")))
	_lbox(h, Vector3(0.2, 1.55, 0.96), Vector3(2.2, 0.9, 0.04), _mat(Color("#ffcf8a"), 1.0, true))  # janela de venda acesa
	_lbox(h, Vector3(0.2, 1.08, 1.1), Vector3(2.3, 0.06, 0.3), _mat(Color("#8a8f9c")))           # balcão
	_awning(h, 0.2, 2.5, 2.32, Color("#ffc83d"))
	for x in [-1.2, 1.2]:
		var w := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.34
		cm.bottom_radius = 0.34
		cm.height = 0.24
		w.mesh = cm
		w.material_override = _mat(Color("#121418"))
		w.position = Vector3(x, 0.34, 0.95)
		w.rotation.x = PI / 2
		h.add_child(w)
	var t := Label3D.new()
	t.text = "CAFÉ DEV" if L.lang != "en" else "DEV CAFÉ"
	t.font = UI.font("title")
	t.font_size = 150
	t.pixel_size = 0.0045
	t.modulate = Color(1.8, 1.4, 0.4)
	t.position = Vector3(0.2, 2.25, 0.97)
	t.shaded = false
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(t)
	var mn := Label3D.new()
	mn.text = "cold brew · git push · deploy" if L.lang == "en" else "café · git push · deploy"
	mn.font = UI.font("type")
	mn.font_size = 60
	mn.pixel_size = 0.0035
	mn.position = Vector3(0.2, 0.75, 0.97)
	mn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(mn)


## Mural grafitado no beco com os logos oficiais das tecnologias (atlas tech_icons).
func _mural(face: Vector3, normal: Vector3, w: float) -> void:
	if not ResourceLoader.exists("res://assets/tech_icons/atlas.png"):
		return
	var h := Node3D.new()
	h.position = face + normal * 0.06
	h.rotation.y = atan2(normal.x, normal.z)
	add_child(h)
	var ids := ["godot", "blender", "node", "vue", "react", "flutter", "typescript", "python", "docker", "postgres",
		"claude", "ollama", "openai", "rust", "nuxt", "aws"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in ids.size():
		var p := "res://assets/tech_icons/%s_256.png" % ids[i]
		if not ResourceLoader.exists(p):
			continue
		var tex: Texture2D = load(p)
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		var sz := rng.randf_range(0.55, 0.85)
		q.size = Vector2(sz, sz)
		mi.mesh = q
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.emission_enabled = true
		m.emission_texture = tex
		m.emission_energy_multiplier = 0.45
		mi.material_override = m
		mi.position = Vector3(-w / 2 + (i % 8) * (w / 7.5) + 0.3, 1.0 + (i / 8) * 1.0 + rng.randf_range(-0.1, 0.1), i * 0.002)
		mi.rotation.z = rng.randf_range(-0.2, 0.2)
		h.add_child(mi)
	var t := Label3D.new()
	t.text = "STACK DO GABRIEL" if L.lang != "en" else "GABRIEL'S STACK"
	t.font = UI.font("marker")
	t.font_size = 140
	t.pixel_size = 0.0045
	t.modulate = Color(1.7, 0.6, 1.2)
	t.position = Vector3(0, 3.3, 0.02)
	t.rotation.z = -0.04
	t.shaded = false
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(t)



# ═════════════════════════════════════════════ cidade capitalista: a propaganda é o Gabriel
## Anúncios gerados por tools/deploy/ads.py (proporção exata da superfície, foto + nome + slogan +
## ícones das tecnologias). Cada prédio ganha um tipo (topo, letreiro vertical, lightbox), os muros
## sem loja ganham lambe-lambe em sequência, faixas cruzam as ruas e telões trocam de anúncio.
var _bldgs: Array = []         # {face, normal, w, h, busy, end}
var _ad_tvs: Array = []           # {mat, texs: [], i, t}
var _ad_tex_cache := {}
var _ads_meta := {}


func _ad_tex(id: String) -> Texture2D:
	# anúncios vêm de um ATLAS por língua (poucas páginas): a região vira AtlasTexture e o quad usa a
	# página inteira com UV da região. Um material por página = os anúncios fundem em poucos draw calls.
	if id == "":
		return null
	if _ads_meta.is_empty():
		var f := FileAccess.open("res://assets/ads/ads.json", FileAccess.READ)
		if f:
			_ads_meta = JSON.parse_string(f.get_as_text())
	var lg := "en" if L.lang == "en" else "pt"
	var key := lg + ":" + id
	if _ad_tex_cache.has(key):
		return _ad_tex_cache[key]
	var t: Texture2D = null
	var at: Dictionary = _ads_meta.get("atlas", {}).get(lg, {})
	var r: Variant = (at.get("map", {}) as Dictionary).get(id)
	if r is Array:
		var page := "res://assets/ads/atlas_%s_%d.png" % [lg, int(r[0])]
		var pt: Texture2D = _ad_tex_cache.get(page)
		if pt == null and FastTex.exists(page):
			var t_l := Time.get_ticks_usec()
			pt = FastTex.get_tex(page)
			_tk("anuncio_paginas", t_l)
			_ad_tex_cache[page] = pt
		if pt:
			var a := AtlasTexture.new()
			a.atlas = pt
			var ps := Vector2(pt.get_width(), pt.get_height())
			a.region = Rect2(float(r[1]) * ps.x, float(r[2]) * ps.y, float(r[3]) * ps.x, float(r[4]) * ps.y)
			t = a
	_ad_tex_cache[key] = t
	return t


## região normalizada (x, y, w, h) de uma AtlasTexture na página
func _uv_rect(tex: Texture2D) -> Rect2:
	if tex is AtlasTexture and (tex as AtlasTexture).atlas:
		var a := tex as AtlasTexture
		var ps := Vector2(a.atlas.get_width(), a.atlas.get_height())
		return Rect2(a.region.position / ps, a.region.size / ps)
	return Rect2(0, 0, 1, 1)


var _ad_mats := {}


func _ad_mat(tex: Texture2D, emit := 0.45) -> StandardMaterial3D:
	var page: Texture2D = (tex as AtlasTexture).atlas if tex is AtlasTexture else tex
	var key := "%d|%.2f" % [page.get_instance_id() if page else 0, emit]
	if _ad_mats.has(key):
		return _ad_mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = page
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.roughness = 0.9
	m.emission_enabled = true
	m.emission_texture = page
	m.emission_energy_multiplier = emit   # retroiluminado; a luz e a névoa da cena continuam valendo
	_ad_mats[key] = m
	return m


func _ad_quad(parent: Node3D, tex: Texture2D, pos: Vector3, size: Vector2, emit := 0.45) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var r := _uv_rect(tex)
	if r == Rect2(0, 0, 1, 1):
		var q := QuadMesh.new()
		q.size = size
		mi.mesh = q
	else:
		mi.mesh = _uv_quad(size, r)
	mi.material_override = _ad_mat(tex, emit)
	mi.position = pos
	parent.add_child(mi)
	return mi


## quad virado para +z com UV numa região do atlas
func _uv_quad(size: Vector2, r: Rect2) -> ArrayMesh:
	var hw := size.x / 2.0
	var hh := size.y / 2.0
	var v := PackedVector3Array([Vector3(-hw, hh, 0), Vector3(hw, hh, 0), Vector3(hw, -hh, 0), Vector3(-hw, -hh, 0)])
	var uv := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var nrm := PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	var idx := PackedInt32Array([0, 1, 2, 0, 2, 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am


func _ad_holder(face: Vector3, normal: Vector3, out := 0.0) -> Node3D:
	var h := Node3D.new()
	h.position = face + normal * out
	h.rotation.y = atan2(normal.x, normal.z)
	_host(h)
	return h


func _ad_pick(kind: String, k: int) -> String:
	var list: Array = _ads_meta.get("ads", {}).get(kind, [])
	if list.is_empty():
		return ""
	return str(list[k % list.size()])


func _build_ads() -> void:
	var f := FileAccess.open("res://assets/ads/ads.json", FileAccess.READ)
	if f == null:
		return
	_ads_meta = JSON.parse_string(f.get_as_text())
	var dark := _mat(Color("#0b0e1a"))
	var metal := _mat(Color("#1b1e2a"))
	var k_top := 0
	var k_tall := 0
	var k_box := 0
	var k_lambe := 0
	for i in _bldgs.size():
		var b: Dictionary = _bldgs[i]
		_ghost = b.has("ghost")
		if b["end"]:
			continue
		var face: Vector3 = b["face"]
		var nrm: Vector3 = b["normal"]
		var w: float = b["w"]
		var h: float = b["h"]
		var right := Vector3(nrm.z, 0, -nrm.x)
		var mode := i % 3
		if _light and i % 2 == 1:   # celular fraco: metade dos anúncios de prédio
			continue
		# 1) topo do prédio: outdoor 4:1 sobre a cornija, com treliça e holofotes
		if mode == 0 or (mode == 1 and h < 12.0):
			var tex := _ad_tex(_ad_pick("top", k_top))
			k_top += 1
			if tex:
				var aw := minf(w * 0.92, 9.0)
				var ah := aw / 4.0
				var hold := _ad_holder(face, nrm, -0.6)
				var y := h + 0.6 + ah / 2
				_lbox(hold, Vector3(0, y, -0.06), Vector3(aw + 0.24, ah + 0.24, 0.14), dark)
				_lbox(hold, Vector3(0, h + 0.3, -0.25), Vector3(aw * 0.85, 0.6, 0.12), metal)   # treliça (uma peça)
				_ad_quad(hold, tex, Vector3(0, y, 0.02), Vector2(aw, ah))
				_lhalo(hold, Vector3(0, y, 0.15), Vector2(aw * 1.1, ah * 1.4), Color("#ffe0a8"), 0.06)
		# 2) letreiro vertical 1:3 pendurado na quina, perpendicular à fachada (visto ao longo da rua)
		elif mode == 1:
			var tex2 := _ad_tex(_ad_pick("tall", k_tall))
			k_tall += 1
			if tex2 and h > 11.0:
				var vh := minf(h - 6.5, 6.0)
				var vw := vh / 3.0
				var corner := face + right * (w / 2 - 0.4)
				var hold2 := Node3D.new()
				hold2.position = corner + nrm * (vw / 2 + 0.35)
				hold2.rotation.y = atan2(right.x, right.z)
				_host(hold2)
				var yc := 5.2 + vh / 2
				_lbox(hold2, Vector3(0, yc, 0), Vector3(vw + 0.16, vh + 0.16, 0.16), dark)
				_ad_quad(hold2, tex2, Vector3(0, yc, 0.09), Vector2(vw, vh), 0.55)
				var back := _ad_quad(hold2, tex2, Vector3(0, yc, -0.09), Vector2(vw, vh), 0.55)
				back.rotation.y = PI
				for yy in [yc - vh * 0.4, yc + vh * 0.4]:   # braços até a parede
					var arm := MeshInstance3D.new()
					var bm := BoxMesh.new()
					bm.size = Vector3(0.08, 0.08, vw / 2 + 0.35)
					arm.mesh = bm
					arm.material_override = metal
					arm.position = corner + nrm * ((vw / 2 + 0.35) / 2) + Vector3(0, yy, 0)
					arm.rotation.y = atan2(nrm.x, nrm.z)
					_host(arm)
		# 3) lightbox 3:4 no 2º andar
		else:
			var tex3 := _ad_tex(_ad_pick("lightbox", k_box))
			k_box += 1
			if tex3:
				var lh := minf(3.2, h - 6.0)
				if lh > 1.6:
					var lw := lh * 0.75
					var hold3 := _ad_holder(face, nrm, 0.32)
					var off := (w / 2 - lw / 2 - 0.3) * (1.0 if i % 2 == 0 else -1.0)
					_lbox(hold3, Vector3(off, 4.4 + lh / 2, -0.08), Vector3(lw + 0.18, lh + 0.18, 0.2), dark)
					_ad_quad(hold3, tex3, Vector3(off, 4.4 + lh / 2, 0.04), Vector2(lw, lh), 0.6)
		# 4) muros sem loja: lambe-lambes em sequência no térreo
		if not b["busy"] and float(b.get("w_full", w)) > 4.0:
			var n := mini(int((w - 1.0) / 0.95), 5)
			var tex4 := _ad_tex(_ad_pick("lseq", k_lambe))
			k_lambe += 1
			if tex4 and n >= 2:
				var hold4 := _ad_holder(face, nrm, 0.16)
				# sequência de 5 cartazes diferentes (3 do Gabriel + 2 panfletos de projetos) num atlas só;
				# muros menores mostram só os n primeiros
				var sub: Texture2D = tex4
				if tex4 is AtlasTexture and n < 5:
					var a4 := (tex4 as AtlasTexture).duplicate() as AtlasTexture
					a4.region = Rect2(a4.region.position, Vector2(a4.region.size.x * n / 5.0, a4.region.size.y))
					sub = a4
				_ad_quad(hold4, sub, Vector3(0, 1.75, 0.0), Vector2(0.9 * n, 1.32), 0.15)
	_ghost = false
	# 5) faixas penduradas cruzando a avenida e a transversal
	var faixas := [[Vector3(-FAC, 0, -6.0), Vector3(FAC, 0, -6.0)], [Vector3(-FAC, 0, -33.0), Vector3(FAC, 0, -33.0)],
		[Vector3(-FAC, 0, -63.0), Vector3(FAC, 0, -63.0)],
		[Vector3(20.0, 0, CROSS_Z - CROSS_HW - SIDE - 0.5), Vector3(20.0, 0, CROSS_Z + CROSS_HW + SIDE + 0.5)],
		[Vector3(-22.0, 0, CROSS_Z - CROSS_HW - SIDE - 0.5), Vector3(-22.0, 0, CROSS_Z + CROSS_HW + SIDE + 0.5)]]
	for fi in faixas.size():
		var a: Vector3 = faixas[fi][0]
		var c2: Vector3 = faixas[fi][1]
		var tex5 := _ad_tex(_ad_pick("faixa", fi))
		if tex5 == null:
			continue
		var span := a.distance_to(c2)
		var fw := minf(span - 2.0, 8.4)
		var fh := fw / 6.0
		var mid := (a + c2) / 2 + Vector3(0, 7.2, 0)
		var across_x := absf((c2 - a).x) > 0.5
		var hold5 := Node3D.new()
		hold5.position = mid
		hold5.rotation.y = 0.0 if across_x else PI / 2
		add_child(hold5)
		_ad_quad(hold5, tex5, Vector3(0, 0, 0.01), Vector2(fw, fh), 0.35)
		var bq := _ad_quad(hold5, tex5, Vector3(0, 0, -0.01), Vector2(fw, fh), 0.35)
		bq.rotation.y = PI
		for sgn in [-1.0, 1.0]:
			var cable := MeshInstance3D.new()
			var cm := BoxMesh.new()
			cm.size = Vector3((span - fw) / 2, 0.025, 0.025)
			cable.mesh = cm
			cable.material_override = metal
			cable.position = Vector3(sgn * (fw / 2 + (span - fw) / 4), fh / 2 - 0.05, 0)
			hold5.add_child(cable)
		_swing.append({"node": hold5, "seed": float(fi) * 1.7, "amp": 0.015})
	# 6) telões grandes animados nas esquinas do cruzamento (trocam de anúncio a cada 4 s)
	var zn := CROSS_Z + CROSS_HW + SIDE
	var zs := CROSS_Z - CROSS_HW - SIDE
	var tvs := []
	var cands := []
	for b in _bldgs:
		if not b["end"] and not b["busy"] and not b.has("alt") and float(b.get("w_full", b["w"])) >= 6.0 and float(b["h"]) >= 11.5:
			var fc: Vector3 = b["face"]
			cands.append([fc.distance_to(Vector3(0, 0, CROSS_Z)), b])
	cands.sort_custom(func(x, y): return x[0] < y[0])
	for c in cands.slice(0, 5):
		tvs.append([c[1]["face"], c[1]["normal"], c[1]["w"], c[1]["h"]])
	for ti in tvs.size():
		var texs: Array = []
		for j in 3:
			var tt := _ad_tex(_ad_pick("tv", ti * 3 + j))
			if tt:
				texs.append(tt)
		if texs.is_empty():
			continue
		var hold6 := _ad_holder(tvs[ti][0], tvs[ti][1], 0.45)
		var tw := minf(6.4, float(tvs[ti][2]) - 0.8)
		var th := tw * 9.0 / 16.0
		var ty := minf(6.2 + th / 2, float(tvs[ti][3]) - th / 2 - 0.6)
		_lbox(hold6, Vector3(0, ty, -0.12), Vector3(tw + 0.4, th + 0.4, 0.3), dark)
		var scr := _screen_quad(hold6, texs[0], Vector3(0, ty, 0.05), Vector2(tw, th), 0.0, float(ti) * 3.1)
		_lhalo(hold6, Vector3(0, ty, 0.3), Vector2(tw * 1.3, th * 1.5), Color("#9fd8ff"), 0.08)
		_ad_tvs.append({"mat": scr.material_override, "texs": texs, "i": 0, "t": float(ti) * 1.3, "g": 0.0})
	var t_r := Time.get_ticks_usec()
	_build_roofs()
	_tk("anuncio_telhados", t_r)


## troca de idioma ao vivo (i18n.gd): os telões guardam a lista de anúncios da língua antiga
func lang_textures(from: String, to: String) -> int:
	var c := 0
	for tv in _ad_tvs:
		var arr: Array = tv["texs"]
		for i in arr.size():
			var nt: Texture2D = L.swap_tex(arr[i], from, to)
			if nt != arr[i]:
				arr[i] = nt
				c += 1
	_ad_tex_cache.clear()
	return c


func _tick_ads(dt: float) -> void:
	for tv in _ad_tvs:
		tv["t"] = float(tv["t"]) + dt
		var m: ShaderMaterial = tv["mat"]
		if float(tv["g"]) > 0.0:
			tv["g"] = maxf(0.0, float(tv["g"]) - dt * 4.0)
			m.set_shader_parameter("swap_glitch", float(tv["g"]))
		if float(tv["t"]) >= 4.0:
			tv["t"] = 0.0
			tv["i"] = (int(tv["i"]) + 1) % (tv["texs"] as Array).size()
			var nt: Texture2D = tv["texs"][tv["i"]]
			m.set_shader_parameter("tex", (nt as AtlasTexture).atlas if nt is AtlasTexture else nt)
			var ur := _uv_rect(nt)
			m.set_shader_parameter("uv_rect", Vector4(ur.position.x, ur.position.y, ur.size.x, ur.size.y))
			tv["g"] = 1.0       # troca de anúncio com glitch
	for bl in _blinkers:
		var on := fmod(_t + float(bl["seed"]), 1.6) < 0.25
		(bl["m"] as StandardMaterial3D).emission_energy_multiplier = 6.0 if on else 0.3
	for sl in _searchlights:
		(sl["n"] as Node3D).rotation = Vector3(-0.35 + sin(_t * 0.4 + float(sl["seed"])) * 0.25, _t * 0.25 + float(sl["seed"]), 0.0)


var _screen_shader: Shader = preload("res://shaders/screen_fx.gdshader")
var _blinkers: Array = []
var _searchlights: Array = []


## tela com o shader de telão/TV (subpixel, scanline, glitch em rajadas)
func _screen_quad(parent: Node3D, tex: Texture2D, pos: Vector3, size: Vector2, crt := 0.0, seed := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = _screen_shader
	m.set_shader_parameter("tex", (tex as AtlasTexture).atlas if tex is AtlasTexture else tex)
	var ur := _uv_rect(tex)
	m.set_shader_parameter("uv_rect", Vector4(ur.position.x, ur.position.y, ur.size.x, ur.size.y))
	m.set_shader_parameter("seed", seed)
	m.set_shader_parameter("crt", crt)
	m.set_shader_parameter("px_res", Vector2(size.x * 60.0, size.y * 60.0))
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


## Topos de prédio vivos: torres de rádio com luz vermelha piscando, antenas, parabólicas, caixas
## d'água, TVs empilhadas com propaganda (shader de TV) e holofotes cruzando o céu. Tudo DENTRO do
## telhado (offsets limitados pela largura e profundidade do prédio).
func _build_roofs() -> void:
	var metal := _mat(Color("#20232e"))
	var red := 0
	var tv_k := 0
	for i in _bldgs.size():
		var b: Dictionary = _bldgs[i]
		_ghost = b.has("ghost")
		if b["end"] or (_light and i % 2 == 1):
			continue
		var face: Vector3 = b["face"]
		var nrm: Vector3 = b["normal"]
		var w: float = b["w"]
		var h: float = b["h"]
		var right := Vector3(nrm.z, 0, -nrm.x)
		var roof := face - nrm * 4.5 + Vector3(0, h, 0)
		var lim := w / 2.0 - 1.0
		var hold := Node3D.new()
		hold.position = roof
		hold.rotation.y = atan2(nrm.x, nrm.z)
		_host(hold)
		var kind := (i * 7 + 3) % 5
		var ox := clampf((((i * 13) % 7) - 3) * 0.6, -lim, lim)
		if kind == 0:   # torre de rádio treliçada com luz vermelha
			var th := 5.0 + float(i % 3)
			_lbox(hold, Vector3(ox, th / 2, -1.0), Vector3(0.18, th, 0.18), metal)
			_lbox(hold, Vector3(ox, th * 0.45, -1.0), Vector3(1.1, 0.06, 0.06), metal)
			_lbox(hold, Vector3(ox, th * 0.75, -1.0), Vector3(0.8, 0.06, 0.06), metal)
			var lm := _mat(Color("#ff2030"), 6.0, true)
			_lbox(hold, Vector3(ox, th + 0.12, -1.0), Vector3(0.22, 0.22, 0.22), lm)
			if not _ghost:
				_blinkers.append({"m": lm, "seed": float(red) * 0.37})
			red += 1
		elif kind == 1:   # antenas + parabólica
			for j in 3:
				_lbox(hold, Vector3(ox + j * 0.5 - 0.5, 1.0 + j * 0.3, -2.0), Vector3(0.05, 2.0 + j * 0.6, 0.05), metal)
			var dish := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.6
			cm.bottom_radius = 0.15
			cm.height = 0.25
			dish.mesh = cm
			dish.material_override = _mat(Color("#8a8fa8"))
			dish.position = Vector3(clampf(ox + 1.4, -lim, lim), 1.0, -1.0)
			dish.rotation = Vector3(-0.9, 0.6, 0)
			hold.add_child(dish)
		elif kind == 2 and w >= 5.0:   # TVs empilhadas com propaganda, viradas para a rua
			var tw := minf(1.6, (w - 2.0) / 2.0)
			var thh := tw * 0.75
			for r in 2:
				for c in 2:
					var tex := _ad_tex(_ad_pick("tv", tv_k))
					tv_k += 1
					if tex == null:
						continue
					var pos := Vector3((c - 0.5) * (tw + 0.2), 0.5 + thh / 2 + r * (thh + 0.18), 3.6)
					_lbox(hold, pos + Vector3(0, 0, -0.18), Vector3(tw + 0.14, thh + 0.14, 0.32), _mat(Color("#121420")))
					_screen_quad(hold, tex, pos, Vector2(tw, thh), 1.0, float(tv_k) * 1.9)
			_lbox(hold, Vector3(0, 0.25, 3.4), Vector3(tw * 2 + 0.6, 0.5, 0.6), metal)
		elif kind == 3:   # caixa d'água em pé sobre estrutura
			_lbox(hold, Vector3(ox, 0.7, -1.5), Vector3(1.4, 1.4, 1.4), metal)
			var tank := MeshInstance3D.new()
			var tc := CylinderMesh.new()
			tc.top_radius = 0.9
			tc.bottom_radius = 0.9
			tc.height = 1.8
			tank.mesh = tc
			tank.material_override = _painted("madeira", Color("#5a4636"), 0.8, 0.0, 1.0)
			tank.position = Vector3(ox, 2.3, -1.5)
			hold.add_child(tank)
		elif not _light:   # holofote varrendo o céu (feixe aditivo, sem luz real)
			var sl := Node3D.new()
			sl.position = Vector3(ox, 0.5, -1.0)
			hold.add_child(sl)
			_lbox(hold, Vector3(ox, 0.25, -1.0), Vector3(0.6, 0.5, 0.6), metal)
			var beam := MeshInstance3D.new()
			var bc := CylinderMesh.new()
			bc.top_radius = 1.6
			bc.bottom_radius = 0.18
			bc.height = 40.0
			beam.mesh = bc
			var bm := _add_mat(Color("#9fc8ff"), 0.05)
			bm.cull_mode = BaseMaterial3D.CULL_DISABLED
			beam.material_override = bm
			beam.position = Vector3(0, 20.0, 0)
			beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			sl.add_child(beam)
			if not _ghost:
				_searchlights.append({"n": sl, "seed": float(i) * 1.3})
	_ghost = false
	_build_alley_lights()


## Beco menos escuro: arandelas na parede, neons de serviço e uma luz real no meio.
func _build_alley_lights() -> void:
	var warm := _mat(Color(2.6, 1.9, 1.2), 0.0, true)
	var x := FAC + 2.5
	var k := 0
	while x < POCKET_X - 1.9:
		for sz in [-1.0, 1.0]:
			var wz: float = ALLEY_Z + sz * 1.92
			_sbox(Vector3(x + (0.0 if sz > 0 else 1.8), 3.1, wz), Vector3(0.3, 0.3, 0.12), warm)
			var hold := Node3D.new()
			hold.position = Vector3(x + (0.0 if sz > 0 else 1.8), 0, wz)
			hold.rotation.y = 0.0 if sz < 0 else PI
			add_child(hold)
			_lhalo(hold, Vector3(0, 2.6, 0.05), Vector2(3.2, 3.6), Color("#ffcf99"), 0.22)
			_lhalo(hold, Vector3(0, 0.04, 1.2), Vector2(2.4, 2.4), Color("#ffcf99"), 0.18, true)
		x += 4.0
		k += 1
	var labels := [["24H", Color("#39ff9b"), 11.0, 1.0], ["SERVIÇO", Color("#ff3d7f"), 17.0, -1.0], ["NO PARKING", Color("#5bd0ff"), 19.2, 1.0]]
	for lb in labels:
		var t := Label3D.new()
		t.text = L.t(str(lb[0]))
		t.font = UI.font("title")
		t.font_size = 110
		t.pixel_size = 0.005
		var c: Color = lb[1]
		t.modulate = Color(c.r * 1.8, c.g * 1.8, c.b * 1.8)
		t.outline_size = 10
		t.outline_modulate = Color(c, 0.4)
		t.shaded = false
		t.position = Vector3(float(lb[2]), 3.9, ALLEY_Z + float(lb[3]) * 1.9)
		t.rotation.y = 0.0 if float(lb[3]) < 0 else PI
		add_child(t)
		var hh := Node3D.new()
		hh.position = t.position
		hh.rotation.y = t.rotation.y
		add_child(hh)
		_lhalo(hh, Vector3(0, 0, 0.05), Vector2(2.6, 1.4), c, 0.35)
	if not _light:
		var l := OmniLight3D.new()
		l.position = Vector3((FAC + ALLEY_END) / 2.0, 3.4, ALLEY_Z)
		l.light_color = Color("#ffcf99")
		l.light_energy = 2.2
		l.omni_range = 11.0
		l.distance_fade_enabled = true
		l.distance_fade_begin = 30.0
		add_child(l)



## Indicação de porta entrável: seta e "ENTRAR" pintados em neon no chão, apontando para a porta,
## na cor do projeto (o anel pulsando fica em volta; tudo emissivo, sem luz real extra).
func _door_hint(k: Dictionary) -> void:
	var rg: Node3D = k["ring"]
	var col: Color = k.get("neon", Color("#ffc83d"))
	var h := Node3D.new()
	rg.get_parent().add_child(h)
	h.position = rg.position + Vector3(0, 0.02, 0.75)   # "ENTRAR" e as setas na frente do anel, apontando para a porta
	var t := Label3D.new()
	t.text = L.t("ENTRAR")
	t.font = UI.font("title")
	t.font_size = 90
	t.pixel_size = 0.004
	t.modulate = Color(col.r * 1.8, col.g * 1.8, col.b * 1.8)
	t.shaded = false
	t.rotation = Vector3(-PI / 2, 0, 0)
	t.position = Vector3(0, 0.0, 0.25)
	h.add_child(t)
	var m := _add_mat(col, 0.7)
	for j in 2:
		var a := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.36, 0.26, 0.01)
		a.mesh = pm
		a.material_override = m
		a.rotation = Vector3(-PI / 2, 0, 0)
		a.position = Vector3(0, 0.0, -0.25 - j * 0.32)
		h.add_child(a)
	k["_hint"] = h


# ═════════════════════════════════════════════ marcador de entrada (rodada 3)
## Seta de neon flutuando acima de cada porta que se pode entrar (estilo marcador de interior de jogo de
## mundo aberto, desenho próprio): gira, balança e pulsa no shader (shaders/door_marker.gdshader), sem
## névoa, cresce um pouco de longe para ler a 30 m ou mais. Todas as portas num MultiMesh: 1 draw.
## Cor por tipo de lugar: projeto dourado, carreira/LAB azul, contato verde.
const MARKER_COLORS := {"project": Color("#ffc83d"), "career": Color("#5bd0ff"), "about": Color("#5bd0ff"), "contact": Color("#5fd38a")}
var _markers: MultiMeshInstance3D


func _marker_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# ponta (prisma de cabeça para baixo) + haste + losango no topo; grosso para continuar legível de perfil ao girar
	var head := PrismMesh.new()
	head.size = Vector3(0.62, 0.42, 0.3)
	var shaft := BoxMesh.new()
	shaft.size = Vector3(0.26, 0.3, 0.26)
	var gem := BoxMesh.new()
	gem.size = Vector3(0.22, 0.22, 0.22)
	# origem na PONTA (y = 0): o crescimento de longe sobe, nunca desce para a porta
	var parts := [[head, Transform3D(Basis(Vector3.FORWARD, PI), Vector3(0, 0.21, 0))],
		[shaft, Transform3D(Basis(), Vector3(0, 0.57, 0))],
		[gem, Transform3D(Basis(Vector3.FORWARD, PI / 4), Vector3(0, 0.92, 0))]]
	for pr in parts:
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, (pr[0] as PrimitiveMesh).get_mesh_arrays())
		st.append_from(am, 0, pr[1])
	return st.commit()


func _build_door_markers() -> void:
	var ks: Array = []
	for k in kiosks:
		if k.has("marker"):
			ks.append(k)
	if ks.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _marker_mesh()
	mm.instance_count = ks.size()
	for i in ks.size():
		var k: Dictionary = ks[i]
		var kind := str(k["project"].get("special", "project"))
		# ponta ~0,45 m acima do batente (2,5 m), colada na frente da porta (0,6 m da fachada)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 1.1), k["marker"]))
		mm.set_instance_color(i, MARKER_COLORS.get(kind, MARKER_COLORS["project"]))
		k["marker_i"] = i
	_markers = MultiMeshInstance3D.new()
	_markers.multimesh = mm
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/door_marker.gdshader")
	_markers.material_override = sm
	_markers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_markers.set_meta("_sharp_done", true)
	# também na passada nítida (camada 20): senão o letreiro nítido, composto por cima do retrô, cobre o marcador
	_markers.layers = 1 | (1 << 19)
	_markers.set_meta("noir_skip", true)
	# a caixa muda com o giro e o crescimento no shader: margem para o recorte de câmera não sumir com ele
	_markers.extra_cull_margin = 1.5
	add_child(_markers)
