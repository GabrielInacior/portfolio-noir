extends SceneTree
## Sonda do trânsito: simula 3 minutos acelerados com as faixas da cidade e confere, a cada passo,
## se algum par de carros se sobrepõe (retângulos x/z) ou se algum carro entra numa vaga.
##   godot --headless --path game --script res://tools_dev/traffic_probe.gd

func _init() -> void:
	var t = load("res://scripts/traffic.gd").new()
	var AVE_X := 4.5
	var CROSS_HW := 4.0
	var CROSS_Z := -42.0
	t.add_lane(Vector3(1.25, 0, 38), Vector3(1.25, 0, -102), "ave")
	t.add_lane(Vector3(-1.25, 0, -102), Vector3(-1.25, 0, 38), "ave")
	t.add_lane(Vector3(-73, 0, CROSS_Z - 1.25), Vector3(73, 0, CROSS_Z - 1.25), "cross")
	t.add_lane(Vector3(73, 0, CROSS_Z + 1.25), Vector3(-73, 0, CROSS_Z + 1.25), "cross")
	t.set_box(Rect2(-AVE_X, CROSS_Z - CROSS_HW, AVE_X * 2, CROSS_HW * 2))
	var placed := 0
	for i in 16:
		var n := Node3D.new()
		if t.add_car(n, i % 4, float(i / 4) * 30.0 + 7.0 * (i % 4), 5.1 + (i % 3) * 0.12):
			placed += 1
	var px := AVE_X - 1.05
	var pz := CROSS_HW - 0.95
	var parks := [Vector3(-px, 0, -13.5), Vector3(px, 0, -25), Vector3(-px, 0, -56), Vector3(px, 0, -8), Vector3(-px, 0, -31),
		Vector3(30, 0, CROSS_Z - pz), Vector3(-34, 0, CROSS_Z + pz), Vector3(22, 0, CROSS_Z + pz)]
	var park_rects := []
	var invalid := 0
	for p in parks:
		var yaw := 0.0 if absf(p.z - CROSS_Z) > 3.0 else PI / 2
		if not t.valid_parking(p, yaw):
			invalid += 1
			continue
		var ext := Vector2(2.05, 5.3) if absf(sin(yaw)) < 0.5 else Vector2(5.3, 2.05)
		park_rects.append(Rect2(Vector2(p.x, p.z) - ext * 0.5, ext))
	var steps := 0
	var overlaps := 0
	var park_hits := 0
	var dt := 1.0 / 30.0
	var moved := 0.0
	var player := Vector3(1.3, 0, -20)   # jogador parado na faixa por 20 s no meio da simulação
	for k in int(180.0 / dt):
		var pp = player if (k * dt > 60.0 and k * dt < 80.0) else null
		var before: Array = t.car_rects()
		t.step(dt, pp)
		var rs: Array = t.car_rects()
		for i in rs.size():
			moved += absf((rs[i] as Rect2).position.length() - (before[i] as Rect2).position.length())
			for j in range(i + 1, rs.size()):
				if (rs[i] as Rect2).grow(-0.05).intersects((rs[j] as Rect2).grow(-0.05)):
					overlaps += 1
			for pr in park_rects:
				if (rs[i] as Rect2).grow(-0.05).intersects(pr):
					park_hits += 1
		steps += 1
	print("TRAFEGO carros=%d passos=%d sobreposicoes=%d invadiu_vaga=%d vagas_invalidas=%d deslocamento_total=%.0f m" % [placed, steps, overlaps, park_hits, invalid, moved])
	quit(0 if overlaps == 0 and park_hits == 0 else 1)
