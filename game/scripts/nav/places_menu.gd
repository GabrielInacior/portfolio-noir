extends Sheet
## MENU DE LUGARES: para quem não quer andar. Cartões com miniatura, ícone do tipo, nome, frase e
## selo de visitado; tocar leva até lá e entra. Celular em pé: uma coluna; deitado/PC: duas.

signal go(place: Dictionary)

var city


func open(c) -> void:
	city = c
	setup(L.t("Navegação rápida"), L.t("Para onde vamos?"), UI.AMBER, 1040.0)
	var list := Nav.places(city)
	var visited := 0
	for p in list:
		if p["visited"]:
			visited += 1
	var intro := UI.text(L.t("Toque num lugar para ir direto até ele. Você também pode andar pela cidade e entrar pelos letreiros."), "small", UI.MIST)
	body.add_child(intro)
	var grid := GridContainer.new()
	grid.columns = 1 if UI.ff(self) == "phone" else 2
	grid.add_theme_constant_override("h_separation", UI.sp(1.6))
	grid.add_theme_constant_override("v_separation", UI.sp(1.6))
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(grid)
	for p in list:
		grid.add_child(_card(p))
	var prog := UI.hbox(UI.sp(1))
	prog.add_child(Icon.make("check", UI.GREEN, UI.fs("small")))
	var pl := UI.text(L.tf("%d de %d lugares visitados", [visited, list.size()]), "small", UI.MIST)
	pl.autowrap_mode = TextServer.AUTOWRAP_OFF
	prog.add_child(pl)
	footer.add_child(prog)


func _card(p: Dictionary) -> Control:
	var neon: Color = p["neon"]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var r := UI.radius(self)
	var n := UI.box(Color(UI.PANEL_2, 0.9), UI.STROKE, 1, r)
	b.add_theme_stylebox_override("normal", n)
	var hv := UI.box(Color(neon, 0.12), Color(neon, 0.8), 1, r)
	hv.shadow_color = Color(neon, 0.28)
	hv.shadow_size = 14
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", UI.box(Color(neon, 0.22), neon, 1, r))
	b.add_theme_stylebox_override("focus", hv)
	var th := UI.tap(self) * 1.25
	b.custom_minimum_size.y = th + UI.sp(2)
	var m := UI.margin(UI.sp(1.2))
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(UI.full(m))
	var h := UI.hbox(UI.sp(1.6))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(h)
	# miniatura (ou ícone do tipo sobre a cor do neon)
	var thumb := PanelContainer.new()
	thumb.custom_minimum_size = Vector2(th * 1.35, th)
	thumb.add_theme_stylebox_override("panel", UI.box(Color(neon, 0.16), Color(neon, 0.6), 1, r - 6))
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.clip_contents = true
	var tex: Texture2D = p["thumb"]
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.add_child(tr)
	var ic := Icon.make(str(p["icon"]), neon if not tex else UI.PAPER, th * 0.38)
	var icc := CenterContainer.new()
	icc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not tex:
		icc.add_child(ic)
		thumb.add_child(icc)
	h.add_child(thumb)
	var tcol := UI.vbox(UI.sp(0.3))
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tcol.alignment = BoxContainer.ALIGNMENT_CENTER
	tcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(tcol)
	# título e selo de status na mesma linha (o cartão tem altura fixa: nada pode empurrar o texto)
	var trow := UI.hbox(UI.sp(0.8))
	trow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := UI.text(str(p["title"]).to_upper(), "h3", UI.PAPER)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.clip_text = true
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trow.add_child(t)
	var st := str((p["project"] as Dictionary).get("status", ""))
	if st != "":
		var ch := Nav.status_chip(st)
		ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		trow.add_child(ch)
	tcol.add_child(trow)
	var s := UI.text(str(p["sub"]), "cap", UI.MIST)
	s.max_lines_visible = 2
	s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tcol.add_child(s)
	if p["visited"]:
		var ck := Icon.make("check", UI.GREEN, UI.fs("body"))
		ck.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ck)
	var arrow := Icon.make("chev_r", neon, UI.fs("body"))
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(arrow)
	b.pressed.connect(func() -> void:
		go.emit(p)
		close())
	return b
