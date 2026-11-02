extends Node
## Auditoria da UI/UX (mudo): entrada, rua com placas, NPC mirado, menu de lugares, mapa grande,
## diálogo, loja com tour, peça, painéis (terminal, skills, linha do tempo) e contato.
## RUMOR_SHOT=<pasta> TAG=<nome> godot --path . res://tools_dev/nav_ui_shot.tscn
var main: Node
var dir := ""
var tag := ""


func _ready() -> void:
	dir = OS.get_environment("RUMOR_SHOT")
	tag = OS.get_environment("TAG")
	main = load("res://scenes/city.tscn").instantiate()
	add_child(main)
	await _wait(2.0)
	await _save("00_entrada")
	main._gate.queue_free()
	main._gate = null
	main.hud.visible = true
	var hud = main.hud
	var p = main.city.player
	p.global_position = Vector3(0.5, 1.6, -2.0)
	p._yaw = 0.15
	p.rotation.y = 0.15
	await _wait(0.8)
	await _save("01_rua_placas")
	# NPC mirado
	if main.city.npcs.size() > 0:
		var n = main.city.npcs[0]
		var np: Vector3 = n.global_position
		var fw := Vector3(0, 0, 2.2)
		p.global_position = Vector3(np.x, 1.6, np.z) + fw.rotated(Vector3.UP, n.rotation.y)
		var to: Vector3 = np - p.global_position
		p._yaw = atan2(-to.x, -to.z)
		p.rotation.y = p._yaw
		await _wait(0.7)
		await _save("02_npc_mirado")
	hud._open_places()
	await _wait(0.8)
	await _save("03_lugares")
	_close_top(hud)
	await _wait(0.4)
	hud._open_map()
	await _wait(0.8)
	await _save("04_mapa")
	_close_top(hud)
	await _wait(0.4)
	if main.city.npcs.size() > 0:
		hud._open_dialogue(main.city.npcs[0])
		await _wait(1.8)
		await _save("05_dialogo")
		var d = hud.get_child(hud.get_child_count() - 1)
		d._close()
		await _wait(0.3)
	var rumor := {}
	for pr in Data.projects:
		if str(pr.get("id", "")) == "rumor":
			rumor = pr
	hud.enter_museum(rumor)
	await _wait(1.4)
	await _save("06_loja_tour")
	if hud._museum and hud._museum.items.size() > 0:
		hud._tour_step(1)
		await _wait(1.2)
		await _save("07_peca")
		_close_top(hud)
		await _wait(0.4)
	hud.exit_museum()
	var lab := {}
	for k in main.city.kiosks:
		if str(k["project"].get("special", "")) == "about":
			lab = k["project"]
	if not lab.is_empty():
		hud.enter_museum(lab)
		await _wait(1.2)
		for e in hud._museum.items:
			if str(e["item"].get("panel", "")) == "skills":
				hud._activate(e)
				await _wait(1.0)
				await _save("08_skills")
				_close_top(hud)
				break
		hud.exit_museum()
	for k in main.city.kiosks:
		if str(k["project"].get("special", "")) == "contact":
			hud.open_dossier(k["project"])
			await _wait(0.9)
			await _save("09_contato")
			_close_top(hud)
	get_tree().quit()


func _close_top(hud) -> void:
	for c in hud.get_children():
		if c is Sheet:
			c.close()
		elif c.get_child_count() > 0 and c.get_child(0) is Sheet:
			(c.get_child(0) as Sheet).close()
	hud._sheet_open = false


func _save(n: String) -> void:
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(dir.path_join(tag + "_" + n + ".png"))
	print("SHOT ", n)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout
