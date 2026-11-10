extends Node
## Troca de idioma ao vivo: captura antes/depois na cidade e dentro de uma loja; tempo da troca.
## RUMOR_SHOT=<pasta> PF_LANG=en godot --audio-driver Dummy --path . --resolution 1280x720 res://tools_dev/lang_probe.tscn
var main: Node


func _ready() -> void:
	var dir := OS.get_environment("RUMOR_SHOT")
	main = load("res://scenes/city.tscn").instantiate()
	add_child(main)
	while main.hud == null or main._gate == null:
		await get_tree().process_frame
	await _wait(1.0)
	main._gate.entered.emit()
	await _wait(8.0)
	var to := "pt" if L.lang == "en" else "en"
	_save(dir, "cidade_antes")
	var pos: Vector3 = main.city.player.global_position
	L.set_lang(to)
	while L.busy:
		await get_tree().process_frame
	await _wait(0.8)
	_save(dir, "cidade_depois")
	print("LANGPROBE cidade %s: %d ms, posição mantida=%s" % [to, L.last_ms, pos.distance_to(main.city.player.global_position) < 0.01])
	for p in Data.projects:
		if str(p.get("id", "")) == "rumor":
			main.hud.enter_museum(p)
	while main.hud._entering:
		await get_tree().process_frame
	await _wait(1.0)
	_save(dir, "loja_antes")
	L.set_lang("pt" if L.lang == "en" else "en")
	while L.busy:
		await get_tree().process_frame
	await _wait(0.8)
	_save(dir, "loja_depois")
	print("LANGPROBE loja: %d ms, ainda na loja=%s" % [L.last_ms, main.hud._museum != null])
	get_tree().quit()


func _save(dir: String, n: String) -> void:
	if dir != "":
		get_viewport().get_texture().get_image().save_png(dir.path_join(n + ".png"))


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout
