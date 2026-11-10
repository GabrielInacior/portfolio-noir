extends SceneTree
## mede o custo de carregar cada imagem grande (decodificação WebP + envio): uso headless
func _init() -> void:
	var pats := ["res://assets/ads", "res://assets/billboards", "res://assets/data/collages", "res://assets/flyers", "res://assets/tech_strips", "res://assets", "res://assets/tex"]
	var rows: Array = []
	for d in pats:
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".import"):
				var p: String = d + "/" + f.trim_suffix(".import")
				var t0 := Time.get_ticks_usec()
				var t = load(p)
				var dt := Time.get_ticks_usec() - t0
				if t is Texture2D:
					rows.append([dt, p, (t as Texture2D).get_width(), (t as Texture2D).get_height()])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	var tot := 0
	for r in rows:
		tot += r[0]
	print("total %d ms em %d imagens" % [tot / 1000, rows.size()])
	for r in rows.slice(0, 40):
		print("%6.1f ms  %s %dx%d" % [r[0] / 1000.0, r[1], r[2], r[3]])
	quit()
