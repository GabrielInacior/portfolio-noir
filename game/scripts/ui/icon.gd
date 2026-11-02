class_name Icon
extends Control
## Ícones vetoriais desenhados em código (traço uniforme, cantos arredondados, grade 24x24), para a
## interface inteira ter o mesmo desenho e nunca virar quadrado no navegador (sem fonte de ícones).

var icon := "dot"
var color := Color.WHITE
var stroke := 2.0


static func make(name: String, col: Color, side: float) -> Icon:
	var i := Icon.new()
	i.icon = name
	i.color = col
	i.custom_minimum_size = Vector2(side, side)
	i.size = Vector2(side, side)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


func set_icon(name: String, col := Color(-1, 0, 0)) -> void:
	icon = name
	if col.r >= 0.0:
		color = col
	queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)
	# quando ancorado no centro de um botão, centraliza pelo próprio tamanho
	if anchor_left == 0.5 and anchor_top == 0.5:
		var s := custom_minimum_size
		offset_left = -s.x / 2.0
		offset_top = -s.y / 2.0
		offset_right = s.x / 2.0
		offset_bottom = s.y / 2.0


func _p(x: float, y: float) -> Vector2:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) / 2.0
	return o + Vector2(x, y) * s / 24.0


func _w() -> float:
	return maxf(1.4, minf(size.x, size.y) / 24.0 * 2.0)


func _line(pts: Array, closed := false) -> void:
	var arr := PackedVector2Array()
	for p in pts:
		arr.append(_p(p.x, p.y))
	if closed:
		arr.append(arr[0])
	draw_polyline(arr, color, _w(), true)


func _arc(cx: float, cy: float, r: float, a0: float, a1: float) -> void:
	var s := minf(size.x, size.y) / 24.0
	draw_arc(_p(cx, cy), r * s, a0, a1, 24, color, _w(), true)


func _dot(cx: float, cy: float, r: float, col := Color(-1, 0, 0)) -> void:
	var s := minf(size.x, size.y) / 24.0
	draw_circle(_p(cx, cy), r * s, color if col.r < 0.0 else col)


func _draw() -> void:
	match icon:
		"close":
			_line([Vector2(6, 6), Vector2(18, 18)])
			_line([Vector2(18, 6), Vector2(6, 18)])
		"sound":
			_line([Vector2(4, 9), Vector2(8, 9), Vector2(13, 5), Vector2(13, 19), Vector2(8, 15), Vector2(4, 15)], true)
			_arc(13, 12, 4.5, -0.9, 0.9)
			_arc(13, 12, 8.0, -0.85, 0.85)
		"mute":
			_line([Vector2(4, 9), Vector2(8, 9), Vector2(13, 5), Vector2(13, 19), Vector2(8, 15), Vector2(4, 15)], true)
			_line([Vector2(16, 9), Vector2(21, 15)])
			_line([Vector2(21, 9), Vector2(16, 15)])
		"globe":
			_arc(12, 12, 8.5, 0, TAU)
			_line([Vector2(3.5, 12), Vector2(20.5, 12)])
			_ellipse(12, 12, 3.8, 8.5)
		"map":
			_line([Vector2(3, 6), Vector2(9, 4), Vector2(15, 6), Vector2(21, 4), Vector2(21, 18), Vector2(15, 20), Vector2(9, 18), Vector2(3, 20)], true)
			_line([Vector2(9, 4), Vector2(9, 18)])
			_line([Vector2(15, 6), Vector2(15, 20)])
		"places":
			for y in [5.0, 12.0, 19.0]:
				_dot(5, y, 1.6)
				_line([Vector2(9, y), Vector2(20, y)])
		"pin":
			_arc(12, 10, 5.5, PI * 0.85, PI * 2.15)
			_line([Vector2(7.2, 12.8), Vector2(12, 20.5), Vector2(16.8, 12.8)])
			_dot(12, 10, 1.8)
		"external":
			_line([Vector2(10, 5), Vector2(5, 5), Vector2(5, 19), Vector2(19, 19), Vector2(19, 14)])
			_line([Vector2(13, 5), Vector2(19, 5), Vector2(19, 11)])
			_line([Vector2(19, 5), Vector2(11, 13)])
		"chev_l":
			_line([Vector2(15, 5), Vector2(8, 12), Vector2(15, 19)])
		"chev_r":
			_line([Vector2(9, 5), Vector2(16, 12), Vector2(9, 19)])
		"chev_d":
			_line([Vector2(5, 9), Vector2(12, 16), Vector2(19, 9)])
		"door":
			_line([Vector2(6, 21), Vector2(6, 3), Vector2(17, 3), Vector2(17, 21)])
			_line([Vector2(3, 21), Vector2(21, 21)])
			_dot(14, 12.5, 1.3)
		"eye":
			_ellipse(12, 12, 9, 5.5)
			_dot(12, 12, 2.6)
		"mouse":
			_line([Vector2(7, 9), Vector2(7, 16), Vector2(9, 20), Vector2(15, 20), Vector2(17, 16), Vector2(17, 9), Vector2(15, 4), Vector2(9, 4)], true)
			_line([Vector2(12, 4), Vector2(12, 9)])
		"tap":
			_arc(12, 8, 4, PI, TAU)
			_line([Vector2(10, 9), Vector2(10, 18), Vector2(13, 21), Vector2(18, 21), Vector2(19, 15), Vector2(14, 13), Vector2(14, 9)])
		"drag":
			_line([Vector2(4, 12), Vector2(20, 12)])
			_line([Vector2(7, 9), Vector2(4, 12), Vector2(7, 15)])
			_line([Vector2(17, 9), Vector2(20, 12), Vector2(17, 15)])
			_line([Vector2(12, 4), Vector2(12, 20)])
			_line([Vector2(9, 7), Vector2(12, 4), Vector2(15, 7)])
			_line([Vector2(9, 17), Vector2(12, 20), Vector2(15, 17)])
		"stick":
			_arc(12, 12, 9, 0, TAU)
			_dot(12, 12, 4)
		"walk":
			_dot(13, 4.5, 2)
			_line([Vector2(12, 8), Vector2(10, 14), Vector2(7, 20)])
			_line([Vector2(10, 14), Vector2(14, 16), Vector2(15, 21)])
			_line([Vector2(8, 11), Vector2(12, 8), Vector2(16, 11)])
		"check":
			_line([Vector2(5, 12.5), Vector2(10, 17.5), Vector2(19, 7)])
		"star":
			var pts := []
			for k in 10:
				var a := -PI / 2 + k * PI / 5
				var r := 9.0 if k % 2 == 0 else 4.0
				pts.append(Vector2(12 + cos(a) * r, 12.5 + sin(a) * r))
			_line(pts, true)
		"play":
			_line([Vector2(8, 5), Vector2(19, 12), Vector2(8, 19)], true)
		"info":
			_arc(12, 12, 9, 0, TAU)
			_line([Vector2(12, 11), Vector2(12, 17)])
			_dot(12, 7.5, 1.3)
		"github":
			_arc(12, 12, 9, 0, TAU)
			_line([Vector2(9, 19), Vector2(9, 15), Vector2(8, 13), Vector2(9, 9), Vector2(12, 10), Vector2(15, 9), Vector2(16, 13), Vector2(15, 15), Vector2(15, 19)])
		"compass":
			_arc(12, 12, 9, 0, TAU)
			_line([Vector2(12, 5.5), Vector2(14.5, 12), Vector2(12, 18.5), Vector2(9.5, 12)], true)
		_:
			_dot(12, 12, 4.5)


func _ellipse(cx: float, cy: float, rx: float, ry: float) -> void:
	var pts := []
	for k in 33:
		var a := k * TAU / 32.0
		pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	_line(pts)
