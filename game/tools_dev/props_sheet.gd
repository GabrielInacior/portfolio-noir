extends Node3D
## Prancha dos props do kit Blender (com o material PS1 do jogo). Mudo.
##   PF_SHOT=<pasta> godot --audio-driver Dummy --path . --resolution 1600x1000 res://tools_dev/props_sheet.tscn
const PS1 := preload("res://scripts/ps1.gd")
const NAMES := ["mesa_detetive", "maquina_escrever", "abajur_banqueiro", "arquivo_aco", "quadro_cortica", "cabideiro",
	"telefone_antigo", "rack_servidor", "mesa_monitores", "cadeira_gamer", "cadeado", "roteador", "fliperama",
	"mesa_cartas", "miniatura_fortaleza", "trofeu", "bancada_lab", "servidor_ia", "estante_livros", "balcao_bar",
	"banqueta_bar", "garrafas", "microfone_estudio", "mesa_som", "mesa_escritorio", "cadeira_escritorio", "monitor",
	"planta_vaso", "sofa_couro", "luminaria_teto", "pilha_papeis"]

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#1a1d2a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#8890b0")
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	sun.light_energy = 1.3
	add_child(sun)
	var cols := 8
	for i in NAMES.size():
		var sc: PackedScene = load("res://assets/props/%s.glb" % NAMES[i])
		var n: Node3D = sc.instantiate()
		PS1.node(n)
		var aabb := AABB()
		var first := true
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var a: AABB = (mi as MeshInstance3D).get_aabb()
			aabb = a if first else aabb.merge(a)
			first = false
		var s := 1.4 / maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
		n.scale = Vector3.ONE * s
		n.position = Vector3((i % cols) * 2.0, -(i / cols) * 2.0 - aabb.position.y * s, 0)
		n.rotation.y = 0.5
		add_child(n)
		var l := Label3D.new()
		l.text = NAMES[i]
		l.font_size = 40
		l.pixel_size = 0.004
		l.position = n.position + Vector3(0, -0.25, 0.6)
		add_child(l)
	var cam := Camera3D.new()
	cam.position = Vector3(7, -2.6, 13)
	cam.fov = 48
	add_child(cam)
	cam.look_at(Vector3(7, -2.4, 0))
	for _i in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OS.get_environment("PF_SHOT").path_join("props_sheet.png"))
	get_tree().quit()
