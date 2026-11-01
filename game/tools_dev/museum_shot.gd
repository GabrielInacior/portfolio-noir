extends Node
## Captura o interior de uma loja-museu de alguns pontos, e o modal de um item.
## RUMOR_SHOT=<pasta> MUSEUM=<id> godot --audio-driver Dummy --path . --resolution WxH res://tools_dev/museum_shot.tscn

const Museum := preload("res://scripts/museum.gd")
const Exhibit := preload("res://scripts/exhibit.gd")

var dir := ""


func _ready() -> void:
	dir = OS.get_environment("RUMOR_SHOT")
	var pid := OS.get_environment("MUSEUM")
	if pid == "":
		pid = "rumor"
	var path := "res://assets/museum/_items/%s.json" % pid
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var proj := {}
	for p in Data.projects:
		if str(p.get("id", "")) == pid:
			proj = p
	var m := Museum.new()
	m.setup(proj if not proj.is_empty() else {"id": pid, "title": pid, "neon": "#ffc83d"}, d, pid == "_lab")
	add_child(m)
	await _wait(1.2)
	var cam := Camera3D.new()
	cam.fov = 70
	cam.current = true
	add_child(cam)
	var shots := [
		[Vector3(0, 1.6, 4.0), Vector3(0, 1.5, -2.0), "01_entrada"],
		[Vector3(-3.0, 1.6, 2.0), Vector3(-4.6, 1.6, -2.0), "02_parede_esq"],
		[Vector3(2.4, 1.6, 1.0), Vector3(4.6, 1.5, -2.0), "03_parede_dir"],
		[Vector3(0, 1.6, 2.5), Vector3(0, 1.6, -5.5), "04_fundo"],
		[Vector3(-1.2, 1.6, -1.0), Vector3(-4.6, 1.6, -3.0), "05_detalhe"],
	]
	for s in shots:
		cam.position = s[0]
		cam.look_at(s[1], Vector3.UP)
		await _wait(0.35)
		_save("%s_%s" % [pid.lstrip("_"), s[2]])
	# modal de um item com imagem
	var layer := CanvasLayer.new()
	add_child(layer)
	var item: Dictionary = (d.get("items", []) as Array)[0]
	var ex := Exhibit.new()
	ex.setup(item, m._accent, m.project)
	layer.add_child(UI.full(ex))
	await _wait(0.8)
	_save("%s_06_modal" % pid.lstrip("_"))
	get_tree().quit()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _save(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	print("SHOT ", name)
