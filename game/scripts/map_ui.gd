class_name MapView
extends Control
## MAPA NOIR desenhado: quadras escuras, ruas com calçada e faixa âmbar tracejada, nomes das ruas,
## praça com árvores, lojas como ícones na cor do neon (visitadas com selo), jogador como seta com cone
## de visão. Dois modos:
##  - radar (minimapa redondo no canto, norte para cima, centrado no jogador);
##  - grande (o bairro inteiro, com legenda; tocar num lugar viaja até ele).

signal pick(place: Dictionary)

var city
var player
var radar := true
var _bounds := Rect2(-72, -78, 128, 92)   # x, z do bairro
var _places: Array = []
var _hover := -1
const RADAR_M := 64.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if not radar else Control.MOUSE_FILTER_PASS
	clip_contents = true
	_places = Nav.places(city)


func _process(_dt: float) -> void:
	queue_redraw()


## mapa grande em tela em pé: gira 90° para o bairro (mais largo que fundo) ocupar a altura
func _rot() -> bool:
	return not radar and size.y > size.x * 1.1


func _bsize() -> Vector2:
	return Vector2(_bounds.size.y, _bounds.size.x) if _rot() else _bounds.size


func _scale() -> float:
	if radar:
		return minf(size.x, size.y) / RADAR_M
	var pad := 18.0
	var b := _bsize()
	return minf((size.x - pad * 2) / b.x, (size.y - pad * 2) / b.y)


func to_map(x: float, z: float) -> Vector2:
	var s := _scale()
	if radar and player:
		var pp: Vector3 = player.global_position
		return size / 2.0 + Vector2(x - pp.x, z - pp.z) * s
	var off := (size - _bsize() * s) / 2.0
	var lx := x - _bounds.position.x
	var lz := z - _bounds.position.y
	if _rot():
		return off + Vector2(_bounds.size.y - lz, lx) * s
	return off + Vector2(lx, lz) * s


func _draw() -> void:
	var s := _scale()
	var r := Rect2(Vector2.ZERO, size)
	if radar:
		var c := size / 2.0
		var rad := minf(size.x, size.y) / 2.0
		draw_circle(c, rad, Color("#070a14", 0.92))
	else:
		draw_rect(r, Color("#070a14"))
		# grade fina de papel de mapa
		var step := 8.0 * s
		var x := fmod(to_map(0, 0).x, step)
		while x < size.x:
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1, 1, 1, 0.025), 1.0)
			x += step
		var y := fmod(to_map(0, 0).y, step)
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.025), 1.0)
			y += step
	if city == null:
		return
	# quadras (área do bairro) e ruas
	var ba := to_map(_bounds.position.x, _bounds.position.y)
	var bb := to_map(_bounds.end.x, _bounds.end.y)
	draw_rect(Rect2(ba, bb - ba).abs(), Color("#121a30"))
	for rr in city.map_rects:
		var q: Rect2 = rr
		var a := to_map(q.position.x, q.position.y)
		var b := to_map(q.end.x, q.end.y)
		var rect := Rect2(a, b - a).abs()
		draw_rect(rect.grow(2.0), Color("#3a4468"))          # calçada
		draw_rect(rect, Color("#232b47"))                     # asfalto
	# faixa central tracejada da avenida e da transversal
	draw_dashed_line(to_map(0, 8), to_map(0, -72), Color(UI.AMBER, 0.65), maxf(1.0, s * 0.18), maxf(3.0, s * 1.2))
	draw_dashed_line(to_map(-48, -42), to_map(48, -42), Color(UI.AMBER, 0.65), maxf(1.0, s * 0.18), maxf(3.0, s * 1.2))
	# praça: árvores
	for t in [Vector2(-62, -50), Vector2(-52, -50), Vector2(-62, -34), Vector2(-52, -34), Vector2(-57, -42)]:
		draw_circle(to_map(t.x, t.y), maxf(2.0, s * 1.4), Color("#1f6b55", 0.8))
	# nomes das ruas
	var f := UI.font("bold")
	var nfs := int(clampf(s * 2.6, 9, 22)) if not radar else int(clampf(s * 3.2, 8, 14))
	for st in Nav.STREETS:
		var p := to_map(float(st[1]), float(st[2]))
		if radar and not r.grow(-6).has_point(p):
			continue
		draw_set_transform(p, float(st[3]) + (PI / 2 if _rot() else 0.0))
		var w := f.get_string_size(L.t(str(st[0])), HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
		draw_string(f, Vector2(-w / 2.0, nfs * 0.35), L.t(str(st[0])), HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color(UI.MIST, 0.95))
		draw_set_transform(Vector2.ZERO)
	# lugares
	_places = Nav.places(city) if _places.size() != city.kiosks.size() else _refresh_visited()
	var used: Array = []
	var ifs := int(clampf(s * 2.4, 10, 20))
	for i in _places.size():
		var pl: Dictionary = _places[i]
		var pos: Vector3 = pl["pos"]
		var p := to_map(pos.x, pos.z)
		if radar and p.distance_to(size / 2.0) > minf(size.x, size.y) / 2.0 - 8.0:
			continue
		var neon: Color = pl["neon"]
		var rad := maxf(7.0, s * (1.6 if radar else 2.2))
		if i == _hover:
			draw_circle(p, rad * 1.9, Color(neon, 0.22))
		draw_circle(p, rad + 2.0, Color("#05070d"))
		draw_circle(p, rad, Color(neon, 0.95 if pl["visited"] else 0.75))
		_icon_at(str(pl["icon"]), p, rad * 1.1, Color("#05070d"))
		if pl["visited"] and not radar:
			draw_circle(p + Vector2(rad * 0.8, -rad * 0.8), rad * 0.42, UI.GREEN)
		# rótulo (só no mapa grande, sem sobrepor)
		if not radar:
			var name: String = str(pl["title"]).to_upper()
			var tw := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, ifs).x
			var lp := p + Vector2(rad + 6, ifs * 0.35)
			var box := Rect2(lp + Vector2(-3, -ifs), Vector2(tw + 6, ifs + 6))
			for u in used:
				if (u as Rect2).intersects(box):
					lp.y += ifs + 6
					box.position.y += ifs + 6
			if box.end.x > size.x - 4:
				lp.x = p.x - rad - 6 - tw
				box.position.x = lp.x - 3
			used.append(box)
			draw_rect(box, Color("#05070d", 0.78))
			draw_string(f, lp, name, HORIZONTAL_ALIGNMENT_LEFT, -1, ifs, neon.lightened(0.2) if i == _hover else UI.PAPER)
	# jogador: cone de visão + seta
	if player:
		var pp: Vector3 = player.global_position
		var p := to_map(pp.x, pp.z)
		var fw: Vector3 = player.forward()
		var ahead := to_map(pp.x + fw.x * 4.0, pp.z + fw.z * 4.0) - p
		var ang := atan2(ahead.y, ahead.x)
		var cl := maxf(26.0, s * 9.0)
		var cone := PackedVector2Array([p, p + Vector2(cos(ang - 0.5), sin(ang - 0.5)) * cl, p + Vector2(cos(ang + 0.5), sin(ang + 0.5)) * cl])
		draw_colored_polygon(cone, Color(UI.CYAN, 0.16))
		var tip := maxf(9.0, s * 2.2)
		var arrow := PackedVector2Array([p + Vector2(cos(ang), sin(ang)) * tip, p + Vector2(cos(ang + 2.5), sin(ang + 2.5)) * tip * 0.75,
			p + Vector2(cos(ang + PI), sin(ang + PI)) * tip * 0.25, p + Vector2(cos(ang - 2.5), sin(ang - 2.5)) * tip * 0.75])
		draw_colored_polygon(arrow, UI.CYAN)
		draw_polyline(arrow + PackedVector2Array([arrow[0]]), Color("#05070d"), 1.5, true)
	if radar:
		var c := size / 2.0
		var rad := minf(size.x, size.y) / 2.0
		draw_arc(c, rad - 1.0, 0, TAU, 64, UI.STROKE.lightened(0.4), 2.0, true)
		draw_string(f, c + Vector2(-5, -rad + 16), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.AMBER)


func _refresh_visited() -> Array:
	for i in _places.size():
		for k in city.kiosks:
			if k["project"] == _places[i]["project"]:
				_places[i]["visited"] = k.get("visited", false)
	return _places


## ícone mínimo dentro do marcador (traços desenhados direto no mapa)
func _icon_at(name: String, p: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.4, s * 0.16)
	match name:
		"play":
			draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.3, -s * 0.4), p + Vector2(s * 0.45, 0), p + Vector2(-s * 0.3, s * 0.4)]), col)
		"star":
			draw_circle(p, s * 0.28, col)
		"compass":
			draw_line(p + Vector2(0, -s * 0.45), p + Vector2(0, s * 0.45), col, w)
			draw_line(p + Vector2(-s * 0.45, 0), p + Vector2(s * 0.45, 0), col, w)
		"pin":
			draw_circle(p + Vector2(0, -s * 0.1), s * 0.26, col)
		"eye":
			draw_arc(p, s * 0.3, 0, TAU, 12, col, w)
		_:
			draw_rect(Rect2(p - Vector2(s, s) * 0.26, Vector2(s, s) * 0.52), col)


func _place_at(pos: Vector2) -> int:
	var s := _scale()
	var best := -1
	var bd := maxf(28.0, s * 4.0)
	for i in _places.size():
		var pp: Vector3 = _places[i]["pos"]
		var d := to_map(pp.x, pp.z).distance_to(pos)
		if d < bd:
			bd = d
			best = i
	return best


func _gui_input(e: InputEvent) -> void:
	if radar:
		return
	if e is InputEventMouseMotion:
		_hover = _place_at((e as InputEventMouseMotion).position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _hover >= 0 else Control.CURSOR_ARROW
	elif (e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
		var pos: Vector2 = e.position
		var i := _place_at(pos)
		if i >= 0:
			accept_event()
			pick.emit(_places[i])
