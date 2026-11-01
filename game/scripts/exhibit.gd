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
	var wide := vs.x > vs.y
	var center := CenterContainer.new()
	add_child(UI.full(center))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(UI.PANEL, _accent, 3, 18, 0))
	var w: float = minf(vs.x - 48.0, 760.0)
	panel.custom_minimum_size = Vector2(w, 0)
	center.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = minf(vs.y - 80.0, 900.0)
	panel.add_child(scroll)
	var pad := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + s, 24)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	var col := UI.vbox(14)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(col)

	# imagem do item (foto do projeto ou cartão), altura limitada para não dominar
	var img_path := str(item.get("img", ""))
	if img_path != "" and ResourceLoader.exists(img_path):
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", UI.box(Color("#0a0c14"), _accent.darkened(0.3), 2, 10, 6))
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tr := TextureRect.new()
		tr.texture = load(img_path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(0, minf(vs.y * 0.4, 360.0))
		frame.add_child(tr)
		col.add_child(frame)

	var head := UI.hbox(8)
	var kicker := UI.label(str(project.get("title", "")).to_upper(), 18, _accent, "type")
	kicker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(kicker)
	var x := UI.ghost("✕", _accent, 44)
	x.custom_minimum_size.x = 48
	x.add_theme_font_override("font", UI.font("body"))
	x.pressed.connect(_close)
	head.add_child(x)
	col.add_child(head)

	col.add_child(UI.title(str(item.get("title", "")), 48, UI.PAPER))
	var rule := ColorRect.new()
	rule.color = Color(_accent, 0.6)
	rule.custom_minimum_size.y = 3
	col.add_child(rule)

	var body := UI.label(str(item.get("text", "")), 24, Color(UI.PAPER, 0.92), "body")
	col.add_child(body)

	var tag := str(item.get("tag", ""))
	if tag != "":
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UI.box(Color(_accent, 0.16), _accent, 1, 8, 10))
		chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		chip.add_child(UI.label(tag, 18, _accent, "type"))
		col.add_child(chip)

	# links do projeto (site/github), se houver
	var links: Dictionary = project.get("links", {})
	if links is Dictionary and not links.is_empty():
		var lr := UI.hbox(10)
		if links.has("site"):
			var b := UI.button("ABRIR O SITE  ↗", _accent, 64)
			b.pressed.connect(func() -> void: _open(str(links["site"])))
			lr.add_child(b)
		if links.has("github"):
			var g := UI.ghost("GITHUB  ↗", UI.PAPER, 64)
			g.pressed.connect(func() -> void: _open(str(links["github"])))
			lr.add_child(g)
		col.add_child(lr)
	elif bool(project.get("private", false)):
		var pv := UI.label("repositório privado", 18, UI.MIST, "type")
		col.add_child(pv)

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
