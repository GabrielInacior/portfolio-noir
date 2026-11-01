extends Node3D
## Folha dos props (orientação e escala): cada um numa célula, câmera de frente (+z olhando para -z).
func _ready() -> void:
	var dir := OS.get_environment("RUMOR_SHOT")
	var names := []
	for f in DirAccess.get_files_at("res://assets/props"):
		if f.ends_with(".glb"):
			names.append(f.get_basename())
	names.sort()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#30344a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.8
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	add_child(sun)
	var cols := 8
	for i in names.size():
		var sc: Node3D = (load("res://assets/props/%s.glb" % names[i]) as PackedScene).instantiate()
		var cell := Vector3((i % cols) * 3.0, 0, -(i / cols) * 3.0)
		# normaliza para caber na célula (só para ver)
		var aabb := AABB()
		for mi in sc.find_children("*", "MeshInstance3D", true, false):
			aabb = (mi as MeshInstance3D).get_aabb()
		var s := 2.0 / maxf(0.01, maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z)))
		sc.scale = Vector3.ONE * s
		sc.position = cell
		add_child(sc)
		var l := Label3D.new()
		l.text = names[i]
		l.pixel_size = 0.004
		l.font_size = 48
		l.position = cell + Vector3(0, -0.3, 0.8)
		add_child(l)
	var cam := Camera3D.new()
	cam.position = Vector3(10.5, 6, 9)
	cam.look_at(Vector3(10.5, 0.6, -7.0))
	cam.fov = 60
	add_child(cam)
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join("props_sheet.png"))
	get_tree().quit()
