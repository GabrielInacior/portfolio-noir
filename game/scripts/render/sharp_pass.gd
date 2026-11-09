extends Node
## Passada NÍTIDA por cima do mundo retrô (pedido do usuário: texto e imagem nunca sofrem downscale).
## O mundo 3D renderiza em baixa resolução com paleta/pontilhado (main.gd, RETRÔ ½). Esta passada
## renderiza em resolução cheia, no mesmo mundo e com uma câmera espelho, SÓ o que é informação:
## textos 3D (Label3D: letreiros, placas, títulos), quadros/prints/colagens/capas/foto, telões e
## monitores (README, código, gráficos, LED). As janelas falsas dos prédios e as texturas pintadas
## continuam no retrô. Para nada nítido aparecer através de uma parede, as malhas grandes do cenário
## ganham um "gêmeo oclusor" que só escreve profundidade (cor transparente) nesta passada.
## Composição: TextureRect com filtro linear por cima do retrô e por baixo da interface.

const SHARP_LAYER := 1 << 19      # camada 20: elementos nítidos
const OCC_LAYER := 1 << 18        # camada 19: oclusores (só nesta passada)
const SHARP_SHADERS := ["code_scroll", "chart_screen", "led_panel", "matrix_rain", "arcade_attract", "screen_fx"]
const SHARP_TEX_HINTS := ["/museum/", "/collages/", "/covers/", "foto_gabriel", "/readmes/", "/captures/", "/billboards/", "/flyers/", "/ads/", "/tech_icons/", "/tech_strips/"]
const RETRO_TEX_HINTS := ["janelas_atlas", "fachada_janelas", "/tex/", "/characters/", "sky_"]

var world_vp: SubViewport
var vp: SubViewport
var cam: Camera3D
var rect: TextureRect
var _occ_mat: ShaderMaterial
var _src_cam: Camera3D
var far_limit := 34.0
## desligado durante a montagem fatiada da cidade (os gêmeos oclusores entrariam na fusão de malhas);
## main.gd liga de novo e marca tudo de uma vez ao fim
var auto_tag := true
var enabled := true
## o nítido sai do mundo retrô (cada letreiro/quadro desenhado uma vez só, aqui) e esta passada vai até o
## fim da câmera; os oclusores da geometria fundida viram poucas malhas por célula (muito menos draw calls)
## (testado: com o nítido só nesta passada e sem limite de distância, letreiros distantes vazavam por vidros
## e frestas que o mundo retrô cobre; fica desligado e o ganho vem dos oclusores fundidos por célula)
var exclusive := false


## PC sem placa: sem segunda renderização; o conteúdo nítido fica no mundo (resolução baixa)
func disable() -> void:
	enabled = false
	auto_tag = false
	set_process(false)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	rect.visible = false


func setup(p_world_vp: SubViewport, under_layer: CanvasLayer) -> void:
	world_vp = p_world_vp
	vp = SubViewport.new()
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED  # MSAA misturaria a cor-chave nas bordas
	vp.handle_input_locally = false
	vp.gui_disable_input = true
	vp.audio_listener_enable_3d = false
	# mesmo mundo do retrô: a câmera desta viewport enxerga os mesmos nós
	vp.world_3d = world_vp.find_world_3d()
	add_child(vp)
	cam = Camera3D.new()
	cam.cull_mask = SHARP_LAYER | OCC_LAYER
	vp.add_child(cam)
	rect = TextureRect.new()
	rect.texture = vp.get_texture()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# recorta a cor-chave dos oclusores (magenta exato) na composição
	var key := Shader.new()
	key.code = "shader_type canvas_item;\nvoid fragment(){ vec4 c = texture(TEXTURE, UV); if (c.g < 0.03 && abs(c.r - c.b) < 0.03 && c.r > 0.45) { c.a = 0.0; } COLOR = c; }\n"
	var km := ShaderMaterial.new()
	km.shader = key
	rect.material = km
	under_layer.add_child(rect)
	# oclusor opaco (testa profundidade de verdade), pintado com a cor-chave
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;\nvoid fragment(){ ALBEDO = vec3(1.0, 0.0, 1.0); }\n"
	_occ_mat = ShaderMaterial.new()
	_occ_mat.shader = sh
	get_window().size_changed.connect(_fit)
	_fit()
	get_tree().node_added.connect(_on_node_added)
	process_priority = 1000  # depois do jogador mover a câmera


func _fit() -> void:
	var ws := Vector2i(DisplayServer.window_get_size())
	if ws.x > 0 and ws.y > 0:
		vp.size = ws


func _process(_dt: float) -> void:
	if _src_cam == null or not is_instance_valid(_src_cam) or not _src_cam.current:
		_src_cam = world_vp.get_camera_3d()
		if _src_cam:
			# o retrô não desenha os oclusores
			_src_cam.cull_mask = _src_cam.cull_mask & ~OCC_LAYER
	if _src_cam == null or (not exclusive and get_tree().get_node_count_in_group("pf_modal") > 0):
		rect.visible = false
		return
	rect.visible = true
	cam.global_transform = _src_cam.global_transform
	cam.fov = _src_cam.fov
	cam.near = _src_cam.near
	# além de ~34 m o texto já é pequeno: lá o retrô mostra a mesma peça, e a passada nítida não
	# precisa desenhar (nem os oclusores). Corta pela metade o custo desta passada na avenida.
	cam.far = _src_cam.far if exclusive else minf(_src_cam.far, far_limit)
	cam.keep_aspect = _src_cam.keep_aspect
	_sync_env()


## ambiente desta câmera: o MESMO do mundo (luz, névoa de distância, tonemap e ajuste de cor), para
## quadros e letreiros nítidos reagirem à cena como o resto; só sai o fundo (transparente) e o glow.
## Os oclusores usam fog_disabled e a cor-chave é detectada de forma robusta ao tonemap.
var _env_src: Environment


func _sync_env() -> void:
	var src: Environment = null
	var w := world_vp.find_world_3d()
	if w:
		src = w.environment
	if src == null:
		for we in get_tree().root.find_children("*", "WorldEnvironment", true, false):
			if (we as WorldEnvironment).environment:
				src = (we as WorldEnvironment).environment
	if src == _env_src and cam.environment != null:
		return
	_env_src = src
	var e: Environment = src.duplicate() if src else Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.glow_enabled = false
	e.volumetric_fog_enabled = false
	cam.environment = e


## marca uma cena montada (cidade, loja): elementos nítidos e oclusores
func tag(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	var occ := {}   # célula|alcance -> SurfaceTool (só posição) com a geometria fundida opaca
	if OS.get_environment("SHARP_DEBUG") != "":
		var kinds := {}
		for n in root.find_children("*", "MeshInstance3D", true, false):
			if n.has_meta("merged"):
				var mo: Material = (n as MeshInstance3D).material_override
				var kk := "%s|done=%s|sharp=%s" % [mo.get_meta("noir_kind", mo.get_class()) if mo else "-", n.has_meta("_sharp_done"), _is_sharp(n)]
				kinds[kk] = int(kinds.get(kk, 0)) + 1
		print("SHARP tipos dos fundidos: ", kinds)
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if enabled and OS.get_environment("SHARP_TWINS") == "" and g is MeshInstance3D and g.has_meta("merged") and not g.has_meta("_sharp_done") 				and (g as MeshInstance3D).mesh != null and not _is_sharp(g):
			g.set_meta("_sharp_done", true)
			if _surface_kinds(g as MeshInstance3D).has(false):
				var c := g.global_transform * g.get_aabb()
				# sem corte por distância no oclusor (a passada nítida termina antes, em far_limit)
				var rg := 0.0
				var ck := "%d,%d" % [floori(c.get_center().x / 32.0), floori(c.get_center().z / 32.0)]
				if not occ.has(ck):
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					occ[ck] = [st, g.visibility_range_end]
				var am := (g as MeshInstance3D).mesh
				if OS.get_environment("SHARP_DEBUG") != "" and g.get_aabb().size.length() > 40.0:
					print("SHARP grande: aabb=", g.global_transform * g.get_aabb(), " key=", ck, " vtx=", (am.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), " idx=", am.surface_get_arrays(0)[Mesh.ARRAY_INDEX] != null)
				for i in am.get_surface_count():
					var arr := am.surface_get_arrays(i)
					var only := []
					only.resize(Mesh.ARRAY_MAX)
					only[Mesh.ARRAY_VERTEX] = arr[Mesh.ARRAY_VERTEX]
					# tudo indexado: SurfaceTool.append_from com malhas mistas (com e sem índice) perde as sem
					# índice (o resultado vira indexado e os vértices antigos ficam sem triângulo)
					var ix: Variant = arr[Mesh.ARRAY_INDEX]
					if ix == null:
						ix = PackedInt32Array(range((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()))
					only[Mesh.ARRAY_INDEX] = ix
					var pm := ArrayMesh.new()
					pm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, only)
					(occ[ck][0] as SurfaceTool).append_from(pm, 0, g.global_transform)
			continue
		_classify(g)
	for ck in occ:
		var mi := MeshInstance3D.new()
		mi.mesh = (occ[ck][0] as SurfaceTool).commit()
		if OS.get_environment("SHARP_DEBUG") != "":
			print("SHARP oclusor ", ck, " vtx=", (mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() if mi.mesh and mi.mesh.get_surface_count() > 0 else -1, " aabb=", mi.mesh.get_aabb() if mi.mesh else null)
		mi.material_override = _occ_mat
		mi.layers = OCC_LAYER
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("_sharp_done", true)
		if float(occ[ck][1]) > 0.0:
			mi.visibility_range_end = float(occ[ck][1])
			mi.visibility_range_end_margin = 4.0
		root.add_child(mi)
		mi.global_transform = Transform3D.IDENTITY
	if not occ.is_empty():
		var nm := 0
		var ns := 0
		var nt := 0
		for n in root.find_children("*", "MeshInstance3D", true, false):
			if n.has_meta("merged"):
				nm += 1
				if (n as GeometryInstance3D).layers & SHARP_LAYER:
					ns += 1
					if ns < 12 and OS.get_environment("SHARP_DEBUG") != "":
						var mm0: Material = (n as MeshInstance3D).material_override
						var tx: Variant = (mm0 as ShaderMaterial).get_shader_parameter("albedo_tex") if mm0 is ShaderMaterial else null
						print("SHARP nítido fundido: ", mm0.get_meta("noir_kind", "?") if mm0 else "-", " tex=", tx.resource_path if tx is Texture2D else str(tx), " w=", tx.get_width() if tx is Texture2D else 0, " aabb=", (n as GeometryInstance3D).get_aabb().size)
				elif not _surface_kinds(n as MeshInstance3D).has(false):
					nt += 1
		print("SHARP oclusores fundidos: %d malhas (fundidos %d, nítidos %d, transparentes %d)" % [occ.size(), nm, ns, nt])


func _on_node_added(n: Node) -> void:
	if not auto_tag:
		return
	# lojas são montadas depois (ao entrar); marca quando terminam de montar
	if n is Node3D and n.get_script() and str(n.get_script().resource_path).ends_with("museum.gd"):
		_tag_later.call_deferred(n)
	elif n is GeometryInstance3D and not n.has_meta("_sharp_done"):
		# tudo que aparece depois (carros, pedestres, props instanciados) também vira oclusor
		_tag_one_later.call_deferred(n)


func _tag_later(n: Node) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	tag(n)


func _tag_one_later(n: Node) -> void:
	if is_instance_valid(n):
		_classify(n as GeometryInstance3D)


func _classify(g: GeometryInstance3D) -> void:
	if not enabled:
		return
	if g == null or not is_instance_valid(g) or g.has_meta("_sharp_done"):
		return
	g.set_meta("_sharp_done", true)
	if _is_sharp(g):
		g.layers = SHARP_LAYER if exclusive else g.layers | SHARP_LAYER
		return
	# oclusor: TUDO que o mundo desenha com volume (cenário, carros, pedestres com esqueleto, props,
	# MultiMesh). Superfícies transparentes (vidro, halos) ficam de fora por superfície, não a malha
	# inteira: o carro esconde o outdoor atrás dele, mas a vitrine continua deixando ver a colagem.
	if g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh:
		var mm := g as MultiMeshInstance3D
		if mm.get_aabb().size.length() >= 0.6 and not _all_see_through_mm(mm):
			var tw := MultiMeshInstance3D.new()
			tw.multimesh = mm.multimesh
			tw.material_override = _occ_mat
			tw.layers = OCC_LAYER
			tw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			tw.set_meta("_sharp_done", true)
			mm.add_child(tw)
		return
	if not (g is MeshInstance3D) or (g as MeshInstance3D).mesh == null:
		return
	var mi := g as MeshInstance3D
	var size := g.get_aabb().size
	if maxf(size.x, maxf(size.y, size.z)) < 0.4:
		return
	var surf := _surface_kinds(mi)
	if not surf.has(false):
		return   # tudo transparente: não esconde nada
	var twin := MeshInstance3D.new()
	twin.mesh = mi.mesh
	twin.layers = OCC_LAYER
	twin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	twin.set_meta("_sharp_done", true)
	if surf.has(true):
		for i in surf.size():
			twin.set_surface_override_material(i, _clear_mat() if surf[i] else _occ_mat)
	else:
		twin.material_override = _occ_mat
	if mi.skin or str(mi.skeleton) != "" and _in_skeleton(mi):
		# malha com esqueleto: o gêmeo é irmão, aponta para o mesmo esqueleto e a mesma pele
		twin.skin = mi.skin
		twin.transform = mi.transform
		var par := mi.get_parent()
		if par:
			par.add_child(twin)
			twin.skeleton = twin.get_path_to(mi.get_node_or_null(mi.skeleton)) if mi.get_node_or_null(mi.skeleton) else NodePath("")
	else:
		mi.add_child(twin)


var _clear: ShaderMaterial


## material que não escreve nada (para as superfícies transparentes do gêmeo)
func _clear_mat() -> ShaderMaterial:
	if _clear == null:
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nrender_mode unshaded, depth_draw_never, blend_mix, cull_disabled, shadows_disabled;\nvoid fragment(){ ALBEDO = vec3(0.0); ALPHA = 0.0; }\n"
		_clear = ShaderMaterial.new()
		_clear.shader = sh
	return _clear


## por superfície: true = transparente (não oculta)
func _surface_kinds(mi: MeshInstance3D) -> Array:
	var out := []
	for i in mi.mesh.get_surface_count():
		var m: Material = mi.material_override if mi.material_override else mi.get_active_material(i)
		var see := false
		if m is ShaderMaterial and m.has_meta("noir_kind"):
			see = str(m.get_meta("noir_kind")) in ["blend", "add"]
		elif m is BaseMaterial3D:
			var bm := m as BaseMaterial3D
			see = bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and bm.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR \
				or bm.blend_mode != BaseMaterial3D.BLEND_MODE_MIX
		out.append(see)
	return out


func _all_see_through_mm(mm: MultiMeshInstance3D) -> bool:
	var m := mm.material_override
	if m is ShaderMaterial and m.has_meta("noir_kind"):
		return str(m.get_meta("noir_kind")) in ["blend", "add"]
	if m is BaseMaterial3D:
		var bm := m as BaseMaterial3D
		return bm.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA or bm.blend_mode != BaseMaterial3D.BLEND_MODE_MIX
	return false


## vidro, halos e qualquer superfície transparente não escondem o que está atrás (vitrines!)
func _is_see_through(mi: MeshInstance3D) -> bool:
	var mats: Array = []
	if mi.material_override:
		mats.append(mi.material_override)
	for i in mi.mesh.get_surface_count():
		var m := mi.get_active_material(i)
		if m:
			mats.append(m)
	for m in mats:
		if m is BaseMaterial3D and (m as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return true
		if m is BaseMaterial3D and (m as BaseMaterial3D).blend_mode != BaseMaterial3D.BLEND_MODE_MIX:
			return true
	return false


func _in_skeleton(n: Node) -> bool:
	var q := n.get_parent()
	while q:
		if q is Skeleton3D:
			return true
		q = q.get_parent()
	return false


func _is_sharp(g: GeometryInstance3D) -> bool:
	if g is Label3D:
		return true
	if not (g is MeshInstance3D):
		return false
	var mi := g as MeshInstance3D
	var mats: Array = []
	if mi.material_override:
		mats.append(mi.material_override)
	if mi.mesh:
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m:
				mats.append(m)
	for m in mats:
		if m is ShaderMaterial and (m as ShaderMaterial).shader:
			var sp := str((m as ShaderMaterial).shader.resource_path)
			for s in SHARP_SHADERS:
				if sp.find(s) >= 0:
					return true
		var t: Texture2D = null
		if m is ShaderMaterial and m.has_meta("noir_kind"):
			t = (m as ShaderMaterial).get_shader_parameter("albedo_tex")
		elif m is StandardMaterial3D:
			t = (m as StandardMaterial3D).albedo_texture
		if m is StandardMaterial3D or m.has_meta("noir_kind"):
			if t == null:
				continue
			if t is ViewportTexture:
				return true  # telão do GitHub (README desenhado numa viewport)
			var path := str(t.resource_path)
			for r in RETRO_TEX_HINTS:
				if path.find(r) >= 0:
					return false
			for h in SHARP_TEX_HINTS:
				if path.find(h) >= 0:
					return true
			# imagem criada em tempo de execução (README baixado, colagem): nítida se for grande
			if path == "" and t.get_width() >= 192:
				return true
	return false
