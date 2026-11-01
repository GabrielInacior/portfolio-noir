extends Node
## Captura a cidade de alguns pontos. Sempre muda.
## RUMOR_SHOT=<pasta> godot --audio-driver Dummy --path . --resolution WxH res://tools_dev/shot.tscn

var main: Node
var dir := ""


func _ready() -> void:
	dir = OS.get_environment("RUMOR_SHOT")
	main = load("res://scenes/city.tscn").instantiate()
	add_child(main)
	await _wait(1.6)
	# pula a porta de entrada e mostra a interface
	if main._gate:
		main.hud.visible = true
		main._gate.queue_free()
	await _wait(0.4)
	var city = main.city
	var player = city.player
	var shots := [
		[Vector3(0, 1.6, 2.5), 0.0, -0.04, "01_entrada"],
		[Vector3(-1.6, 1.6, -4.5), 0.55, 0.0, "02_rumor"],
		[Vector3(2.2, 1.6, -9.0), -0.7, 0.02, "03_vitrine"],
		[Vector3(0, 1.6, -16.0), 0.25, 0.1, "04_rua"],
		[Vector3(-7.2, 1.6, -7.0), -1.3, 0.05, "05_outdoor"],
		[Vector3(-1.2, 1.6, -5.0), 0.9, -0.02, "06_npc"],
	]
	for s in shots:
		player.global_position = s[0]
		player._yaw = s[1]
		player._pitch = s[2]
		player.rotation.y = s[1]
		player.head.rotation.x = s[2]
		await _wait(0.5)
		_save(s[3])
	main.hud.open_dossier(Data.projects[0])
	await _wait(0.7)
	_save("07_dossie")
	for c in main.hud.get_children():
		if c is Control and c.get_script() != null and c != main.hud.minimap:
			c.queue_free()
	await _wait(0.3)
	# tela de diálogo com close 3D e três expressões
	if city.npcs.size() > 0:
		main.hud._open_dialogue(city.npcs[0])
		await _wait(1.0)
		var dlg = main.hud.get_child(main.hud.get_child_count() - 1)
		_save("08_conversa_serio")
		if dlg and dlg._face:
			dlg._face.set_expression("desconfiado")
			dlg._say("Servidor autoritativo pra turma inteira ao mesmo tempo. Isso não é trivial.", "desconfiado")
			await _wait(1.2)
			_save("09_conversa_desconfiado")
			dlg._face.set_expression("satisfeito")
			dlg._say("Mas roda liso no navegador do celular. Pode testar.", "satisfeito")
			await _wait(1.2)
			_save("10_conversa_satisfeito")
	get_tree().quit()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _save(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	print("SHOT ", name)
