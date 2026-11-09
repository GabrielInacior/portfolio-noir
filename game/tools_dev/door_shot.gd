extends Node
## Capturas dos marcadores de entrada: cada porta de perto (6 m, de frente e a 35 graus) e de longe (32 m).
## RUMOR_SHOT=<pasta> godot --audio-driver Dummy --path . --resolution 1280x720 res://tools_dev/door_shot.tscn
## DOORS=rumor,carreira limita; FAR=1 também tira a de longe.
var main: Node


func _ready() -> void:
	var dir := OS.get_environment("RUMOR_SHOT")
	main = load("res://scenes/city.tscn").instantiate()
	add_child(main)
	await _wait(1.6)
	if main._gate:
		main.hud.visible = true
		main._gate.queue_free()
	await _wait(0.5)
	var p = main.city.player
	var only := OS.get_environment("DOORS")
	for k in main.city.kiosks:
		if not k.has("marker"):
			continue
		var id := str(k["project"].get("id", ""))
		if only != "" and not (id in only.split(",")):
			continue
		var m: Vector3 = k["marker"]
		var n: Vector3 = k["normal"]
		n.y = 0.0
		n = n.normalized()
		var side := n.cross(Vector3.UP).normalized()
		var views := [["perto", n * 6.0], ["diag", n * 4.8 + side * 3.4]]
		if OS.get_environment("FAR") != "":
			views.append(["longe", n * 4.0 + side * 30.0])
		for v in views:
			var off: Vector3 = v[1]
			var pos := Vector3(m.x, 0, m.z) + off
			p.global_position = Vector3(pos.x, 1.6, pos.z)
			var to := m - Vector3(pos.x, 1.6, pos.z)
			p._yaw = atan2(-to.x, -to.z)
			p._pitch = atan2(to.y - 1.0, Vector2(to.x, to.z).length())
			p.rotation.y = p._yaw
			p.head.rotation.x = p._pitch
			await _wait(0.5)
			for md in get_tree().get_nodes_in_group("pf_modal"):
				(md as Node).queue_free()
			await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(dir.path_join("%s_%s.png" % [id, v[0]]))
			print("SHOT ", id, " ", v[0])
	get_tree().quit()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout
