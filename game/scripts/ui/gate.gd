class_name Gate
extends Control
## TELA DE ENTRADA: fundo noir animado (chuva e neon desfocado desenhados em código), sobretítulo
## PORTFÓLIO, nome em destaque, subtítulo, ENTRAR, idioma e o cartão de comandos para o dispositivo.
## Celular em pé: coluna única centrada. Celular deitado/PC: título à esquerda e comandos à direita.

signal entered

var _t := 0.0
var _drops: Array = []
var _logo: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 90:
		_drops.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.4, 1.0)))
	_build()
	get_viewport().size_changed.connect(_rebuild)


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame
	_build()


func _build() -> void:
	var f := UI.ff(self)
	var vs := get_viewport_rect().size
	var root := UI.margin(UI.sp(4), UI.safe_top(self) + UI.sp(4), UI.sp(4))
	add_child(UI.full(root))
	var lay: BoxContainer = UI.vbox(UI.sp(4)) if f == "phone" else UI.hbox(UI.sp(6))
	lay.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(lay)
	# coluna do título
	var left := UI.vbox(UI.sp(1.6))
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL if f == "phone" else Control.SIZE_SHRINK_CENTER
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lay.add_child(left)
	var center_align := f == "phone"
	var over := UI.label(L.t("PORTFÓLIO"), UI.fs("small"), UI.PINK, "bold")
	over.uppercase = true
	over.add_theme_constant_override("outline_size", 0)
	over.text = " ".join(L.t("PORTFÓLIO").split(""))
	over.autowrap_mode = TextServer.AUTOWRAP_OFF
	left.add_child(over)
	_logo = UI.label("GABRIEL INÁCIO", UI.fs("display"), UI.PAPER, "title")
	_logo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_logo.add_theme_constant_override("line_spacing", -12)
	_logo.add_theme_color_override("font_shadow_color", Color(UI.PINK, 0.22))
	_logo.add_theme_constant_override("shadow_offset_x", 0)
	_logo.add_theme_constant_override("shadow_offset_y", 0)
	_logo.add_theme_constant_override("shadow_outline_size", 7)
	left.add_child(_logo)
	var tag := UI.label(str(Data.profile.get("hero_tag", "// FULLSTACK DEVELOPER")), UI.fs("small"), UI.CYAN, "type")
	left.add_child(tag)
	left.move_child(tag, left.get_child_count() - 2)
	var sub := UI.label("engenharia de software · games · IA", UI.fs("h3") * 0.9, UI.AMBER, "type")
	left.add_child(sub)
	for l in [over, tag, _logo, sub]:
		(l as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center_align else HORIZONTAL_ALIGNMENT_LEFT
	var gap := Control.new()
	gap.custom_minimum_size.y = UI.sp(2)
	left.add_child(gap)
	var enter := UI.button("ENTRAR NA CIDADE", UI.AMBER, int(UI.tap() * 1.1))
	enter.custom_minimum_size.x = minf(vs.x - UI.sp(8), 460.0 if f != "phone" else 9999.0)
	enter.size_flags_horizontal = Control.SIZE_FILL if f == "phone" else Control.SIZE_SHRINK_BEGIN
	enter.pressed.connect(func() -> void: entered.emit())
	left.add_child(enter)
	enter.grab_focus.call_deferred()
	# seletor de idioma segmentado
	var seg := UI.hbox(UI.sp(1))
	seg.alignment = BoxContainer.ALIGNMENT_CENTER if center_align else BoxContainer.ALIGNMENT_BEGIN
	for spec in [["PORTUGUÊS", "pt"], ["ENGLISH", "en"]]:
		var on: bool = L.lang == spec[1]
		var lb: Button = UI.ghost(spec[0], UI.AMBER if on else UI.DIM, int(UI.tap() * 0.78))
		lb.custom_minimum_size.x = UI.sp(22)
		if not on:
			lb.pressed.connect(func() -> void: L.set_lang(spec[1]))
		seg.add_child(lb)
	left.add_child(seg)
	var hint := UI.text("Ative o volume para experiência completa", "cap", UI.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center_align else HORIZONTAL_ALIGNMENT_LEFT
	left.add_child(hint)
	# cartão de comandos
	var card := ControlsCard.make(UI.is_touch() or f == "phone", f != "desk")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL if f == "phone" else Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if f != "phone":
		card.custom_minimum_size.x = minf(vs.x * 0.42, 620.0)
	lay.add_child(card)
	# respiração do título (o tween pertence ao título e morre com ele)
	var tw := _logo.create_tween().set_loops()
	tw.tween_property(_logo, "modulate:a", 0.78, 1.6)
	tw.tween_property(_logo, "modulate:a", 1.0, 1.6)


func _process(dt: float) -> void:
	_t += dt
	queue_redraw()


## fundo: gradiente noite, dois halos de neon que respiram e chuva fina diagonal
func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color("#05060c"))
	var k := 0.5 + 0.5 * sin(_t * 0.7)
	for i in 6:
		var r := s.length() * (0.42 - i * 0.05)
		draw_circle(Vector2(s.x * 0.85, s.y * 0.1), r, Color(UI.PINK, 0.022 + 0.01 * k))
		draw_circle(Vector2(s.x * 0.08, s.y * 0.95), r * 0.9, Color(UI.CYAN, 0.02 + 0.008 * (1.0 - k)))
	for d in _drops:
		var x: float = fmod(d.x + _t * 0.05 * d.z, 1.0) * s.x
		var y: float = fmod(d.y + _t * 0.6 * d.z, 1.0) * s.y
		draw_line(Vector2(x, y), Vector2(x - 6 * d.z, y + 26 * d.z), Color(0.6, 0.7, 1.0, 0.12 * d.z), 1.2)
	# vinheta
	draw_rect(Rect2(0, s.y * 0.82, s.x, s.y * 0.18), Color(0, 0, 0, 0.25))
