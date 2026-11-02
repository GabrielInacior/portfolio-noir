extends Node
## Carros na rua à noite (mudo): fotos com os estacionados e os que circulam, faróis acesos.
## RUMOR_SHOT=<pasta> godot --audio-driver Dummy --path . --resolution 1600x900 res://tools_dev/car_street_shot.tscn
var main
var dir := ""


func _ready() -> void:
	dir = OS.get_environment("RUMOR_SHOT")
	main = load("res://scenes/city.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.4).timeout
	if main._gate:
		main._gate.queue_free()
	main.hud.visible = false
	var p = main.city.player
	var views := [
		[Vector3(-0.6, 1.35, -9.0), 0.55, -0.14, "car_rua_a"],   # meio da rua, 3/4 do estacionado
		[Vector3(5.7, 1.35, -20.2), 0.45, -0.12, "car_rua_c"],    # calçada direita, 3/4 do estacionado
		[Vector3(0.6, 1.5, 6.0), 0.0, -0.05, "car_rua_b"],        # avenida, trânsito com faróis
	]

	for v in views:
		p.global_position = v[0]
		p._yaw = v[1]
		p._pitch = v[2]
		p.rotation.y = v[1]
		p.head.rotation.x = v[2]
		for k in 3:
			await get_tree().create_timer(1.3).timeout
			get_viewport().get_texture().get_image().save_png(dir.path_join("%s_%d.png" % [v[3], k]))
	print("SHOT car_street")
	get_tree().quit()
