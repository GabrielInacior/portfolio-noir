extends Node
## Varredura de quebras: grade de vistas (olhando para cima, quinas de perto, telhados).
## RUMOR_SHOT=<pasta> TAG=<antes|depois> godot --path . --resolution 960x540 res://tools_dev/sweep_shot.tscn
var main: Node


func _ready() -> void:
	var dir := OS.get_environment("RUMOR_SHOT")
	var tag := OS.get_environment("TAG")
	main = load("res://scenes/city.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(1.6).timeout
	if main._gate:
		main.hud.visible = true
		main._gate.queue_free()
	main.hud.visible = false
	var p = main.city.player
	var views := [
		[Vector3(-5.5, 1.6, -3.0), 0.9, 0.7], [Vector3(5.5, 1.6, -12.0), -0.9, 0.8], [Vector3(-6.0, 1.6, -36.6), 2.2, 0.5],
		[Vector3(6.2, 1.6, -37.0), -2.3, 0.6], [Vector3(10.0, 1.6, -19.0), -1.2, 0.9], [Vector3(-47.0, 1.8, -30.0), 2.6, 0.4],
		[Vector3(0, 1.6, -60.0), 0.0, 0.5], [Vector3(30.0, 1.6, -40.0), -1.5, 0.3], [Vector3(-20.0, 1.6, -44.0), 0.0, 0.6],
	]
	var imgs := []
	for v in views:
		p.global_position = v[0]
		p._yaw = v[1]
		p._pitch = v[2]
		p.rotation.y = v[1]
		p.head.rotation.x = v[2]
		await get_tree().create_timer(0.35).timeout
		imgs.append(get_viewport().get_texture().get_image())
	var w: int = imgs[0].get_width() / 2
	var h: int = imgs[0].get_height() / 2
	var sheet := Image.create(w * 3, h * 3, false, Image.FORMAT_RGBA8)
	for i in imgs.size():
		var im: Image = imgs[i]
		im.resize(w, h)
		sheet.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % 3) * w, (i / 3) * h))
	sheet.save_png(dir.path_join("sweep_%s.png" % tag))
	print("SWEEP ", tag)
	get_tree().quit()
