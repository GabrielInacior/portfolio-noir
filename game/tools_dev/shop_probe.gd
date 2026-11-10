extends Node
## Lojas: tempo da porta (quadro mais longo ao entrar), draws e CPU dentro, e capturas de pontos fixos.
## RUMOR_SHOT=<pasta> SHOPS=rumor,labia [SHOPNOIR=0] [TAG=motor] godot --audio-driver Dummy --path . --resolution 1280x720 res://tools_dev/shop_probe.tscn
var main: Node


func _ready() -> void:
	var dir := OS.get_environment("RUMOR_SHOT")
	var tag := OS.get_environment("TAG")
	if tag == "":
		tag = "x"
	main = load("res://scenes/city.tscn").instantiate()
	add_child(main)
	while main.hud == null or main._gate == null:
		await get_tree().process_frame
	await _wait(1.0)
	main._gate.entered.emit()
	await _wait(1.5)
	var shops := OS.get_environment("SHOPS")
	if shops == "":
		shops = "rumor,fortress,formataai,ankiana,labia,carreira"
	var list := Array(shops.split(","))
	if OS.get_environment("REPEAT") != "":
		list = list + list
	var pw := float(OS.get_environment("PREWAIT")) if OS.get_environment("PREWAIT") != "" else 0.0
	var tw0 := Time.get_ticks_msec()
	var cw := 0
	var cfr := []
	while Time.get_ticks_msec() - tw0 < pw * 1000.0:
		var a0 := Time.get_ticks_usec()
		await get_tree().process_frame
		cfr.append((Time.get_ticks_usec() - a0) / 1000)
		if cfr[-1] > 40:
			print("SHOPPROBE quadro lento %d ms em %d ms" % [cfr[-1], Time.get_ticks_msec()])
	cfr.sort()
	if not cfr.is_empty():
		print("SHOPPROBE cidade durante a pré-montagem: pior quadro %d ms, p95 %d ms, mediana %d ms" % [cfr[-1], cfr[int(cfr.size() * 0.95)], cfr[cfr.size() / 2]])
	for sid in list:
		var pj := {}
		if sid == "sobre":
			pj = {"id": "sobre", "title": "LAB", "special": "about"}
		elif sid == "carreira":
			pj = {"id": "carreira", "title": "CARREIRA", "special": "career"}
		else:
			for p in Data.projects:
				if str(p.get("id", "")) == sid:
					pj = p
		if pj.is_empty():
			continue
		var t0 := Time.get_ticks_usec()
		var worst := 0
		main.hud.enter_museum(pj)
		var fr := 0
		while main.hud._entering or fr < 3:
			var a := Time.get_ticks_usec()
			await get_tree().process_frame
			worst = maxi(worst, Time.get_ticks_usec() - a)
			fr += 1
		var enter_ms := (Time.get_ticks_usec() - t0) / 1000
		var mu = main.hud._museum
		var ls := []
		for l in mu.find_children("*", "Light3D", true, false):
			if (l as Light3D).is_visible_in_tree():
				ls.append("%s e=%.1f r=%.1f c=%s" % [l.get_class().substr(0, 4), l.light_energy, l.omni_range if l is OmniLight3D else l.spot_range, (l as Light3D).light_color.to_html(false)])
		print("SHOPLIGHTS %s %d: %s" % [sid, ls.size(), ", ".join(ls)])
		var p = main.city.player
		var dd: float = mu.D / 2
		var ww: float = mu.W / 2
		var views := [
			[Vector3(0, 1.6, dd - 1.4), Vector3(0, 1.4, -dd), "a"],
			[Vector3(ww - 0.6, 1.6, dd - 0.8), Vector3(-ww, 1.3, -1.0), "b"],
			[Vector3(-ww + 0.6, 1.6, -dd + 1.0), Vector3(ww, 1.3, dd), "c"],
		]
		var cpu := 0.0
		var cpu_max := 0.0
		var dcs := []
		for v in views:
			p.global_position = v[0]
			var to: Vector3 = v[1] - v[0]
			p._yaw = atan2(-to.x, -to.z)
			p._pitch = atan2(to.y, Vector2(to.x, to.z).length())
			p.rotation.y = p._yaw
			p.sync_look()
			var n := 0
			var acc := 0.0
			for i in 40:
				var a := Time.get_ticks_usec()
				await get_tree().process_frame
				var d := (Time.get_ticks_usec() - a) / 1000.0
				if i > 5:
					acc += RenderingServer.get_frame_setup_time_cpu()
					n += 1
					cpu_max = maxf(cpu_max, d)
			cpu += acc / maxf(1, n)
			var rid: RID = main._world_vp.get_viewport_rid()
			var rid2: RID = main._sharp.vp.get_viewport_rid()
			dcs.append("%d+%d" % [RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
				RenderingServer.viewport_get_render_info(rid2, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)])
			if OS.get_environment("CENSUS") != "" and v[2] == "a":
				print(preload("res://scripts/render/census.gd").run(main._world_vp, sid, []))
			if dir != "":
				get_viewport().get_texture().get_image().save_png(dir.path_join("%s_%s_%s.png" % [sid, v[2], tag]))
		print("SHOPPROBE %s enter=%d ms worst_frame=%.1f ms draws=%s setup_cpu=%.2f ms" % [sid, enter_ms, worst / 1000.0, ",".join(dcs), cpu / views.size()])
		main.hud.exit_museum()
		await _wait(0.6)
	get_tree().quit()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout
