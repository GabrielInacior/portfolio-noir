extends Node
func _m() -> int:
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576
func _ready() -> void:
	print("MEM0 ", _m())
	var main = load("res://scenes/city.tscn").instantiate()
	print("MEM load ", _m())
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	print("MEM +2.5s ", _m())
	var d := {}
	for dir in ["res://assets/ads","res://assets/billboards","res://assets/tex","res://assets/covers","res://assets/data/collages","res://assets/museum","res://assets/flyers","res://assets/tech_icons","res://assets/tech_strips","res://assets"]:
		_walk(dir, d)
	var arr := d.keys()
	arr.sort_custom(func(a, b): return d[a] > d[b])
	var tot := 0
	for k in arr:
		tot += d[k]
	print("TOTAL loaded KB ", tot / 1024)
	for k in arr.slice(0, 40):
		print("  LOADED %dKB %s" % [d[k] / 1024, k])
	get_tree().quit()
func _walk(dir: String, d: Dictionary) -> void:
	for f in DirAccess.get_files_at(dir):
		var p := dir + "/" + f.replace(".import", "")
		if f.ends_with(".import") and ResourceLoader.has_cached(p):
			var t = load(p)
			if t is Texture2D:
				d[p] = (t as Texture2D).get_image().get_data().size() if t.get_image() else 0
	for sub in DirAccess.get_directories_at(dir):
		_walk(dir + "/" + sub, d)
