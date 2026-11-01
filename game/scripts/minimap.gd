extends Control
## Minimapa noir legível: quadras escuras, ruas claras (avenida, transversal, beco, praça), lojas como
## pontos de neon com o nome (apagados até visitar, acesos depois) e o jogador como seta.
## Mapa com o norte fixo; leve, desenhado em _draw.

var city
var player
var _bounds := Rect2(-70, -76, 122, 88)   # x, z do bairro


func _process(_dt: float) -> void:
	queue_redraw()


func _to_map(x: float, z: float) -> Vector2:
	var pad := 8.0
	var area := size - Vector2(pad * 2, pad * 2)
	var s := minf(area.x / _bounds.size.x, area.y / _bounds.size.y)
	var off := Vector2(pad, pad) + (area - _bounds.size * s) / 2.0
	return off + Vector2(x - _bounds.position.x, (_bounds.end.y - z)) * s * Vector2(1, 1) - Vector2(0, 0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0a0c18", 0.88))
	if city == null:
		return
	# ruas
	for r in city.map_rects:
		var rr: Rect2 = r
		var a := _to_map(rr.position.x, rr.end.y)
		var b := _to_map(rr.end.x, rr.position.y)
		draw_rect(Rect2(a, b - a).abs(), Color("#5a6286"))
	# avenida com faixa central amarela tracejada
	var t0 := _to_map(0, 8)
	var t1 := _to_map(0, -72)
	draw_dashed_line(t0, t1, Color("#c9a640", 0.8), 1.2, 4.0)
	# lojas
	var f := UI.font("title")
	for k in city.kiosks:
		var kp: Vector3 = k["pos"]
		var p := _to_map(kp.x, kp.z)
		var neon: Color = k.get("neon", UI.AMBER)
		var vis: bool = k.get("visited", false)
		draw_circle(p, 5.0, neon if vis else Color(neon, 0.55))
		draw_arc(p, 7.5, 0, TAU, 18, Color(neon, 0.9 if vis else 0.35), 1.5)
		var nm := str(k["project"].get("title", "")).to_upper()
		if nm.length() > 12:
			nm = nm.substr(0, 11) + "."
		draw_string(f, p + Vector2(8, 4), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(UI.PAPER, 0.9 if vis else 0.6))
	if player:
		var pp: Vector2 = _to_map(player.global_position.x, player.global_position.z)
		var dir := Vector2(-sin(player._yaw), -cos(player._yaw))
		var a := pp + dir * 10
		var b := pp - dir.rotated(0.65) * 7
		var c := pp - dir.rotated(-0.65) * 7
		draw_colored_polygon(PackedVector2Array([a, b, c]), Color("#ffffff"))
		draw_polyline(PackedVector2Array([a, b, c, a]), Color("#ffc83d"), 1.5)
	draw_rect(Rect2(Vector2.ZERO, size), Color(UI.AMBER, 0.6), false, 2.0)
