extends SceneTree
func _init() -> void:
	var m: Node3D = (load("res://assets/characters/student.glb") as PackedScene).instantiate()
	root.add_child(m)
	var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
	print("SK path ", m.get_path_to(sk), " scale ", sk.global_transform.basis.get_scale())
	for i in sk.get_bone_count():
		var g := sk.get_bone_global_rest(i)
		print(i, " ", sk.get_bone_name(i), " ", g.origin.snapped(Vector3.ONE*0.001), " y-axis ", g.basis.y.normalized().snapped(Vector3.ONE*0.01))
	quit()
