class_name Sheet
extends Control
## MODAL PADRÃO do design system: fundo escurecido, painel de vidro com cabeçalho FIXO (sobretítulo,
## título, fechar), corpo com rolagem por toque e rodapé fixo opcional. Responsivo:
##  - celular em pé: folha que sobe do rodapé, largura total, até a área segura de cima;
##  - celular deitado: painel centrado quase da altura toda (largura máx. 900);
##  - PC: cartela centrada com largura de leitura (máx. 940) e margem generosa.
## Fecha no X, no Esc, no clique fora e no botão voltar. Nada corta: o corpo rola.
## Uso: var s := Sheet.new(); s.setup(kicker, title, accent); add_child(UI.full(s)); s.body.add_child(...)

signal closed

var accent := UI.AMBER
var kicker_text := ""
var title_text := ""
var body: VBoxContainer          # onde o conteúdo entra
var footer: HBoxContainer        # botões fixos embaixo (opcional, some se vazio)
var panel: PanelContainer
var scroll: ScrollContainer
var width_hint := 0.0            # largura preferida no PC (0 = padrão)
var scrollable := true           # false: corpo ocupa a altura toda sem rolar (jogos, mapa)
var theme_data: Dictionary = {}   # tema por projeto (Themes): fundo, moldura, fonte, decoração
var _closing := false
var _stripe: ColorRect
var _kicker: Label
var _title: Label
var _deco: Control
var _t := 0.0


func setup(kick: String, ttl: String, acc := UI.AMBER, w := 0.0) -> void:
	kicker_text = kick
	title_text = ttl
	accent = acc
	width_hint = w
	_build()


func _build() -> void:
	if panel:
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.04, 0.72)
	add_child(UI.full(dim))
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
			close())
	panel = PanelContainer.new()
	add_child(panel)
	# camada de decoração do tema (desenhada atrás do conteúdo)
	_deco = Control.new()
	_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deco.draw.connect(_draw_deco)
	panel.add_child(_deco)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	panel.add_child(col)
	# faixa de acento no topo (assinatura visual dos painéis)
	var stripe := ColorRect.new()
	_stripe = stripe
	stripe.color = accent
	stripe.custom_minimum_size.y = 3
	col.add_child(stripe)
	# cabeçalho fixo
	var head_m := UI.margin(UI.sp(3), UI.sp(2.4), UI.sp(1.6))
	col.add_child(head_m)
	var head := UI.hbox(UI.sp(2))
	head_m.add_child(head)
	var tcol := UI.vbox(UI.sp(0.4))
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tcol.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(tcol)
	_kicker = UI.kicker(kicker_text, accent)
	_kicker.visible = kicker_text != ""
	tcol.add_child(_kicker)
	var t := UI.text(title_text, "h2", UI.PAPER)
	t.add_theme_constant_override("line_spacing", -4)
	t.visible = title_text != ""
	_title = t
	tcol.add_child(t)
	var x := UI.icon_btn("close", UI.PAPER, UI.tap(), "Fechar")
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	x.pressed.connect(close)
	head.add_child(x)
	var sep := ColorRect.new()
	sep.color = UI.STROKE
	sep.custom_minimum_size.y = 1
	col.add_child(sep)
	# corpo com rolagem (ou fixo, para jogos)
	var pad := UI.margin(UI.sp(3), UI.sp(2.4), UI.sp(3))
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if scrollable:
		scroll = ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(scroll)
		TouchScroll.attach(scroll)
		scroll.add_child(pad)
	else:
		pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(pad)
	body = UI.vbox(UI.sp(2))
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL if not scrollable else Control.SIZE_FILL
	pad.add_child(body)
	# rodapé fixo
	var foot_m := UI.margin(UI.sp(3), UI.sp(1.6), UI.sp(2.4))
	foot_m.name = "Foot"
	col.add_child(foot_m)
	footer = UI.hbox(UI.sp(1.5))
	foot_m.add_child(footer)
	foot_m.visible = false
	footer.child_entered_tree.connect(func(_n: Node) -> void: foot_m.visible = true)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_intro()


func _layout() -> void:
	if not is_inside_tree() or panel == null:
		return
	var vs := get_viewport_rect().size
	var f := UI.ff(self)
	var r := UI.radius(self)
	var st := UI.glass(accent, r, 0, 0.97)
	var w: float
	var h: float
	var pos: Vector2
	if f == "phone":
		var top := UI.safe_top(self) + UI.sp(3)
		w = vs.x - UI.sp(2) * 2
		h = vs.y - top - UI.sp(2)
		pos = Vector2(UI.sp(2), top)
	elif f == "land":
		w = minf(vs.x - UI.sp(4) * 2, maxf(width_hint, UI.max_w(self)))
		h = vs.y - UI.sp(3) * 2
		pos = Vector2((vs.x - w) / 2.0, UI.sp(3))
	else:
		w = minf(vs.x - 96.0, width_hint if width_hint > 0.0 else UI.max_w(self))
		h = minf(vs.y - 80.0, 1100.0)
		pos = (vs - Vector2(w, h)) / 2.0
	if not theme_data.is_empty():
		st = _theme_box(r)
	panel.add_theme_stylebox_override("panel", st)
	panel.custom_minimum_size = Vector2(w, h)
	panel.size = Vector2(w, h)
	panel.position = pos
	panel.pivot_offset = Vector2(w, h) / 2.0


# ───────── tema por projeto
func restyle() -> void:
	if theme_data.is_empty() or panel == null:
		return
	var t := theme_data
	accent = Themes.col(t, "accent", accent)
	var ink: Color = Themes.col(t, "ink", UI.PAPER)
	_stripe.color = accent
	var style := str(t.get("style", "startup"))
	var k := str(t.get("kicker", ""))
	if k != "":
		_kicker.text = L.t(k).to_upper()
		_kicker.visible = true
	_kicker.add_theme_color_override("font_color", accent)
	var tf := str(t.get("title_font", "title"))
	_title.add_theme_font_override("font", UI.font(tf))
	_title.add_theme_color_override("font_color", ink)
	if tf in ["type", "bold"]:
		_title.add_theme_font_size_override("font_size", int(UI.fs("h2", self) * 0.74))
	elif tf == "marker":
		_title.add_theme_font_size_override("font_size", int(UI.fs("h2", self) * 0.86))
	if style == "arcade":
		_title.add_theme_color_override("font_shadow_color", Themes.col(t, "accent2", UI.CYAN))
		_title.add_theme_constant_override("shadow_offset_x", 3)
		_title.add_theme_constant_override("shadow_offset_y", 3)
	elif style == "terminal":
		_title.text = "> " + _title.text
	_layout()
	_deco.queue_redraw()


func _theme_box(r: int) -> StyleBoxFlat:
	var t := theme_data
	var style := str(t.get("style", "startup"))
	var bg := Themes.col(t, "bg", UI.PANEL)
	var st := UI.box(Color(bg, 0.98), Color(accent, 0.7), 1, r)
	st.shadow_color = Color(accent, 0.22)
	st.shadow_size = 22
	match style:
		"dossier":
			st.set_corner_radius_all(4)
			st.set_border_width_all(2)
			st.border_color = Color(accent, 0.55)
		"arcade":
			st.set_corner_radius_all(0)
			st.set_border_width_all(4)
			st.border_color = accent
		"terminal":
			st.set_corner_radius_all(2)
		"menu":
			st.set_corner_radius_all(r + 8)
			st.set_border_width_all(2)
		"product":
			st.set_corner_radius_all(r + 4)
			st.border_color = Color(accent, 0.4)
		"career":
			st.set_corner_radius_all(6)
	return st


## decoração própria de cada estilo, desenhada por trás do conteúdo
func _draw_deco() -> void:
	if theme_data.is_empty():
		return
	var t := theme_data
	var s := _deco.size
	var style := str(t.get("style", ""))
	var a2 := Themes.col(t, "accent2", UI.CYAN)
	match style:
		"dossier":
			var rng := RandomNumberGenerator.new()
			rng.seed = 11
			for i in 260:
				var p := Vector2(rng.randf() * s.x, rng.randf() * s.y)
				_deco.draw_line(p, p + Vector2(rng.randf_range(4, 18), rng.randf_range(-1, 1)), Color(1, 0.9, 0.7, 0.03), 1.0)
			var stamp := L.t(str(t.get("stamp", "CONFIDENCIAL"))).to_upper()
			var f := UI.font("title")
			var fz := int(UI.fs("h2", self) * 0.8)
			var tw := f.get_string_size(stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, fz).x
			var c := Vector2(s.x - tw * 0.6 - UI.tap(self) - UI.sp(6, self), UI.sp(3, self) + fz * 0.7)
			_deco.draw_set_transform(c, -0.16)
			_deco.draw_rect(Rect2(Vector2(-tw / 2.0 - 12, -fz * 0.75), Vector2(tw + 24, fz * 1.1)), Color(a2, 0.45), false, 3.0)
			_deco.draw_string(f, Vector2(-tw / 2.0, fz * 0.22), stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, fz, Color(a2, 0.45))
			_deco.draw_set_transform(Vector2.ZERO)
		"arcade":
			for y in range(0, int(s.y), 4):
				_deco.draw_line(Vector2(0, y), Vector2(s.x, y), Color(0, 0, 0, 0.2), 1.0)
			var px := 10.0
			for kk in 4:
				_deco.draw_rect(Rect2(Vector2(kk * px, 0), Vector2(px, px)), Color(accent, 0.55 - kk * 0.12))
				_deco.draw_rect(Rect2(Vector2(s.x - (kk + 1) * px, s.y - px), Vector2(px, px)), Color(a2, 0.55 - kk * 0.12))
		"terminal":
			for y in range(0, int(s.y), 3):
				_deco.draw_line(Vector2(0, y), Vector2(s.x, y), Color(0, 0, 0, 0.32), 1.0)
			_deco.draw_rect(Rect2(Vector2.ZERO, s), Color(accent, 0.035 + 0.02 * sin(_t * 2.0)))
			if fmod(_t, 1.0) < 0.55 and _title and _title.is_inside_tree():
				var tr := _title.get_global_rect()
				var p2 := tr.position - _deco.get_global_rect().position
				var f2 := _title.get_theme_font("font")
				var w := f2.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _title.get_theme_font_size("font_size")).x
				_deco.draw_rect(Rect2(p2 + Vector2(minf(w, tr.size.x) + 6, tr.size.y * 0.2), Vector2(12, tr.size.y * 0.6)), accent)
		"menu":
			var m := UI.sp(1.2, self)
			_deco.draw_rect(Rect2(Vector2(m, m), s - Vector2(m, m) * 2), Color(a2, 0.35), false, 1.0)
			for cc in [Vector2(m, m), Vector2(s.x - m, m), Vector2(m, s.y - m), Vector2(s.x - m, s.y - m)]:
				_deco.draw_circle(cc, 4.0, Color(a2, 0.6))
		"product":
			for i in 3:
				_deco.draw_circle(Vector2(s.x * (0.85 - i * 0.05), s.y * 0.05), s.x * (0.25 + i * 0.1), Color(accent, 0.03))
		"career":
			var step := float(UI.sp(4, self))
			var x := 0.0
			while x < s.x:
				_deco.draw_line(Vector2(x, 0), Vector2(x, s.y), Color(accent, 0.05), 1.0)
				x += step
			var yy := 0.0
			while yy < s.y:
				_deco.draw_line(Vector2(0, yy), Vector2(s.x, yy), Color(accent, 0.05), 1.0)
				yy += step
		"lab":
			for i in 5:
				_deco.draw_circle(Vector2(s.x * 0.1, s.y * 0.95), s.y * (0.2 + i * 0.12), Color(a2, 0.02))
		_:
			var st2 := float(UI.sp(3, self))
			var y2 := st2
			while y2 < s.y:
				var x2 := st2
				while x2 < s.x:
					_deco.draw_circle(Vector2(x2, y2), 1.0, Color(accent, 0.07))
					x2 += st2
				y2 += st2


func _process(dt: float) -> void:
	if str(theme_data.get("style", "")) == "terminal":
		_t += dt
		_deco.queue_redraw()


func _intro() -> void:
	modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	if UI.ff(self) == "phone":
		var p0 := panel.position
		panel.position = p0 + Vector2(0, 60)
		tw.tween_property(panel, "position", p0, 0.32).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	else:
		panel.scale = Vector2(0.965, 0.965)
		tw.tween_property(panel, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 0.0, 0.16)
	if panel:
		tw.tween_property(panel, "scale", Vector2(0.98, 0.98), 0.16)
	tw.chain().tween_callback(func() -> void:
		closed.emit()
		queue_free())


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") or (e is InputEventKey and (e as InputEventKey).pressed and (e as InputEventKey).keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close()


# ───────── ajudantes de conteúdo (mesmo visual em todos os painéis)
func add_text(t: String, role := "body", col := Color(UI.PAPER, 0.92)) -> Label:
	var l := UI.text(t, role, col)
	l.add_theme_constant_override("line_spacing", 4)
	body.add_child(l)
	return l


func add_image(tex: Texture2D, max_h := 0.0) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.box(Color("#05070d"), Color(accent, 0.35), 1, UI.radius(self) - 6, UI.sp(0.8)))
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var vs := get_viewport_rect().size
	var mh := max_h if max_h > 0.0 else minf(vs.y * (0.3 if UI.ff(self) == "phone" else 0.42), 440.0)
	# proporção da imagem respeitada: altura pela largura disponível, limitada
	if tex:
		var avail := panel.custom_minimum_size.x - UI.sp(3) * 2 - UI.sp(0.8) * 2
		mh = minf(mh, avail * float(tex.get_height()) / maxf(1.0, float(tex.get_width())))
	tr.custom_minimum_size = Vector2(0, mh)
	frame.add_child(tr)
	body.add_child(frame)
	return frame


func add_rule() -> void:
	var rule := ColorRect.new()
	rule.color = Color(accent, 0.45)
	rule.custom_minimum_size = Vector2(UI.sp(8), 3)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	body.add_child(rule)


func add_chips(list: Array, col := Color(-1, 0, 0)) -> HFlowContainer:
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", UI.sp(1))
	fl.add_theme_constant_override("v_separation", UI.sp(1))
	for c in list:
		fl.add_child(UI.chip(str(c), accent if col.r < 0.0 else col))
	body.add_child(fl)
	return fl


## botão de link no rodapé (abre em nova aba no navegador)
func add_link(t: String, url: String, primary := true) -> Button:
	var b: Button = UI.button(t + "  ↗", accent) if primary else UI.ghost(t + "  ↗", UI.PAPER)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void: Sheet.open_url(url))
	footer.add_child(b)
	return b


static func open_url(url: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.open(%s,'_blank','noopener')" % JSON.stringify(url), true)
	else:
		OS.shell_open(url)
