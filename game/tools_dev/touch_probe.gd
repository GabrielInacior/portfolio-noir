extends Node
## Toques sintéticos: o dedo da alavanca nunca gira a câmera; só o dedo fora dela olha, e pouco.
## godot --audio-driver Dummy --path . --resolution 405x720 res://tools_dev/touch_probe.tscn
func _t(i: int, p: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = p
	e.pressed = down
	Input.parse_input_event(e)
func _d(i: int, p: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = p
	e.relative = rel
	Input.parse_input_event(e)
func _ready() -> void:
	var main = load("res://scenes/city.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	if main._gate:
		main.hud.visible = true
		main._gate.queue_free()
	await get_tree().create_timer(0.5).timeout
	var p = main.city.player
	var y0: float = p._yaw
	_t(0, Vector2(90, 560), true)
	for k in 20:
		_d(0, Vector2(90 + k * 3, 560), Vector2(3, 0))
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	print("TOUCH stick yaw delta=%.3f (esperado 0)" % absf(angle_difference(y0, p._yaw)))
	var y1: float = p._yaw
	_t(1, Vector2(300, 300), true)
	for k in 30:
		_d(1, Vector2(300 + k * 4, 300), Vector2(4, 0))
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	print("TOUCH look 120px (30%% da tela) yaw delta=%.3f rad" % absf(angle_difference(y1, p._yaw)))
	_t(1, Vector2(420, 300), false)
	_t(0, Vector2(150, 560), false)
	get_tree().quit()
