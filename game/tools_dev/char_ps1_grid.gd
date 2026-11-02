extends Node3D
## Prova dos personagens PS1 dentro do Godot: os 6 lado a lado em cada animação (frente e 3/4, dois
## instantes) e uma folha de expressões em close. Sempre mudo.
##   RUMOR_SHOT=<pasta> godot --audio-driver Dummy --path . --resolution 400x720 res://tools_dev/char_ps1_grid.tscn

const Character := preload("res://scripts/scene3d/noir_character.gd")
const IDS := ["detetive", "couro", "bartender", "hacker", "extra1", "extra2"]
const ANIMS := ["idle", "respirando", "falando", "perguntando", "pensativo", "sim", "nao", "olhando",
	"bracos_cruzados", "maos_bolsos", "fumando", "andando", "bartender"]
var dir := ""
var cam: Camera3D
var chars: Array = []


func _ready() -> void:
	dir = OS.get_environment("RUMOR_SHOT")
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#1a2036")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#9098b8")
	e.ambient_light_energy = 1.0
	we.environment = e
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -30, 0)
	key.light_energy = 1.3
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 150, 0)
	fill.light_energy = 0.5
	add_child(fill)
	cam = Camera3D.new()
	cam.current = true
	cam.fov = 30
	add_child(cam)
	for i in IDS.size():
		var c := Character.new()
		add_child(c)
		c.setup({"id": IDS[i], "rim": "#4ec9ff"})
		c.position = Vector3(-4.0 + i * 1.6, 0, 0)
		chars.append(c)
	await get_tree().create_timer(0.6).timeout
	for an in ANIMS:
		for c in chars:
			c.play(an)
			if c.anim:
				c.anim.seek(0.0, true)
		for t in [0.6, 1.6]:
			await get_tree().create_timer(t if t == 0.6 else 1.0).timeout
			for view in ["frente", "34"]:
				for ci in chars.size():
					var c: Node3D = chars[ci]
					for o in chars:
						o.visible = o == c
					c.rotation_degrees.y = 0 if view == "frente" else 40
					cam.position = c.position + Vector3(0, 1.0, 4.4)
					cam.look_at(c.position + Vector3(0, 0.92, 0))
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png(dir.path_join("g_%s_%s_%d_%d.png" % [an, view, int(t * 10), ci]))
				for o in chars:
					o.visible = true
	# expressões em close (o detetive e a Lena), boca fechada e aberta
	for c in chars:
		c.rotation_degrees.y = 0
		c.play("idle")
	cam.fov = 18
	for ci in [0, 1, 2, 3]:
		var c: Node3D = chars[ci]
		for ex in Character.EXPRS:
			for mouth in [false, true]:
				c.expression = ex
				c._mouth_open = mouth
				c._apply_face()
				cam.position = c.position + Vector3(0, 1.66, 1.6)
				cam.look_at(c.position + Vector3(0, 1.64, 0))
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(dir.path_join("e_%d_%s_%d.png" % [ci, ex, int(mouth)]))
	print("GRADE_OK")
	get_tree().quit()
