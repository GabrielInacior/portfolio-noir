extends Control
## Modo lista: todos os projetos numa grade de cartões, para recrutador com pressa. Abre o dossiê.

signal open_project(project: Dictionary)
signal closed


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(UI.INK, 0.94)
	add_child(UI.full(bg))
	var pad := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + s, 22)
	add_child(UI.full(pad))
	var v := UI.vbox(16)
	pad.add_child(v)
	var top := UI.hbox(10)
	top.add_child(UI.title("CONSTRUÇÕES DIGITAIS", 40, UI.AMBER))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var x := UI.ghost("VOLTAR À CIDADE", UI.CYAN, 50)
	x.pressed.connect(func() -> void:
		closed.emit()
		queue_free())
	top.add_child(x)
	v.add_child(top)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 1 if get_viewport_rect().size.x < 820 else (2 if get_viewport_rect().size.x < 1300 else 3)
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for p in Data.projects:
		grid.add_child(_card(p))
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func _card(project: Dictionary) -> Control:
	var accent := Color(str(project.get("neon", "#ffc83d")))
	var b := Button.new()
	b.custom_minimum_size = Vector2(300, 150)
	b.add_theme_stylebox_override("normal", UI.box(UI.PANEL, accent, 2, 14, 16))
	b.add_theme_stylebox_override("hover", UI.box(UI.PANEL.lightened(0.05), accent, 3, 14, 16))
	b.add_theme_stylebox_override("pressed", UI.box(UI.PANEL, accent, 3, 14, 16))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(func() -> void:
		open_project.emit(project)
		closed.emit()
		queue_free())
	var v := UI.vbox(6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16
	v.offset_top = 14
	v.offset_right = -16
	v.add_child(UI.title(str(project.get("title", "")).to_upper(), 34, accent))
	var tl := UI.label(str(project.get("tagline", "")), 19, UI.PAPER, "type")
	v.add_child(tl)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	for s in (project.get("stack", []) as Array).slice(0, 4):
		var l := UI.label(str(s).to_upper(), 15, accent, "type")
		flow.add_child(l)
	v.add_child(flow)
	b.add_child(v)
	return b
