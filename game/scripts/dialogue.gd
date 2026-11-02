extends Control
## Tela de diálogo noir dedicada (no espírito da talk_view do RUMOR): close 3D do personagem
## animado (respira, muda de expressão a cada fala), nome e função, fala datilografada e escolhas
## de pergunta em árvore. Ao fim, botão para abrir o projeto. Abaixa a trilha enquanto aberta.
## RESPONSIVO: celular em pé = personagem grande em cima (42% da altura), fala e escolhas embaixo
## com rolagem por toque; deitado/PC = personagem à esquerda, painel à direita. Alvos de toque de
## 88 px lógicos, fala >= 28 px no celular, tudo com quebra de linha.

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
var _portrait_mode := true
var _small := false


func setup(nm: String, rl: String, acc: Color, g: String, qa: Array, project: Dictionary) -> void:
	npc_name = nm
	role = rl
	accent = acc
	greet = g
	lines = qa
	npc_project = project


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#05070e", 0.97)
	add_child(UI.full(bg))
	ducking.emit(true)
	var vs := get_viewport_rect().size
	_portrait_mode = vs.y > vs.x
	_small = vs.y <= 560.0   # celular deitado
	var root: BoxContainer = UI.vbox(0) if _portrait_mode else UI.hbox(0)
	add_child(UI.full(root))
	root.add_child(_build_portrait(vs))
	root.add_child(_build_panel(vs))
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.22)
	_say(greet, "serio")
	_show_choices()


# ───────── close 3D do personagem num SubViewport (retrato vivo)
func _build_portrait(vs: Vector2) -> Control:
	var holder := SubViewportContainer.new()
	holder.stretch = true
	if _portrait_mode:
		holder.custom_minimum_size.y = vs.y * 0.42
		holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		holder.custom_minimum_size.x = vs.x * (0.4 if _small else 0.46)
		holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	holder.add_child(_vp)
	var world := Node3D.new()
	_vp.add_child(world)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#0a0c16")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#2a3150")
	e.ambient_light_energy = 1.2
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = e
	world.add_child(we)
	# fundo: parede de tijolo com neon desfocado (o personagem não flutua no vazio)
	var wall := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(6, 4)
	wall.mesh = q
	var wm := StandardMaterial3D.new()
	wm.albedo_texture = load("res://assets/tex/tijolo.png")
	wm.albedo_color = Color("#3a3050")
	wm.uv1_scale = Vector3(3, 2, 1)
	wall.material_override = wm
	wall.position = Vector3(0, 1.6, -1.6)
	world.add_child(wall)
	var glow := MeshInstance3D.new()
	var gq := QuadMesh.new()
	gq.size = Vector2(2.6, 2.6)
	glow.mesh = gq
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	gt.gradient = gr
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1, 0.5)
	gm.albedo_texture = gt
	gm.albedo_color = Color(accent, 0.55)
	glow.material_override = gm
	glow.position = Vector3(0.7, 1.9, -1.55)
	world.add_child(glow)
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
	var Npc := load("res://scripts/npc.gd")
	var helper = Npc.new()
	var Character := load("res://scripts/scene3d/noir_character.gd")
	_face = Character.new()
	_face.setup(helper._card_for(npc_project))
	world.add_child(_face)
	helper.free()
	_face.rotation.y = 0.32
	var cam := Camera3D.new()
	# em pé o quadro é largo e baixo: busto mais aberto; deitado/PC, close do rosto e ombros
	if _portrait_mode:
		cam.position = Vector3(0.05, 1.5, 1.6)
		cam.fov = 34
	else:
		cam.position = Vector3(0.05, 1.5, 1.35)
		cam.fov = 32
	cam.look_at_from_position(cam.position, Vector3(0, 1.48, 0))
	cam.current = true
	world.add_child(cam)
	return holder


# ───────── painel de fala e escolhas (design system)
func _build_panel(vs: Vector2) -> Control:
	var panel := PanelContainer.new()
	var st := UI.glass(accent, 0, 0, 0.97)
	st.set_corner_radius_all(0)
	if _portrait_mode:
		st.corner_radius_top_left = UI.radius(self)
		st.corner_radius_top_right = UI.radius(self)
	st.content_margin_left = UI.sp(3, self)
	st.content_margin_right = UI.sp(3, self)
	st.content_margin_top = UI.sp(2.4, self) + (UI.safe_top(self) if not _portrait_mode else 0)
	st.content_margin_bottom = UI.sp(2.4, self)
	panel.add_theme_stylebox_override("panel", st)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(UI.sp(1.6, self))
	panel.add_child(v)
	# cabeçalho: sobretítulo (função), nome e fechar
	var head := UI.hbox(UI.sp(1.6, self))
	var tv := UI.vbox(UI.sp(0.3, self))
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	if role != "":
		tv.add_child(UI.kicker(L.t(role), accent))
	var nml := UI.text(L.t(npc_name).to_upper(), "h2", UI.PAPER)
	nml.autowrap_mode = TextServer.AUTOWRAP_OFF
	nml.clip_text = true
	nml.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(nml)
	head.add_child(tv)
	var x := UI.icon_btn("close", UI.PAPER, UI.tap(self), "Fechar")
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	x.pressed.connect(_close)
	head.add_child(x)
	v.add_child(head)
	# fala datilografada em balão
	var speech_box := PanelContainer.new()
	var sb := UI.box(Color(UI.INK, 0.7), Color(accent, 0.45), 1, UI.radius(self) - 4, UI.sp(2, self))
	sb.border_width_left = 3
	speech_box.add_theme_stylebox_override("panel", sb)
	speech_box.custom_minimum_size.y = UI.tap(self) * 1.2
	_speech = UI.label("", UI.fs("body", self) + 2, UI.PAPER, "type")
	_speech.add_theme_constant_override("line_spacing", 4)
	_speech.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_speech.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speech_box.add_child(_speech)
	v.add_child(speech_box)
	v.add_child(UI.kicker(L.t("Pergunte"), UI.DIM))
	# escolhas numa área que rola com o dedo (nunca cortadas)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	_choices = UI.vbox(UI.sp(1, self))
	_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_choices)
	TouchScroll.attach(sc)
	return panel


func _say(text: String, expr: String) -> void:
	_full = text
	_shown = 0.0
	_typing = true
	if _face and _face.has_method("set_expression"):
		_face.set_expression(expr)
	if _face and _face.has_method("set_talking"):
		_face.set_talking(true)


func _process(dt: float) -> void:
	if _typing:
		_shown += dt * 45.0
		var n := int(_shown)
		_speech.text = _full.substr(0, n)
		if n >= _full.length():
			_typing = false
			_speech.text = _full
			if _face and _face.has_method("set_talking"):
				_face.set_talking(false)


func _choice_button(text: String, col: Color, filled := false) -> Button:
	var b := UI.button(text, col) if filled else UI.ghost(text, col)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT if not filled else HORIZONTAL_ALIGNMENT_CENTER
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not filled:
		b.add_theme_font_override("font", UI.font("bold"))
		b.add_theme_font_size_override("font_size", UI.fs("small", self))
		b.add_theme_color_override("font_color", UI.PAPER)
		var r := UI.radius(self) - 6
		var n := UI.box(Color(UI.PANEL_2, 0.9), UI.STROKE, 1, r, UI.sp(1.6, self))
		n.border_width_left = 3
		n.border_color = Color(col, 0.6)
		b.add_theme_stylebox_override("normal", n)
		var hv := UI.box(Color(col, 0.16), col, 1, r, UI.sp(1.6, self))
		hv.border_width_left = 3
		b.add_theme_stylebox_override("hover", hv)
	return b


func _show_choices() -> void:
	for c in _choices.get_children():
		c.queue_free()
	for qa in lines:
		var b := _choice_button(str(qa.get("q", "")), accent)
		b.pressed.connect(_answer.bind(qa))
		_choices.add_child(b)
	if not npc_project.has("special"):
		var open := _choice_button("ABRIR O PROJETO  ↗", accent, true)
		open.pressed.connect(func() -> void:
			open_project.emit()
			_close())
		_choices.add_child(open)
	var bye := _choice_button("Até mais.", UI.MIST)
	bye.pressed.connect(_close)
	_choices.add_child(bye)


func _answer(qa: Dictionary) -> void:
	_say(str(qa.get("a", "")), str(qa.get("expr", "serio")))


func _close() -> void:
	ducking.emit(false)
	closed.emit()
	queue_free()
