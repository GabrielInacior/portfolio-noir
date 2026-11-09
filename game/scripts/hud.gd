extends Control
## INTERFACE POR CIMA DA CIDADE (design system em ui.gd): barra de vidro no topo (nome, progresso e
## ícones: lugares, mapa, som, idioma), radar redondo, retícula, aviso de ação com tecla/ícone,
## placas clicáveis na rua, menu de lugares e mapa grande (viajar sem andar), tour guiado dentro das
## lojas (anterior/próxima peça), alavanca virtual no celular e conversa com os NPCs (realce amarelo).
## Responsivo pelo formato (UI.ff): celular em pé, celular deitado e PC. Fica fora do filtro retrô.

const Dossier := preload("res://scripts/dossier.gd")
const ListMode := preload("res://scripts/list_mode.gd")
const Dialogue := preload("res://scripts/dialogue.gd")
const Museum := preload("res://scripts/museum.gd")
const Exhibit := preload("res://scripts/exhibit.gd")
const Panels := preload("res://scripts/panels.gd")
const PlacesMenu := preload("res://scripts/nav/places_menu.gd")
const HOVER := preload("res://shaders/hover_outline.gdshader")

var _museum = null
var _entry_xform: Transform3D
var _exam: Dictionary = {}

var player
var city
var world_vp: SubViewport
var prompt: PanelContainer
var prompt_label: Label
var _prompt_hint: Label
var _prompt_key: Control
var counter_label: Label
var minimap: MapView
var signs: StreetSigns
var reticle: Control
var stick_base: Control
var stick_knob: Control
var _stick_touch := -1
var _look_touch := -1
var _look_last := Vector2.ZERO
var _look_live := false   # passou da zona morta
var _stick_center := Vector2.ZERO
var _touch_start := {}
var _current: Dictionary = {}
var _sheet_open := false
var _ret_hot := false
var _ret_col := UI.AMBER
var _topbar: Control
var _ff := ""
var _snd_btn: Button
var _tour: Control
var _tour_label: Label
var _tour_i := -1
var _npc_hot = null
var goal: Dictionary = {}       # lugar marcado (seta de HUD na borda até ele)
var _goal_arrow: Control
var _npc_mat: ShaderMaterial


func setup(p, c) -> void:
	player = p
	city = c
	player.target_changed.connect(_on_target)
	player.interacted.connect(_on_interact)
	city.visited_changed.connect(_on_visited)
	var m := get_parent().get_parent() if get_parent() else null
	if m and "_world_vp" in m:
		world_vp = m._world_vp
	_build()
	_on_visited(city.visited_count(), city.total_projects())


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_npc_mat = ShaderMaterial.new()
	_npc_mat.shader = HOVER
	_npc_mat.set_shader_parameter("color", UI.AMBER)
	_npc_mat.set_shader_parameter("width", 0.02)
	get_viewport().size_changed.connect(func() -> void:
		if UI.ff(self) != _ff and player:
			_build.call_deferred())
	set_process_input(true)


## (re)monta tudo pelo formato de tela atual
func _build() -> void:
	_ff = UI.ff(self)
	for n in [_topbar, minimap, signs, prompt, reticle, stick_base, stick_knob, _tour, _goal_arrow]:
		if n and is_instance_valid(n):
			n.queue_free()
	_build_topbar()
	_build_minimap()
	_build_prompt()
	_build_reticle()
	_build_tour()
	_build_goal_arrow()
	if UI.is_touch() or _ff == "phone":
		_build_stick()
	_sync_mode()


# ───────────────────────────────── barra de cima
func _build_topbar() -> void:
	var bar := PanelContainer.new()
	_topbar = bar
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var g := UI.sp(1.6, self)
	bar.offset_left = g
	bar.offset_right = -g
	bar.offset_top = g + UI.safe_top(self)
	var st := UI.glass(Color.TRANSPARENT, UI.radius(self), 0, 0.7)
	st.content_margin_left = UI.sp(2, self)
	st.content_margin_right = UI.sp(1, self)
	st.content_margin_top = UI.sp(1, self)
	st.content_margin_bottom = UI.sp(1, self)
	bar.add_theme_stylebox_override("panel", st)
	var h := UI.hbox(UI.sp(1, self))
	bar.add_child(h)
	var names := UI.vbox(0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(names)
	var nm := UI.text("GABRIEL INÁCIO", "h3", UI.PAPER)
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(nm)
	counter_label = UI.text("", "cap", UI.AMBER)
	counter_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	counter_label.clip_text = true
	counter_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(counter_label)
	var side := int(UI.tap(self) * (0.86 if _ff == "phone" else 0.92))
	var places := UI.icon_btn("places", UI.AMBER, side, "Lugares")
	places.pressed.connect(_open_places)
	h.add_child(places)
	var mp := UI.icon_btn("map", UI.CYAN, side, "Mapa (M)")
	mp.pressed.connect(_open_map)
	h.add_child(mp)
	_snd_btn = UI.icon_btn("sound" if Audio.is_on() else "mute", UI.PINK, side, "Som")
	_snd_btn.pressed.connect(func() -> void:
		var on := not Audio.is_on()
		Audio.set_enabled(on)
		(_snd_btn.get_meta("icon") as Icon).set_icon("sound" if on else "mute"))
	h.add_child(_snd_btn)
	var lang := UI.icon_btn("globe", UI.PAPER, side, "English" if L.lang == "pt" else "Português")
	var tag := UI.label("EN" if L.lang == "pt" else "PT", int(side * 0.22), UI.PAPER, "bold")
	tag.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	tag.offset_left = -side * 0.42
	tag.offset_top = -side * 0.36
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lang.add_child(tag)
	lang.pressed.connect(func() -> void: L.set_lang("en" if L.lang == "pt" else "pt"))
	h.add_child(lang)
	add_child(bar)


func _topbar_bottom() -> float:
	return UI.sp(1.6, self) + UI.safe_top(self) + UI.tap(self) * (0.86 if _ff == "phone" else 0.92) + UI.sp(2, self)


# ───────────────────────────────── radar (minimapa)
func _build_minimap() -> void:
	minimap = MapView.new()
	minimap.radar = true
	minimap.city = city
	minimap.player = player
	var d: float = {"phone": 230.0, "land": 150.0, "desk": 190.0}[_ff]
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.size = Vector2(d, d)
	minimap.position = Vector2(get_viewport_rect().size.x - d - UI.sp(1.6, self), _topbar_bottom())
	minimap.mouse_filter = Control.MOUSE_FILTER_STOP
	minimap.tooltip_text = L.t("Mapa (M)")
	minimap.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
			accept_event()
			_open_map())
	add_child(minimap)


# ───────────────────────────────── placas clicáveis na rua
func _build_signs() -> void:
	signs = StreetSigns.new()
	signs.city = city
	signs.player = player
	signs.world_vp = world_vp
	add_child(signs)
	# regra do usuário: nada flutuando; a orientação vem das placas físicas da rua (city.gd)
	signs.visible = false
	signs.set_process(false)


# ───────────────────────────────── aviso de ação (tecla/ícone + verbo + nome)
func _build_prompt() -> void:
	prompt = PanelContainer.new()
	prompt.mouse_filter = Control.MOUSE_FILTER_STOP
	prompt.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var h := UI.hbox(UI.sp(1.6, self))
	prompt.add_child(h)
	if UI.is_touch() or _ff == "phone":
		_prompt_key = Icon.make("tap", UI.INK, UI.fs("h3", self))
		var holder := PanelContainer.new()
		holder.add_theme_stylebox_override("panel", UI.box(UI.AMBER, UI.AMBER, 0, 999, UI.sp(1, self)))
		holder.add_child(_prompt_key)
		_prompt_key = holder
	else:
		_prompt_key = UI.keycap("E", UI.AMBER)
	_prompt_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_prompt_key)
	var v := UI.vbox(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	_prompt_hint = UI.text("", "small" if _ff == "phone" else "cap", UI.AMBER, "bold")
	_prompt_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_prompt_hint.uppercase = true
	v.add_child(_prompt_hint)
	prompt_label = UI.text("", "h3", UI.PAPER)
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_OFF

	v.add_child(prompt_label)
	prompt.visible = false
	prompt.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
			accept_event()
			_do_interact())
	add_child(prompt)


func _show_prompt(verb: String, name: String, col := UI.AMBER) -> void:
	var maxc := 22 if _ff == "phone" else 34
	if name.length() > maxc:
		name = name.substr(0, maxc - 1) + "…"
	_prompt_hint.text = L.t(verb)
	_prompt_hint.add_theme_color_override("font_color", col)
	prompt_label.text = name
	var st := UI.glass(col, 999, 0, 0.9)
	st.content_margin_left = UI.sp(1.2, self)
	st.content_margin_right = UI.sp(3, self)
	st.content_margin_top = UI.sp(1, self)
	st.content_margin_bottom = UI.sp(1, self)
	prompt.add_theme_stylebox_override("panel", st)
	if not prompt.visible:
		prompt.visible = true
		prompt.modulate.a = 0.0
		prompt.create_tween().tween_property(prompt, "modulate:a", 1.0, 0.14)
	_place_prompt()


func _place_prompt() -> void:
	var vs := get_viewport_rect().size
	prompt.reset_size()
	var ms := prompt.get_combined_minimum_size()
	var w := ms.x
	var bottom := UI.sp(4, self)
	if _tour and _tour.visible and _ff != "phone":
		bottom = UI.sp(3, self) + UI.tap(self) + UI.sp(2, self)
	prompt.size = Vector2(w, ms.y)
	if _ff == "phone":
		# celular: botão grande no canto de baixo à direita (a alavanca fica à esquerda)
		w = maxf(w, vs.x * 0.5)
		prompt.size = Vector2(w, ms.y)
		prompt.position = Vector2(vs.x - w - UI.sp(3, self), vs.y - UI.sp(6, self) - ms.y)
	else:
		prompt.position = Vector2((vs.x - w) / 2.0, vs.y - bottom - ms.y)


func _hide_prompt() -> void:
	prompt.visible = false


# ───────────────────────────────── retícula
func _build_reticle() -> void:
	reticle = Control.new()
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.draw.connect(func() -> void:
		var s := UI.sp(1, self) / 6.0
		if _ret_hot:
			var k := 0.88 + 0.12 * sin(Time.get_ticks_msec() * 0.009)
			for i in 4:
				var a := i * PI / 2 + PI / 4
				reticle.draw_arc(Vector2.ZERO, 15.0 * s * k, a - 0.45, a + 0.45, 8, _ret_col, 2.5 * s, true)
			reticle.draw_circle(Vector2.ZERO, 2.6 * s, _ret_col)
		else:
			reticle.draw_circle(Vector2.ZERO, 2.4 * s, Color(1, 1, 1, 0.6))
			reticle.draw_arc(Vector2.ZERO, 5.0 * s, 0, TAU, 16, Color(0, 0, 0, 0.35), 1.2 * s))
	reticle.visible = not (UI.is_touch() or _ff == "phone")
	add_child(reticle)


# ───────────────────────────────── seta de destino (HUD)
func _build_goal_arrow() -> void:
	_goal_arrow = Control.new()
	_goal_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goal_arrow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_goal_arrow.draw.connect(_draw_goal)
	add_child(_goal_arrow)


func _draw_goal() -> void:
	if goal.is_empty() or _museum != null or _sheet_open or player == null or player.cam == null:
		return
	var pos: Vector3 = goal["pos"]
	var d: float = player.global_position.distance_to(pos)
	if d < 4.0:
		goal = {}
		return
	var vs := get_viewport_rect().size
	var cam: Camera3D = player.cam
	var vp := Vector2(world_vp.size) if world_vp else vs
	var sp := cam.unproject_position(pos + Vector3(0, 2.0, 0)) * (vs / vp)
	var behind := cam.is_position_behind(pos)
	var c := vs / 2.0
	var dir := (sp - c)
	if behind:
		dir = -dir
	var m := UI.sp(5, self)
	var inside := not behind and Rect2(Vector2(m, m + _topbar_bottom()), vs - Vector2(m * 2, m * 2 + _topbar_bottom())).has_point(sp)
	var neon: Color = goal.get("neon", UI.AMBER)
	var f := UI.font("bold")
	var fsz := UI.fs("cap", self) + 2
	var label := "%s · %dm" % [str(goal["title"]).to_upper(), int(d)]
	if inside:
		var k := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.006)
		_goal_arrow.draw_arc(sp, 14.0 * k, 0, TAU, 24, neon, 2.5, true)
		_goal_arrow.draw_circle(sp, 4.0, neon)
		var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		_goal_arrow.draw_string(f, sp + Vector2(-tw / 2.0, -22), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, neon)
		return
	var ang := dir.angle()
	var half := vs / 2.0 - Vector2(m, m)
	var t := minf(absf(half.x / maxf(0.001, absf(cos(ang)))), absf(half.y / maxf(0.001, absf(sin(ang)))))
	var p := c + Vector2(cos(ang), sin(ang)) * t
	p.y = maxf(p.y, _topbar_bottom() + m)
	var a := 18.0 * UI.sp(1, self) / 6.0
	var tri := PackedVector2Array([p + Vector2(cos(ang), sin(ang)) * a, p + Vector2(cos(ang + 2.4), sin(ang + 2.4)) * a * 0.8, p + Vector2(cos(ang - 2.4), sin(ang - 2.4)) * a * 0.8])
	_goal_arrow.draw_colored_polygon(tri, neon)
	var tw2 := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
	var lp := p - Vector2(cos(ang), sin(ang)) * (a + 10.0) - Vector2(tw2 / 2.0, -fsz * 0.35)
	lp.x = clampf(lp.x, m, vs.x - m - tw2)
	_goal_arrow.draw_string(f, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, neon)


# ───────────────────────────────── tour guiado dentro da loja
func _build_tour() -> void:
	_tour = PanelContainer.new()
	var st := UI.glass(Color.TRANSPARENT, 999, 0, 0.82)
	st.content_margin_left = UI.sp(1, self)
	st.content_margin_right = UI.sp(1, self)
	st.content_margin_top = UI.sp(0.8, self)
	st.content_margin_bottom = UI.sp(0.8, self)
	_tour.add_theme_stylebox_override("panel", st)
	var h := UI.hbox(UI.sp(1, self))
	_tour.add_child(h)
	var side := int(UI.tap(self) * 0.9)
	var prev := UI.icon_btn("chev_l", UI.PAPER, side, "Peça anterior")
	prev.pressed.connect(func() -> void: _tour_step(-1))
	h.add_child(prev)
	_tour_label = UI.text("", "small", UI.PAPER, "bold")
	_tour_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_tour_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tour_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tour_label.custom_minimum_size.x = UI.sp(18, self)
	h.add_child(_tour_label)
	var nxt := UI.icon_btn("chev_r", UI.AMBER, side, "Próxima peça")
	nxt.pressed.connect(func() -> void: _tour_step(1))
	h.add_child(nxt)
	var out := UI.icon_btn("door", UI.PINK, side, "Sair para a rua")
	out.pressed.connect(func() -> void:
		if not _sheet_open:
			exit_museum())
	h.add_child(out)
	_tour.visible = false
	add_child(_tour)


func _place_tour() -> void:
	if _tour == null:
		return
	var vs := get_viewport_rect().size
	_tour.reset_size()
	var sz := _tour.get_combined_minimum_size()
	var bottom := UI.sp(3, self) + (UI.safe_top(self) * 0.0)
	_tour.position = Vector2((vs.x - sz.x) / 2.0 if _ff != "phone" else vs.x - sz.x - UI.sp(1.6, self), vs.y - sz.y - bottom - (0.0 if _ff != "phone" else 0.0))
	if _ff == "phone":
		_tour.position = Vector2((vs.x - sz.x) / 2.0, _topbar_bottom())


## leva a câmera até a peça seguinte/anterior e abre o painel dela
func _tour_step(dir: int) -> void:
	if _museum == null or _sheet_open or _museum.items.is_empty():
		return
	var n: int = _museum.items.size()
	_tour_i = (_tour_i + dir + n) % n if _tour_i >= 0 else (0 if dir > 0 else n - 1)
	var e: Dictionary = _museum.items[_tour_i]
	var node: Node3D = e.get("node")
	if node and is_instance_valid(node):
		var target := node.global_position
		var bmin: Vector2 = player.bound_min
		var bmax: Vector2 = player.bound_max
		var center := Vector3((bmin.x + bmax.x) / 2.0, 0, (bmin.y + bmax.y) / 2.0)
		var dirv := (center - Vector3(target.x, 0, target.z)).normalized()
		var stand := Vector3(target.x, 0, target.z) + dirv * 1.7
		stand.x = clampf(stand.x, bmin.x + 0.3, bmax.x - 0.3)
		stand.z = clampf(stand.z, bmin.y + 0.3, bmax.y - 0.3)
		var fade := ColorRect.new()
		fade.color = Color(0, 0, 0, 0)
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(UI.full(fade))
		var tw := create_tween()
		tw.tween_property(fade, "color:a", 0.85, 0.14)
		tw.tween_callback(func() -> void:
			player.global_position = Vector3(stand.x, player.global_position.y, stand.z)
			var to: Vector3 = target - player.global_position
			player._yaw = atan2(-to.x, -to.z)
			player.rotation.y = player._yaw
			player._pitch = clampf(atan2(to.y, Vector2(to.x, to.z).length()), -0.6, 0.5)
			if player.head:
				player.head.rotation.x = player._pitch
			player.sync_look())
		tw.tween_property(fade, "color:a", 0.0, 0.2)
		tw.tween_callback(fade.queue_free)
		await tw.finished
	_update_tour_label()
	_activate(e)


func _update_tour_label() -> void:
	if _museum == null:
		return
	var n: int = _museum.items.size()
	_tour_label.text = L.tf("PEÇA %d DE %d", [maxi(_tour_i + 1, 1), n]) if _tour_i >= 0 else L.tf("TOUR · %d PEÇAS", [n])


# ───────────────────────────────── alavanca (celular)
func _build_stick() -> void:
	var r := 150.0
	stick_base = Control.new()
	stick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stick_base.size = Vector2(r * 2, r * 2)
	stick_base.draw.connect(func() -> void:
		var c := stick_base.size / 2.0
		stick_base.draw_circle(c, r, Color(UI.PANEL, 0.35))
		stick_base.draw_arc(c, r - 1.0, 0, TAU, 64, Color(UI.PAPER, 0.22), 2.0, true)
		for i in 4:
			var a := i * PI / 2
			var p := c + Vector2(cos(a), sin(a)) * (r - 26.0)
			stick_base.draw_colored_polygon(PackedVector2Array([p + Vector2(cos(a), sin(a)) * 9.0, p + Vector2(cos(a + 2.3), sin(a + 2.3)) * 9.0, p + Vector2(cos(a - 2.3), sin(a - 2.3)) * 9.0]), Color(UI.PAPER, 0.35)))
	add_child(stick_base)
	stick_knob = Control.new()
	stick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stick_knob.size = Vector2(124, 124)
	stick_knob.draw.connect(func() -> void:
		var c := stick_knob.size / 2.0
		stick_knob.draw_circle(c, 60.0, Color(UI.AMBER, 0.22))
		stick_knob.draw_circle(c, 46.0, Color(UI.AMBER, 0.9))
		stick_knob.draw_arc(c, 46.0, 0, TAU, 32, UI.INK, 2.0, true))
	add_child(stick_knob)
	_reset_knob()


func _stick_home() -> Vector2:
	var vs := get_viewport_rect().size
	return Vector2(UI.sp(4, self) + 150.0, vs.y - UI.sp(4, self) - 150.0)


func _reset_knob() -> void:
	if stick_base:
		stick_base.position = _stick_home() - stick_base.size / 2.0
	if stick_knob:
		stick_knob.position = _stick_home() - stick_knob.size / 2.0


# ───────────────────────────────── modo (rua x loja)
func _sync_mode() -> void:
	var in_shop := _museum != null
	if minimap:
		minimap.visible = not in_shop
	if signs:
		signs.visible = false  # placas físicas na rua (city.gd); nada flutuante
	if _tour:
		_tour.visible = in_shop
		_update_tour_label()
		_place_tour()
	if in_shop:
		counter_label.text = L.tf("%s · %d/%d examinados", [L.t(str(_museum.project.get("title", ""))).to_upper(), _museum_seen(), _museum.items.size()])
	elif city:
		counter_label.text = L.tf("%d/%d projetos explorados", [city.visited_count(), city.total_projects()])


func _museum_seen() -> int:
	var c := 0
	if _museum:
		for e in _museum.items:
			if e.get("seen", false):
				c += 1
	return c


func _on_target(project: Dictionary) -> void:
	_current = project


func _on_visited(count: int, total: int) -> void:
	if counter_label and _museum == null:
		counter_label.text = L.tf("%d/%d projetos explorados", [count, total])


# ───────────────────────────────── entrada (toques, cliques)
func _input(e: InputEvent) -> void:
	if _sheet_open:
		return
	# clique com o mouse preso enquanto mira um letreiro/porta, NPC ou peça = interagir (E também)
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _ret_hot:
		get_viewport().set_input_as_handled()
		_do_interact()
		return
	if not (UI.is_touch() or _ff == "phone"):
		return
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			_touch_start[t.index] = t.position
			if t.position.x < size.x * 0.45 and _stick_touch == -1 and t.position.y > size.y * 0.45:
				_stick_touch = t.index
				_stick_center = t.position
				if stick_base:
					stick_base.position = t.position - stick_base.size / 2.0
			elif _look_touch == -1 and t.position.y > _topbar_bottom() and t.index != _stick_touch 					and (t.position.x >= size.x * 0.4 or _stick_touch != -1 and t.position.distance_to(_stick_center) > 220.0):
				# olhar só com o dedo que NÃO está na alavanca, e (sem alavanca ativa) só na parte direita
				_look_touch = t.index
				_look_last = t.position
				_look_live = false
		else:
			var st: Vector2 = _touch_start.get(t.index, t.position)
			var was_tap := st.distance_to(t.position) < 18.0
			if t.index == _stick_touch:
				_stick_touch = -1
				player.move_vec = Vector2.ZERO
				_reset_knob()
			elif t.index == _look_touch:
				_look_touch = -1
				if was_tap:
					_tap_world(t.position)
			_touch_start.erase(t.index)
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		if d.index == _stick_touch:
			var off := (d.position - _stick_center).limit_length(110)
			player.move_vec = Vector2(off.x, off.y) / 110.0
			if stick_knob:
				stick_knob.position = _stick_center + off - stick_knob.size / 2.0
		elif d.index == _look_touch:
			# delta calculado pela posição deste dedo (o relative do navegador às vezes salta entre dedos)
			var st: Vector2 = _touch_start.get(d.index, d.position)
			if not _look_live:
				if st.distance_to(d.position) < 10.0:
					return
				_look_live = true
				_look_last = d.position
				return
			var dl := (d.position - _look_last).limit_length(48.0)
			_look_last = d.position
			# um arrasto da largura da tela gira ~120° (x sensibilidade escolhida); curva suave
			var w := maxf(size.x, 1.0)
			var v := dl / w
			var accel := 1.0 + clampf(v.length() * 6.0, 0.0, 0.6)
			player.look_rad += Vector2(v.x * 2.1, v.y * 1.5) * accel * UI.look_sens()


## toque curto no mundo: placa, NPC ou objeto mirado
func _tap_world(pos: Vector2) -> void:
	if prompt.visible and prompt.get_global_rect().has_point(pos):
		return
	if _npc_hot != null or not _current.is_empty() or not _exam.is_empty():
		_do_interact()


func _unhandled_input(e: InputEvent) -> void:
	if _sheet_open:
		return
	if e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo:
		var k := (e as InputEventKey).keycode
		if k == KEY_M:
			get_viewport().set_input_as_handled()
			_open_map()
			return
		if k == KEY_TAB or k == KEY_L:
			get_viewport().set_input_as_handled()
			_open_places()
			return
		if _museum != null and (k == KEY_PERIOD or k == KEY_BRACKETRIGHT):
			_tour_step(1)
			return
		if _museum != null and (k == KEY_COMMA or k == KEY_BRACKETLEFT):
			_tour_step(-1)
			return
	# conversar com o NPC mirado tem prioridade sobre a loja (o jogador não recebe o E)
	if e.is_action_pressed("interact") and _npc_hot != null and _museum == null:
		get_viewport().set_input_as_handled()
		_open_dialogue(_npc_hot)


func _do_interact() -> void:
	if _npc_hot != null and _museum == null:
		_open_dialogue(_npc_hot)
		return
	if _museum != null:
		_on_interact({})
		return
	if not _current.is_empty():
		_on_interact(_current)


func _on_interact(project: Dictionary) -> void:
	if _sheet_open:
		return
	if _npc_hot != null and _museum == null and project.is_empty():
		_open_dialogue(_npc_hot)
		return
	# dentro de uma loja-museu: examinar o item mirado ou sair pela porta
	if _museum != null:
		if _museum.at_exit(player.global_position) and _exam.is_empty():
			exit_museum()
		elif not _exam.is_empty():
			_activate(_exam)
		return
	if project.is_empty():
		return
	if project.get("special", "") == "contact":
		open_dossier(project)
		return
	enter_museum(project)


# ───────────────────────────────── navegação rápida
func _open_places() -> void:
	if _sheet_open:
		return
	_modal_open()
	var pm := PlacesMenu.new()
	add_child(UI.full(pm))
	pm.open(city)
	pm.go.connect(func(pl: Dictionary) -> void:
		_sheet_open = false
		Nav.travel(self, pl))
	pm.closed.connect(_modal_closed)


func _open_map() -> void:
	if _sheet_open:
		return
	_modal_open()
	var sh := Sheet.new()
	add_child(UI.full(sh))
	sh.setup(L.t("Mapa do bairro"), L.t("Toque num lugar para ir até lá"), UI.CYAN, 1180.0)
	var mv := MapView.new()
	mv.radar = false
	mv.city = city
	mv.player = player
	var vs := get_viewport_rect().size
	mv.custom_minimum_size = Vector2(0, maxf(sh.panel.custom_minimum_size.y - UI.tap(self) * 3.2, 280.0))
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.body.add_child(mv)
	mv.pick.connect(func(pl: Dictionary) -> void:
		sh.close()
		_sheet_open = false
		Nav.travel(self, pl))
	# legenda
	var leg := HFlowContainer.new()
	leg.add_theme_constant_override("h_separation", UI.sp(2, self))
	leg.add_theme_constant_override("v_separation", UI.sp(0.8, self))
	for spec in [["play", "Jogos", UI.AMBER], ["places", "Software", UI.CYAN], ["eye", "Segurança", UI.GREEN], ["star", "LAB · sobre mim", UI.PAPER], ["compass", "Carreira", UI.VIOLET], ["pin", "Contato", UI.GREEN]]:
		var it := UI.hbox(UI.sp(0.6, self))
		it.add_child(Icon.make(spec[0], spec[2], UI.fs("small", self)))
		var lt := UI.text(spec[1], "cap", UI.MIST)
		lt.autowrap_mode = TextServer.AUTOWRAP_OFF
		it.add_child(lt)
		leg.add_child(it)
	var me := UI.hbox(UI.sp(0.6, self))
	me.add_child(Icon.make("compass", UI.CYAN, UI.fs("small", self)))
	var ml := UI.text("Você", "cap", UI.CYAN)
	ml.autowrap_mode = TextServer.AUTOWRAP_OFF
	me.add_child(ml)
	leg.add_child(me)
	sh.footer.add_child(leg)
	sh.closed.connect(_modal_closed)


func _modal_open() -> void:
	_sheet_open = true
	add_to_group("pf_modal")  # a passada nítida some atrás do modal (sem "fantasma")
	_hide_prompt()
	if signs:
		signs.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player:
		player.move_vec = Vector2.ZERO


func _modal_closed() -> void:
	_sheet_open = false
	remove_from_group("pf_modal")
	_sync_mode()
	if not (UI.is_touch() or _ff == "phone"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ───────────────────────────────── entrar e sair da loja-museu
var _veil: ColorRect
var _entering := false


## véu preto: esconde o trabalho pesado de montar a sala (antes a tela congelava por 100 a 500 ms ao abrir a porta)
func _veil_in() -> void:
	if _veil == null:
		_veil = ColorRect.new()
		_veil.color = Color(0.02, 0.02, 0.05, 0.0)
		_veil.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(UI.full(_veil))
		var vl := Label.new()
		vl.text = "ENTERING..." if L.lang == "en" else "ENTRANDO..."
		vl.add_theme_font_size_override("font_size", 22)
		vl.add_theme_color_override("font_color", Color(1, 0.78, 0.24))
		vl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		vl.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_veil.add_child(vl)
	move_child(_veil, get_child_count() - 1)
	_veil.visible = true
	var tw := create_tween()
	tw.tween_property(_veil, "color:a", 1.0, 0.16)
	await tw.finished
	await get_tree().process_frame
	await get_tree().process_frame


func _veil_out() -> void:
	# quadros extras com a sala já montada por baixo do véu: os shaders novos compilam escondidos
	for _i in 3:
		await get_tree().process_frame
	var tw := create_tween()
	tw.tween_property(_veil, "color:a", 0.0, 0.3)
	await tw.finished
	_veil.visible = false


func enter_museum(project: Dictionary) -> void:
	if _entering:
		return
	if not Packs.ready_pack("shops"):
		# as lojas chegam em segundo plano; em rede lenta o jogador espera aqui
		if prompt_label:
			prompt.visible = true
			prompt_label.text = "Loading the shop..." if L.lang == "en" else "Carregando a loja..."
		await Packs.need("shops")
	var id := "_lab" if project.get("special", "") == "about" else ("_carreira" if project.get("special", "") == "career" else str(project.get("id", "")))
	var path := "res://assets/museum/_items/%s.json" % id
	if not FileAccess.file_exists(path):
		open_dossier(project)
		return
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_entering = true
	await _veil_in()
	if city:
		city.mark_visited(project)
	_set_npc_hot(null)
	_entry_xform = player.global_transform
	city.visible = false
	city.set_process(false)
	city.set_physics_process(false)
	_museum = Museum.new()
	_museum.setup(project if project.get("special", "") != "career" else {"id": "_carreira", "title": "CARREIRA", "special": "career"}, d, project.get("special", "") == "about")
	city.get_parent().add_child(_museum)
	if UI.software():
		for l in _museum.find_children("*", "Light3D", true, false):
			(l as Light3D).visible = false
	player.get_parent().remove_child(player)
	_museum.add_child(player)
	player.global_position = _museum.spawn_pos()
	# de costas para a porta, olhando o centro da sala, câmera nivelada
	player._yaw = 0.0
	player.rotation.y = 0.0
	player._pitch = 0.0
	player.sync_look()
	player.set_meta("walk", player.walk_rects)
	player.walk_rects = []
	var br: Rect2 = _museum.bounds()
	player.bound_min = br.position
	player.bound_max = br.end
	_museum.examined.connect(func(_c: int, _t: int) -> void: _sync_mode())
	_tour_i = -1
	_hide_prompt()
	_sync_mode()
	UI.toast(self, L.t("Use as setas da barra para o tour guiado"), _museum._accent)
	await _veil_out()
	_entering = false


func exit_museum() -> void:
	if _museum == null:
		return
	player.get_parent().remove_child(player)
	city.add_child(player)
	player.global_transform = _entry_xform
	player._yaw = player.rotation.y
	player.sync_look()
	player.walk_rects = player.get_meta("walk", [])
	_museum.queue_free()
	_museum = null
	_exam = {}
	_tour_i = -1
	city.visible = true
	city.set_process(true)
	city.set_physics_process(true)
	_hide_prompt()
	_ret_hot = false
	_sync_mode()
	_suggest_next()


## ao sair de uma loja, a seta de HUD sugere o próximo projeto ainda não visitado (o mais perto)
func _suggest_next() -> void:
	goal = {}
	var best := 1e9
	for pl in Nav.places(city):
		if pl["visited"] or str((pl["project"] as Dictionary).get("special", "")) != "":
			continue
		var d: float = player.global_position.distance_to(pl["pos"])
		if d < best:
			best = d
			goal = pl


func _activate(entry: Dictionary) -> void:
	var it: Dictionary = entry["item"]
	var action := str(it.get("action", ""))
	if Audio.has_method("on_action"):
		Audio.call("on_action", action if action != "" else str(it.get("panel", "doc")), it)
	match action:
		"switch":
			var on: bool = _museum.toggle_lights()
			var tog = it.get("toggle")
			if tog and is_instance_valid(tog):
				(tog as Node3D).position.y = 0.02 if on else -0.02
			_museum.mark_seen(entry)
			return
		"phone":
			if entry.has("ring"):
				entry["ring"]["on"] = false
		"drawer":
			var dr = it.get("drawer")
			if dr and is_instance_valid(dr):
				var tw := create_tween()
				tw.tween_property(dr, "position:z", 0.6, 0.35).set_trans(Tween.TRANS_BACK)
	var panel := str(it.get("panel", ""))
	_museum.mark_seen(entry)
	_modal_open()
	if panel == "" or panel == "exhibit":
		var ex := Exhibit.new()
		ex.setup(it, _museum._accent, _museum.project)
		ex.closed.connect(_modal_closed)
		add_child(UI.full(ex))
		return
	var p := Panels.new()
	p.setup(panel, it, _museum._accent, _museum.project)
	p.closed.connect(func() -> void:
		var dr2 = it.get("drawer")
		if dr2 and is_instance_valid(dr2):
			create_tween().tween_property(dr2, "position:z", 0.24, 0.3)
		_modal_closed())
	add_child(UI.full(p))


func _open_exhibit(entry: Dictionary) -> void:
	_museum.mark_seen(entry)
	_modal_open()
	var ex := Exhibit.new()
	ex.setup(entry["item"], _museum._accent, _museum.project)
	ex.closed.connect(_modal_closed)
	add_child(UI.full(ex))


# ───────────────────────────────── quadro a quadro: alvo atual e realces
func _process(_dt: float) -> void:
	if reticle:
		reticle.queue_redraw()
	if _goal_arrow:
		_goal_arrow.queue_redraw()
	if stick_base:
		stick_base.queue_redraw()
	if _sheet_open or player == null:
		return
	if _museum != null:
		for e in _museum.items:
			e["_hot"] = false
		_exam = _museum.nearest(player.global_position, player.forward())
		_museum.set_hot(_exam)
		_ret_hot = not _exam.is_empty()
		if not _exam.is_empty():
			_exam["_hot"] = true
			var it: Dictionary = _exam["item"]
			_ret_col = _museum._accent
			var verb := L.t(str(it.get("verb", "EXAMINAR")))
			_show_prompt(verb, L.tx(it, "title").to_upper(), _museum._accent)
		elif _museum.at_exit(player.global_position):
			_ret_col = UI.PINK
			_show_prompt("sair", L.t("PARA A RUA"), UI.PINK)
		else:
			_hide_prompt()
		return
	# rua: NPC mirado (realce amarelo) tem prioridade; senão a loja à frente
	var npc = _aimed_npc()
	_set_npc_hot(npc)
	if npc != null:
		_ret_hot = true
		_ret_col = UI.AMBER
		var nm: String = "O GUIA" if npc.project.get("special", "") == "about" else str(npc.project.get("title", "GUIA")).to_upper()
		_show_prompt("conversar", L.t(nm) + "  ·  " + L.t(str(npc.role)), UI.AMBER)
	elif not _current.is_empty():
		_ret_hot = true
		var neon := Color(str(_current.get("neon", "#ffc83d")))
		_ret_col = neon
		var verb := "abrir" if _current.get("special", "") == "contact" else "entrar"
		_show_prompt(verb, L.t(str(_current.get("title", ""))).to_upper(), neon)
	else:
		_ret_hot = false
		_hide_prompt()


## NPC conversável à frente (até 3,4 m, dentro de um cone de ~45°); figurantes não contam
func _aimed_npc():
	if city == null or not ("npcs" in city):
		return null
	var best = null
	var bs := 0.0
	var fw: Vector3 = player.forward()
	fw.y = 0
	fw = fw.normalized()
	for n in city.npcs:
		if not is_instance_valid(n):
			continue
		var to: Vector3 = n.global_position - player.global_position
		to.y = 0
		var d := to.length()
		if d > 3.4 or d < 0.2:
			continue
		var dot := fw.dot(to / d)
		if dot < 0.7:
			continue
		var score := dot - d * 0.1
		if score > bs:
			bs = score
			best = n
	return best


## contorno amarelo pulsando no NPC mirado (sobreposição na malha, compatível com o esqueleto)
func _set_npc_hot(npc) -> void:
	if npc == _npc_hot:
		return
	if _npc_hot != null and is_instance_valid(_npc_hot):
		for mi in _npc_hot.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = null
	_npc_hot = npc
	if npc != null:
		for mi in npc.find_children("*", "MeshInstance3D", true, false):
			if mi is Label3D:
				continue
			(mi as MeshInstance3D).material_overlay = _npc_mat


# ───────────────────────────────── conversas, dossiês, lista
func _open_dialogue(npc) -> void:
	if _sheet_open:
		return
	_modal_open()
	var d := Dialogue.new()
	var acc := Color(str(npc.project.get("neon", "#ffc83d")))
	var nm := "O GUIA" if npc.project.get("special", "") == "about" else str(npc.project.get("title", "GUIA")).to_upper()
	d.setup(nm, npc.role, acc, npc.greet, npc.lines, npc.project)
	d.ducking.connect(func(a: bool) -> void: Audio.duck(a))
	d.open_project.connect(func() -> void:
		open_dossier(npc.project))
	d.closed.connect(_modal_closed)
	add_child(UI.full(d))


func open_dossier(project: Dictionary) -> void:
	if project.is_empty():
		return
	_modal_open()
	if city:
		city.mark_visited(project)
	var sp := str(project.get("special", ""))
	var d := Dossier.new()
	add_child(UI.full(d))
	d.closed.connect(_modal_closed)
	if sp == "about":
		d.setup_about(Data.profile)
	elif sp == "contact":
		d.setup_contact(Data.profile)
	else:
		d.setup_project(project)


func _open_list() -> void:
	_open_places()
