extends RefCounted
class_name Traffic
## Trânsito sem física: carros só andam em FAIXAS fixas, mantêm distância do carro da frente,
## respeitam um semáforo lógico nos cruzamentos e param diante do jogador. Vagas de estacionamento
## são validadas para nunca invadir o corredor de uma faixa. Custo O(n) por faixa a cada quadro.
##
## Uso (city.gd):
##   traffic.add_lane(a, b, group)      -> índice da faixa (group: "ave" ou "cross")
##   traffic.set_box(rect_xz)           -> área do cruzamento (Rect2 em x/z)
##   traffic.add_car(node, lane, s)     -> carro na faixa a s metros do início
##   traffic.valid_parking(pos, yaw, size) -> false se a vaga invade alguma faixa
##   traffic.step(dt, player_pos)

const CAR_LEN := 5.3          # comprimento de referência (m)
const CAR_W := 2.05         # largura real dos modelos (com retrovisor)
const GAP := 2.2              # folga mínima entre para-choques (m)
const CRUISE := 8.5           # velocidade de cruzeiro (m/s)
const ACC := 4.0
const BRAKE := 9.0
const GREEN := 9.0            # segundos de verde por grupo
const ALL_RED := 2.5

var lanes: Array = []         # {a, b, len, dir, group, cars: []}
var box := Rect2()
var has_box := false
var phase := "ave"            # grupo com verde
var phase_t := 0.0
var all_red := 0.0


func add_lane(a: Vector3, b: Vector3, group: String) -> int:
	var d := b - a
	lanes.append({"a": a, "b": b, "len": d.length(), "dir": d.normalized(), "group": group, "cars": []})
	return lanes.size() - 1


func set_box(r: Rect2) -> void:
	box = r
	has_box = true


func add_car(node: Node3D, lane: int, s: float, length := CAR_LEN) -> bool:
	var ln: Dictionary = lanes[lane]
	for c in ln["cars"]:
		if absf(float(c["s"]) - s) < (length + float(c["len"])) * 0.5 + GAP:
			return false
	ln["cars"].append({"node": node, "s": s, "v": CRUISE * 0.8, "len": length, "vmax": CRUISE * randf_range(0.85, 1.1)})
	_place(ln, ln["cars"][-1])
	return true


## Corredor ocupado por uma faixa (retângulo no plano x/z, largura de um carro + margem).
func _lane_rect(ln: Dictionary) -> Rect2:
	var a: Vector3 = ln["a"]
	var b: Vector3 = ln["b"]
	var half := CAR_W * 0.5 + 0.03
	var mn := Vector2(minf(a.x, b.x), minf(a.z, b.z))
	var mx := Vector2(maxf(a.x, b.x), maxf(a.z, b.z))
	var dir: Vector3 = ln["dir"]
	if absf(dir.x) > absf(dir.z):
		mn.y -= half
		mx.y += half
	else:
		mn.x -= half
		mx.x += half
	return Rect2(mn, mx - mn)


func valid_parking(pos: Vector3, yaw: float, size := Vector2(CAR_W, CAR_LEN)) -> bool:
	var along_z := absf(sin(yaw)) < 0.5
	var ext := Vector2(size.x, size.y) if along_z else Vector2(size.y, size.x)
	var r := Rect2(Vector2(pos.x, pos.z) - ext * 0.5, ext)
	for ln in lanes:
		if _lane_rect(ln).intersects(r):
			return false
	if has_box and box.grow(1.0).intersects(r):
		return false
	return true


func _pos(ln: Dictionary, s: float) -> Vector3:
	return (ln["a"] as Vector3) + (ln["dir"] as Vector3) * s


func _place(ln: Dictionary, c: Dictionary) -> void:
	var n: Node3D = c["node"]
	n.position = _pos(ln, float(c["s"]))
	var d: Vector3 = ln["dir"]
	n.rotation.y = atan2(d.x, d.z)


## Distância (ao longo da faixa) até a linha de parada antes do cruzamento; INF se já passou/não cruza.
func _stop_dist(ln: Dictionary, c: Dictionary) -> float:
	if not has_box:
		return INF
	var front := float(c["s"]) + float(c["len"]) * 0.5
	# s de entrada no cruzamento (primeiro ponto da faixa dentro da caixa)
	var s_in: float = ln.get("s_in", -1.0)
	if s_in < 0.0:
		s_in = INF
		var L: float = ln["len"]
		var k := 0.0
		while k <= L:
			var p := _pos(ln, k)
			if box.has_point(Vector2(p.x, p.z)):
				s_in = k
				break
			k += 0.25
		ln["s_in"] = s_in
	if s_in == INF:
		return INF
	var stop := s_in - 0.6
	if front > s_in + 0.5:      # já entrou: segue em frente
		return INF
	return stop - front


func _box_has_other(group: String) -> bool:
	for ln in lanes:
		if ln["group"] == group:
			continue
		for c in ln["cars"]:
			var p := _pos(ln, float(c["s"]))
			if box.grow(CAR_LEN * 0.5).has_point(Vector2(p.x, p.z)):
				return true
	return false


func step(dt: float, player_pos = null) -> void:
	# semáforo lógico: um grupo por vez, com intervalo de tudo vermelho
	if has_box:
		if all_red > 0.0:
			all_red -= dt
			if all_red <= 0.0:
				phase = "cross" if phase == "ave" else "ave"
				phase_t = 0.0
		else:
			phase_t += dt
			if phase_t >= GREEN:
				all_red = ALL_RED
	for ln in lanes:
		var cars: Array = ln["cars"]
		cars.sort_custom(func(x, y): return float(x["s"]) > float(y["s"]))  # da frente para trás
		var L: float = ln["len"]
		for i in cars.size():
			var c: Dictionary = cars[i]
			var limit := INF
			# carro da frente na mesma faixa
			if i > 0:
				var f: Dictionary = cars[i - 1]
				limit = float(f["s"]) - float(f["len"]) * 0.5 - (float(c["s"]) + float(c["len"]) * 0.5) - GAP
			# semáforo / cruzamento ocupado pelo outro grupo
			var sd := _stop_dist(ln, c)
			if sd != INF and (all_red > 0.0 or phase != ln["group"] or _box_has_other(ln["group"])):
				limit = minf(limit, sd)
			# jogador na faixa à frente
			if player_pos != null:
				var pp: Vector3 = player_pos
				var rel: Vector3 = pp - _pos(ln, float(c["s"]))
				var ahead := rel.dot(ln["dir"])
				var side := (rel - (ln["dir"] as Vector3) * ahead).length()
				if ahead > 0.0 and ahead < 14.0 and side < CAR_W * 0.5 + 0.7:
					limit = minf(limit, ahead - float(c["len"]) * 0.5 - 1.5)
			# velocidade alvo pela distância livre (para suavemente antes do obstáculo)
			var v: float = c["v"]
			var target: float = c["vmax"]
			if limit < INF:
				target = minf(target, sqrt(maxf(0.0, 2.0 * BRAKE * 0.5 * maxf(0.0, limit))))
			if v < target:
				v = minf(target, v + ACC * dt)
			else:
				v = maxf(target, v - BRAKE * dt)
			var move := v * dt
			if limit < INF:
				move = minf(move, maxf(0.0, limit))   # nunca avança além do espaço livre
			c["v"] = v
			c["s"] = float(c["s"]) + move
		# carros que chegaram ao fim voltam ao começo só se houver espaço
		for c in cars:
			if float(c["s"]) > L:
				var ok := true
				for o in cars:
					if o != c and float(o["s"]) < float(c["len"]) + GAP + 1.0:
						ok = false
				if ok:
					c["s"] = 0.0
				else:
					c["s"] = L
					c["v"] = 0.0
			_place(ln, c)


## Retângulos (x/z) de todos os carros em movimento, para sondas de sobreposição.
func car_rects() -> Array:
	var out := []
	for ln in lanes:
		var d: Vector3 = ln["dir"]
		for c in ln["cars"]:
			var p := _pos(ln, float(c["s"]))
			var ext := Vector2(CAR_W, float(c["len"])) if absf(d.z) > absf(d.x) else Vector2(float(c["len"]), CAR_W)
			out.append(Rect2(Vector2(p.x, p.z) - ext * 0.5, ext))
	return out
