extends Control
## Dossiê de um projeto: painel noir com capa, descrição, stack e botões (abre site/GitHub).
## Também serve a ficha "Sobre mim" e o cartão de contato. Abre links com window.open na web.

signal closed

var _accent := UI.AMBER


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	add_child(UI.full(dim))
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_close())


func _frame(accent: Color) -> VBoxContainer:
	_accent = accent
	var center := CenterContainer.new()
	add_child(UI.full(center))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(UI.PANEL, accent, 3, 18, 0))
	var vs := get_viewport_rect().size
	var w: float = minf(vs.x - 48.0, 620.0)
	panel.custom_minimum_size = Vector2(w, 0)
	center.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = minf(vs.y - 90.0, 880.0)
	panel.add_child(scroll)
	var pad := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + s, 26)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	var v := UI.vbox(16)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(v)
	# X de fechar
	var x := UI.ghost("✕", accent, 44)
	x.custom_minimum_size.x = 44
	x.add_theme_font_override("font", UI.font("body"))
	x.pressed.connect(_close)
	var top := UI.hbox(8)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(x)
	v.add_child(top)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.22)
	return v


func _cover(v: VBoxContainer, project: Dictionary) -> void:
	var cover := str(project.get("cover", ""))
	var path := "res://assets/covers/" + cover
	if cover != "" and ResourceLoader.exists(path):
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.custom_minimum_size.y = 220
		tr.clip_contents = true
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UI.box(UI.INK, _accent, 2, 12, 0))
		pc.clip_contents = true
		pc.add_child(tr)
		v.add_child(pc)
	else:
		# sem capa: faixa de neon com a inicial
		var band := PanelContainer.new()
		band.add_theme_stylebox_override("panel", UI.box(_accent.darkened(0.55), _accent, 2, 12, 0))
		band.custom_minimum_size.y = 150
		var cc := CenterContainer.new()
		cc.add_child(UI.title(str(project.get("title", "?")).substr(0, 1).to_upper(), 120, _accent))
		band.add_child(cc)
		v.add_child(band)


func _chips(v: VBoxContainer, items: Array, col: Color) -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for it in items:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI.box(Color(col, 0.14), col, 1, 8, 6))
		var l := UI.label(str(it).to_upper(), 18, col, "type")
		p.add_child(l)
		flow.add_child(p)
	v.add_child(flow)


func setup_project(project: Dictionary) -> void:
	var accent := Color(str(project.get("neon", "#ffc83d")))
	var v := _frame(accent)
	_cover(v, project)
	v.add_child(UI.title(str(project.get("title", "")).to_upper(), 58, accent))
	v.add_child(UI.label(str(project.get("tagline", "")), 24, UI.PAPER, "type"))
	var meta := UI.hbox(10)
	var yr := int(project.get("year", 0))
	if yr > 0:
		meta.add_child(_tag(str(yr), UI.MIST))
	if bool(project.get("private", false)):
		meta.add_child(_tag("PRIVADO", UI.RED))
	else:
		meta.add_child(_tag("PÚBLICO", UI.GREEN))
	meta.add_child(_tag(str(project.get("kind", "")).to_upper(), accent))
	v.add_child(meta)
	v.add_child(_rule(accent))
	v.add_child(UI.label(str(project.get("desc", "")), 22, UI.PAPER.darkened(0.08), "body"))
	v.add_child(UI.label("STACK", 22, accent, "title"))
	_chips(v, project.get("stack", []), accent)
	var links: Dictionary = project.get("links", {})
	var row := UI.hbox(10)
	if links.has("site"):
		var b := UI.button("VER SITE  ↗", accent, 62)
		b.pressed.connect(_open.bind(str(links["site"])))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	if links.has("github"):
		var g := UI.ghost("GITHUB  </>", accent, 62)
		g.pressed.connect(_open.bind(str(links["github"])))
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(g)
	if row.get_child_count() > 0:
		v.add_child(row)
	elif bool(project.get("private", false)):
		v.add_child(UI.label("Repositório privado. Posso mostrar numa conversa.", 18, UI.MIST, "body"))


func setup_about(profile: Dictionary) -> void:
	var v := _frame(UI.PAPER)
	v.add_child(UI.title("QUEM HABITA ESSA CIDADE", 44, UI.PAPER))
	v.add_child(UI.label(str(profile.get("role", "")) + "  ·  " + str(profile.get("tagline", "")), 22, UI.AMBER, "type"))
	v.add_child(_rule(UI.PAPER))
	for para in profile.get("bio", []):
		v.add_child(UI.label(str(para), 22, UI.PAPER.darkened(0.06), "body"))
	v.add_child(UI.label("ARSENAL", 22, UI.CYAN, "title"))
	_chips(v, profile.get("stack", []), UI.CYAN)


func setup_contact(profile: Dictionary) -> void:
	var v := _frame(UI.GREEN)
	v.add_child(UI.title("VAMOS CONSTRUIR?", 48, UI.GREEN))
	v.add_child(UI.label("Tem um projeto em mente? Me chama.", 22, UI.PAPER, "type"))
	v.add_child(_rule(UI.GREEN))
	var links: Dictionary = profile.get("links", {})
	for spec in [["E-MAIL", str(links.get("email", "")), "mailto:" + str(links.get("email", "")), UI.AMBER],
			["LINKEDIN", "linkedin.com/in/gabriel-inácio", str(links.get("linkedin", "")), UI.CYAN],
			["GITHUB", "github.com/GabrielInacior", str(links.get("github", "")), UI.PAPER]]:
		var b := UI.button(str(spec[0]) + "  ↗", spec[3], 62)
		b.pressed.connect(_open.bind(str(spec[2])))
		v.add_child(b)
		var l := UI.label(str(spec[1]), 18, UI.MIST, "type")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)


func _tag(text: String, col: Color) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color(col, 0.16), col, 1, 7, 5))
	p.add_child(UI.label(text, 16, col, "type"))
	return p


func _rule(col: Color) -> Control:
	var r := ColorRect.new()
	r.color = Color(col, 0.4)
	r.custom_minimum_size.y = 2
	return r


func _open(url: String) -> void:
	if url == "" or url.begins_with("mailto::"):
		return
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.open(%s, '_blank')" % JSON.stringify(url), true)
	else:
		OS.shell_open(url)


func _close() -> void:
	closed.emit()
	queue_free()
