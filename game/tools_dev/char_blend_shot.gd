extends Node3D
## Prova em MOVIMENTO: troca de animação com mistura (como no jogo) e fotografa a cada 1/12 s.
## Pega torção que só aparece na interpolação/mistura. Sempre mudo.
##   RUMOR_SHOT=<pasta> CHAR_ID=detetive godot --audio-driver Dummy --path . --resolution 500x700 res://tools_dev/char_blend_shot.tscn
const Character := preload("res://scripts/scene3d/noir_character.gd")


func _ready() -> void:
	var dir := OS.get_environment("RUMOR_SHOT")
	var id := OS.get_environment("CHAR_ID")
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#1a2036")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#9098b8")
	we.environment = e
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, -25, 0)
	add_child(key)
	var cam := Camera3D.new()
	cam.fov = 34
	add_child(cam)
	cam.position = Vector3(0.9, 1.25, 2.6)
	cam.look_at(Vector3(0, 1.1, 0))
	var c := Character.new()
	add_child(c)
	c.setup({"id": id, "name": id})
	await get_tree().create_timer(0.3).timeout
	var seq := ["idle", "falando", "perguntando", "apontando", "idle"]
	var n := 0
	for an in seq:
		c.play(an)
		for k in 18:
			await get_tree().create_timer(1.0 / 12.0).timeout
			get_viewport().get_texture().get_image().save_png(dir.path_join("f%03d.png" % n))
			n += 1
	print("BLEND ", n)
	get_tree().quit()
