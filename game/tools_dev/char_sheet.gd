extends Node3D
## Folha de personagens: os 4 do elenco (corpo inteiro, busto frontal e 3/4) e expressões. Sempre muda.
## RUMOR_SHOT=<pasta> godot --audio-driver Dummy --path . --resolution 1200x900 res://tools_dev/char_sheet.tscn

const Character := preload("res://scripts/scene3d/noir_character.gd")
const Cast := preload("res://scripts/cast.gd")
var dir := ""
var cam: Camera3D


func _ready() -> void:
	dir = OS.get_environment("RUMOR_SHOT")
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#141a30")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#5a6080")
	e.ambient_light_energy = 1.0
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = e
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-25, -30, 0)
	key.light_color = Color("#ffe2c4")
	key.light_energy = 1.6
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, 150, 0)
	fill.light_color = Color("#ff4fa0")
	fill.light_energy = 0.8
	add_child(fill)
	cam = Camera3D.new()
	cam.current = true
	add_child(cam)
	var ids := ["detetive", "couro", "bartender", "hacker"]
	var chars := []
	for i in ids.size():
		var c := Character.new()
		c.position = Vector3(-2.7 + i * 1.8, 0, 0)
		add_child(c)
		c.setup(Cast.card(ids[i]))
		chars.append(c)
	await get_tree().create_timer(1.2).timeout
	_shot_at(Vector3(0, 1.0, 7.2), Vector3(0, 0.95, 0), 38)
	await get_tree().create_timer(0.3).timeout
	_save("g1_elenco")
	for i in chars.size():
		var x: float = chars[i].position.x
		for k in 2:
			var a := 0.0 if k == 0 else 0.6
			_shot_at(Vector3(x + sin(a) * 1.25, 1.45, cos(a) * 1.25), Vector3(x, 1.42, 0), 34)
			await get_tree().create_timer(0.35).timeout
			_save("g1_busto_%d_%d" % [i, k])
	var x0: float = chars[3].position.x
	_shot_at(Vector3(x0 + 0.25, 1.62, 0.75), Vector3(x0, 1.6, 0), 30)
	for k in 3:
		chars[3].set_expression(["serio", "desconfiado", "sorriso_canto"][k])
		await get_tree().create_timer(0.35).timeout
		_save("g1_expr_%d" % k)
	get_tree().quit()


func _shot_at(pos: Vector3, look: Vector3, fov: float) -> void:
	cam.fov = fov
	cam.look_at_from_position(pos, look)


func _save(n: String) -> void:
	get_viewport().get_texture().get_image().save_png(dir.path_join(n + ".png"))
	print("SHOT ", n)
