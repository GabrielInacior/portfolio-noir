extends Control
## Dossiê de um projeto: painel noir com capa, descrição, stack e botões (abre site/GitHub).
## Também serve a ficha "Sobre mim" e o cartão de contato. Abre links com window.open na web.

signal closed

var _accent := UI.AMBER


var _sheet: Sheet
var _theme_project: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## moldura do design system (Sheet). Precisa estar na árvore (o HUD adiciona antes do setup).
func _frame(accent: Color, kick := "", ttl := "") -> VBoxContainer:
	_accent = accent
	_sheet = Sheet.new()
	add_child(UI.full(_sheet))
	_sheet.setup(kick, ttl, accent, 760.0)
	if not _theme_project.is_empty():
		Themes.apply(_sheet, Themes.of(_theme_project))
		_accent = _sheet.accent
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
	flow.add_theme_constant_override("h_separation", UI.sp(1))
	flow.add_theme_constant_override("v_separation", UI.sp(1))
	for it in items:
		flow.add_child(UI.tech_chip(str(it), col))
	v.add_child(flow)


func setup_project(project: Dictionary) -> void:
	var accent := Color(str(project.get("neon", "#ffc83d")))
	_theme_project = project
	var v := _frame(accent, L.t("Projeto"), L.t(str(project.get("title", ""))).to_upper())
	accent = _accent
	_cover(v, project)
	v.add_child(UI.label(L.tx(project, "tagline"), UI.fs("body"), UI.PAPER, "type"))
	var meta := HFlowContainer.new()
	meta.add_theme_constant_override("h_separation", UI.sp(1))
	meta.add_theme_constant_override("v_separation", UI.sp(1))
	var yr := int(project.get("year", 0))
	if yr > 0:
		meta.add_child(_tag(str(yr), UI.MIST))
	if str(project.get("status", "")) != "":
		meta.add_child(Nav.status_chip(str(project["status"])))
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
	var v := _frame(UI.PAPER, L.t("Sobre"), L.t("QUEM HABITA ESSA CIDADE"))
	var stats: Array = profile.get("stats", [])
	if not stats.is_empty():
		var row := UI.hbox(UI.sp(1.2))
		for st in stats:
			var c := UI.card(UI.AMBER, UI.sp(1.6))
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var cv := UI.vbox(0)
			var num := UI.text(str(st.get("value", "")), "h1", UI.AMBER)
			num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cv.add_child(num)
			var lb := UI.text(L.t(str(st.get("label", ""))), "cap", UI.MIST)
			lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cv.add_child(lb)
			c.add_child(cv)
			row.add_child(c)
		v.add_child(row)
	var paras: Array = profile.get("about_city", profile.get("bio", []))
	for para in paras:
		var l := UI.text(L.t(str(para)), "body", Color(UI.PAPER, 0.92))
		l.add_theme_constant_override("line_spacing", 4)
		v.add_child(l)
	v.add_child(UI.kicker(L.t("Arsenal"), UI.CYAN))
	_chips(v, profile.get("stack", []), UI.CYAN)


func setup_contact(profile: Dictionary) -> void:
	var c: Dictionary = profile.get("contact", {})
	_theme_project = {"special": "contact"}
	var v := _frame(UI.GREEN, L.t("Contato"), L.t(str(c.get("title", "VAMOS CONSTRUIR?"))))
	v.add_child(UI.text(L.t(str(c.get("subtitle", "Tem um projeto em mente? Me chama."))), "body", UI.PAPER))
	var links: Dictionary = profile.get("links", {})
	var email := str(links.get("email", ""))
	if email != "":
		# e-mail: tocar copia (toast) e o ícone ao lado abre o app de e-mail
		var eb := UI.button(email, UI.AMBER)
		eb.add_theme_font_override("font", UI.font("bold"))
		eb.add_theme_font_size_override("font_size", UI.fs("body"))
		eb.tooltip_text = L.t("Copiar e-mail")
		eb.pressed.connect(func() -> void:
			DisplayServer.clipboard_set(email)
			if OS.has_feature("web"):
				JavaScriptBridge.eval("navigator.clipboard&&navigator.clipboard.writeText(%s)" % JSON.stringify(email), true)
			UI.toast(self, L.t(str(c.get("copied", "E-mail copiado"))), UI.GREEN))
		v.add_child(eb)
		v.add_child(UI.text(L.t("Toque para copiar"), "cap", UI.DIM))
	var row := UI.hbox(UI.sp(1.2))
	for spec in [["LINKEDIN", str(links.get("linkedin", "")), UI.CYAN], ["GITHUB", str(links.get("github", "")), UI.PAPER]]:
		if str(spec[1]) == "":
			continue
		var b := UI.ghost(str(spec[0]) + "  ↗", spec[2])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_open.bind(str(spec[1])))
		row.add_child(b)
	v.add_child(row)
	var rs: Dictionary = profile.get("resume", {})
	if bool(rs.get("available", false)) and str(rs.get("url", "")) != "":
		var cv := UI.ghost(L.t("CURRÍCULO") + "  ↓", UI.AMBER)
		cv.pressed.connect(_open.bind(str(rs["url"])))
		v.add_child(cv)


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
