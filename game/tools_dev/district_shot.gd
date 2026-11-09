extends Node
## Capturas do bairro (esquinas, beco, praça, lojas). Sempre mudo.
## RUMOR_SHOT=<pasta> godot --audio-driver Dummy --path . --resolution WxH res://tools_dev/district_shot.tscn
var main: Node
var dir := ""


func _ready() -> void:
	dir = OS.get_environment("RUMOR_SHOT")
	main = load("res://scenes/city.tscn").instantiate()
	add_child(main)
	await _wait(1.6)
	if main._gate:
		main.hud.visible = true
		main._gate.queue_free()
	await _wait(0.5)
	if OS.get_environment("NOLIGHTS") != "":
		for l in main.city.find_children("*", "Light3D", true, false):
			if not (l is DirectionalLight3D):
				(l as Light3D).visible = false
	var p = main.city.player
	var only := OS.get_environment("SHOTS")
	var shots := [
		[Vector3(0, 1.6, 5.0), 0.0, 0.02, "01_avenida"],
		[Vector3(-0.8, 1.6, -2.5), 1.05, 0.04, "02_loja_rumor"],
		[Vector3(1.0, 1.6, -31.0), 0.0, 0.08, "03_cruzamento"],
		[Vector3(-3.0, 1.6, -41.0), 1.5708, 0.05, "04_transversal_praca"],
		[Vector3(5.0, 1.6, -20.0), -1.5708, 0.04, "05_beco"],
		[Vector3(-47.0, 1.8, -42.0), 1.5708, 0.06, "06_praca"],
		[Vector3(0, 1.6, -52.0), 0.0, 0.1, "07_lab"],
		[Vector3(3.0, 1.6, -42.5), -1.5708, 0.05, "08_transversal_dir"],
		[Vector3(-14.0, 1.6, -40.5), 2.4, 0.05, "09_fortress"],
	]
	for s in shots:
		if only != "":
			var hit := false
			for tok in only.split(","):
				if str(s[3]).begins_with(tok):
					hit = true
			if not hit:
				continue
		p.global_position = s[0]
		p._yaw = s[1]
		p._pitch = s[2]
		p.rotation.y = s[1]
		p.head.rotation.x = s[2]
		await _wait(0.6)
		get_viewport().get_texture().get_image().save_png(dir.path_join(s[3] + ".png"))
		if OS.get_environment("SHARPSHOT") != "":
			main._sharp.vp.get_texture().get_image().save_png(dir.path_join(s[3] + "_sharp.png"))
			main._world_vp.get_texture().get_image().save_png(dir.path_join(s[3] + "_retro.png"))
		print("SHOT ", s[3])
	if OS.get_environment("PERF") != "":
		p.global_position = Vector3(0, 1.6, -30)
		p._yaw = 0.0
		await _wait(2.0)
		print("PERF fps=", Engine.get_frames_per_second(), " draws=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			" objs=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			" prims=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			" vram_mb=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576)
	get_tree().quit()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout
