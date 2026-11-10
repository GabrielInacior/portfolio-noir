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
	if UI.software():
		# sem placa de vídeo: 30 quadros por segundo dão fôlego à CPU, e o 3D desenha em 240 px de altura
		Engine.max_fps = 30
		_potato_h = 240
	# tela lógica por orientação: celular em pé 720x1280; deitado baixo (celular) 960x540; PC 1280x720
	get_window().size_changed.connect(_fit_scale)
	_fit_scale()
	_build_world_view()
	# os anúncios e outdoors do idioma vêm num pacote pequeno que baixa em paralelo com o principal
	await Packs.need("lang")
	city = City.new()
	# na web (ou com PFSLICE=1) a cidade monta em fatias, com progresso para o carregador da página
	city.sliced = OS.has_feature("web") or OS.get_environment("PFSLICE") != ""
	_sharp.auto_tag = false
	# enquanto a cidade monta, o 3D não é desenhado (o carregador da página cobre a tela): cada quadro
	# custaria dezenas de ms com a cidade pela metade e o tempo de montagem quadruplicava
	var draw_mode := _world_vp.render_target_update_mode
	if city.sliced:
		_world_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_sharp.vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_world_vp.add_child(city)
	if not city.is_built:
		await city.built
	_world_vp.render_target_update_mode = draw_mode
	if UI.software():
		_sharp.disable()
	else:
		_sharp.auto_tag = true
		_sharp.vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var tt := Time.get_ticks_msec()
	_sharp.tag(city)
	print("PFT %5d ms  nítida marcada (%d ms)" % [Time.get_ticks_msec(), Time.get_ticks_msec() - tt])
	tt = Time.get_ticks_msec()
	# personagens montam o material no próprio _ready (depois da conversão da cidade): converte de novo
	preload("res://scripts/render/noir.gd").convert_tree(city)
	_noir.auto_convert = true
	print("PFT %5d ms  reconversão noir (%d ms)" % [Time.get_ticks_msec(), Time.get_ticks_msec() - tt])
	_apply_quality()
	if _census_on():
		_census("cidade")
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.visible = false
	layer.add_child(hud)
	await get_tree().process_frame
	hud.setup(city.player, city)
	_read_args()
	# troca de idioma ao vivo: índice e imagens do outro idioma prontos ainda com o carregador na tela
	if not UI.software():
		await L.prepare(true)
	_build_gate(layer)
	# avisa a página (boot.js) que a cidade está montada e desenhada: o carregador HTML some
	for _i in 3:
		await get_tree().process_frame
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.pfReady&&window.pfReady()", true)
	print("PFT %5d ms  pronto (ENTRAR)" % Time.get_ticks_msec())
	_setup_ab()


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
var _noir
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
	# mundo noir: luzes viram dados do shader próprio (scripts/render/noir.gd)
	_noir = preload("res://scripts/render/noir.gd").new()
	add_child(_noir)
	_noir.setup(_world_vp)
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
		var vfx := _vhs_level()
		m.set_shader_parameter("fx", vfx)
		if _sharp and _sharp.rect and _sharp.rect.material:
			(_sharp.rect.material as ShaderMaterial).set_shader_parameter("fx", vfx)
		_world_rect.material = m
		_world_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## filtro de fita VHS / TV antiga (retro_ps1.gdshader): DESLIGADO (pedido do usuário depois da rodada 4; a imagem
## volta à de antes). Só para teste: ?vhs=1 liga (completo no PC, com grão no celular, mínimo no batata/sem placa).
func _vhs_level() -> float:
	if OS.get_environment("PF_VHS") != "":
		return float(OS.get_environment("PF_VHS"))
	if not OS.has_feature("web") or str(JavaScriptBridge.eval("/[?&]vhs=1/.test(location.search)?1:0", true)) != "1":
		return 0.0
	if UI.software() or UI.quality() == 0:
		return 1.0
	return 2.0 if UI.is_mobile() else 3.0


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
## PC sem placa (SwiftShader/llvmpipe): medido no SwiftShader, luzes reais custam ~45 ms por quadro, MultiMesh
## de janelas/skyline ~58 ms e a malha fundida ~68 ms. Aqui só se corta o que for preciso: sem luz real (o
## neon é emissivo), 45% das instâncias de janelas e skyline, nada além de 55 m.
func _apply_software() -> void:
	# com o mundo noir as luzes são dados do shader (poucas, ver noir.gd): continuam
	if not preload("res://scripts/render/noir.gd").enabled():
		for n in city.find_children("*", "Light3D", true, false):
			(n as Light3D).visible = false
	for n in city.find_children("*", "MultiMeshInstance3D", true, false):
		var mm := (n as MultiMeshInstance3D).multimesh
		if mm and mm.instance_count > 40:
			mm.visible_instance_count = int(mm.instance_count * 0.45)


func _apply_quality() -> void:
	if UI.software() and city:
		_apply_software()
	var q := UI.quality()
	_sharp.set_far([16.0, 34.0, 40.0][q])
	if city and city.player and city.player.cam:
		city.player.cam.far = 38.0 if UI.software() else [70.0, 140.0, 160.0][q]
	for n in city.find_children("*", "WorldEnvironment", true, false) if city else []:
		var e: Environment = (n as WorldEnvironment).environment
		if e and q == 0:
			e.glow_enabled = false
			e.fog_depth_end = 34.0 if UI.software() else 62.0
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
			_sharp.set_far(maxf(8.0, _sharp.far_limit - 4.0))


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


## censo de programas de shader e draws por categoria (depuração: ?perf=1 ou CENSUS=1)
func _census_on() -> bool:
	if OS.get_environment("CENSUS") != "":
		return true
	return OS.has_feature("web") and str(JavaScriptBridge.eval("/[?&]census=1/.test(location.search)?1:0", true)) == "1"


func _census(label: String) -> void:
	var cars: Array = []
	for c in city._cars:
		cars.append(c["node"])
	var txt: String = preload("res://scripts/render/census.gd").run(_world_vp, label, cars)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__pfCensus=%s" % JSON.stringify(txt), true)


# ───────────────────────────────── interruptores de teste A/B de desempenho (web, `window.pfAB(nome, ligado)`)
## Liga/desliga um sistema por vez para medir o custo de cada um (ver docs/PERFORMANCE.md). Inofensivo no uso normal.
var _ab_cb


func _setup_ab() -> void:
	if not OS.has_feature("web"):
		return
	_ab_cb = JavaScriptBridge.create_callback(_ab)
	JavaScriptBridge.get_interface("window").pfAB = _ab_cb


var _ab_saved := {}


## desliga/religa preservando o estado original (alguns nós já nascem escondidos por desenho)
func _ab_vis(n: Node3D, on: bool) -> void:
	var id := n.get_instance_id()
	if not on:
		if not _ab_saved.has(id):
			_ab_saved[id] = n.visible
		n.visible = false
	elif _ab_saved.has(id):
		n.visible = bool(_ab_saved[id])


func _ab(args: Array) -> void:
	var name := str(args[0])
	var on := bool(args[1])
	match name:
		"world":
			city.visible = on
		"sharp":
			_sharp.vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
			_sharp.rect.visible = on
		"retro":
			_world_rect.material = null if not on else _world_rect.material
			if on:
				_fit_world()
			else:
				_world_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		"lights":
			for n in city.find_children("*", "Light3D", true, false):
				_ab_vis(n, on)
		"labels":
			for n in city.find_children("*", "Label3D", true, false):
				_ab_vis(n, on)
		"rain":
			for n in [city._rain_node, city._splash_node]:
				if n:
					_ab_vis(n, on)
		"glow":
			for n in city.find_children("*", "WorldEnvironment", true, false):
				var e: Environment = (n as WorldEnvironment).environment
				if not _ab_saved.has("glow"):
					_ab_saved["glow"] = e.glow_enabled
				e.glow_enabled = bool(_ab_saved["glow"]) if on else false
		"fog":
			for n in city.find_children("*", "WorldEnvironment", true, false):
				(n as WorldEnvironment).environment.fog_enabled = on
		"hud":
			hud.visible = on
		"audio":
			var au := get_node("/root/Audio")
			au._player.stream_paused = not on
			for b in au._beds.values():
				(b as AudioStreamPlayer).stream_paused = not on
		"merged", "mm", "lbl", "part", "mesh", "light":
			var cls: String = {"merged": "MeshInstance3D", "mm": "MultiMeshInstance3D", "lbl": "Label3D", "part": "CPUParticles3D", "mesh": "MeshInstance3D", "light": "Light3D"}[name]
			for n in city.find_children("*", cls, true, false):
				var is_merged: bool = n.has_meta("merged")
				if name == "merged" and not is_merged:
					continue
				if name == "mesh" and is_merged:
					continue
				_ab_vis(n, on)
		"info":
			var rid: RID = _world_vp.get_viewport_rid()
			var rid2: RID = _sharp.vp.get_viewport_rid()
			var dc := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
			var ob := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)
			var pr := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
			var dc2 := RenderingServer.viewport_get_render_info(rid2, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
			var txt := "dc=%d obj=%d prim=%d sharp_dc=%d vram=%dMB" % [dc, ob, pr, dc2, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576]
			JavaScriptBridge.eval("window.__pfInfo=%s" % JSON.stringify(txt), true)
			print("PFINFO dc=%d obj=%d prim=%d sharp_dc=%d vram=%dMB tex=%dMB buf=%dMB" % [dc, ob, pr, dc2, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) / 1048576])
		"shop":
			var sid := str(args[2]) if args.size() > 2 else ""
			var pj := {}
			if sid == "sobre":
				pj = {"id": "sobre", "title": "LAB", "special": "about"}
			elif sid == "carreira":
				pj = {"id": "carreira", "title": "CARREIRA", "special": "career"}
			else:
				for p in Data.projects:
					if str(p.get("id", "")) == sid:
						pj = p
			if on and not pj.is_empty():
				hud.enter_museum(pj)
			elif not on:
				hud.exit_museum()
		"enter":
			if _gate and is_instance_valid(_gate):
				_gate.entered.emit()
		"noirfeed":
			_noir.set_process(on)
		"lang":
			L.set_lang(str(args[2]) if args.size() > 2 else ("pt" if L.lang == "en" else "en"))
		"census":
			_census(str(args[2]) if args.size() > 2 else "cena")
		"sfxtick":
			get_node("/root/Audio").set_process(on)
		"sfx", "sfx3d":
			# sonda de som: toca um efeito pelo id (2D ou 3D a 2 m na frente do jogador)
			var au2 := get_node("/root/Audio")
			var sid2 := str(args[2]) if args.size() > 2 else "ui_abrir"
			if name == "sfx":
				au2.play(sid2)
			elif city and city.player:
				var cam3: Camera3D = city.player.cam
				au2.play_at(sid2, cam3.global_position - cam3.global_transform.basis.z * 2.0)
		"cars":
			for c in city._cars:
				_ab_vis(c["node"], on)
		"walkers":
			for w in city._walkers:
				_ab_vis(w["node"], on)
		"fx", "traffic", "ads", "proc":
			if on:
				city.ab.erase("no" + name)
			else:
				city.ab["no" + name] = true
