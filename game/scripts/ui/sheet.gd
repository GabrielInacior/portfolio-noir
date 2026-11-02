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
var _closing := false


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
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	panel.add_child(col)
	# faixa de acento no topo (assinatura visual dos painéis)
	var stripe := ColorRect.new()
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
	if kicker_text != "":
		tcol.add_child(UI.kicker(kicker_text, accent))
	if title_text != "":
		var t := UI.text(title_text, "h2", UI.PAPER)
		t.add_theme_constant_override("line_spacing", -4)
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
	panel.add_theme_stylebox_override("panel", st)
	panel.custom_minimum_size = Vector2(w, h)
	panel.size = Vector2(w, h)
	panel.position = pos
	panel.pivot_offset = Vector2(w, h) / 2.0


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
