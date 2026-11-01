extends Control
## Minimapa noir: a rua vista de cima, os projetos como pontos de neon (apagados até visitar,
## acesos depois) e o jogador como uma seta. Leve, desenhado em _draw.

var city
var player


func _process(_dt: float) -> void:
	queue_redraw()


func _world_to_map(w: Vector3) -> Vector2:
	# rua vai de x[-5,5], z[2,-64]; mapeia para o retângulo
	var u := (w.x + 5.0) / 10.0
	var v := (2.0 - w.z) / 66.0
	return Vector2(u, v) * size


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(UI.INK, 0.72))
	draw_rect(Rect2(Vector2.ZERO, size), Color(UI.AMBER, 0.5), false, 2.0)
	# faixa da rua
	var top := _world_to_map(Vector3(0, 0, 2))
	var bot := _world_to_map(Vector3(0, 0, -64))
	draw_line(top, bot, Color(UI.MIST, 0.4), 10.0)
	if city == null:
		return
	for k in city.kiosks:
		var p: Vector2 = _world_to_map(k["pos"])
		var neon: Color = k.get("neon", UI.AMBER)
		var vis: bool = k.get("visited", false)
		draw_circle(p, 5.5, neon if vis else Color(neon, 0.3))
		if vis:
			draw_arc(p, 8.0, 0, TAU, 16, Color(neon, 0.6), 1.5)
	if player:
		var pp: Vector2 = _world_to_map(player.global_position)
		var dir := Vector2(sin(-player._yaw), -cos(-player._yaw))
		var a := pp + dir * 9
		var b := pp - dir.rotated(0.6) * 6
		var c := pp - dir.rotated(-0.6) * 6
		draw_colored_polygon(PackedVector2Array([a, b, c]), UI.PAPER)
