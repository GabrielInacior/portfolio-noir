extends Node
## Monta a cidade e a interface, com entrada cinematográfica (preto -> ENTRAR -> fade na cidade).
## O ENTRAR destrava o áudio (exigência da web) e o pointer lock no desktop.

const City := preload("res://scripts/city.gd")
const Hud := preload("res://scripts/hud.gd")

var city
var hud
var _gate: Control


func _ready() -> void:
	# tela lógica por orientação: celular em pé 720x1280; deitado baixo (celular) 960x540; PC 1280x720
	get_window().size_changed.connect(_fit_scale)
	_fit_scale()
	_build_world_view()
	city = City.new()
	_world_vp.add_child(city)
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


# ───────────────────────────────── visual retrô (PS1): 3D em baixa resolução, ampliado sem borrar
## O 3D renderiza numa SubViewport pequena (altura interna 360 no "forte", 540 no "suave") e é
## ampliado com filtro NEAREST, com quantização de cor e pontilhado Bayer. Altura mínima de 540 para que
## imagens, telões, outdoors, letreiros e placas (conteúdo informativo) continuem nítidos (regra do usuário). A interface fica por
## cima em resolução cheia (texto nunca pixela). Escolha salva no navegador (pf_retro).
const RETRO := preload("res://shaders/retro_ps1.gdshader")
const RETRO_H := {"forte": 360, "suave": 432}
var _world_vp: SubViewport
var _world_rect: TextureRect
var retro := "forte"


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
	get_window().size_changed.connect(_fit_world)
	_fit_world()


func _fit_world() -> void:
	if _world_vp == null:
		return
	var ws := Vector2(DisplayServer.window_get_size())
	if ws.x <= 0 or ws.y <= 0:
		return
	var h: float = float(RETRO_H.get(retro, 0))
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
	_gate = Control.new()
	_gate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gate.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("#05060c")
	_gate.add_child(UI.full(bg))
	var center := CenterContainer.new()
	_gate.add_child(UI.full(center))
	var v := UI.vbox(18)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)
	var over := UI.label(L.t("PORTFÓLIO"), 22, UI.PINK, "type")
	over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over.add_theme_constant_override("outline_size", 0)
	v.add_child(over)
	var logo := UI.title("GABRIEL INÁCIO", 86, UI.PAPER)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(logo)
	var sub := UI.label("engenharia de software · games · IA", 26, UI.AMBER, "type")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 30
	v.add_child(spacer)
	var enter := UI.button("ENTRAR NA CIDADE", UI.AMBER, 86)
	enter.custom_minimum_size.x = 420
	enter.pressed.connect(_enter)
	v.add_child(enter)
	var langs := UI.hbox(10)
	langs.alignment = BoxContainer.ALIGNMENT_CENTER
	for spec in [["PORTUGUÊS", "pt"], ["ENGLISH", "en"]]:
		var lb := UI.ghost(spec[0], UI.AMBER if L.lang == spec[1] else UI.MIST, 56)
		lb.custom_minimum_size.x = 180
		lb.pressed.connect(func() -> void: L.set_lang(spec[1]))
		langs.add_child(lb)
	v.add_child(langs)
	var hint := UI.label("ative o som para a experiência completa", 18, UI.MIST, "body")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	layer.add_child(_gate)
	# respiração do título: o tween pertence ao próprio título e morre com a tela de entrada (preso ao
	# nó principal ele virava loop infinito instantâneo quando a tela era liberada e travava a aba no
	# navegador; no desktop o Godot só avisa "Infinite loop detected")
	var tw := logo.create_tween().set_loops()
	tw.tween_property(logo, "modulate:a", 0.6, 1.4)
	tw.tween_property(logo, "modulate:a", 1.0, 1.4)


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


## Vigia de texto vertical (lição do RUMOR): texto que quebra linha e ficou espremido vira coluna de
## letras; aqui ele deixa de quebrar. Só confere quando a tela muda (nó novo ou janela girada).
var _watch_t := 0.0
var _watch_dirty := 2
var _watch_hooked := false


func _process(dt: float) -> void:
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
