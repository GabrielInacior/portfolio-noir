extends SceneTree
## Compara a pose de repouso dos esqueletos (anims.glb x personagens). Uso: godot --headless -s res://tools_dev/char_rest_probe.gd
func _skel(path: String) -> Skeleton3D:
	var n: Node = (load(path) as PackedScene).instantiate()
	root.add_child(n)
	return n.find_children("*", "Skeleton3D", true, false)[0]

func _find(s: Skeleton3D, suffix: String) -> int:
	for i in s.get_bone_count():
		var n := s.get_bone_name(i)
		if n == suffix or n.ends_with(":" + suffix) or n.ends_with("_" + suffix):
			return i
	return -1

func _init() -> void:
	await process_frame
	var src := _skel("res://assets/characters/meshy/anims.glb")
	var nm := []
	for i in src.get_bone_count(): nm.append(src.get_bone_name(i))
	print("SRC ", nm)
	for id in ["vance", "otto", "kai", "lena"]:
		var t := _skel("res://assets/characters/meshy/%s.glb" % id)
		var worst := 0.0
		var wn := ""
		var line := ""
		for bn in ["Hips", "Spine2", "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "LeftUpLeg", "Head"]:
			var bs := _find(src, bn)
			var bt := _find(t, bn)
			if bs < 0 or bt < 0:
				line += " %s:FALTA" % bn
				continue
			var qs := src.get_bone_global_rest(bs).basis.get_rotation_quaternion()
			var qt := t.get_bone_global_rest(bt).basis.get_rotation_quaternion()
			var ang := rad_to_deg(qs.angle_to(qt))
			line += " %s=%.0f" % [bn.replace("mixamorig:", ""), ang]
		var nt := []
		for i in t.get_bone_count(): nt.append(t.get_bone_name(i))
		print("T ", id, " ", nt)
		print(id, " bones=", t.get_bone_count(), " src=", src.get_bone_count(), " |", line)
	quit()
