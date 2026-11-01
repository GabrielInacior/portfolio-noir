extends Control
## DEFENDA A FORTALEZA (homenagem ao Fortress Chaos): inimigos seguem a trilha até o castelo;
## toque/clique nas bases vazias para erguer torres (custa ouro). Ondas cada vez mais fortes.
var accent := Color("#ff7a3d")
var touch := false
var path := [Vector2(0.0, 0.2), Vector2(0.7, 0.2), Vector2(0.7, 0.5), Vector2(0.25, 0.5), Vector2(0.25, 0.8), Vector2(1.0, 0.8)]
var slots := [Vector2(0.4, 0.33), Vector2(0.85, 0.35), Vector2(0.5, 0.65), Vector2(0.1, 0.65), Vector2(0.6, 0.92), Vector2(0.45, 0.08), Vector2(0.85, 0.65)]
var towers := {}
var enemies: Array = []
var shots: Array = []
var gold := 60
var lives := 10
var wave := 0
var spawn_left := 0
var spawn_t := 0.0
var wave_t := 2.0
var over := false


func help() -> String:
	return L.t("Toque nas bases para erguer torres (30 de ouro). Segure as ondas!") if touch else L.t("Clique nas bases para erguer torres (30 de ouro). Segure as ondas! ESC sai.")


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP


func _area() -> Rect2:
	var w: float = minf(size.x, (size.y - 44) * 1.2)
	var h: float = w / 1.2
	return Rect2((size.x - w) / 2, 44, w, minf(h, size.y - 44))


func _seg_pos(d: float) -> Vector2:
	for i in path.size() - 1:
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var l := a.distance_to(b)
		if d <= l:
			return a.lerp(b, d / l)
		d -= l
	return path[-1]


func _total() -> float:
	var t := 0.0
	for i in path.size() - 1:
		t += (path[i] as Vector2).distance_to(path[i + 1])
	return t


func _process(dt: float) -> void:
	queue_redraw()
	if over:
		return
	if spawn_left <= 0 and enemies.is_empty():
		wave_t -= dt
		if wave_t <= 0:
			wave += 1
			spawn_left = 5 + wave * 2
			wave_t = 3.0
	if spawn_left > 0:
		spawn_t -= dt
		if spawn_t <= 0:
			spawn_t = 0.8
			spawn_left -= 1
			enemies.append({"d": 0.0, "hp": 3.0 + wave * 1.5, "max": 3.0 + wave * 1.5, "sp": 0.12 + wave * 0.006})
	var tot := _total()
	for i in range(enemies.size() - 1, -1, -1):
		var e: Dictionary = enemies[i]
		e["d"] = float(e["d"]) + float(e["sp"]) * dt
		if float(e["d"]) >= tot:
			enemies.remove_at(i)
			lives -= 1
			if lives <= 0:
				over = true
	for k in towers:
		var tw: Dictionary = towers[k]
		tw["cd"] = float(tw["cd"]) - dt
		if float(tw["cd"]) > 0:
			continue
		var sp: Vector2 = slots[k]
		for e in enemies:
			var ep := _seg_pos(float(e["d"]))
			if ep.distance_to(sp) < 0.22:
				e["hp"] = float(e["hp"]) - 1.0
				shots.append({"a": sp, "b": ep, "t": 0.12})
				tw["cd"] = 0.45
				break
	for i in range(enemies.size() - 1, -1, -1):
		if float(enemies[i]["hp"]) <= 0:
			enemies.remove_at(i)
			gold += 5
	for i in range(shots.size() - 1, -1, -1):
		shots[i]["t"] = float(shots[i]["t"]) - dt
		if float(shots[i]["t"]) <= 0:
			shots.remove_at(i)


func _gui_input(e: InputEvent) -> void:
	var pos := Vector2(-1, -1)
	if e is InputEventMouseButton and e.pressed:
		pos = e.position
	elif e is InputEventScreenTouch and e.pressed:
		pos = e.position
	elif e is InputEventKey and e.pressed and (e as InputEventKey).keycode in [KEY_SPACE, KEY_ENTER] and over:
		_restart()
	if pos.x < 0:
		return
	if over:
		_restart()
		return
	var a := _area()
	var p := (pos - a.position) / a.size
	for i in slots.size():
		if (slots[i] as Vector2).distance_to(p) < 0.07 and not towers.has(i) and gold >= 30:
			towers[i] = {"cd": 0.0}
			gold -= 30
			accept_event()
			return


func _restart() -> void:
	towers.clear()
	enemies.clear()
	gold = 60
	lives = 10
	wave = 0
	spawn_left = 0
	over = false


func _draw() -> void:
	var a := _area()
	draw_rect(a, Color("#0b0f08"))
	for i in path.size() - 1:
		draw_line(a.position + (path[i] as Vector2) * a.size, a.position + (path[i + 1] as Vector2) * a.size, Color("#5a4630"), a.size.x * 0.06)
	var castle: Vector2 = a.position + Vector2(0.95, 0.8) * a.size
	draw_rect(Rect2(castle - Vector2(20, 34), Vector2(40, 40)), Color("#8a8a9a"))
	draw_rect(Rect2(castle - Vector2(24, 44), Vector2(10, 12)), Color("#8a8a9a"))
	draw_rect(Rect2(castle + Vector2(14, -44), Vector2(10, 12)), Color("#8a8a9a"))
	for i in slots.size():
		var sp: Vector2 = a.position + (slots[i] as Vector2) * a.size
		if towers.has(i):
			draw_rect(Rect2(sp - Vector2(12, 22), Vector2(24, 30)), accent)
			draw_rect(Rect2(sp - Vector2(15, 26), Vector2(30, 6)), accent.lightened(0.3))
		else:
			draw_arc(sp, 16, 0, TAU, 20, Color(accent, 0.6 if gold >= 30 else 0.25), 3.0)
	for e in enemies:
		var ep: Vector2 = a.position + _seg_pos(float(e["d"])) * a.size
		draw_circle(ep, 9, Color("#e23a4a"))
		draw_rect(Rect2(ep + Vector2(-10, -16), Vector2(20 * float(e["hp"]) / float(e["max"]), 3)), Color("#5fd38a"))
	for s in shots:
		draw_line(a.position + (s["a"] as Vector2) * a.size, a.position + (s["b"] as Vector2) * a.size, Color("#ffe08a"), 2.0)
	draw_rect(a, accent, false, 3.0)
	var f := UI.font("title")
	draw_string(f, Vector2(a.position.x, 32), "%s %d   %s %d   %s %d" % [L.t("ONDA"), wave, L.t("OURO"), gold, L.t("VIDAS"), lives], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, accent)
	if over:
		draw_rect(a, Color(0, 0, 0, 0.55))
		draw_string(f, a.position + Vector2(0, a.size.y / 2), L.t("A FORTALEZA CAIU"), HORIZONTAL_ALIGNMENT_CENTER, a.size.x, 50, Color("#ff4fa3"))
		draw_string(UI.font("type"), a.position + Vector2(0, a.size.y / 2 + 40), L.tf("ondas resistidas: %d · toque para recomeçar", [maxi(wave - 1, 0)]), HORIZONTAL_ALIGNMENT_CENTER, a.size.x, 20, UI.PAPER)
