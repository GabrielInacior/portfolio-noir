extends Control
## QUEBRA TIJOLO: mouse, dedo ou setas movem a raquete; quebre todos os tijolos neon.
var accent := Color("#4e9bff")
var touch := false
var pad_x := 0.5
var ball := Vector2(0.5, 0.7)
var vel := Vector2(0.32, -0.42)
var bricks: Array = []
var score := 0
var lives := 3
var stuck := true
var over := false
var keys := 0.0


func help() -> String:
	return L.t("Arraste o dedo para mover a raquete. Toque para lançar.") if touch else L.t("Mouse ou setas movem a raquete. Clique ou espaço lança. ESC sai.")


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_level()


func _level() -> void:
	bricks.clear()
	for r in 5:
		for c in 8:
			bricks.append(Rect2(0.04 + c * 0.115, 0.1 + r * 0.055, 0.105, 0.04))


func _area() -> Rect2:
	var w: float = minf(size.x, (size.y - 40) * 0.9)
	var h: float = w / 0.9
	return Rect2((size.x - w) / 2, 40, w, minf(h, size.y - 40))


func _process(dt: float) -> void:
	queue_redraw()
	pad_x = clampf(pad_x + keys * dt * 1.4, 0.08, 0.92)
	if over:
		return
	if stuck:
		ball = Vector2(pad_x, 0.88)
		return
	ball += vel * dt
	if ball.x < 0.01 or ball.x > 0.99:
		vel.x = -vel.x
		ball.x = clampf(ball.x, 0.01, 0.99)
	if ball.y < 0.01:
		vel.y = absf(vel.y)
	if ball.y > 0.9 and ball.y < 0.93 and absf(ball.x - pad_x) < 0.09 and vel.y > 0:
		vel.y = -absf(vel.y)
		vel.x = (ball.x - pad_x) * 4.0
	if ball.y > 1.0:
		lives -= 1
		stuck = true
		if lives <= 0:
			over = true
	for i in range(bricks.size() - 1, -1, -1):
		var b: Rect2 = bricks[i]
		if b.has_point(ball):
			bricks.remove_at(i)
			vel.y = -vel.y
			score += 10
			break
	if bricks.is_empty():
		_level()
		vel *= 1.12
		stuck = true


func _gui_input(e: InputEvent) -> void:
	var a := _area()
	if e is InputEventMouseMotion or e is InputEventScreenDrag:
		pad_x = clampf((e.position.x - a.position.x) / a.size.x, 0.08, 0.92)
	elif (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		_launch()
	elif e is InputEventKey:
		var k := e as InputEventKey
		if k.keycode in [KEY_LEFT, KEY_A]:
			keys = -1.0 if k.pressed else 0.0
		elif k.keycode in [KEY_RIGHT, KEY_D]:
			keys = 1.0 if k.pressed else 0.0
		elif k.pressed and k.keycode in [KEY_SPACE, KEY_ENTER]:
			_launch()
		accept_event()


func _launch() -> void:
	if over:
		over = false
		lives = 3
		score = 0
		_level()
		vel = Vector2(0.32, -0.42)
	stuck = false


func _draw() -> void:
	var a := _area()
	draw_rect(a, Color("#05060c"))
	draw_rect(a, accent, false, 3.0)
	var pal := [Color("#ff4fa3"), Color("#ffc83d"), Color("#5fd38a"), Color("#4e9bff"), Color("#b06bff")]
	for i in bricks.size():
		var b: Rect2 = bricks[i]
		var r := Rect2(a.position + b.position * a.size, b.size * a.size)
		draw_rect(r, pal[int(b.position.y * 18) % pal.size()] * 1.2)
	draw_rect(Rect2(a.position + Vector2((pad_x - 0.08) * a.size.x, 0.91 * a.size.y), Vector2(0.16 * a.size.x, 0.02 * a.size.y)), accent * 1.4)
	draw_circle(a.position + ball * a.size, a.size.x * 0.012, Color.WHITE)
	var f := UI.font("title")
	draw_string(f, Vector2(a.position.x, 30), "%s %d   %s %d" % [L.t("PONTOS"), score, L.t("VIDAS"), lives], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, accent)
	if over:
		draw_string(f, a.position + Vector2(0, a.size.y / 2), L.t("FIM DE JOGO"), HORIZONTAL_ALIGNMENT_CENTER, a.size.x, 56, Color("#ff4fa3"))
