extends Node
## Prova DENTRO DO JOGO das animações: abre a cidade real, acha os NPCs (os 4 personagens), põe uma
## câmera em close de frente e em 3/4 na rua e abre a tela de diálogo, tocando cada animação.
## Sempre mudo.
##   RUMOR_SHOT=<pasta> godot --audio-driver Dummy --path . --resolution 900x1100 res://tools_dev/char_ingame_shot.tscn

const ANIMS := ["idle", "respirando", "falando", "perguntando", "pensativo", "sim", "nao", "olhando", "apontando", "bartender", "fumando", "andando"]
var main: Node
var dir := ""


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _save(n: String) -> void:
	get_viewport().get_texture().get_image().save_png(dir.path_join(n + ".png"))


func _ready() -> void:
	dir = OS.get_environment("RUMOR_SHOT")
	main = load("res://scenes/city.tscn").instantiate()
	add_child(main)
	await _wait(1.6)
	if main.get("_gate") and main._gate:
		main.hud.visible = true
		main._gate.queue_free()
	await _wait(0.4)
	var seen := {}
	var npcs: Array = []
	for n in main.find_children("*", "Node3D", true, false):
		if n.get_script() == load("res://scripts/npc.gd") and n.get("ch") != null:
			var id := str(n.ch.card.get("id", ""))
			if not seen.has(id):
				seen[id] = true
				npcs.append(n)
	print("NPCS ", seen.keys())
	var cam := Camera3D.new()
	cam.fov = 35
	# o mundo 3D agora renderiza numa SubViewport retrô (main.gd): a câmera de prova vai para lá
	var world_parent: Node = main.get("_world_vp") if main.get("_world_vp") != null else main
	world_parent.add_child(cam)
	for npc in npcs:
		var ch: Node3D = npc.ch
		var id := str(ch.card.get("id", ""))
		var ap: AnimationPlayer = ch.anim
		cam.current = true
		for an in ANIMS:
			if ap == null:
				continue
			# pelo play() do personagem: as trocas por personagem (SAFE_ANIMS/SUBST) valem como no jogo
			ch.play(an)
			ap.playback_default_blend_time = 0.0
			var cur := ap.current_animation
			for view in ["frente", "34"]:
				var fwd: Vector3 = ch.global_transform.basis.z.normalized()
				var side: Vector3 = ch.global_transform.basis.x.normalized()
				var dir_v: Vector3 = fwd if view == "frente" else (fwd + side).normalized()
				var target: Vector3 = ch.global_position + Vector3(0, 1.15, 0)
				cam.global_position = target + dir_v * 2.3 + Vector3(0, 0.1, 0)
				cam.look_at(target)
				for frac in [0.35, 0.75]:
					ap.seek(ap.get_animation(cur).length * frac, true)
					await get_tree().process_frame
					await get_tree().process_frame
					_save("rua_%s_%s_%s_%d" % [id, an, view, int(frac * 100)])
		cam.current = false
		# tela de diálogo com o mesmo personagem
		main.hud._open_dialogue(npc)
		await _wait(1.0)
		var dlg = main.hud.get_child(main.hud.get_child_count() - 1)
		if dlg and dlg.get("_face"):
			var f: Node3D = dlg._face
			for an in ["falando", "perguntando", "apontando"]:
				f.play(an)
				for k in 2:
					await _wait(0.7)
					_save("dlg_%s_%s_%d" % [id, an, k])
		if dlg and dlg.has_method("_close"):
			dlg._close()
		await _wait(0.4)
		print("OK ", id)
	get_tree().quit()
