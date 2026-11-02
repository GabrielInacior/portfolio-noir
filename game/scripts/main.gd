extends Node
## Monta a cidade e a interface, com entrada cinematográfica (preto -> ENTRAR -> fade na cidade).
## O ENTRAR destrava o áudio (exigência da web) e o pointer lock no desktop.

const City := preload("res://scripts/city.gd")
const Hud := preload("res://scripts/hud.gd")

var city
var hud
var _gate: Control


func _ready() -> void:
	_setup_input()
	# tela lógica por orientação: celular em pé 720x1280; deitado baixo (celular) 960x540; PC 1280x720
	get_window().size_changed.connect(_fit_scale)
	_fit_scale()
	_build_world_view()
	city = City.new()
	_world_vp.add_child(city)
	_sharp.tag(city)
	_apply_quality()
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.visible = false
	layer.add_child(hud)
	await get_tree().process_frame
	hud.setup(city.player, city)
	_read_args()
	_build_gate(layer)
	# avisa a página (boot.js) que a cidade está montada e desenhada: o carregador HTML some
	for _i in 3:
		await get_tree().process_frame
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.pfReady&&window.pfReady()", true)


## argumentos vindos da página (boot.js): lang=en (página /en/) e loja=<projeto> (páginas de projeto
## abrem o jogo já dentro da loja daquele projeto, depois do ENTRAR)
var _open_shop := ""


func _read_args() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := str(a).trim_prefix("--").split("=", true, 1)
		if kv.size() != 2:
			continue
		if kv[0] == "lang" and kv[1] in ["pt", "en"]:
			L.force(kv[1])
		elif kv[0] == "loja":
			_open_shop = kv[1]


## Teclas registradas por código: o mapa de ações escrito à mão no project.godot estava num formato
## que o Godot ignora (as ações ficavam sem tecla e nada andava). Tecla lógica + física (WASD também
## funciona em teclados AZERTY pela posição), setas e espaço/Enter para interagir.
func _setup_input() -> void:
	var map := {
		"move_forward": [KEY_W, KEY_UP, KEY_Z],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT, KEY_Q],
		"move_right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_E, KEY_SPACE, KEY_ENTER],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		InputMap.action_erase_events(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.keycode = k
			InputMap.action_add_event(action, ev)
			# Z e Q só pela posição física de W/A (AZERTY); as demais também pela posição
			if k not in [KEY_Z, KEY_Q]:
				var ph := InputEventKey.new()
				ph.physical_keycode = k
				InputMap.action_add_event(action, ph)


# ───────────────────────────────── visual retrô (PS1): 3D em baixa resolução, ampliado sem borrar
## O 3D renderiza numa SubViewport pequena (altura interna 360 no "forte", 540 no "suave") e é
## ampliado com filtro NEAREST, com quantização de cor e pontilhado Bayer. Altura mínima de 540 para que
## imagens, telões, outdoors, letreiros e placas (conteúdo informativo) continuem nítidos (regra do usuário). A interface fica por
## cima em resolução cheia (texto nunca pixela). Escolha salva no navegador (pf_retro).
const RETRO := preload("res://shaders/retro_ps1.gdshader")
const RETRO_H := {"forte": 360, "suave": 432}
var _world_vp: SubViewport
var _world_rect: TextureRect
var _sharp
var retro := "forte"
var _potato_h := 300


func _build_world_view() -> void:
	retro = _load_retro()
	_world_vp = SubViewport.new()
	_world_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_world_vp.handle_input_locally = false
	_world_vp.audio_listener_enable_3d = true
	add_child(_world_vp)
	_world_rect = TextureRect.new()
	_world_rect.texture = _world_vp.get_texture()
	_world_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_world_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_world_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_world_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var under := CanvasLayer.new()
	under.layer = -1
	add_child(under)
	under.add_child(_world_rect)
	# passada nítida por cima do retrô: textos, imagens e telas do 3D em resolução cheia
	_sharp = preload("res://scripts/render/sharp_pass.gd").new()
	add_child(_sharp)
	_sharp.setup(_world_vp, under)
	get_window().size_changed.connect(_fit_world)
	_fit_world()


func _fit_world() -> void:
	if _world_vp == null:
		return
	var ws := Vector2(DisplayServer.window_get_size())
	if ws.x <= 0 or ws.y <= 0:
		return
	var h: float = float(RETRO_H.get(retro, 0))
	# perfil batata: o 3D desenha em resolução ainda menor (o retrô esconde, e a GPU agradece)
	if UI.quality() == 0 and h > 0.0:
		h = minf(h, float(_potato_h))
	var short_side := minf(ws.x, ws.y)
	var k := 1.0 if h <= 0.0 or h >= short_side else h / short_side
	_world_vp.size = Vector2i(maxi(16, int(ws.x * k)), maxi(16, int(ws.y * k)))
	if retro == "off":
		_world_rect.material = null
		_world_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	else:
		var m := ShaderMaterial.new()
		m.shader = RETRO
		m.set_shader_parameter("res", Vector2(_world_vp.size))
		m.set_shader_parameter("levels", 28.0 if retro == "forte" else 48.0)
		m.set_shader_parameter("dither", 1.0 if retro == "forte" else 0.6)
		_world_rect.material = m
		_world_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func set_retro(level: String) -> void:
	retro = level if level in ["forte", "suave", "off"] else "forte"
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try{localStorage.setItem('pf_retro','%s')}catch(e){}" % retro, true)
	_fit_world()


func _load_retro() -> String:
	# visual fixo: RETRÔ ½ ("suave"), sem seletor na interface (pedido do usuário). PF_RETRO só para capturas.
	var fixed := OS.get_environment("PF_RETRO")
	return fixed if fixed in ["forte", "suave", "off"] else "suave"


func _load_retro_old() -> String:
	var env := OS.get_environment("PF_RETRO")
	if env != "":
		return env
	if OS.has_feature("web"):
		var v: Variant = JavaScriptBridge.eval("(function(){try{return localStorage.getItem('pf_retro')||''}catch(e){return ''}})()", true)
		if v != null and str(v) in ["forte", "suave", "off"]:
			return str(v)
	return "forte"


## eventos (mouse, teclado) seguem para o mundo 3D dentro da SubViewport
func _unhandled_input(e: InputEvent) -> void:
	if _world_vp and not (e is InputEventScreenTouch or e is InputEventScreenDrag):
		_world_vp.push_input(e, true)


func _build_gate(layer: CanvasLayer) -> void:
	# tela de entrada do design system (scripts/ui/gate.gd): título, ENTRAR, idioma e comandos
	_gate = Gate.new()
	_gate.entered.connect(_enter)
	layer.add_child(_gate)


func _enter() -> void:
	Audio.start()
	hud.visible = true
	if not UI.is_mobile():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var tw := create_tween()
	tw.tween_property(_gate, "modulate:a", 0.0, 0.9)
	tw.tween_callback(_gate.queue_free)
	if _open_shop != "":
		for pr in Data.projects:
			if str(pr.get("id", "")) == _open_shop:
				hud.enter_museum(pr)
				break
		_open_shop = ""



func _fit_scale() -> void:
	var ws := DisplayServer.window_get_size()
	if ws.x <= 0 or ws.y <= 0:
		return
	var want := Vector2i(1280, 720)
	if ws.y > ws.x:
		want = Vector2i(720, 1280)
	elif ws.y < 600:
		want = Vector2i(960, 540)
	if get_window().content_scale_size != want:
		get_window().content_scale_size = want
		_watch_dirty = 3


## perfil de qualidade aplicado ao que não é montagem: distância da passada nítida, câmera, névoa, brilho
func _apply_quality() -> void:
	var q := UI.quality()
	_sharp.far_limit = [16.0, 34.0, 40.0][q]
	if city and city.player and city.player.cam:
		city.player.cam.far = [70.0, 140.0, 160.0][q]
	for n in city.find_children("*", "WorldEnvironment", true, false) if city else []:
		var e: Environment = (n as WorldEnvironment).environment
		if e and q == 0:
			e.glow_enabled = false
			e.fog_depth_end = 62.0
	_fit_world()


## FPS baixo por alguns segundos: cai para o perfil batata em tempo real (resolução, passada nítida,
## distância de desenho) e, se ainda pesar, baixa mais a resolução interna. Nunca volta a subir sozinho.
var _fps_acc := 0.0
var _fps_n := 0
var _fps_bad := 0.0


func _watch_fps(dt: float) -> void:
	if hud == null or not hud.visible:
		return
	_fps_acc += dt
	_fps_n += 1
	if _fps_acc < 1.0:
		return
	var fps := _fps_n / _fps_acc
	_fps_acc = 0.0
	_fps_n = 0
	_fps_bad = _fps_bad + 1.0 if fps < 28.0 else maxf(0.0, _fps_bad - 1.0)
	if _fps_bad >= 4.0:
		_fps_bad = 0.0
		if UI.quality() > 0:
			UI.set_quality(0)
			_apply_quality()
		elif _potato_h > 216:
			_potato_h -= 42
			_fit_world()
			_sharp.far_limit = maxf(8.0, _sharp.far_limit - 4.0)


## Vigia de texto vertical (lição do RUMOR): texto que quebra linha e ficou espremido vira coluna de
## letras; aqui ele deixa de quebrar. Só confere quando a tela muda (nó novo ou janela girada).
var _watch_t := 0.0
var _watch_dirty := 2
var _watch_hooked := false


func _process(dt: float) -> void:
	_watch_fps(dt)
	if not _watch_hooked:
		_watch_hooked = true
		get_tree().node_added.connect(func(n: Node) -> void:
			if n is Label:
				_watch_dirty = 2)
	_watch_t += dt
	if _watch_t < 0.4 or _watch_dirty <= 0:
		return
	_watch_t = 0.0
	_watch_dirty -= 1
	_scan_labels(self)


func _scan_labels(n: Node) -> void:
	for c in n.get_children():
		if c is Label:
			var l := c as Label
			if l.autowrap_mode != TextServer.AUTOWRAP_OFF and l.is_visible_in_tree() and l.text.length() > 3:
				var fs := l.get_theme_font_size("font_size")
				if l.size.x > 0.0 and l.size.x < fs * 2.2:
					l.autowrap_mode = TextServer.AUTOWRAP_OFF
					l.clip_text = true
		elif c is CanvasItem and not (c as CanvasItem).visible:
			continue
		_scan_labels(c)
