extends Control
## Modal noir de um item da loja-museu: cartela de arquivo com a imagem grande do item, título,
## texto da história e etiqueta (stack/tema). Abre e fecha com animação; fundo escurecido.

signal closed

var _accent := UI.AMBER
var item: Dictionary = {}
var project: Dictionary = {}


func setup(it: Dictionary, accent: Color, proj: Dictionary) -> void:
	item = it
	_accent = accent
	project = proj


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.74)
	add_child(UI.full(dim))
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_close())
	var vs := get_viewport_rect().size
	var tall := vs.y > vs.x
	var small := vs.y <= 560.0
	var mobile := tall or small
	# folha: no celular quase a tela toda; no PC uma cartela centrada (máx. 860)
	var w: float = vs.x - 24.0 if tall else minf(vs.x - 48.0, 860.0)
	var h: float = vs.y - (24.0 if mobile else 80.0)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(UI.PANEL, _accent, 3, 18, 0))
	panel.custom_minimum_size = Vector2(w, h)
	panel.size = Vector2(w, h)
	panel.position = (vs - Vector2(w, h)) / 2.0
	add_child(panel)
	var outer := UI.vbox(0)
	panel.add_child(outer)
	# cabeçalho fixo (fechar sempre visível)
	var headpad := MarginContainer.new()
	for sd in ["left", "right", "top"]:
		headpad.add_theme_constant_override("margin_" + sd, 18)
	headpad.add_theme_constant_override("margin_bottom", 6)
	var head := UI.hbox(8)
	var kicker := UI.label(str(project.get("title", "")).to_upper(), 24 if mobile else 20, _accent, "type")
	kicker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kicker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(kicker)
	var x := UI.ghost("✕", _accent, 72 if small else 88)
	x.custom_minimum_size.x = 72 if small else 88
	x.add_theme_font_override("font", UI.font("body"))
	x.add_theme_font_size_override("font_size", 34)
	x.pressed.connect(_close)
	head.add_child(x)
	headpad.add_child(head)
	outer.add_child(headpad)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	TouchScroll.attach(scroll)
	var pad := MarginContainer.new()
	for sd in ["left", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + sd, 22)
	pad.add_theme_constant_override("margin_top", 4)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	var col := UI.vbox(14)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(col)

	var img_path := str(item.get("img", ""))
	if img_path != "" and ResourceLoader.exists(img_path):
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", UI.box(Color("#0a0c14"), _accent.darkened(0.3), 2, 10, 6))
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tr := TextureRect.new()
		tr.texture = load(img_path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(0, minf(vs.y * (0.32 if tall else 0.42), 380.0))
		frame.add_child(tr)
		col.add_child(frame)

	col.add_child(UI.title(str(item.get("title", "")), 46 if mobile else 48, UI.PAPER))
	var rule := ColorRect.new()
	rule.color = Color(_accent, 0.6)
	rule.custom_minimum_size.y = 3
	col.add_child(rule)
	var body := UI.label(str(item.get("text", "")), 28 if mobile else 24, Color(UI.PAPER, 0.92), "body")
	col.add_child(body)
	var tag := str(item.get("tag", ""))
	if tag != "":
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UI.box(Color(_accent, 0.16), _accent, 1, 8, 10))
		chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		chip.add_child(UI.label(tag, 22 if mobile else 18, _accent, "type"))
		col.add_child(chip)
	var links: Dictionary = project.get("links", {})
	if links is Dictionary and not links.is_empty():
		var lr: BoxContainer = UI.vbox(10) if tall else UI.hbox(10)
		if links.has("site"):
			var b := UI.button("ABRIR O SITE  ↗", _accent, 88 if mobile else 64)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(func() -> void: _open(str(links["site"])))
			lr.add_child(b)
		if links.has("github"):
			var g := UI.ghost("GITHUB  ↗", UI.PAPER, 88 if mobile else 64)
			g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			g.pressed.connect(func() -> void: _open(str(links["github"])))
			lr.add_child(g)
		col.add_child(lr)
	elif bool(project.get("private", false)):
		col.add_child(UI.label("repositório privado", 22 if mobile else 18, UI.MIST, "type"))

	modulate.a = 0.0
	scale = Vector2(0.98, 0.98)
	pivot_offset = vs / 2.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(self, "scale", Vector2.ONE, 0.2)
	Audio.duck(true)


func _open(url: String) -> void:
	if url == "":
		return
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.open('%s','_blank')" % url, true)
	else:
		OS.shell_open(url)


func _close() -> void:
	Audio.duck(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.16)
	tw.tween_callback(func() -> void:
		closed.emit()
		queue_free())
