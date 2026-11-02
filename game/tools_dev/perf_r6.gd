extends Node
## Medida confiável do custo da rua: lê as estatísticas da SubViewport do mundo 3D
## (RenderingServer.viewport_get_render_info) com vários quadros de média, escondendo um grupo por vez.
## godot --audio-driver Dummy --path . --resolution WxH res://tools_dev/perf_r6.tscn
## PERF_POINTS=1 mede em 4 pontos da cidade; PF_RETRO=off|forte.
var main


func _ready() -> void:
	main = load("res://scenes/city.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	if main._gate:
		main.hud.visible = true
		main._gate.queue_free()
	await get_tree().create_timer(0.5).timeout
	var p = main.city.player
	var pts := [[Vector3(0, 1.6, -30), 0.0, "cruzamento"], [Vector3(-0.8, 1.6, -2.5), 1.05, "loja_rumor"],
		[Vector3(0, 1.6, 5.0), 0.0, "avenida"], [Vector3(-47.0, 1.8, -42.0), 1.5708, "praca"]]
	for pt in pts:
		p.global_position = pt[0]
		p._yaw = pt[1]
		p.rotation.y = pt[1]
		await get_tree().create_timer(0.8).timeout
		var base := await _measure()
		print("PONTO %s | dc=%d objs=%d prims=%d fps=%d" % [pt[2], base[0], base[1], base[2], Engine.get_frames_per_second()])
		if OS.get_environment("PERF_SPLIT") == "" or pt[2] != OS.get_environment("PERF_SPLIT"):
			continue
		_census()
		var groups := _groups()
		for gname in groups:
			var hidden: Array = []
			for n in groups[gname]:
				if n is Node3D and (n as Node3D).visible:
					(n as Node3D).visible = false
					hidden.append(n)
			var r := await _measure()
			print("  sem %-14s (%3d nós) dc=%d (-%d) prims=%d (-%d)" % [gname, hidden.size(), r[0], base[0] - r[0], r[2], base[2] - r[2]])
			for n in hidden:
				(n as Node3D).visible = true
	get_tree().quit()


## conta geometria visível perto da câmera por "família" (nome do pai) para achar o que gera draw calls
func _census() -> void:
	var cam := get_viewport().get_camera_3d() if main._world_vp == null else main._world_vp.get_camera_3d()
	var fam := {}
	for n in main.city.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var d := cam.global_position.distance_to(g.global_position)
		if g.visibility_range_end > 0.0 and d > g.visibility_range_end:
			continue
		if not cam.is_position_in_frustum(g.global_position):
			continue
		var key := g.get_class() + ":" + str(g.get_parent().name).left(18)
		fam[key] = fam.get(key, 0) + 1
	var arr := []
	for k in fam:
		arr.append([fam[k], k])
	arr.sort_custom(func(a, b): return a[0] > b[0])
	for a in arr.slice(0, 18):
		print("    CENSO ", a[0], " ", a[1])


func _groups() -> Dictionary:
	var c: Node = main.city
	var g := {"personagens": [], "multimesh": [], "particulas": [], "luzes_sombra": [], "label3d": [], "malhas": []}
	for n in c.find_children("*", "Skeleton3D", true, false):
		g["personagens"].append(n.get_parent())
	for n in c.find_children("*", "MultiMeshInstance3D", true, false):
		g["multimesh"].append(n)
	for n in c.find_children("*", "CPUParticles3D", true, false):
		g["particulas"].append(n)
	for n in c.find_children("*", "Label3D", true, false):
		g["label3d"].append(n)
	for n in c.find_children("*", "Light3D", true, false):
		if (n as Light3D).shadow_enabled:
			g["luzes_sombra"].append(n)
	for n in c.find_children("*", "MeshInstance3D", true, false):
		var inside_char := false
		var q: Node = n.get_parent()
		while q and q != c:
			if q is Skeleton3D:
				inside_char = true
				break
			q = q.get_parent()
		if not inside_char:
			g["malhas"].append(n)
	return g


## média de 10 quadros das estatísticas da SubViewport do mundo (inclui a passada de sombra)
func _measure() -> Array:
	var vp_rid: RID = main._world_vp.get_viewport_rid()
	var acc := [0, 0, 0]
	for _i in 10:
		await get_tree().process_frame
		acc[0] += RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME) \
			+ RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		acc[1] += RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)
		acc[2] += RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME) \
			+ RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	return [acc[0] / 10, acc[1] / 10, acc[2] / 10]
