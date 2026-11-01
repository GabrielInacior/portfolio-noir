extends SceneTree
func _init() -> void:
	var m: Node3D = (load("res://assets/characters/noir_cast.glb") as PackedScene).instantiate()
	for mi in m.find_children("Cast_detetive", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			if mat and mat.resource_name.begins_with("M_face"):
				var arr := mesh.surface_get_arrays(s)
				print(mat.resource_name, " uv ", arr[Mesh.ARRAY_TEX_UV], " ", mat)
	quit()
