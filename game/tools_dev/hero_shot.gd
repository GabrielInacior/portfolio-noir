extends Node
## Hero shots para divulgação (README de perfil, LinkedIn): a cena do jogo de verdade, com o visual
## retrô escolhido (PF_RETRO), sem a interface. Sempre mudo.
## RUMOR_SHOT=<pasta> PF_RETRO=suave godot --audio-driver Dummy --path . --resolution 1920x1080 res://tools_dev/hero_shot.tscn
## HERO=rua|loja|lab|vertical (padrão: rua,loja,lab)
var main
var dir := ""


func _ready() -> void:
	dir = OS.get_environment("RUMOR_SHOT")
	main = load("res://scenes/city.tscn").instantiate()
	add_child(main)
	await _wait(2.4)
	if main._gate:
		main._gate.queue_free()
	main.hud.visible = false
	var which := OS.get_environment("HERO")
	if which == "":
		which = "rua,loja,lab"
	var p = main.city.player
	for w in which.split(","):
		match w:
			"rua":
				await _street(p, Vector3(-0.8, 1.62, -2.5), 1.05, 0.05, "hero_rua")
				await _street(p, Vector3(1.2, 1.7, -27.0), 0.12, 0.06, "hero_cruzamento")
				await _street(p, Vector3(-47.0, 1.8, -42.0), 1.5708, 0.07, "hero_praca")
			"capa":
				await _street(p, Vector3(2.6, 1.7, 3.0), 0.55, 0.04, "capa_a")
				await _street(p, Vector3(3.2, 1.8, 1.0), 0.75, 0.06, "capa_b")
				await _street(p, Vector3(1.6, 1.65, 4.5), 0.42, 0.02, "capa_c")
				await _street(p, Vector3(2.0, 1.75, -6.0), 1.25, 0.05, "capa_d")
			"vertical":
				await _street(p, Vector3(-0.2, 1.65, -1.5), 0.62, 0.08, "hero_vertical")
			"loja":
				await _museum("inaciocyber", Vector3(0.0, 1.62, 3.6), Vector3(0.0, 1.35, -4.5), "hero_loja_inaciocyber")
				await _museum("fortress", Vector3(0.6, 1.62, 3.6), Vector3(-0.3, 1.3, -4.5), "hero_loja_fortress")
				await _museum("rumor", Vector3(-0.4, 1.62, 3.6), Vector3(0.2, 1.3, -4.5), "hero_loja_rumor")
			"lab":
				await _museum("_lab", Vector3(0.0, 1.62, 3.6), Vector3(0.0, 1.55, -4.5), "hero_lab")
	get_tree().quit()


func _street(p, pos: Vector3, yaw: float, pitch: float, name: String) -> void:
	if main.hud._museum:
		main.hud.exit_museum()
		await _wait(0.6)
		main.hud.visible = false
	p.global_position = pos
	p._yaw = yaw
	p._pitch = pitch
	p.rotation.y = yaw
	p.head.rotation.x = pitch
	await _wait(1.2)
	_save(name)


func _museum(pid: String, local_pos: Vector3, local_look: Vector3, name: String) -> void:
	if main.hud._museum:
		main.hud.exit_museum()
		await _wait(0.6)
	var proj := {}
	for pr in Data.projects:
		if str(pr.get("id", "")) == pid:
			proj = pr
	if pid == "_lab":
		proj = {"id": "_lab", "title": "LAB"}
	main.hud.enter_museum(proj)
	await _wait(1.6)
	main.hud.visible = false
	var m: Node3D = main.hud._museum
	if m == null:
		print("HERO sem museu para ", pid)
		return
	var p = main.city.player
	var gp: Vector3 = m.global_transform * local_pos
	var gl: Vector3 = m.global_transform * local_look
	p.global_position = Vector3(gp.x, p.global_position.y, gp.z)
	await _wait(0.2)
	var d: Vector3 = gl - p.head.global_position
	var yaw := atan2(-d.x, -d.z)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	p._yaw = yaw
	p._pitch = pitch
	p.rotation.y = yaw
	p.head.rotation.x = pitch
	await _wait(1.4)
	_save(name)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _save(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	print("HERO ", name)
