extends Node
## Interface em vários tamanhos: HUD na rua, diálogo e modal de objeto. Sempre mudo.
## RUMOR_SHOT=<pasta> TAG=<nome> godot --path . --resolution WxH res://tools_dev/ui_shot.tscn
var main: Node


func _ready() -> void:
	var dir := OS.get_environment("RUMOR_SHOT")
	var tag := OS.get_environment("TAG")
	main = load("res://scenes/city.tscn").instantiate()
	add_child(main)
	await _wait(1.8)
	_save(dir, tag + "_0_entrada")
	if main._gate:
		main.hud.visible = true
		main._gate.queue_free()
	var p = main.city.player
	p.global_position = Vector3(-1.5, 1.6, -6.0)
	p._yaw = 1.1
	p.rotation.y = 1.1
	await _wait(0.8)
	_save(dir, tag + "_1_hud")
	if main.city.npcs.size() > 0:
		main.hud._open_dialogue(main.city.npcs[0])
		await _wait(1.6)
		_save(dir, tag + "_2_dialogo")
		var d = main.hud.get_child(main.hud.get_child_count() - 1)
		d._answer({"a": "Escrevi doze casos à mão. Servidor autoritativo pra turma inteira ao mesmo tempo, rodando no celular de cada aluno.", "expr": "desconfiado"})
		await _wait(3.2)
		_save(dir, tag + "_3_dialogo_resposta")
		d._close()
		await _wait(0.3)
	var rumor := {}
	for pr in Data.projects:
		if str(pr.get("id", "")) == "rumor":
			rumor = pr
	main.hud.enter_museum(rumor)
	await _wait(1.2)
	if main.hud._museum and main.hud._museum.items.size() > 0:
		main.hud._open_exhibit(main.hud._museum.items[0])
		await _wait(0.8)
		_save(dir, tag + "_4_modal")
	get_tree().quit()


func _save(dir: String, n: String) -> void:
	get_viewport().get_texture().get_image().save_png(dir.path_join(n + ".png"))
	print("SHOT ", n)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout
