extends Control
## Interface por cima da cidade: alavanca virtual (celular), olhar por arrasto, aviso de
## interação, nome, minimapa, contador de projetos visitados, som liga/desliga, modo lista.

const Dossier := preload("res://scripts/dossier.gd")
const ListMode := preload("res://scripts/list_mode.gd")
const Dialogue := preload("res://scripts/dialogue.gd")
const Minimap := preload("res://scripts/minimap.gd")
const Museum := preload("res://scripts/museum.gd")
const Exhibit := preload("res://scripts/exhibit.gd")

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
	if UI.is_mobile():
		_build_stick()
	set_process_input(true)


func _build_topbar() -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.box(Color(UI.INK, 0.5), Color.TRANSPARENT, 0, 0))
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 76
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 18)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 12)
	pad.add_theme_constant_override("margin_bottom", 8)
	bar.add_child(pad)
	var h := UI.hbox(14)
	pad.add_child(h)
	var nm := UI.title("GABRIEL INÁCIO", 36, UI.PAPER)
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(nm)
	counter_label = UI.label("", 20, UI.AMBER, "type")
	counter_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	counter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(counter_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spacer)
	var snd := UI.ghost("♪", UI.PINK, 48)
	snd.custom_minimum_size.x = 56
	snd.add_theme_font_override("font", UI.font("body"))
	snd.pressed.connect(func() -> void:
		var on := not Audio.is_on()
		Audio.set_enabled(on)
		snd.text = "♪" if on else "✕")
	h.add_child(snd)
	var lst := UI.ghost("PROJETOS", UI.AMBER, 48)
	lst.custom_minimum_size.x = 150
	lst.pressed.connect(_open_list)
	h.add_child(lst)


func _build_minimap() -> void:
	minimap = Minimap.new()
	minimap.custom_minimum_size = Vector2(190, 150)
	minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -206
	minimap.offset_top = 86
	minimap.offset_right = -16
	minimap.offset_bottom = 236
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(minimap)


func _build_prompt() -> void:
	prompt = PanelContainer.new()
	prompt.add_theme_stylebox_override("panel", UI.box(Color(UI.NIGHT, 0.95), UI.AMBER, 2, 14, 16))
	var v := UI.vbox(4)
	prompt_label = UI.label("", 28, UI.AMBER, "type")
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(prompt_label)
	var hint := UI.label("toque para abrir" if UI.is_mobile() else "[E] abrir  ·  toque no letreiro para ir até lá", 18, UI.MIST, "body")
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
	counter_label.text = "· %d/%d explorados" % [count, total]


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
			_open_exhibit(_exam)
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
	var id := "_lab" if project.get("special", "") == "about" else str(project.get("id", ""))
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
	_museum.setup(project, d, project.get("special", "") == "about")
	city.get_parent().add_child(_museum)
	player.get_parent().remove_child(player)
	_museum.add_child(player)
	player.global_position = _museum.spawn_pos()
	player._yaw = PI
	player.rotation.y = PI
	player.bound_min = Vector2(-4.4, -5.4)
	player.bound_max = Vector2(4.4, 5.4)
	_museum.examined.connect(func(c: int, t: int) -> void:
		counter_label.text = "· %d/%d examinados" % [c, t])
	counter_label.text = "· 0/%d examinados" % _museum.items.size()
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
	player.bound_min = Vector2(-4.2, -64.0)
	player.bound_max = Vector2(4.2, 4.0)
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
	if _museum == null or _sheet_open:
		return
	# realce do item mirado e aviso de examinar/sair
	for e in _museum.items:
		e["_hot"] = false
	_exam = _museum.nearest(player.global_position, player.forward())
	if not _exam.is_empty():
		_exam["_hot"] = true
		prompt_label.text = str(_exam["item"].get("title", "")).to_upper()
		prompt.visible = true
	elif _museum.at_exit(player.global_position):
		prompt_label.text = "SAIR PARA A RUA"
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
