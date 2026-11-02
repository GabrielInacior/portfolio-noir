extends Node
## Prova do teclado: aperta W (e seta para cima) por 1 s via evento real de tecla e mede o deslocamento.
var main
func _ready() -> void:
	main = load("res://scenes/city.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.0).timeout
	main._enter()
	await get_tree().create_timer(1.2).timeout
	var p = main.city.player
	for spec in [[KEY_W, "W"], [KEY_UP, "SETA"], [KEY_S, "S"]]:
		var a: Vector3 = p.global_position
		var ev := InputEventKey.new()
		ev.keycode = spec[0]; ev.physical_keycode = spec[0]; ev.pressed = true
		Input.parse_input_event(ev)
		await get_tree().create_timer(1.0).timeout
		var up := ev.duplicate(); up.pressed = false
		Input.parse_input_event(up)
		await get_tree().create_timer(0.2).timeout
		print("TECLA %s andou %.2f m" % [spec[1], a.distance_to(p.global_position)])
	get_tree().quit()
