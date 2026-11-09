extends Node
## confere se a fusão com material noir mantém COLOR e CUSTOM0/1 (sonda de desenvolvimento)
func _ready() -> void:
	var root := Node3D.new()
	add_child(root)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.4, 0.6)
	m.emission_enabled = true
	m.emission = Color(1, 0, 0)
	m.emission_energy_multiplier = 2.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(0.2, 0.4, 0.6, 0.045)
	for i in 3:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		mi.mesh = bm
		mi.position = Vector3(i * 2, 0, 0)
		mi.material_override = load("res://scripts/render/noir.gd").conv(m)
		root.add_child(mi)
	await get_tree().process_frame
	var cm = load("res://scripts/render/noir.gd").conv(m)
	print("MT param=", cm.get_shader_parameter("albedo_color"), " ", typeof(cm.get_shader_parameter("albedo_color")))
	var dd = cm.duplicate()
	dd.set_shader_parameter("albedo_color", Color(1, 1, 1, 1))
	print("MT after dup set: orig=", cm.get_shader_parameter("albedo_color"))
	var r: Dictionary = await load("res://scripts/render/merge.gd").merge(root, [])
	print("MT ", r)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh:
			var arr: Array = mi.mesh.surface_get_arrays(0)
			print("MT fmt=", mi.mesh.surface_get_format(0), " colors=", (arr[Mesh.ARRAY_COLOR] as PackedColorArray).slice(0, 2) if arr[Mesh.ARRAY_COLOR] != null else "NONE", " c0=", arr[Mesh.ARRAY_CUSTOM0].slice(0, 4), " mat=", mi.material_override.get_meta("noir_kind", "?"), " p=", mi.material_override.get_shader_parameter("albedo_color"), " vc=", mi.material_override.get_shader_parameter("use_vc") if arr[Mesh.ARRAY_CUSTOM0] != null else "NONE")
	get_tree().quit()
