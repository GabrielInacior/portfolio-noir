extends Control
## Painéis de interação das lojas, um por tipo de objeto, todos responsivos (celular em pé,
## deitado e PC): inspeção 3D girando o objeto, terminal com README do GitHub, galeria de prints,
## documento (telefone, máquina de escrever, ficha do arquivo), skills ligadas aos projetos,
## linha do tempo da carreira, cartão de contato e fliperama jogável.
## Uso: var p = Panels.new(); p.setup(kind, item, accent, project); add_child(UI.full(p))

signal closed

const GH := preload("res://scripts/gh_screen.gd")

var kind := "doc"
var item: Dictionary = {}
var project: Dictionary = {}
var _accent := UI.AMBER
var _vs := Vector2.ZERO
var _mobile := false
var _tall := false
var _col: VBoxContainer
var _outer: VBoxContainer
var _anim_t := 0.0
var _type_label: Label
var _type_full := ""
var _type_pos := 0.0
var _spin_node: Node3D
var _drag_rot := false
var _game: Control


func setup(k: String, it: Dictionary, accent: Color, proj: Dictionary) -> void:
	kind = k
	item = it
	_accent = accent
	project = proj


var _sheet: Sheet


func _ready() -> void:
	# moldura do design system (Sheet): cabeçalho fixo, rolagem por toque, rodapé com os links
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vs = get_viewport_rect().size
	_tall = _vs.y > _vs.x
	_mobile = _tall or _vs.y <= 560.0
	_sheet = Sheet.new()
	_sheet.scrollable = kind != "arcade"
	add_child(UI.full(_sheet))
	var wide := kind in ["skills", "arcade", "terminal", "timeline"]
	_sheet.setup(L.t(str(project.get("title", ""))), L.tx(item, "title") if item.has("title") else "", _accent, 1060.0 if wide else 0.0)
	Themes.apply(_sheet, Themes.of(project))
	_accent = _sheet.accent
	_sheet.closed.connect(func() -> void:
		Audio.duck(false)
		closed.emit()
		queue_free())
	_col = _sheet.body
	_outer = _sheet.body
	match kind:
		"arcade":
			_build_arcade()
		"inspect": _build_inspect()
		"terminal": _build_terminal()
		"gallery": _build_gallery()
		"doc": _build_doc()
		"skills": _build_skills()
		"timeline": _build_timeline()
		"contact": _build_contact()
	Audio.duck(true)


func _body(text: String, col := UI.PAPER, size := 0) -> Label:
	var l := UI.label(text, size if size > 0 else UI.fs("body"), col, "body")
	l.add_theme_constant_override("line_spacing", 4)
	_col.add_child(l)
	return l


func _chips(list: Array, col: Color) -> void:
	_sheet.add_chips(list, col)


func _link_buttons() -> void:
	var links: Dictionary = project.get("links", {}) if project.get("links") is Dictionary else {}
	if links.has("site"):
		_sheet.add_link(L.t("ABRIR O SITE"), str(links["site"]), true)
	if links.has("github"):
		_sheet.add_link(L.t("VER NO GITHUB"), str(links["github"]), not links.has("site"))
	if links.is_empty() and bool(project.get("private", false)):
		var l := UI.text("Repositório privado", "small", UI.MIST)
		_sheet.footer.add_child(l)


# ───────────────────────────────── inspeção 3D: o objeto gira com o mouse/dedo
func _build_inspect() -> void:
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(0, minf(_vs.y * (0.4 if _tall else 0.48), 460.0))
	svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col.add_child(svc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = false
	svc.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#0b0d16")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#5a5a70")
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.7, 0.6, 0)
	key.light_color = Color("#ffe2b8")
	world.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.2, 1.0, -1.0)
	rim.light_color = _accent
	rim.light_energy = 3.0
	world.add_child(rim)
	_spin_node = Node3D.new()
	world.add_child(_spin_node)
	var model := str(item.get("model", ""))
	var glb: String = load("res://scripts/museum.gd").PROP_GLB.get(model, model)
	var path := "res://assets/props/%s.glb" % glb
	if ResourceLoader.exists(path):
		var n: Node3D = (load(path) as PackedScene).instantiate()
		_spin_node.add_child(n)
		var aabb := _aabb(n)
		var s := 1.0 / maxf(aabb.size.length(), 0.01)
		n.scale = Vector3.ONE * s * 1.6
		n.position = -aabb.get_center() * n.scale.x
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.35, 1.9)
	cam.fov = 40
	world.add_child(cam)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	svc.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			_drag_rot = (ev as InputEventMouseButton).pressed
		elif ev is InputEventMouseMotion and _drag_rot:
			_spin_node.rotate_y((ev as InputEventMouseMotion).relative.x * 0.01)
			_spin_node.rotation.x = clampf(_spin_node.rotation.x + (ev as InputEventMouseMotion).relative.y * 0.006, -0.6, 0.6)
		elif ev is InputEventScreenDrag:
			_spin_node.rotate_y((ev as InputEventScreenDrag).relative.x * 0.01))
	_col.add_child(UI.label("Arraste para girar", UI.fs("small"), UI.MIST, "type"))
	_body(L.tx(item, "text"))
	if str(item.get("tag", "")) != "":
		_chips([L.t(str(item["tag"]))], _accent)
	_link_buttons()


func _aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var a := mi.get_aabb()
		a = mi.transform * a
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	return out


# ───────────────────────────────── terminal: README do GitHub (ao vivo ou snapshot)
func _build_terminal() -> void:
	var id := str(item.get("repo", project.get("id", "")))
	var r := GithubLive.repo(id)
	var head := UI.label("$ cat %s/README.md" % str(r.get("full", "GabrielInacior/" + id)), UI.fs("small"), Color("#5fd38a"), "type")
	_col.add_child(head)
	var priv: bool = r.get("private", false)
	var meta := UI.label("★ %d   ·   %s   ·   %s %s" % [int(r.get("stars", 0)), L.t("privado") if priv else L.t("público"), L.t("atualizado"), str(r.get("pushed", r.get("updated", "")))], UI.fs("small"), UI.MIST, "type")
	_col.add_child(meta)
	var langs: Dictionary = r.get("languages", {})
	if not langs.is_empty():
		_chips(langs.keys(), Color("#5bd0ff"))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_override("normal_font", UI.font("body"))
	rt.add_theme_font_override("bold_font", UI.font("bold"))
	rt.add_theme_font_size_override("normal_font_size", UI.fs("small"))
	rt.add_theme_font_size_override("bold_font_size", UI.fs("body"))
	rt.add_theme_color_override("default_color", Color("#e6eaf6"))
	rt.text = GH.md_to_bbcode(GithubLive.readme(id), _accent)
	_col.add_child(rt)
	GithubLive.fetch_readme(id, func(txt: String) -> void:
		if is_instance_valid(rt):
			rt.text = GH.md_to_bbcode(txt, _accent))
	if priv:
		_col.add_child(UI.label("Repositório privado: o código não é público, só a descrição.", UI.fs("small"), UI.MIST, "type"))
	else:
		var b := UI.ghost("VER NO GITHUB  ↗", Color("#5fd38a"), UI.tap())
		b.pressed.connect(func() -> void: open_url(str(r.get("url", "https://github.com/GabrielInacior/" + id))))
		_col.add_child(b)


# ───────────────────────────────── galeria: imagens com anterior/próxima e deslizar
var _gi := 0
var _gtex: TextureRect
var _gcap: Label
var _gtext: Label
var _glist: Array = []


func _build_gallery() -> void:
	_glist = item.get("gallery", [item])
	_gtex = TextureRect.new()
	_gtex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gtex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_gtex.custom_minimum_size = Vector2(0, minf(_vs.y * (0.36 if _tall else 0.46), 420.0))
	_gtex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fr := PanelContainer.new()
	fr.add_theme_stylebox_override("panel", UI.box(Color("#0a0c14"), _accent.darkened(0.3), 2, 10, 6))
	fr.add_child(_gtex)
	_col.add_child(fr)
	var nav := UI.hbox(10)
	var prev := UI.ghost("◀", _accent, UI.tap())
	prev.custom_minimum_size.x = 100
	prev.pressed.connect(func() -> void: _gshow(_gi - 1))
	nav.add_child(prev)
	_gcap = UI.label("", UI.fs("small"), UI.MIST, "type")
	_gcap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gcap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gcap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nav.add_child(_gcap)
	var nxt := UI.ghost("▶", _accent, UI.tap())
	nxt.custom_minimum_size.x = 100
	nxt.pressed.connect(func() -> void: _gshow(_gi + 1))
	nav.add_child(nxt)
	_col.add_child(nav)
	_gtext = _body("")
	_gtex.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventScreenDrag and absf((ev as InputEventScreenDrag).relative.x) > 25:
			_gshow(_gi + (-1 if (ev as InputEventScreenDrag).relative.x > 0 else 1)))
	_gshow(0)
	_link_buttons()


func _gshow(i: int) -> void:
	if _glist.is_empty():
		return
	_gi = posmod(i, _glist.size())
	var it: Dictionary = _glist[_gi]
	var p := str(it.get("img", ""))
	_gtex.texture = load(p) if p != "" and ResourceLoader.exists(p) else null
	_gcap.text = "%s  ·  %d/%d" % [L.tx(it, "title"), _gi + 1, _glist.size()]
	_gtext.text = L.tx(it, "text")


# ───────────────────────────────── documento: telefone, máquina de escrever, ficha
func _build_doc() -> void:
	var style := str(item.get("doc_style", "file"))
	var full := L.tx(item, "text")
	if style == "phone":
		var row := UI.hbox(12)
		var ic := UI.label("☎", 64, _accent, "body")
		row.add_child(ic)
		var who := UI.label("Chamada recebida", UI.fs("body"), UI.MIST, "type")
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(who)
		_col.add_child(row)
		_type_label = _body("", UI.PAPER, UI.fs("h3"))
	else:
		# folha de papel datilografada (cor de papel só dentro do cartão; o painel segue escuro)
		var paper := PanelContainer.new()
		var ps := UI.box(Color("#efe6cf"), Color("#c9b98f"), 1, 6, UI.sp(3))
		ps.shadow_color = Color(0, 0, 0, 0.5)
		ps.shadow_size = 12
		paper.add_theme_stylebox_override("panel", ps)
		_type_label = UI.label("", UI.fs("h3"), Color("#2a1a10"), "type")
		paper.add_child(_type_label)
		_col.add_child(paper)
	_type_full = full
	_type_pos = 0.0
	if style == "file":
		_link_buttons()


# ───────────────────────────────── skills: tocar numa tecnologia mostra os projetos


func _build_skills() -> void:
	# PAINEL NAVEGÁVEL: abas por categoria, busca, grade de cartões com o logo; tocar abre o detalhe
	# (descrição, site oficial e os projetos que usam a tecnologia, cada um levando à loja).
	_sk_all = Data.profile.get("skills", {})
	_sk_info = Data.profile.get("tech_info", {})
	_sk_pal = [Color("#ff4fa3"), Color("#4e9bff"), Color("#5fd38a"), Color("#ffc83d"), Color("#b06bff"), Color("#ff7a3d"), Color("#5bd0ff"), Color("#ff3d5a")]
	_sk_cats = ["*"]
	for c in _sk_all:
		_sk_cats.append(str(c))
	var top := UI.vbox(UI.sp(1))
	_col.add_child(top)
	var search := LineEdit.new()
	search.placeholder_text = L.t("Buscar tecnologia...")
	search.clear_button_enabled = true
	search.custom_minimum_size.y = UI.tap(self) * 0.8
	search.add_theme_font_size_override("font_size", UI.fs("body"))
	search.add_theme_stylebox_override("normal", UI.box(Color(UI.PANEL_2, 0.9), UI.STROKE, 1, 10, 10))
	search.text_changed.connect(func(t: String) -> void:
		_sk_query = t.strip_edges().to_lower()
		_sk_fill())
	top.add_child(search)
	var tabs_sc := ScrollContainer.new()
	tabs_sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs_sc.custom_minimum_size.y = UI.tap(self) * 0.85
	_sk_tabs = UI.hbox(UI.sp(0.8))
	tabs_sc.add_child(_sk_tabs)
	top.add_child(tabs_sc)
	for i in _sk_cats.size():
		var cname: String = L.t("Todas") if _sk_cats[i] == "*" else L.t(str(_sk_cats[i]))
		var tb := UI.ghost(cname, _sk_pal[(i + 7) % _sk_pal.size()], int(UI.tap(self) * 0.7))
		tb.add_theme_font_size_override("font_size", UI.fs("small"))
		tb.toggle_mode = true
		tb.button_pressed = i == 0
		tb.pressed.connect(_sk_pick_tab.bind(i))
		_sk_tabs.add_child(tb)
	_sk_grid = GridContainer.new()
	_sk_grid.columns = 2 if _mobile else 4
	_sk_grid.add_theme_constant_override("h_separation", UI.sp(1))
	_sk_grid.add_theme_constant_override("v_separation", UI.sp(1))
	_sk_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col.add_child(_sk_grid)
	_sk_out = UI.vbox(UI.sp(1))
	_col.add_child(_sk_out)
	_sk_fill()


var _sk_info: Dictionary = {}
var _sk_pal: Array = []
var _sk_cats: Array = []
var _sk_all: Dictionary = {}
var _sk_cat := 0
var _sk_query := ""
var _sk_tabs: HBoxContainer
var _sk_grid: GridContainer
var _sk_out: VBoxContainer


func _sk_pick_tab(i: int) -> void:
	_sk_cat = i
	for k in _sk_tabs.get_child_count():
		(_sk_tabs.get_child(k) as Button).button_pressed = k == i
	_sk_fill()


func _sk_fill() -> void:
	for c in _sk_grid.get_children():
		c.queue_free()
	var seen := {}
	for ci in range(1, _sk_cats.size()):
		if _sk_cat != 0 and ci != _sk_cat:
			continue
		var col: Color = _sk_pal[(ci - 1) % _sk_pal.size()]
		for t in _sk_all[_sk_cats[ci]]:
			var nm := str(t)
			if seen.has(nm.to_lower()):
				continue
			if _sk_query != "" and nm.to_lower().find(_sk_query) < 0:
				continue
			seen[nm.to_lower()] = true
			_sk_grid.add_child(_sk_card(nm, col))
	if _sk_grid.get_child_count() == 0:
		_sk_grid.add_child(UI.text(L.t("Nada encontrado."), "small", UI.MIST))


func _sk_card(nm: String, col: Color) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = UI.tap(self) * 1.5
	b.add_theme_stylebox_override("normal", UI.box(Color(UI.PANEL_2, 0.92), Color(col, 0.35), 1, 12))
	var hv := UI.box(Color(col, 0.14), col, 1, 12)
	hv.shadow_color = Color(col, 0.3)
	hv.shadow_size = 12
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("focus", hv)
	b.add_theme_stylebox_override("pressed", UI.box(Color(col, 0.24), col, 1, 12))
	var m := UI.margin(UI.sp(1))
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(UI.full(m))
	var h := UI.hbox(UI.sp(1))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(h)
	var tr := TextureRect.new()
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2.ONE * UI.tap(self) * 1.05
	var tex := UI.tech_icon(nm)
	if tex:
		tr.texture = tex
	h.add_child(tr)
	var v := UI.vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nl := UI.label(nm, UI.fs("body"), UI.PAPER, "title")
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nl)
	var info: Variant = _sk_info.get(nm)
	if info is Array and (info as Array).size() > 0:
		var dl := UI.label(L.t(str(info[0])), UI.fs("small"), UI.MIST, "body")
		dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.max_lines_visible = 2
		v.add_child(dl)
	h.add_child(v)
	b.pressed.connect(_show_projects.bind(nm, col))
	return b


func _show_projects(tech: String, col: Color) -> void:
	for c in _sk_out.get_children():
		c.queue_free()
	var key := tech.to_lower().split(" ")[0].split("(")[0].trim_suffix(".js")
	var hits := []
	for p in Data.projects:
		for s in p.get("stack", []):
			var sl := str(s).to_lower()
			if sl.begins_with(key) or key.begins_with(sl.split(" ")[0]) or (key.length() > 3 and sl.find(key) >= 0):
				hits.append(p)
				break
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.box(Color(col, 0.1), col, 1, 14, 16))
	var v := UI.vbox(UI.sp(1))
	card.add_child(v)
	var h := UI.hbox(UI.sp(1.2))
	var tex := UI.tech_icon(tech)
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2.ONE * UI.tap(self) * 1.6
		h.add_child(tr)
	var hv := UI.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UI.title(tech, UI.fs("h2"), col))
	var info: Variant = _sk_info.get(tech)
	if info is Array and (info as Array).size() > 0:
		var dl := UI.label(L.t(str(info[0])), UI.fs("body"), UI.PAPER, "body")
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hv.add_child(dl)
	h.add_child(hv)
	v.add_child(h)
	if info is Array and (info as Array).size() > 1:
		var site := UI.ghost(L.t("Site oficial") + "  ↗", col, int(UI.tap(self) * 0.75))
		var url := str(info[1])
		site.pressed.connect(func() -> void: OS.shell_open(url))
		v.add_child(site)
	var note := L.tf("Usada em %d projeto(s)", [hits.size()]) if not hits.is_empty() else L.t("Usada no trabalho profissional (veja a CARREIRA).")
	v.add_child(UI.text(note, "small", UI.MIST))
	for p in hits:
		var pb := Button.new()
		pb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pb.focus_mode = Control.FOCUS_ALL
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.custom_minimum_size.y = UI.tap(self)
		pb.add_theme_stylebox_override("normal", UI.box(Color(UI.PANEL_2, 0.9), Color(col, 0.4), 1, 10))
		pb.add_theme_stylebox_override("hover", UI.box(Color(col, 0.18), col, 1, 10))
		pb.add_theme_stylebox_override("focus", UI.box(Color(col, 0.18), col, 1, 10))
		pb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pb.text = "  %s   ·   %s  →" % [str(p.get("title", "")), L.tx(p, "tagline")]
		pb.clip_text = true
		pb.add_theme_font_size_override("font_size", UI.fs("small"))
		pb.add_theme_color_override("font_color", UI.PAPER)
		pb.pressed.connect(_go_project.bind(str(p.get("id", ""))))
		v.add_child(pb)
	_sk_out.add_child(card)
	await get_tree().process_frame
	var sc := _col.get_parent().get_parent() as ScrollContainer
	if sc:
		sc.ensure_control_visible(card)


## leva o jogador até a loja do projeto (fecha o painel e usa a viagem rápida do HUD)
func _go_project(pid: String) -> void:
	var hud: Node = null
	var n: Node = get_parent()
	while n != null:
		if n.has_method("enter_museum"):
			hud = n
			break
		n = n.get_parent()
	if hud == null:
		return
	for pl in Nav.places(hud.city):
		if str((pl["project"] as Dictionary).get("id", "")) == pid:
			_sheet.close()
			Nav.travel(hud, pl)
			return


# ───────────────────────────────── linha do tempo da carreira
func _build_timeline() -> void:
	for e in Data.profile.get("experience", []):
		var row := UI.hbox(12)
		var dot := ColorRect.new()
		dot.color = _accent
		dot.custom_minimum_size = Vector2(6, 0)
		row.add_child(dot)
		var v := UI.vbox(4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.title(str(e.get("company", "")), UI.fs("h3"), _accent))
		v.add_child(UI.label("%s  ·  %s  ·  %s" % [L.t(str(e.get("role", ""))), L.t(str(e.get("period", ""))), L.t(str(e.get("place", "")))], UI.fs("small"), UI.MIST, "type"))
		for hl in e.get("highlights", []):
			v.add_child(UI.label("▸ " + L.t(str(hl)), UI.fs("small"), UI.PAPER, "body"))
		row.add_child(v)
		_col.add_child(row)
	var edu: Array = Data.profile.get("education", [])
	if not edu.is_empty():
		_col.add_child(UI.title("Formação", UI.fs("h3"), UI.PAPER))
		for ed in edu:
			_col.add_child(UI.label("▸ " + L.t(str(ed.get("course", ed.get("title", "")))) + "  ·  " + str(ed.get("school", ed.get("place", ""))) + "  ·  " + L.t(str(ed.get("period", ""))), UI.fs("small"), UI.PAPER, "body"))


# ───────────────────────────────── contato
func _build_contact() -> void:
	var p: Dictionary = Data.profile
	_col.add_child(UI.title("Gabriel Inácio", UI.fs("h2"), _accent))
	_body(L.t(str(p.get("role", ""))), UI.MIST)
	var links: Dictionary = p.get("links", {})
	for spec in [["LINKEDIN  ↗", "linkedin", Color("#4e9bff")], ["GITHUB  ↗", "github", UI.PAPER], ["E-MAIL  ↗", "email", Color("#5fd38a")]]:
		if links.has(spec[1]):
			var url := str(links[spec[1]])
			if spec[1] == "email":
				url = "mailto:" + url
			var b := UI.button(spec[0], spec[2], UI.tap())
			b.pressed.connect(func() -> void: open_url(url))
			_col.add_child(b)


# ───────────────────────────────── fliperama jogável
func _build_arcade() -> void:
	var pad := MarginContainer.new()
	for sd in ["left", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + sd, 12)
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_outer.add_child(pad)
	var v := UI.vbox(8)
	pad.add_child(v)
	var scripts := {"snake": "res://scripts/arcade/snake.gd", "breakout": "res://scripts/arcade/breakout.gd", "fortress": "res://scripts/arcade/fortress_td.gd"}
	var path: String = scripts.get(str(item.get("game", "snake")), scripts["snake"])
	_game = load(path).new()
	_game.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_game.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_game.set("accent", _accent)
	_game.set("touch", UI.is_mobile())
	v.add_child(_game)
	var help := UI.label(_game.call("help"), UI.fs("small"), UI.MIST, "type")
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(help)
	_game.grab_focus()


func _process(dt: float) -> void:
	_anim_t += dt
	if _type_label and _type_pos < _type_full.length():
		_type_pos += dt * 38.0
		_type_label.text = _type_full.substr(0, int(_type_pos)) + ("▌" if fmod(_anim_t, 0.8) < 0.4 else "")
	if _spin_node and not _drag_rot:
		_spin_node.rotate_y(dt * 0.5)


static func open_url(url: String) -> void:
	if url == "":
		return
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.open('%s','_blank')" % url, true)
	else:
		OS.shell_open(url)


func close() -> void:
	if _sheet:
		_sheet.close()
