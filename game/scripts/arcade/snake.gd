extends Control
## COBRA NEON: setas/WASD ou deslizar o dedo. Come os bits, cresce, não bata em si mesma.
var accent := Color("#5fd38a")
var touch := false
const N := 18
var snake: Array = []
var dir := Vector2i(1, 0)
var next_dir := Vector2i(1, 0)
var food := Vector2i(5, 5)
var step_t := 0.0
var score := 0
var best := 0
var dead := false
var _swipe := Vector2.ZERO
var _rng := RandomNumberGenerator.new()


func help() -> String:
	return L.t("Deslize o dedo para virar. Toque para recomeçar.") if touch else L.t("Setas ou WASD para virar. Espaço para recomeçar. ESC sai.")


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_reset()


func _reset() -> void:
	snake = [Vector2i(6, 9), Vector2i(5, 9), Vector2i(4, 9)]
	dir = Vector2i(1, 0)
	next_dir = dir
	score = 0
	dead = false
	_food()


func _food() -> void:
	while true:
		food = Vector2i(_rng.randi_range(0, N - 1), _rng.randi_range(0, N - 1))
		if not snake.has(food):
			return


func _process(dt: float) -> void:
	queue_redraw()
	if dead:
		return
	step_t += dt
	if step_t < maxf(0.06, 0.14 - score * 0.002):
		return
	step_t = 0.0
	dir = next_dir
	var head: Vector2i = snake[0] + dir
	head = Vector2i(posmod(head.x, N), posmod(head.y, N))
	if snake.has(head):
		dead = true
		best = maxi(best, score)
		return
	snake.push_front(head)
	if head == food:
		score += 1
		_food()
	else:
		snake.pop_back()


func _turn(d: Vector2i) -> void:
	if d != -dir:
		next_dir = d


func _gui_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		match (e as InputEventKey).keycode:
			KEY_UP, KEY_W: _turn(Vector2i(0, -1))
			KEY_DOWN, KEY_S: _turn(Vector2i(0, 1))
			KEY_LEFT, KEY_A: _turn(Vector2i(-1, 0))
			KEY_RIGHT, KEY_D: _turn(Vector2i(1, 0))
			KEY_SPACE, KEY_ENTER:
				if dead:
					_reset()
		accept_event()
	elif e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			_swipe = t.position
			if dead:
				_reset()
	elif e is InputEventScreenDrag:
		var d := (e as InputEventScreenDrag).position - _swipe
		if d.length() > 30:
			_turn(Vector2i(int(sign(d.x)), 0) if absf(d.x) > absf(d.y) else Vector2i(0, int(sign(d.y))))
			_swipe = (e as InputEventScreenDrag).position
	elif e is InputEventMouseButton and e.pressed and dead:
		_reset()


func _draw() -> void:
	var side: float = minf(size.x, size.y - 40)
	var o := Vector2((size.x - side) / 2, 40)
	var c := side / N
	draw_rect(Rect2(o, Vector2(side, side)), Color("#05060c"))
	for i in N + 1:
		draw_line(o + Vector2(i * c, 0), o + Vector2(i * c, side), Color(accent, 0.07))
		draw_line(o + Vector2(0, i * c), o + Vector2(side, i * c), Color(accent, 0.07))
	draw_rect(Rect2(o, Vector2(side, side)), accent, false, 3.0)
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
	draw_rect(Rect2(o + Vector2(food) * c + Vector2(c * 0.2, c * 0.2), Vector2(c * 0.6, c * 0.6)), Color("#ff4fa3") * (1.0 + pulse * 0.5))
	for i in snake.size():
		var p: Vector2i = snake[i]
		var k := 1.0 - float(i) / maxf(snake.size(), 1) * 0.6
		draw_rect(Rect2(o + Vector2(p) * c + Vector2(1, 1), Vector2(c - 2, c - 2)), accent * k)
	var f := UI.font("title")
	draw_string(f, Vector2(o.x, 30), "%s %d   %s %d" % [L.t("PONTOS"), score, L.t("RECORDE"), best], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, accent)
	if dead:
		draw_rect(Rect2(o, Vector2(side, side)), Color(0, 0, 0, 0.55))
		draw_string(f, o + Vector2(0, side / 2), L.t("FIM DE JOGO"), HORIZONTAL_ALIGNMENT_CENTER, side, 56, Color("#ff4fa3"))
		draw_string(UI.font("type"), o + Vector2(0, side / 2 + 44), L.t("toque ou espaço para jogar de novo"), HORIZONTAL_ALIGNMENT_CENTER, side, 20, UI.PAPER)
