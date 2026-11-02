extends Node3D
## Prancha dos carros (mudo): os 8 modelos em fila, luz noturna com rim neon.
## RUMOR_SHOT=<pasta> godot --path . res://tools_dev/car_sheet.tscn
func _ready() -> void:
	var names := ["car_sedan_maroon", "car_sedan_teal", "car_sedan_cream", "car_taxi_yellow", "car_coupe_black", "car_coupe_crimson", "car_van_grey", "car_van_navy"]
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#0c1020")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#5a6aa0")
	e.ambient_light_energy = 0.9
	we.environment = e
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_energy = 1.1
	add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, -150, 0)
	rim.light_color = Color("#ff4f9a")
	rim.light_energy = 0.9
	add_child(rim)
	for i in names.size():
		var sc: Node3D = (load("res://assets/vehicles/%s.glb" % names[i]) as PackedScene).instantiate()
		add_child(sc)
		sc.position = Vector3((i % 4) * 2.6 - 3.9, 0, (i / 4) * 6.0)
		sc.rotation.y = 0.75
		load("res://scripts/ps1.gd").node(sc)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 6.5, 14.5)
	cam.look_at(Vector3(0, 0.4, 3.0))
	cam.fov = 40
	cam.current = true
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_environment("RUMOR_SHOT").path_join("car_sheet.png"))
	print("SHOT car_sheet")
	get_tree().quit()
