extends Control
## Interface por cima da cidade: alavanca virtual (celular), olhar por arrasto, aviso de
## interação, nome, minimapa, contador de projetos visitados, som liga/desliga, modo lista.

const Dossier := preload("res://scripts/dossier.gd")
const ListMode := preload("res://scripts/list_mode.gd")
const Dialogue := preload("res://scripts/dialogue.gd")
const Minimap := preload("res://scripts/minimap.gd")
const Museum := preload("res://scripts/museum.gd")
const Exhibit := preload("res://scripts/exhibit.gd")
const Panels := preload("res://scripts/panels.gd")

var _museum = null
var _entry_xform: Transform3D
var _exam: Dictionary = {}

var player
var city
var prompt: PanelContainer
var prompt_label: Label
var counter_label: Label
var minimap: Control
var stick_base: Panel
var stick_knob: Panel
var _stick_touch := -1
var _look_touch := -1
var _stick_center := Vector2.ZERO
var _current: Dictionary = {}
var _sheet_open := false
var reticle: Control
var _prompt_hint: Label
var _ret_hot := false


func setup(p, c) -> void:
	player = p
	city = c
	player.target_changed.connect(_on_target)
	player.interacted.connect(_on_interact)
	city.visited_changed.connect(_on_visited)
	if minimap:
		minimap.city = c
		minimap.player = p


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_topbar()
	_build_minimap()
	_build_prompt()
	_build_reticle()
	if UI.is_mobile():
		_build_stick()
	set_process_input(true)


var _topbar: Control
var _topbar_narrow := -1


## Barra de cima responsiva: no PC uma linha (nome, contador, som, idioma, retrô, projetos); no
## celular em pé duas linhas, com nome e contador em cima e botões de toque de 88 px embaixo
## (antes a linha única passava da largura de 720 e a barra sumia no celular).
func _build_topbar() -> void:
	var narrow := get_viewport_rect().size.x < 900.0
	_topbar_narrow = 1 if narrow else 0
	if _topbar and is_instance_valid(_topbar):
		_topbar.queue_free()
	var bar := PanelContainer.new()
	_topbar = bar
	bar.add_theme_stylebox_override("panel", UI.box(Color(UI.INK, 0.62), Color.TRANSPARENT, 0, 0))
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 18)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 12 + _safe_top())
	pad.add_theme_constant_override("margin_bottom", 8)
	bar.add_child(pad)
	var rows := UI.vbox(6)
	pad.add_child(rows)
	var h := UI.hbox(14)
	rows.add_child(h)
	var nm := UI.title("GABRIEL INÁCIO", 34 if narrow else 36, UI.PAPER)
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(nm)
	counter_label = UI.label(counter_label.text if counter_label and is_instance_valid(counter_label) else "", 20, UI.AMBER, "type")
	counter_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	counter_label.clip_text = true
	counter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	counter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(counter_label)
	var btns := h
	if narrow:
		btns = UI.hbox(10)
		rows.add_child(btns)
	var bh := 76 if narrow else 48
	# texto em vez de símbolo: a fonte do navegador não tem "♪" (saía um quadrado)
	var snd := UI.ghost(L.t("SOM") if Audio.is_on() else L.t("MUDO"), UI.PINK, bh)
	snd.custom_minimum_size.x = 96 if narrow else 84
	snd.tooltip_text = L.t("Som")
	snd.pressed.connect(func() -> void:
		var on := not Audio.is_on()
		Audio.set_enabled(on)
		snd.text = L.t("SOM") if on else L.t("MUDO"))
	btns.add_child(snd)
	# idioma (PT/EN) e visual retrô (forte/suave/desligado), salvos no navegador
	var lang := UI.ghost("EN" if L.lang == "pt" else "PT", UI.CYAN, bh)
	lang.custom_minimum_size.x = 88 if narrow else 64
	lang.tooltip_text = "English" if L.lang == "pt" else "Português"
	lang.pressed.connect(func() -> void: L.set_lang("en" if L.lang == "pt" else "pt"))
	btns.add_child(lang)
	var main_node := get_tree().current_scene
	var names := {"forte": "RETRÔ", "suave": "RETRÔ ½", "off": "HD"}
	var rb := UI.ghost(L.t(names.get(str(main_node.get("retro")) if main_node and main_node.get("retro") != null else "forte", "RETRÔ")), UI.GREEN, bh)
	rb.custom_minimum_size.x = 130 if narrow else 110
	rb.pressed.connect(func() -> void:
		var mn := get_tree().current_scene
		if mn == null or not mn.has_method("set_retro"):
			return
		var order := ["forte", "suave", "off"]
		var nxt: String = order[(order.find(str(mn.get("retro"))) + 1) % 3]
		mn.set_retro(nxt)
		rb.text = L.t(names[nxt]))
	btns.add_child(rb)
	var lst := UI.ghost(L.t("PROJETOS"), UI.AMBER, bh)
	lst.custom_minimum_size.x = 150
	if narrow:
		lst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lst.pressed.connect(_open_list)
	btns.add_child(lst)
	add_child(bar)
	move_child(bar, 0)
	# minimapa logo abaixo da barra (que no celular tem duas linhas)
	if minimap:
		_place_minimap()


func _safe_top() -> int:
	# entalhe/barra de status: área segura do sistema (no navegador vem da janela inteira)
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_position()
	var top := safe.position.y - win.y
	return clampi(top, 0, 60)


func _place_minimap() -> void:
	var top := 172 if _topbar_narrow == 1 else 86
	minimap.offset_top = top
	minimap.offset_bottom = top + 150


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _topbar_narrow != -1:
		var narrow := 1 if get_viewport_rect().size.x < 900.0 else 0
		if narrow != _topbar_narrow:
			_build_topbar.call_deferred()


func _build_minimap() -> void:
	minimap = Minimap.new()
	minimap.custom_minimum_size = Vector2(190, 150)
	minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -206
	minimap.offset_right = -16
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.clip_contents = true
	add_child(minimap)
	_place_minimap()


func _build_prompt() -> void:
	prompt = PanelContainer.new()
	prompt.add_theme_stylebox_override("panel", UI.box(Color(UI.NIGHT, 0.95), UI.AMBER, 2, 14, 16))
	var v := UI.vbox(4)
	prompt_label = UI.label("", 28, UI.AMBER, "type")
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(prompt_label)
	var hint := UI.label("toque para abrir" if UI.is_mobile() else "[E] abrir  ·  toque no letreiro para ir até lá", 20 if UI.is_mobile() else 18, UI.MIST, "body")
	_prompt_hint = hint
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	prompt.add_child(v)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_top = -176
	prompt.offset_bottom = -96
	prompt.offset_left = -240
	prompt.offset_right = 240
	prompt.visible = false
	prompt.mouse_filter = Control.MOUSE_FILTER_STOP
	prompt.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and not _current.is_empty():
			_on_interact(_current))
	add_child(prompt)


## retícula central: ponto discreto; vira anel com a cor do objeto quando há algo interativo
func _build_reticle() -> void:
	reticle = Control.new()
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.draw.connect(func() -> void:
		if _ret_hot:
			var k := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.01)
			reticle.draw_arc(Vector2.ZERO, 16.0 * k, 0, TAU, 32, UI.AMBER, 3.0, true)
			reticle.draw_circle(Vector2.ZERO, 3.0, UI.AMBER)
		else:
			reticle.draw_circle(Vector2.ZERO, 3.0, Color(1, 1, 1, 0.55)))
	add_child(reticle)


func _build_stick() -> void:
	stick_base = Panel.new()
	stick_base.add_theme_stylebox_override("panel", UI.box(Color(UI.PAPER, 0.07), Color(UI.PAPER, 0.28), 2, 80))
	stick_base.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	stick_base.offset_left = 40
	stick_base.offset_top = -200
	stick_base.offset_right = 200
	stick_base.offset_bottom = -40
	stick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stick_base)
	stick_knob = Panel.new()
	stick_knob.add_theme_stylebox_override("panel", UI.box(Color(UI.AMBER, 0.85), UI.AMBER, 0, 50))
	stick_knob.size = Vector2(72, 72)
	stick_knob.position = Vector2(84, stick_base.offset_top + 44)
	stick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stick_knob)
	_reset_knob()


func _reset_knob() -> void:
	if stick_knob:
		stick_knob.position = Vector2(84, size.y - 200 + 44)


func _on_target(project: Dictionary) -> void:
	_current = project
	if project.is_empty():
		prompt.visible = false
	elif not _sheet_open:
		prompt_label.text = str(project.get("title", "")).to_upper()
		prompt.visible = true


func _on_visited(count: int, total: int) -> void:
	counter_label.text = L.tf("· %d/%d explorados", [count, total])


func _input(e: InputEvent) -> void:
	if not UI.is_mobile() or _sheet_open:
		return
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			if t.position.x < size.x * 0.45 and _stick_touch == -1 and t.position.y > size.y * 0.4:
				_stick_touch = t.index
				_stick_center = t.position
			elif _look_touch == -1 and t.position.y > 90:
				_look_touch = t.index
		else:
			if t.index == _stick_touch:
				_stick_touch = -1
				player.move_vec = Vector2.ZERO
				_reset_knob()
			elif t.index == _look_touch:
				_look_touch = -1
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		if d.index == _stick_touch:
			var off := (d.position - _stick_center).limit_length(70)
			player.move_vec = Vector2(off.x, off.y) / 70.0
			if stick_knob:
				stick_knob.position = _stick_center + off - Vector2(36, 36)
		elif d.index == _look_touch:
			player.look_delta += d.relative


func _on_interact(project: Dictionary) -> void:
	if _sheet_open:
		return
	# dentro de uma loja-museu: examinar o item mirado ou sair pela porta
	if _museum != null:
		if _museum.at_exit(player.global_position) and _exam.is_empty():
			exit_museum()
		elif not _exam.is_empty():
			_activate(_exam)
		return
	if project.is_empty():
		return
	# contato é um cartão simples; sobre e projetos entram numa loja-museu
	if project.get("special", "") == "contact":
		open_dossier(project)
		return
	enter_museum(project)


# ───────────────────────────────── entrar e sair da loja-museu
func enter_museum(project: Dictionary) -> void:
	var id := "_lab" if project.get("special", "") == "about" else ("_carreira" if project.get("special", "") == "career" else str(project.get("id", "")))
	var path := "res://assets/museum/_items/%s.json" % id
	if not FileAccess.file_exists(path):
		open_dossier(project)   # sem museu montado: cai no dossiê
		return
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	if city:
		city.mark_visited(project)
	_entry_xform = player.global_transform
	city.visible = false
	city.set_process(false)
	city.set_physics_process(false)
	_museum = Museum.new()
	_museum.setup(project if project.get("special", "") != "career" else {"id": "_carreira", "title": "CARREIRA", "special": "career"}, d, project.get("special", "") == "about")
	city.get_parent().add_child(_museum)
	player.get_parent().remove_child(player)
	_museum.add_child(player)
	player.global_position = _museum.spawn_pos()
	player._yaw = PI
	player.rotation.y = PI
	player.set_meta("walk", player.walk_rects)
	player.walk_rects = []
	var br: Rect2 = _museum.bounds()
	player.bound_min = br.position
	player.bound_max = br.end
	_museum.examined.connect(func(c: int, t: int) -> void:
		counter_label.text = L.tf("· %d/%d examinados", [c, t]))
	counter_label.text = L.tf("· 0/%d examinados", [_museum.items.size()])
	if minimap:
		minimap.visible = false
	prompt_label.text = ""
	prompt.visible = false


func exit_museum() -> void:
	if _museum == null:
		return
	player.get_parent().remove_child(player)
	city.add_child(player)
	player.global_transform = _entry_xform
	player.walk_rects = player.get_meta("walk", [])
	_museum.queue_free()
	_museum = null
	_exam = {}
	city.visible = true
	city.set_process(true)
	city.set_physics_process(true)
	if minimap:
		minimap.visible = true
	_on_visited(city.visited_count(), city.total_projects())
	prompt.visible = false
	_museum_hot_clear()
	_prompt_hint.text = L.t("toque para abrir") if UI.is_mobile() else L.t("[E] abrir  ·  toque no letreiro para ir até lá")


## Aciona o objeto: ação física (telefone, gaveta, máquina, interruptor) e/ou o painel do tipo dele.
func _museum_hot_clear() -> void:
	_ret_hot = false


func _activate(entry: Dictionary) -> void:
	var it: Dictionary = entry["item"]
	var action := str(it.get("action", ""))
	if Audio.has_method("on_action"):
		Audio.call("on_action", action if action != "" else str(it.get("panel", "doc")), it)
	match action:
		"switch":
			var on: bool = _museum.toggle_lights()
			var tog = it.get("toggle")
			if tog and is_instance_valid(tog):
				(tog as Node3D).position.y = 0.02 if on else -0.02
			_museum.mark_seen(entry)
			return
		"phone":
			if entry.has("ring"):
				entry["ring"]["on"] = false
		"drawer":
			var dr = it.get("drawer")
			if dr and is_instance_valid(dr):
				var tw := create_tween()
				tw.tween_property(dr, "position:z", 0.6, 0.35).set_trans(Tween.TRANS_BACK)
	var panel := str(it.get("panel", ""))
	if panel == "" or panel == "exhibit":
		_open_exhibit(entry)
		return
	_sheet_open = true
	prompt.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_museum.mark_seen(entry)
	var p := Panels.new()
	p.setup(panel, it, _museum._accent, _museum.project)
	p.closed.connect(func() -> void:
		_sheet_open = false
		var dr2 = it.get("drawer")
		if dr2 and is_instance_valid(dr2):
			create_tween().tween_property(dr2, "position:z", 0.24, 0.3)
		if not UI.is_mobile():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	add_child(UI.full(p))


func _open_exhibit(entry: Dictionary) -> void:
	_sheet_open = true
	prompt.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_museum.mark_seen(entry)
	var ex := Exhibit.new()
	ex.setup(entry["item"], _museum._accent, _museum.project)
	ex.closed.connect(func() -> void:
		_sheet_open = false
		if not UI.is_mobile():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	add_child(UI.full(ex))


func _process(_dt: float) -> void:
	if reticle:
		reticle.queue_redraw()
	if _museum == null or _sheet_open:
		_ret_hot = not _current.is_empty() and _museum == null
		return
	# realce do item mirado (contorno + retícula) e aviso de ação/sair
	for e in _museum.items:
		e["_hot"] = false
	_exam = _museum.nearest(player.global_position, player.forward())
	_museum.set_hot(_exam)
	_ret_hot = not _exam.is_empty()
	if not _exam.is_empty():
		_exam["_hot"] = true
		var it: Dictionary = _exam["item"]
		var verb := L.t(str(it.get("verb", "EXAMINAR")))
		prompt_label.text = L.tx(it, "title").to_upper()
		_prompt_hint.text = (L.t("toque para") + " " + verb.to_lower()) if UI.is_mobile() else ("[E] " + verb.to_lower())
		prompt.visible = true
	elif _museum.at_exit(player.global_position):
		prompt_label.text = L.t("SAIR PARA A RUA")
		_prompt_hint.text = L.t("toque para sair") if UI.is_mobile() else L.t("[E] sair")
		prompt.visible = true
	else:
		prompt.visible = false


func _nearest_npc() -> Node:
	if city == null:
		return null
	for n in city.npcs:
		if n.global_position.distance_to(player.global_position) < 3.0:
			return n
	return null


func _open_dialogue(npc) -> void:
	_sheet_open = true
	prompt.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var d := Dialogue.new()
	var acc := Color(str(npc.project.get("neon", "#ffc83d")))
	var nm := "O GUIA" if npc.project.get("special", "") == "about" else str(npc.project.get("title", "GUIA")).to_upper()
	d.setup(nm, npc.role, acc, npc.greet, npc.lines, npc.project)
	d.ducking.connect(func(a: bool) -> void: Audio.duck(a))
	d.open_project.connect(func() -> void:
		open_dossier(npc.project))
	d.closed.connect(func() -> void:
		_sheet_open = false
		if not UI.is_mobile():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	add_child(UI.full(d))


func open_dossier(project: Dictionary) -> void:
	if project.is_empty():
		return
	_sheet_open = true
	prompt.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if city:
		city.mark_visited(project)
	var sp := str(project.get("special", ""))
	var d := Dossier.new()
	if sp == "about":
		d.setup_about(Data.profile)
	elif sp == "contact":
		d.setup_contact(Data.profile)
	else:
		d.setup_project(project)
	d.closed.connect(func() -> void:
		_sheet_open = false
		if not UI.is_mobile() and player:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	add_child(UI.full(d))


func _open_list() -> void:
	if _sheet_open:
		return
	_sheet_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var lm := ListMode.new()
	lm.open_project.connect(open_dossier)
	lm.closed.connect(func() -> void:
		_sheet_open = false)
	add_child(UI.full(lm))
