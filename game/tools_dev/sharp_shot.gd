extends Node
## Prova de nitidez no visual retrô: telão (loja), outdoor da praça e letreiro neon, de perto.
var main
func _ready() -> void:
	var dir := OS.get_environment("RUMOR_SHOT")
	main = load("res://scenes/city.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(1.8).timeout
	if main._gate:
		main.hud.visible = true
		main._gate.queue_free()
	var p = main.city.player
	for s in [[Vector3(-47.0, 1.8, -42.0), 1.5708, 0.12, "outdoor"], [Vector3(-3.4, 1.6, -6.0), 1.5708, 0.25, "letreiro"]]:
		p.global_position = s[0]
		p._yaw = s[1]
		p._pitch = s[2]
		await get_tree().create_timer(1.0).timeout
		get_viewport().get_texture().get_image().save_png(dir.path_join("sharp_%s.png" % s[3]))
	main.hud.enter_museum(Data.projects[0])
	await get_tree().create_timer(1.2).timeout
	p = main.city.player
	p.global_position = Vector3(1.6, 1.6, 2.4)
	p._yaw = 0.35
	p._pitch = 0.1
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join("sharp_telao.png"))
	get_tree().quit()
