extends Control
## Minimapa noir legível. Pequeno: radar centrado no jogador (norte para cima), ruas claras, lojas como
## pontos de neon e o NOME só das lojas próximas. Tocar nele (ou apertar M) abre o MAPA GRANDE do
## bairro inteiro com todos os nomes, sem sobreposição. Desenhado em _draw (leve).

var city
var player
var big := false
var _bounds := Rect2(-70, -76, 122, 88)   # x, z do bairro
var _small_rect := Rect2()
const RADAR_M := 70.0                    # metros visíveis no radar


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
			toggle_big())


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and (e as InputEventKey).pressed and (e as InputEventKey).keycode == KEY_M:
		toggle_big()


func toggle_big() -> void:
	big = not big
	if big:
		_small_rect = Rect2(position, size)
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var m := 24.0
		offset_left = m
		offset_top = m + 70
		offset_right = -m
		offset_bottom = -m
	else:
		set_anchors_preset(Control.PRESET_TOP_RIGHT)
		position = _small_rect.position
		size = _small_rect.size


func _process(_dt: float) -> void:
	queue_redraw()


func _to_map(x: float, z: float) -> Vector2:
	if not big and player:
		var s := size.x / RADAR_M
		var pp: Vector3 = player.global_position
		return size / 2.0 + Vector2(x - pp.x, z - pp.z) * s
	var pad := 16.0
	var area := size - Vector2(pad * 2, pad * 2)
	var s2 := minf(area.x / _bounds.size.x, area.y / _bounds.size.y)
	var off := Vector2(pad, pad) + (area - _bounds.size * s2) / 2.0
	return off + Vector2(x - _bounds.position.x, z - _bounds.position.y) * s2


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#080a14", 0.92 if big else 0.85))
	if city == null:
		return
	for r in city.map_rects:
		var rr: Rect2 = r
		var a := _to_map(rr.position.x, rr.position.y)
		var b := _to_map(rr.end.x, rr.end.y)
		draw_rect(Rect2(a, b - a).abs(), Color("#5a6286"))
	draw_dashed_line(_to_map(0, 8), _to_map(0, -72), Color("#c9a640", 0.8), 1.2, 4.0)
	var f := UI.font("title")
	var fs := 22 if big else 13
	var used: Array = []
	var pp3: Vector3 = player.global_position if player else Vector3.ZERO
	for k in city.kiosks:
		var kp: Vector3 = k["pos"]
		var p := _to_map(kp.x, kp.z)
		if not big and not Rect2(Vector2.ZERO, size).grow(-4).has_point(p):
			continue
		var neon: Color = k.get("neon", UI.AMBER)
		var vis: bool = k.get("visited", false)
		draw_circle(p, 7.0 if big else 5.0, neon if vis else Color(neon, 0.6))
		draw_arc(p, 10.0 if big else 7.5, 0, TAU, 18, Color(neon, 0.95 if vis else 0.4), 1.5)
		var show_name := big or kp.distance_to(pp3) < 16.0
		if not show_name:
			continue
		var nm := str(k["project"].get("title", "")).to_upper()
		var sz := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var at := p + Vector2(12, fs * 0.35)
		var rect := Rect2(at - Vector2(0, sz.y * 0.8), sz)
		# empurra para baixo até não sobrepor outro nome
		for _i in 6:
			var hit := false
			for u in used:
				if (u as Rect2).intersects(rect):
					hit = true
			if not hit:
				break
			rect.position.y += sz.y * 0.9
			at.y += sz.y * 0.9
		used.append(rect)
		draw_rect(rect.grow(2), Color(0, 0, 0, 0.55))
		draw_string(f, at, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UI.PAPER, 1.0 if vis else 0.8))
	if player:
		var pp: Vector2 = _to_map(pp3.x, pp3.z)
		var dir := Vector2(-sin(player._yaw), -cos(player._yaw))
		var k := 1.6 if big else 1.0
		var a := pp + dir * 11 * k
		var b := pp - dir.rotated(0.65) * 7 * k
		var c := pp - dir.rotated(-0.65) * 7 * k
		draw_colored_polygon(PackedVector2Array([a, b, c]), Color("#ffffff"))
		draw_polyline(PackedVector2Array([a, b, c, a]), Color("#ffc83d"), 1.5)
	if big:
		draw_string(f, Vector2(18, 34), "MAPA DO BAIRRO  ·  toque para fechar", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UI.AMBER)
	draw_rect(Rect2(Vector2.ZERO, size), Color(UI.AMBER, 0.6), false, 2.0)
