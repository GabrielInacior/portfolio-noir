extends Control
## Dossiê de um projeto: painel noir com capa, descrição, stack e botões (abre site/GitHub).
## Também serve a ficha "Sobre mim" e o cartão de contato. Abre links com window.open na web.

signal closed

var _accent := UI.AMBER


var _sheet: Sheet


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## moldura do design system (Sheet). Precisa estar na árvore (o HUD adiciona antes do setup).
func _frame(accent: Color, kick := "", ttl := "") -> VBoxContainer:
	_accent = accent
	_sheet = Sheet.new()
	add_child(UI.full(_sheet))
	_sheet.setup(kick, ttl, accent, 760.0)
	_sheet.closed.connect(func() -> void:
		closed.emit()
		queue_free())
	return _sheet.body


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
		cc.add_child(UI.title(str(project.get("title", "?")).substr(0, 1).to_upper(), UI.fs("display") * 1.4, _accent))
		band.add_child(cc)
		v.add_child(band)


func _chips(v: VBoxContainer, items: Array, col: Color) -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for it in items:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI.box(Color(col, 0.14), col, 1, 8, 6))
		var l := UI.label(str(it).to_upper(), UI.fs("small"), col, "type")
		p.add_child(l)
		flow.add_child(p)
	v.add_child(flow)


func setup_project(project: Dictionary) -> void:
	var accent := Color(str(project.get("neon", "#ffc83d")))
	var v := _frame(accent)
	_cover(v, project)
	v.add_child(UI.title(str(project.get("title", "")).to_upper(), UI.fs("h1"), accent))
	v.add_child(UI.label(str(project.get("tagline", "")), UI.fs("body"), UI.PAPER, "type"))
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
	v.add_child(UI.label(str(project.get("desc", "")), UI.fs("body"), UI.PAPER.darkened(0.08), "body"))
	v.add_child(UI.label("STACK", UI.fs("body"), accent, "title"))
	_chips(v, project.get("stack", []), accent)
	var links: Dictionary = project.get("links", {})
	var row := UI.hbox(10)
	if links.has("site"):
		var b := UI.button("VER SITE  ↗", accent)
		b.pressed.connect(_open.bind(str(links["site"])))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	if links.has("github"):
		var g := UI.ghost("GITHUB  </>", accent)
		g.pressed.connect(_open.bind(str(links["github"])))
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(g)
	if row.get_child_count() > 0:
		v.add_child(row)
	elif bool(project.get("private", false)):
		v.add_child(UI.label("Repositório privado. Posso mostrar numa conversa.", UI.fs("small"), UI.MIST, "body"))


func setup_about(profile: Dictionary) -> void:
	var v := _frame(UI.PAPER)
	v.add_child(UI.title("QUEM HABITA ESSA CIDADE", UI.fs("h1"), UI.PAPER))
	v.add_child(UI.label(str(profile.get("role", "")) + "  ·  " + str(profile.get("tagline", "")), UI.fs("small"), UI.AMBER, "type"))
	v.add_child(_rule(UI.PAPER))
	for para in profile.get("bio", []):
		v.add_child(UI.label(str(para), UI.fs("body"), UI.PAPER.darkened(0.06), "body"))
	v.add_child(UI.label("ARSENAL", UI.fs("body"), UI.CYAN, "title"))
	_chips(v, profile.get("stack", []), UI.CYAN)


func setup_contact(profile: Dictionary) -> void:
	var v := _frame(UI.GREEN)
	v.add_child(UI.title("VAMOS CONSTRUIR?", UI.fs("h1"), UI.GREEN))
	v.add_child(UI.label("Tem um projeto em mente? Me chama.", UI.fs("body"), UI.PAPER, "type"))
	v.add_child(_rule(UI.GREEN))
	var links: Dictionary = profile.get("links", {})
	for spec in [["E-MAIL", str(links.get("email", "")), "mailto:" + str(links.get("email", "")), UI.AMBER],
			["LINKEDIN", "linkedin.com/in/gabriel-inácio", str(links.get("linkedin", "")), UI.CYAN],
			["GITHUB", "github.com/GabrielInacior", str(links.get("github", "")), UI.PAPER]]:
		var b := UI.button(str(spec[0]) + "  ↗", spec[3])
		b.pressed.connect(_open.bind(str(spec[2])))
		v.add_child(b)
		var l := UI.label(str(spec[1]), UI.fs("small"), UI.MIST, "type")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)


func _tag(text: String, col: Color) -> Control:
	return UI.chip(text, col)


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
	if _sheet:
		_sheet.close()
		return
	closed.emit()
	queue_free()
