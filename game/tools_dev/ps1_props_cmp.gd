extends Node3D
## Prancha: 6 props da Meshy e 6 do kit Blender lado a lado, sob a mesma luz. PF_PS1=1 aplica o
## material PS1 (para o depois). RUMOR_SHOT=<pasta> TAG=<antes|depois>
const PS1 := preload("res://scripts/ps1.gd")
func _ready() -> void:
	var dir := OS.get_environment("RUMOR_SHOT")
	var tag := OS.get_environment("TAG")
	var names := ["maquina_escrever", "abajur_banqueiro", "telefone_antigo", "fliperama", "cadeira_gamer", "trofeu",
		"sd_cinzeiro", "sd_pizza", "sd_copos", "sd_caixa_arquivo", "sd_latas", "sd_guarda_chuva"]
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#1a1626")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#6a6080")
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var key := OmniLight3D.new()
	key.position = Vector3(4, 4, 4)
	key.light_color = Color("#ffcf8a")
	key.light_energy = 4.0
	key.omni_range = 30
	add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(6, 2, -3)
	rim.light_color = Color("#ff4fa3")
	rim.light_energy = 3.0
	rim.omni_range = 20
	add_child(rim)
	for i in names.size():
		var sc: Node3D = (load("res://assets/props/%s.glb" % names[i]) as PackedScene).instantiate()
		if OS.get_environment("PF_PS1") == "1":
			PS1.node(sc)
		var aabb := AABB()
		var first := true
		for mi in sc.find_children("*", "MeshInstance3D", true, false):
			var a := (mi as MeshInstance3D).get_aabb()
			aabb = a if first else aabb.merge(a)
			first = false
		var s := 1.6 / maxf(0.01, maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z)))
		sc.scale = Vector3.ONE * s
		sc.position = Vector3((i % 6) * 2.2, -(i / 6) * 2.4, 0) - aabb.get_center() * s
		sc.rotation.y = 0.5
		add_child(sc)
	var cam := Camera3D.new()
	cam.position = Vector3(5.5, -1.2, 9.0)
	cam.fov = 45
	add_child(cam)
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join("props_%s.png" % tag))
	get_tree().quit()
