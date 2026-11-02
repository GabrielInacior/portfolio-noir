extends Node
## SONDA DAS SALAS (mudo): monta cada loja-museu e verifica
##  1) interação: cada objeto examinável é achado por nearest() de um ponto de pé alcançável na sala
##  2) posicionamento: objeto flutuando, enterrado, atravessando outro, fora da sala
##  3) vazio: fração do piso livre (grade 0,5 m) descontando o corredor de circulação
## e fotografa 4 cantos de cada sala. Uso:
##   ROOM_SHOT=<pasta> godot --audio-driver Dummy --path . --resolution 1280x720 res://tools_dev/room_probe.tscn
## ROOMS=rumor,_lab para limitar.
const Museum := preload("res://scripts/museum.gd")

var dir := ""
var report := []


func _ready() -> void:
	dir = OS.get_environment("ROOM_SHOT")
	var only := OS.get_environment("ROOMS")
	var files := Array(DirAccess.get_files_at("res://assets/museum/_items")).filter(func(f): return str(f).ends_with(".json"))
	files.sort()
	var tot_items := 0
	var tot_fail := 0
	for f in files:
		var id := str(f).trim_suffix(".json")
		if id == "sitembm":
			continue
		if only != "" and not (only.split(",") as PackedStringArray).has(id):
			continue
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/museum/_items/" + f))
		var proj := {"id": id, "title": id.to_upper()}
		if id == "_lab":
			proj = {"id": "_lab", "title": "LAB", "special": "about"}
		elif id == "_carreira":
			proj = {"id": "_carreira", "title": "CARREIRA", "special": "career"}
		var m = Museum.new()
		m.setup(proj, d, id == "_lab")
		add_child(m)
		for _i in 4:
			await get_tree().process_frame
		var r := _check(m, id)
		tot_items += r["items"]
		tot_fail += r["fail"].size()
		print("SALA %-12s itens=%2d interacao_falhas=%d flutuando=%d enterrados=%d atravessando=%d fora=%d piso_livre=%.0f%%" % [
			id, r["items"], r["fail"].size(), r["float"].size(), r["buried"].size(), r["overlap"].size(), r["out"].size(), r["free"] * 100.0])
		for k in ["fail", "float", "buried", "overlap", "out"]:
			for x in (r[k] as Array).slice(0, 6):
				print("   ", k, ": ", x)
		if dir != "":
			await _shots(m, id)
		m.queue_free()
		await get_tree().process_frame
	print("TOTAL interação: %d de %d OK" % [tot_items - tot_fail, tot_items])
	get_tree().quit()


func _check(m, id: String) -> Dictionary:
	var W: float = m.W
	var D: float = m.D
	var H: float = m.H
	var b: Rect2 = m.bounds()
	# 1) interação
	var fail := []
	for e in m.items:
		var ep: Vector3 = e["pos"]
		var ok := false
		var center := Vector3(0, 1.6, 0)
		for dist in [1.4, 1.0, 2.0, 0.7, 2.6]:
			for ang in [0.0, 0.5, -0.5, 1.0, -1.0]:
				var away := Vector3(center.x - ep.x, 0, center.z - ep.z)
				if away.length() < 0.01:
					away = Vector3(0, 0, 1)
				away = away.normalized().rotated(Vector3.UP, ang)
				var st := Vector3(ep.x, 1.6, ep.z) + away * dist
				st.x = clampf(st.x, b.position.x, b.end.x)
				st.z = clampf(st.z, b.position.y, b.end.y)
				var fw := Vector3(ep.x - st.x, 0, ep.z - st.z)
				if fw.length() < 0.05:
					continue
				var got: Dictionary = m.nearest(st, fw.normalized())
				if not got.is_empty() and got["node"] == e["node"]:
					ok = true
					break
			if ok:
				break
		if not ok:
			fail.append(str(e["item"].get("title", e["item"].get("id", "?"))))
	# 2) posicionamento: objetos "soltos" (não estrutura)
	var boxes := []
	for n in m.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var a := mi.global_transform * mi.get_aabb()
		var s := a.size
		# estrutura (parede/piso/teto/rodapé longo) e itens finos de parede ficam de fora
		if s.x > W * 0.6 or s.z > D * 0.6 or s.y > H * 0.85:
			continue
		if s.length() < 0.12:
			continue
		boxes.append({"a": a, "n": str(mi.get_parent().name) + "/" + str(mi.name)})
	var flt := []
	var bur := []
	var ovl := []
	var out := []
	for i in boxes.size():
		var a: AABB = boxes[i]["a"]
		var c := a.get_center()
		if a.position.y < -0.06:
			bur.append(boxes[i]["n"])
		if absf(c.x) > W / 2 + 0.05 or absf(c.z) > D / 2 + 0.05:
			out.append(boxes[i]["n"])
		var near_wall := absf(a.position.x) > W / 2 - 0.35 or absf(a.end.x) > W / 2 - 0.35 or absf(a.position.z) > D / 2 - 0.35 or absf(a.end.z) > D / 2 - 0.35
		var hang := a.end.y > H - 0.25
		if a.position.y > 0.08 and not near_wall and not hang:
			var supported := false
			for j in boxes.size():
				if i == j:
					continue
				var o: AABB = boxes[j]["a"]
				if o.end.y <= a.position.y + 0.08 and o.end.y >= a.position.y - 0.6 \
						and o.position.x < a.end.x and o.end.x > a.position.x and o.position.z < a.end.z and o.end.z > a.position.z:
					supported = true
					break
			if not supported:
				flt.append(boxes[i]["n"] + " (y=%.2f)" % a.position.y)
	# atravessando: pares grandes com interseção relevante (ignora peças do mesmo objeto)
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			var ni: String = boxes[i]["n"]
			var nj: String = boxes[j]["n"]
			if ni.get_slice("/", 0) == nj.get_slice("/", 0):
				continue
			var A: AABB = boxes[i]["a"]
			var B: AABB = boxes[j]["a"]
			if not A.intersects(B):
				continue
			var I := A.intersection(B)
			var vi := I.get_volume()
			var vm := minf(A.get_volume(), B.get_volume())
			if vm > 0.02 and vi / vm > 0.45 and minf(A.size.y, B.size.y) > 0.3:
				ovl.append(ni + " x " + nj)
	# 3) vazio: grade de 0,5 m no piso (fora do corredor central de 1,2 m até a porta)
	var cells := 0
	var free := 0
	var x := -W / 2 + 0.75
	while x < W / 2 - 0.5:
		var z := -D / 2 + 0.75
		while z < D / 2 - 0.5:
			if absf(x) > 0.7:
				cells += 1
				var hit := false
				for bx in boxes:
					var a: AABB = bx["a"]
					if a.position.y < 1.2 and x + 0.25 > a.position.x and x - 0.25 < a.end.x and z + 0.25 > a.position.z and z - 0.25 < a.end.z:
						hit = true
						break
				if not hit:
					free += 1
			z += 0.5
		x += 0.5
	return {"items": m.items.size(), "fail": fail, "float": flt, "buried": bur, "overlap": ovl, "out": out,
		"free": float(free) / maxf(1, cells)}


func _shots(m, id: String) -> void:
	var cam := Camera3D.new()
	cam.fov = 78
	m.add_child(cam)
	cam.current = true
	var W: float = m.W
	var D: float = m.D
	var corners := [Vector3(W / 2 - 0.6, 1.7, D / 2 - 0.6), Vector3(-W / 2 + 0.6, 1.7, D / 2 - 0.6),
		Vector3(W / 2 - 0.6, 1.7, -D / 2 + 0.6), Vector3(-W / 2 + 0.6, 1.7, -D / 2 + 0.6)]
	var i := 0
	for c in corners:
		cam.position = c
		cam.look_at(Vector3(-c.x * 0.3, 1.1, -c.z * 0.3), Vector3.UP)
		for _k in 3:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(dir.path_join("%s_%d.png" % [id, i]))
		i += 1
	cam.queue_free()
