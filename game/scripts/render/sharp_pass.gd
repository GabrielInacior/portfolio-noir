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
const SHARP_SHADERS := ["code_scroll", "chart_screen", "led_panel", "matrix_rain", "arcade_attract"]
const SHARP_TEX_HINTS := ["/museum/", "/collages/", "/covers/", "foto_gabriel", "/readmes/", "/captures/", "/billboards/", "/flyers/"]
const RETRO_TEX_HINTS := ["janelas_atlas", "fachada_janelas", "/tex/", "/characters/", "sky_"]

var world_vp: SubViewport
var vp: SubViewport
var cam: Camera3D
var rect: TextureRect
var _occ_mat: ShaderMaterial
var _src_cam: Camera3D


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
	if _src_cam == null:
		rect.visible = false
		return
	rect.visible = true
	cam.global_transform = _src_cam.global_transform
	cam.fov = _src_cam.fov
	cam.near = _src_cam.near
	cam.far = _src_cam.far
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
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		_classify(n as GeometryInstance3D)


func _on_node_added(n: Node) -> void:
	# lojas são montadas depois (ao entrar); marca quando terminam de montar
	if n is Node3D and n.get_script() and str(n.get_script().resource_path).ends_with("museum.gd"):
		_tag_later.call_deferred(n)
	elif n is Label3D:
		_tag_one_later.call_deferred(n)


func _tag_later(n: Node) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	tag(n)


func _tag_one_later(n: Node) -> void:
	if is_instance_valid(n):
		_classify(n as GeometryInstance3D)


func _classify(g: GeometryInstance3D) -> void:
	if g == null or not is_instance_valid(g) or g.has_meta("_sharp_done"):
		return
	g.set_meta("_sharp_done", true)
	if _is_sharp(g):
		g.layers = g.layers | SHARP_LAYER
		return
	# oclusor: malha estática grande do cenário (paredes, fachadas, chão, móveis grandes)
	if g is MeshInstance3D and (g as MeshInstance3D).mesh and not _in_skeleton(g) and not _is_see_through(g as MeshInstance3D):
		var size := g.get_aabb().size
		if maxf(size.x, maxf(size.y, size.z)) >= 1.2:
			var twin := MeshInstance3D.new()
			twin.mesh = (g as MeshInstance3D).mesh
			twin.material_override = _occ_mat
			twin.layers = OCC_LAYER
			twin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			twin.set_meta("_sharp_done", true)
			g.add_child(twin)


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
		if m is StandardMaterial3D:
			var t: Texture2D = (m as StandardMaterial3D).albedo_texture
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
