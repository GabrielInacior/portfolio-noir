extends Node
## Prova da tela de diálogo com o personagem novo: abre a conversa com o primeiro NPC guia que achar
## na cidade e fotografa três expressões. Sempre muda.
## RUMOR_SHOT=<pasta> godot --audio-driver Dummy --path . --resolution WxH res://tools_dev/char_dialogue_shot.tscn

var main: Node
var dir := ""


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _save(n: String) -> void:
	get_viewport().get_texture().get_image().save_png(dir.path_join(n + ".png"))
	print("SHOT ", n)


func _ready() -> void:
	dir = OS.get_environment("RUMOR_SHOT")
	main = load("res://scenes/city.tscn").instantiate()
	add_child(main)
	await _wait(1.6)
	if main._gate:
		main.hud.visible = true
		main._gate.queue_free()
	await _wait(0.4)
	var npc: Node = null
	var want := OS.get_environment("NPC_KIND")
	for n in main.find_children("*", "Node3D", true, false):
		if n.get_script() == load("res://scripts/npc.gd"):
			if want == "" or str(n.ch.card.get("id", "")) == want:
				npc = n
				break
	if npc == null:
		# cidade sem guia montado agora: cria um guia avulso com o primeiro projeto
		var projs: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/projects.json"))
		var list: Array = projs if projs is Array else (projs as Dictionary).get("projects", [])
		npc = load("res://scripts/npc.gd").new()
		npc.setup(list[0])
	main.hud._open_dialogue(npc)
	await _wait(1.2)
	var dlg = main.hud.get_child(main.hud.get_child_count() - 1)
	_save("dlg_serio")
	if dlg and dlg._face:
		dlg._face.set_expression("desconfiado")
		dlg._say("Servidor autoritativo pra turma inteira ao mesmo tempo. Isso não é trivial.", "desconfiado")
		await _wait(1.4)
		_save("dlg_desconfiado")
		dlg._face.set_expression("sorriso_canto")
		dlg._say("Mas roda liso no navegador do celular. Pode testar.", "sorriso_canto")
		await _wait(1.4)
		_save("dlg_sorriso")
	get_tree().quit()
