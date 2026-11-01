extends Node3D
## Prova das animações: os 4 personagens lado a lado em 6 animações, de frente e de lado, em 2 momentos
## de cada animação. Uma imagem por animação e vista. Sempre mudo.
##   RUMOR_SHOT=<pasta> [GRID_OLD=1] godot --audio-driver Dummy --path . --resolution 1600x900 res://tools_dev/char_anim_grid.tscn
## GRID_OLD=1 usa a biblioteca comum antiga (sem conversão por esqueleto), para comparar.

const Character := preload("res://scripts/scene3d/noir_character.gd")
const ANIMS := ["idle", "falando", "apontando", "encostado", "pensativo", "andando"]
var dir := ""
var cam: Camera3D
var chars: Array = []


func _ready() -> void:
	dir = OS.get_environment("RUMOR_SHOT")
	if OS.get_environment("GRID_OLD") == "1":
		Character.BAKED.clear()
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#1a2036")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#8890b0")
	e.ambient_light_energy = 1.1
	we.environment = e
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, -25, 0)
	key.light_energy = 1.4
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 160, 0)
	fill.light_energy = 0.6
	add_child(fill)
	cam = Camera3D.new()
	cam.current = true
	cam.fov = 38
	add_child(cam)
	var ids := ["detetive", "couro", "bartender", "hacker"]
	for i in ids.size():
		var c := Character.new()
		add_child(c)
		c.setup({"id": ids[i], "name": ids[i]})
		c.position = Vector3(-2.4 + i * 1.6, 0, 0)
		chars.append(c)
	await get_tree().create_timer(0.5).timeout
	for c in chars:
		c.visible = false
	for an in ANIMS:
		for ci in chars.size():
			var c: Node3D = chars[ci]
			for o in chars:
				o.visible = o == c
			var ap: AnimationPlayer = c.anim
			if ap and ap.has_animation(an):
				ap.play(an, 0.0)
			for view in ["frente", "lado"]:
				c.rotation_degrees.y = 0 if view == "frente" else 90
				cam.position = c.position + Vector3(0, 1.0, 3.6)
				cam.look_at(c.position + Vector3(0, 0.95, 0))
				for frac in [0.3, 0.7]:
					if ap and ap.has_animation(an):
						ap.seek(ap.get_animation(an).length * frac, true)
					await get_tree().process_frame
					await get_tree().process_frame
					var img := get_viewport().get_texture().get_image()
					img.save_png(dir.path_join("%s_%d_%s_%d.png" % [an, ci, view, int(frac * 10)]))
		print("GRID ", an)
	get_tree().quit()
