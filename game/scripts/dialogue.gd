extends Control
## Tela de diálogo noir dedicada (no espírito da talk_view do RUMOR): close 3D do personagem
## animado (respira, muda de expressão a cada fala), nome e função, fala datilografada e escolhas
## de pergunta em árvore. Ao fim, botão para abrir o projeto. Abaixa a trilha enquanto aberta.

signal closed
signal open_project
signal ducking(active: bool)

var npc_name := ""
var role := ""
var accent := UI.AMBER
var greet := ""
var lines: Array = []       # [{q, a, expr}]
var npc_project: Dictionary = {}

var _vp: SubViewport
var _face                    # clone do NPC para o close
var _speech: Label
var _choices: VBoxContainer
var _full := ""
var _shown := 0.0
var _typing := false


func setup(nm: String, rl: String, acc: Color, g: String, qa: Array, project: Dictionary) -> void:
	npc_name = nm
	role = rl
	accent = acc
	greet = g
	lines = qa
	npc_project = project


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("#05070e", 0.96)
	add_child(UI.full(bg))
	ducking.emit(true)
	var wide := get_viewport_rect().size.x > get_viewport_rect().size.y
	var root: BoxContainer = UI.hbox(0) if wide else UI.vbox(0)
	add_child(UI.full(root))
	root.add_child(_build_portrait(wide))
	root.add_child(_build_panel(wide))
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.22)
	_say(greet, "serio")
	_show_choices()


# ───────── close 3D do personagem num SubViewport (retrato vivo)
func _build_portrait(wide: bool) -> Control:
	var holder := SubViewportContainer.new()
	holder.stretch = true
	var vs := get_viewport_rect().size
	if wide:
		holder.custom_minimum_size.x = vs.x * 0.46
		holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		holder.custom_minimum_size.y = vs.y * 0.5
		holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = false
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	holder.add_child(_vp)
	var world := Node3D.new()
	_vp.add_child(world)
	# fundo noir com vinheta de neon
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#0a0c16")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#20283f")
	e.ambient_light_energy = 1.2
	we.environment = e
	world.add_child(we)
	# luz chave fria + preenchimento quente do neon do projeto
	var key := OmniLight3D.new()
	key.position = Vector3(-1.2, 2.4, 1.6)
	key.light_color = Color("#9fb6ff")
	key.light_energy = 3.0
	key.omni_range = 6
	world.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(1.4, 2.0, -0.8)
	rim.light_color = accent
	rim.light_energy = 3.5
	rim.omni_range = 5
	world.add_child(rim)
	# mesmo personagem riggado da rua, em close (usa a ficha do NPC guia)
	var Npc := load("res://scripts/npc.gd")
	var helper = Npc.new()
	var Character := load("res://scripts/scene3d/noir_character.gd")
	_face = Character.new()
	_face.setup(helper._card_for(npc_project))
	world.add_child(_face)
	helper.free()
	# enquadramento de busto, levemente de 3/4 (o rosto e as expressões lidos de perto)
	_face.rotation.y = 0.32
	var cam := Camera3D.new()
	cam.position = Vector3(0.05, 1.58, 1.15)
	cam.fov = 30
	cam.look_at_from_position(cam.position, Vector3(0, 1.55, 0))
	cam.current = true
	world.add_child(cam)
	return holder


# ───────── painel de fala e escolhas
func _build_panel(wide: bool) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(Color(UI.NIGHT, 0.98), accent, 3, 0, 24))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(14)
	panel.add_child(v)
	var head := UI.hbox(10)
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", UI.box(accent, Color.TRANSPARENT, 0, 8, 8))
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var tv := UI.vbox(0)
	var nml := UI.label(npc_name.to_upper(), 26, UI.INK, "title")
	nml.autowrap_mode = TextServer.AUTOWRAP_OFF
	tv.add_child(nml)
	if role != "":
		var rl := UI.label(role, 16, Color(UI.INK, 0.8), "type")
		rl.autowrap_mode = TextServer.AUTOWRAP_OFF
		tv.add_child(rl)
	tag.add_child(tv)
	head.add_child(tag)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var x := UI.ghost("✕", accent, 44)
	x.custom_minimum_size.x = 48
	x.add_theme_font_override("font", UI.font("body"))
	x.pressed.connect(_close)
	head.add_child(x)
	v.add_child(head)
	# caixa de fala datilografada (altura fixa confortável; as escolhas ficam logo abaixo)
	var speech_box := PanelContainer.new()
	speech_box.add_theme_stylebox_override("panel", UI.box(Color(UI.INK, 0.6), Color(accent, 0.4), 1, 12, 16))
	speech_box.custom_minimum_size.y = 150
	_speech = UI.label("", 25, UI.PAPER, "type")
	_speech.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.custom_minimum_size.x = 0
	_speech.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speech_box.add_child(_speech)
	v.add_child(speech_box)
	_choices = UI.vbox(8)
	_choices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_choices)
	return panel


func _say(text: String, expr: String) -> void:
	_full = text
	_shown = 0.0
	_typing = true
	if _face and _face.has_method("set_expression"):
		_face.set_expression(expr)


func _process(dt: float) -> void:
	if _typing:
		_shown += dt * 45.0
		var n := int(_shown)
		_speech.text = _full.substr(0, n)
		if n >= _full.length():
			_typing = false
			_speech.text = _full


func _show_choices() -> void:
	for c in _choices.get_children():
		c.queue_free()
	for qa in lines:
		var b := UI.ghost(str(qa.get("q", "")), accent, 54)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", UI.font("body"))
		b.add_theme_font_size_override("font_size", 21)
		b.pressed.connect(_answer.bind(qa))
		_choices.add_child(b)
	if not npc_project.has("special"):
		var open := UI.button("ABRIR O PROJETO  ↗", accent, 56)
		open.pressed.connect(func() -> void:
			open_project.emit()
			_close())
		_choices.add_child(open)
	var bye := UI.ghost("Até mais.", UI.MIST, 48)
	bye.add_theme_font_override("font", UI.font("body"))
	bye.add_theme_font_size_override("font_size", 20)
	bye.pressed.connect(_close)
	_choices.add_child(bye)


func _answer(qa: Dictionary) -> void:
	_say(str(qa.get("a", "")), str(qa.get("expr", "serio")))


func _close() -> void:
	ducking.emit(false)
	closed.emit()
	queue_free()
