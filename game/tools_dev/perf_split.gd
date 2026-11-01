extends Node
## Descobre o que pesa na rua: mede primitivas/draw calls escondendo um grupo por vez.
var main
func _ready() -> void:
	main = load("res://scenes/city.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	if main._gate: main.hud.visible = true; main._gate.queue_free()
	await get_tree().create_timer(0.5).timeout
	_r("tudo")
	var groups := {"MeshInstance3D": [], "MultiMeshInstance3D": [], "Skeleton3D": [], "Label3D": [], "GPUParticles3D": [], "CPUParticles3D": []}
	for k in groups:
		for n in main.city.find_children("*", k, true, false):
			groups[k].append(n)
	# personagens: nós com Skeleton3D (esconde o pai)
	for k in ["Skeleton3D", "MultiMeshInstance3D", "CPUParticles3D", "Label3D"]:
		var hidden := []
		for n in groups[k]:
			var t: Node3D = n.get_parent() if k == "Skeleton3D" else n
			if t.visible:
				t.visible = false
				hidden.append(t)
		await get_tree().create_timer(0.4).timeout
		_r("sem " + k + " (%d)" % hidden.size())
		for t in hidden: t.visible = true
	# maiores malhas soltas
	var big := []
	for n in groups["MeshInstance3D"]:
		var mi := n as MeshInstance3D
		if mi.mesh and mi.is_visible_in_tree():
			var tris := 0
			for s in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(s)
				var idx = arr[Mesh.ARRAY_INDEX]
				tris += (idx.size() / 3) if idx != null and idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX].size() / 3)
			big.append([tris, str(mi.get_path()).right(60)])
	big.sort_custom(func(a, b): return a[0] > b[0])
	for b in big.slice(0, 12): print("MALHA ", b[0], " ", b[1])
	var mm_tot := 0
	for n in groups["MultiMeshInstance3D"]:
		var mmi := n as MultiMeshInstance3D
		if mmi.multimesh and mmi.multimesh.mesh:
			var arr := mmi.multimesh.mesh.surface_get_arrays(0)
			var idx = arr[Mesh.ARRAY_INDEX]
			var tris: int = (idx.size() / 3) if idx != null and idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX].size() / 3)
			print("MULTI ", tris * mmi.multimesh.instance_count, " = ", tris, " x ", mmi.multimesh.instance_count, " ", mmi.name)
	get_tree().quit()
func _r(tag: String) -> void:
	await get_tree().process_frame
	print("SPLIT %s | dc=%d prims=%d" % [tag, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
