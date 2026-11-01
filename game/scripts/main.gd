extends Node
## Monta a cidade e a interface, com entrada cinematográfica (preto -> ENTRAR -> fade na cidade).
## O ENTRAR destrava o áudio (exigência da web) e o pointer lock no desktop.

const City := preload("res://scripts/city.gd")
const Hud := preload("res://scripts/hud.gd")

var city
var hud
var _gate: Control


func _ready() -> void:
	# tela lógica por orientação: celular em pé 720x1280; deitado baixo (celular) 960x540; PC 1280x720
	get_window().size_changed.connect(_fit_scale)
	_fit_scale()
	city = City.new()
	add_child(city)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.visible = false
	layer.add_child(hud)
	await get_tree().process_frame
	hud.setup(city.player, city)
	_build_gate(layer)


func _build_gate(layer: CanvasLayer) -> void:
	_gate = Control.new()
	_gate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gate.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("#05060c")
	_gate.add_child(UI.full(bg))
	var center := CenterContainer.new()
	_gate.add_child(UI.full(center))
	var v := UI.vbox(18)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)
	var logo := UI.title("GABRIEL INÁCIO", 86, UI.PAPER)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(logo)
	var sub := UI.label("engenharia de software · games · IA", 26, UI.AMBER, "type")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 30
	v.add_child(spacer)
	var enter := UI.button("ENTRAR NA CIDADE", UI.AMBER, 86)
	enter.custom_minimum_size.x = 420
	enter.pressed.connect(_enter)
	v.add_child(enter)
	var hint := UI.label("ative o som para a experiência completa", 18, UI.MIST, "body")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	layer.add_child(_gate)
	# respiração do título
	var tw := create_tween().set_loops()
	tw.tween_property(logo, "modulate:a", 0.6, 1.4)
	tw.tween_property(logo, "modulate:a", 1.0, 1.4)


func _enter() -> void:
	Audio.start()
	hud.visible = true
	if not UI.is_mobile():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var tw := create_tween()
	tw.tween_property(_gate, "modulate:a", 0.0, 0.9)
	tw.tween_callback(_gate.queue_free)



func _fit_scale() -> void:
	var ws := DisplayServer.window_get_size()
	if ws.x <= 0 or ws.y <= 0:
		return
	var want := Vector2i(1280, 720)
	if ws.y > ws.x:
		want = Vector2i(720, 1280)
	elif ws.y < 600:
		want = Vector2i(960, 540)
	if get_window().content_scale_size != want:
		get_window().content_scale_size = want
		_watch_dirty = 3


## Vigia de texto vertical (lição do RUMOR): texto que quebra linha e ficou espremido vira coluna de
## letras; aqui ele deixa de quebrar. Só confere quando a tela muda (nó novo ou janela girada).
var _watch_t := 0.0
var _watch_dirty := 2
var _watch_hooked := false


func _process(dt: float) -> void:
	if not _watch_hooked:
		_watch_hooked = true
		get_tree().node_added.connect(func(n: Node) -> void:
			if n is Label:
				_watch_dirty = 2)
	_watch_t += dt
	if _watch_t < 0.4 or _watch_dirty <= 0:
		return
	_watch_t = 0.0
	_watch_dirty -= 1
	_scan_labels(self)


func _scan_labels(n: Node) -> void:
	for c in n.get_children():
		if c is Label:
			var l := c as Label
			if l.autowrap_mode != TextServer.AUTOWRAP_OFF and l.is_visible_in_tree() and l.text.length() > 3:
				var fs := l.get_theme_font_size("font_size")
				if l.size.x > 0.0 and l.size.x < fs * 2.2:
					l.autowrap_mode = TextServer.AUTOWRAP_OFF
					l.clip_text = true
		elif c is CanvasItem and not (c as CanvasItem).visible:
			continue
		_scan_labels(c)
