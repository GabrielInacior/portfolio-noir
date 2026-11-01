extends SceneTree
## Converte a biblioteca comum de animações (anims.glb, gravada no esqueleto do Vance) para o
## esqueleto de CADA personagem, respeitando a pose de repouso de cada um. Sem isso, a mesma rotação
## local aplicada a um esqueleto com repouso diferente torce ombros e braços.
##
## Para cada osso b: C(b) = Gs(b)^-1 * Gt(b)  (Gs/Gt = rotação global de repouso na origem/destino)
## rotação local no destino: qt(b) = C(pai)^-1 * qs(b) * C(b)
## Equivale a aplicar no destino a mesma rotação global "a partir do repouso" que a origem faz.
## Posição só no quadril: repouso do destino + deslocamento da origem escalado pelo comprimento da perna.
##
## Uso (mudo): godot --headless --audio-driver Dummy --path game -s res://tools_dev/char_bake_anims.gd
## Saída: res://assets/characters/meshy/anims_<id>.res (uma biblioteca por personagem)

var _moved := 0
const SRC := "res://assets/characters/meshy/anims.glb"
const IDS := ["vance", "otto", "kai", "lena"]
## "Espaço dos braços" (como o ajuste Character Arm-Space da Mixamo): as animações foram gravadas
## para um corpo magro; em quem tem sobretudo ou tronco largo o braço atravessaria o corpo. Abre
## o braço para fora (em graus, no eixo da frente do personagem) e um pouco o antebraço.
const ARM_OPEN := {"vance": 9.0, "otto": 9.0, "kai": 6.0, "lena": 4.0}
const FORE_OPEN := {"vance": 11.0, "otto": 9.0, "kai": 6.0, "lena": 4.0}


func _skel_of(path: String) -> Skeleton3D:
	var n: Node = (load(path) as PackedScene).instantiate()
	root.add_child(n)
	return n.find_children("*", "Skeleton3D", true, false)[0]


func _leg(s: Skeleton3D) -> float:
	var u := s.find_bone("mixamorig_LeftUpLeg")
	var f := s.find_bone("mixamorig_LeftFoot")
	return s.get_bone_global_rest(u).origin.distance_to(s.get_bone_global_rest(f).origin)


## rotação de repouso NO MUNDO (inclui a orientação do nó do esqueleto: a Mixamo põe 90° no nó,
## o rig feito no Blender não)
func _grest(s: Skeleton3D, i: int) -> Quaternion:
	return (s.global_transform.basis.orthonormalized() * s.get_bone_global_rest(i).basis.orthonormalized()).get_rotation_quaternion()


func _skq(s: Skeleton3D) -> Quaternion:
	return s.global_transform.basis.orthonormalized().get_rotation_quaternion()


func _track(an: Animation, bone: String) -> int:
	return an.find_track(NodePath("%SKEL:" + bone), Animation.TYPE_ROTATION_3D)


## rotação global (no mundo) de um osso no instante t, percorrendo a hierarquia (cinemática direta)
func _gpose(an: Animation, ts: Skeleton3D, bi: int, t: float) -> Quaternion:
	var chain: Array[int] = []
	var b := bi
	while b >= 0:
		chain.push_front(b)
		b = ts.get_bone_parent(b)
	var g := _skq(ts)
	for c in chain:
		var tr := _track(an, ts.get_bone_name(c))
		var q: Quaternion = an.rotation_track_interpolate(tr, t) if tr >= 0 else ts.get_bone_rest(c).basis.get_rotation_quaternion()
		g = g * q
	return g


## "Espaço dos braços" dependente da pose: em cada quadro empurra braço e antebraço para longe do
## tronco (gira a direção do osso em direção ao lado de fora do corpo). Forte quando o braço está
## colado ou cruzando o corpo; some quando ele já está aberto. Corpo largo (sobretudo) precisa mais.
func _open_arms(an: Animation, ts: Skeleton3D, id: String) -> void:
	var arm_deg: float = ARM_OPEN.get(id, 0.0)
	var fore_deg: float = FORE_OPEN.get(id, 0.0)
	if arm_deg == 0.0 and fore_deg == 0.0:
		return
	var sp2 := ts.find_bone("mixamorig_Spine2")
	for side in ["Left", "Right"]:
		var arm_i := ts.find_bone("mixamorig_" + side + "Arm")
		var fore_i := ts.find_bone("mixamorig_" + side + "ForeArm")
		var hand_i := ts.find_bone("mixamorig_" + side + "Hand")
		var sh_i := ts.get_bone_parent(arm_i)
		var ta := _track(an, "mixamorig_" + side + "Arm")
		var tf := _track(an, "mixamorig_" + side + "ForeArm")
		if ta < 0 or tf < 0:
			print("  sem trilha de braço ", side, " ", ta, " ", tf)
			continue
		# eixos em repouso: direção do osso (até o filho) e o "lado de fora" (do peito ao ombro)
		var ax_arm := ts.get_bone_rest(fore_i).origin.normalized()
		var ax_fore := ts.get_bone_rest(hand_i).origin.normalized()
		var w := ts.global_transform
		var lat_rest := ((w * ts.get_bone_global_rest(arm_i).origin) - (w * ts.get_bone_global_rest(sp2).origin))
		lat_rest.y = 0.0
		lat_rest = lat_rest.normalized()
		var sp2_rest := _grest(ts, sp2)
		for pass_i in 2:
			var tr := ta if pass_i == 0 else tf
			var deg := arm_deg if pass_i == 0 else fore_deg
			var bi := arm_i if pass_i == 0 else fore_i
			var ax := ax_arm if pass_i == 0 else ax_fore
			var vals: Array = []
			for k in an.track_get_key_count(tr):
				var t := an.track_get_key_time(tr, k)
				var gpar := _gpose(an, ts, ts.get_bone_parent(bi), t)
				var q: Quaternion = an.track_get_key_value(tr, k)
				var g := gpar * q
				var dir := (g * ax).normalized()
				var lat := (_gpose(an, ts, sp2, t) * sp2_rest.inverse()) * lat_rest
				var d := dir.dot(lat)
				var f := clampf((0.75 - d) / 0.75, 0.0, 1.0)
				var axis := dir.cross(lat)
				if axis.length() < 0.001 or f <= 0.0:
					vals.append(q)
					continue
				var r := Quaternion(axis.normalized(), deg_to_rad(deg) * f)
				vals.append((gpar.inverse() * r * g).normalized())
			for k in vals.size():
				an.track_set_key_value(tr, k, vals[k])
			_moved += vals.size()


var _torso := {}
var _fixed_total := 0
## Animações que não servem em pé, sem cenário (encostar precisa de parede, sentar e digitar
## precisam de cadeira): não entram na biblioteca; o personagem usa outra no lugar (noir_character.gd).
const DROP := ["encostado", "sentado", "digitando"]
const TORSO_SCALE := {"lena": 0.78}


## pose global (no espaço do esqueleto) de um osso no instante t, cinemática direta com as trilhas
func _gxf(an: Animation, ts: Skeleton3D, bi: int, t: float) -> Transform3D:
	var chain: Array[int] = []
	var b := bi
	while b >= 0:
		chain.push_front(b)
		b = ts.get_bone_parent(b)
	var x := Transform3D.IDENTITY
	for c in chain:
		var rest := ts.get_bone_rest(c)
		var nm := ts.get_bone_name(c)
		var tr := an.find_track(NodePath("%SKEL:" + nm), Animation.TYPE_ROTATION_3D)
		var q: Quaternion = an.rotation_track_interpolate(tr, t) if tr >= 0 else rest.basis.get_rotation_quaternion()
		var o := rest.origin
		var tp := an.find_track(NodePath("%SKEL:" + nm), Animation.TYPE_POSITION_3D)
		if tp >= 0:
			o = an.position_track_interpolate(tp, t)
		x = x * Transform3D(Basis(q), o)
	return x


## Volume do tronco medido na malha em repouso (espaço do esqueleto): elipse por altura, metade da
## largura (x) e da profundidade para a frente e para trás, da cintura ao pescoço. Braços ficam de
## fora (só vértices perto do eixo do corpo entram na medida).
func _measure_torso(ts: Skeleton3D) -> Dictionary:
	var root_n: Node = ts
	while root_n.get_parent() != null and root_n.get_parent() != root:
		root_n = root_n.get_parent()
	var inv := ts.global_transform.affine_inverse()
	var hips := ts.get_bone_global_rest(ts.find_bone("mixamorig_Hips")).origin
	var neck := ts.get_bone_global_rest(ts.find_bone("mixamorig_Neck")).origin
	var toe := ts.get_bone_global_rest(ts.find_bone("mixamorig_LeftToeBase")).origin
	var front_pos := toe.z > hips.z
	# perfil por altura (6 fatias da cintura ao pescoço): barriga é mais rasa que o peito
	const NB := 6
	var y0 := hips.y + 0.12
	var y1 := neck.y - 0.02
	var bx: Array = []
	var bf: Array = []
	var bb: Array = []
	for _k in NB:
		bx.append([])
		bf.append([])
		bb.append([])
	for mi in root_n.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		var xf := inv * m3.global_transform
		for si in m3.mesh.get_surface_count():
			var arr: Array = m3.mesh.surface_get_arrays(si)
			for v in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var p: Vector3 = xf * v
				if p.y < y0 or p.y > y1:
					continue
				var dx := p.x - hips.x
				if absf(dx) > 0.2:
					continue
				var k := clampi(int((p.y - y0) / (y1 - y0) * NB), 0, NB - 1)
				(bx[k] as Array).append(absf(dx))
				var dz := p.z - hips.z
				if (dz > 0) == front_pos:
					(bf[k] as Array).append(absf(dz))
				else:
					(bb[k] as Array).append(absf(dz))
	# largura: a mão e o braço pendentes entram na faixa e inflariam a medida; limita pelo ombro
	var sh := ts.get_bone_global_rest(ts.find_bone("mixamorig_LeftArm")).origin
	var rxs: Array = []
	var rfs: Array = []
	var rbs: Array = []
	for k in NB:
		(bx[k] as Array).sort()
		(bf[k] as Array).sort()
		(bb[k] as Array).sort()
		rxs.append(minf(_pq(bx[k], 0.75), absf(sh.x - hips.x) * 0.8))
		rfs.append(clampf(_pq(bf[k], 0.8), 0.06, 0.16))
		rbs.append(clampf(_pq(bb[k], 0.8), 0.06, 0.15))
	return {"rx": rxs, "rf": rfs, "rb": rbs, "fz": 1.0 if front_pos else -1.0, "y0": y0, "y1": y1,
		"hy": hips.y, "ny": neck.y}


func _pq(a: Array, q: float) -> float:
	return float(a[int(a.size() * q)]) if not a.is_empty() else 0.15


func _p95(a: Array) -> float:
	return float(a[int(a.size() * 0.95)]) if not a.is_empty() else 0.15


## posição do ponto em relação ao eixo do tronco, normalizada pela elipse (y = 1 na superfície)
func _ell(p: Vector3, c: Vector3, yaw_q: Quaternion, tv: Dictionary, pad: float, frac := 0.5) -> Vector3:
	var l := yaw_q.inverse() * (p - c)
	# fatia do perfil: altura equivalente no repouso (fração entre quadril e pescoço)
	var yr := float(tv["hy"]) + frac * (float(tv["ny"]) - float(tv["hy"]))
	var nb := (tv["rx"] as Array).size()
	var k := clampi(int((yr - float(tv["y0"])) / (float(tv["y1"]) - float(tv["y0"])) * nb), 0, nb - 1)
	var rz: float = (tv["rf"] as Array)[k] if l.z * float(tv["fz"]) > 0 else (tv["rb"] as Array)[k]
	var ex := l.x / (float((tv["rx"] as Array)[k]) + pad)
	var ez := l.z / (rz + pad)
	return Vector3(ex, sqrt(ex * ex + ez * ez), ez)


## Restrição de distância mínima braço x tronco, assada nas chaves: em cada quadro, se o cotovelo,
## o meio do antebraço, o punho ou a ponta da mão estiver dentro do volume do tronco (mais a
## grossura do braço), gira o braço (cotovelo) e depois o antebraço o mínimo para tirar o ponto.
func _avoid_torso(an: Animation, ts: Skeleton3D, tv: Dictionary) -> void:
	var hips_i := ts.find_bone("mixamorig_Hips")
	var neck_i := ts.find_bone("mixamorig_Neck")
	var hips_rest_q := ts.get_bone_global_rest(hips_i).basis.get_rotation_quaternion()
	for side in ["Left", "Right"]:
		var arm_i := ts.find_bone("mixamorig_" + side + "Arm")
		var fore_i := ts.find_bone("mixamorig_" + side + "ForeArm")
		var hand_i := ts.find_bone("mixamorig_" + side + "Hand")
		# 0: braço afasta o cotovelo; 1: antebraço afasta punho e mão; 2: braço de novo, agora pela
		# mão (quando só o antebraço não consegue, o braço inteiro abre)
		for pass_i in 3:
			var bi := arm_i if pass_i != 1 else fore_i
			var tr := an.find_track(NodePath("%SKEL:" + ts.get_bone_name(bi)), Animation.TYPE_ROTATION_3D)
			if tr < 0:
				continue
			for k in an.track_get_key_count(tr):
				var t := an.track_get_key_time(tr, k)
				for _iter in 10:
					var hx := _gxf(an, ts, hips_i, t)
					var nx := _gxf(an, ts, neck_i, t)
					var yq := hx.basis.get_rotation_quaternion() * hips_rest_q.inverse()
					var fwd := yq * Vector3(0, 0, 1)
					fwd.y = 0.0
					var yaw := atan2(fwd.x, fwd.z) if fwd.length() > 0.01 else 0.0
					var yaw_q := Quaternion(Vector3.UP, yaw)
					var bx := _gxf(an, ts, bi, t)
					var pivot := bx.origin
					var pts: Array = []
					var fo_o := _gxf(an, ts, fore_i, t).origin
					if pass_i == 0:
						pts = [[fo_o, 0.05]]
					else:
						var hxf := _gxf(an, ts, hand_i, t)
						var tip := hxf.origin + (hxf.origin - fo_o).normalized() * 0.16
						pts = [[hxf.origin, 0.035], [tip, 0.02], [fo_o.lerp(hxf.origin, 0.5), 0.045]]
						if pass_i == 2:
							pts.append([fo_o, 0.05])
					var worst := 0.0
					var target := Vector3.ZERO
					var src := Vector3.ZERO
					for pp in pts:
						var p: Vector3 = pp[0]
						var a := (p.y - hx.origin.y) / maxf(nx.origin.y - hx.origin.y, 0.01)
						var yr := float(tv["hy"]) + a * (float(tv["ny"]) - float(tv["hy"]))
						if yr < float(tv["y0"]) or yr > float(tv["y1"]):
							continue
						a = clampf(a, 0.0, 1.0)
						var c := hx.origin.lerp(nx.origin, a)
						c.y = p.y
						var e := _ell(p, c, yaw_q, tv, float(pp[1]), a)
						# só o que cruza o corpo (na frente ou atrás do tronco); mão ao lado da coxa
						# ou braço encostado de lado é postura normal, não atravessa
						if absf(e.x) > 0.78:
							continue
						if e.y < 1.0 and (1.0 - e.y) > worst:
							worst = 1.0 - e.y
							var l := yaw_q.inverse() * (p - c)
							var out := l / maxf(e.y, 0.05) * 1.03
							if e.y < 0.05:
								out = Vector3(0, 0, 0.2 * float(tv["fz"]))
							out.y = l.y
							target = c + yaw_q * out
							src = p
					if worst <= 0.0 or (src - pivot).length() < 0.03 or (target - pivot).length() < 0.03:
						break
					var v0 := (src - pivot).normalized()
					var v1 := (target - pivot).normalized()
					if v0.dot(v1) > 0.99999:
						break
					var rw := Quaternion(v0, v1)
					var gpar := _gxf(an, ts, ts.get_bone_parent(bi), t).basis.get_rotation_quaternion()
					var q: Quaternion = an.track_get_key_value(tr, k)
					an.track_set_key_value(tr, k, (gpar.inverse() * rw * gpar * q).normalized())
					_fixed_total += 1


## Prova numérica: amostra a animação a cada 0,1 s e devolve a maior penetração (m) de cotovelo,
## punho, meio do antebraço ou ponta da mão no volume do tronco (sem a folga da grossura do braço).
func _residual(an: Animation, ts: Skeleton3D, tv: Dictionary) -> float:
	var hips_i := ts.find_bone("mixamorig_Hips")
	var neck_i := ts.find_bone("mixamorig_Neck")
	var hips_rest_q := ts.get_bone_global_rest(hips_i).basis.get_rotation_quaternion()
	var worst := 0.0
	var t := 0.0
	while t <= an.length:
		var hx := _gxf(an, ts, hips_i, t)
		var nx := _gxf(an, ts, neck_i, t)
		var fwd := (hx.basis.get_rotation_quaternion() * hips_rest_q.inverse()) * Vector3(0, 0, 1)
		var yaw_q := Quaternion(Vector3.UP, atan2(fwd.x, fwd.z))
		for side in ["Left", "Right"]:
			var fo := _gxf(an, ts, ts.find_bone("mixamorig_" + side + "ForeArm"), t).origin
			var ha := _gxf(an, ts, ts.find_bone("mixamorig_" + side + "Hand"), t).origin
			var tip := ha + (ha - fo).normalized() * 0.16
			for pv in [fo, ha, tip, fo.lerp(ha, 0.5)]:
				var p: Vector3 = pv
				var a := (p.y - hx.origin.y) / maxf(nx.origin.y - hx.origin.y, 0.01)
				var yr := float(tv["hy"]) + a * (float(tv["ny"]) - float(tv["hy"]))
				if yr < float(tv["y0"]) or yr > float(tv["y1"]):
					continue
				a = clampf(a, 0.0, 1.0)
				var c := hx.origin.lerp(nx.origin, a)
				c.y = p.y
				var e := _ell(p, c, yaw_q, tv, 0.0, a)
				if e.y < 1.0 and absf(e.x) <= 0.78:
					var l := yaw_q.inverse() * (p - c)
					l.y = 0.0
					worst = maxf(worst, l.length() * (1.0 / maxf(e.y, 0.01) - 1.0))
		t += 0.1
	return worst


func _init() -> void:
	await process_frame
	var src_scene: Node = (load(SRC) as PackedScene).instantiate()
	root.add_child(src_scene)
	var ss: Skeleton3D = src_scene.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = src_scene.find_children("*", "AnimationPlayer", true, false)[0]
	var hip_s := ss.find_bone("mixamorig_Hips")
	var hip_rest_s := ss.get_bone_global_rest(hip_s).origin
	var leg_s := _leg(ss)
	for id in IDS:
		var ts := _skel_of("res://assets/characters/meshy/%s.glb" % id)
		var hip_t := ts.find_bone("mixamorig_Hips")
		var hip_rest_t := ts.get_bone_global_rest(hip_t).origin
		var k_hip := _leg(ts) / maxf(leg_s, 0.001)
		var sk_s := _skq(ss)
		var sk_t := _skq(ts)
		var root_pre := sk_t.inverse() * sk_s   # raiz: muda do espaço do esqueleto de origem para o de destino
		_torso[id] = _measure_torso(ts)
		# Lena: jaqueta aberta e busto entram na medida da frente e o volume sai fundo demais (as mãos
		# na frente da barriga, que não atravessam, eram empurradas e os braços abriam)
		if TORSO_SCALE.has(id):
			for key in ["rx", "rf", "rb"]:
				var arr: Array = _torso[id][key]
				for k in arr.size():
					arr[k] = float(arr[k]) * float(TORSO_SCALE[id])
		print("  tronco ", id, " ", _torso[id])
		# correção por osso (nome -> C)
		var corr := {}
		for i in ts.get_bone_count():
			var nm := ts.get_bone_name(i)
			var j := ss.find_bone(nm)
			if j < 0:
				continue
			corr[nm] = _grest(ss, j).inverse() * _grest(ts, i)
		var lib := AnimationLibrary.new()
		for lib_name in ap.get_animation_library_list():
			var srclib := ap.get_animation_library(lib_name)
			for a in srclib.get_animation_list():
				if DROP.has(a):
					continue
				var an := srclib.get_animation(a).duplicate(true) as Animation
				for t in range(an.get_track_count() - 1, -1, -1):
					var tp := an.track_get_type(t)
					var pth := String(an.track_get_path(t))
					var bone := pth.substr(pth.find(":") + 1)
					var keep := tp == Animation.TYPE_ROTATION_3D or (tp == Animation.TYPE_POSITION_3D and bone == "mixamorig_Hips")
					if not keep or ts.find_bone(bone) < 0:
						an.remove_track(t)
						continue
					an.track_set_path(t, NodePath("%SKEL:" + bone))
					if tp == Animation.TYPE_ROTATION_3D:
						var ti := ts.find_bone(bone)
						var par := ts.get_bone_parent(ti)
						var cpi: Quaternion = root_pre
						if par >= 0:
							cpi = (corr.get(ts.get_bone_name(par), Quaternion.IDENTITY) as Quaternion).inverse()
						var cb: Quaternion = corr.get(bone, Quaternion.IDENTITY)
						for k in an.track_get_key_count(t):
							var q: Quaternion = an.track_get_key_value(t, k)
							an.track_set_key_value(t, k, (cpi * q * cb).normalized())
					else:
						for k in an.track_get_key_count(t):
							var p: Vector3 = an.track_get_key_value(t, k)
							an.track_set_key_value(t, k, hip_rest_t + root_pre * ((p - hip_rest_s) * k_hip))
				_open_arms(an, ts, id)
				_avoid_torso(an, ts, _torso[id])
				var pen := _residual(an, ts, _torso[id])
				if pen > 0.0:
					print("    resto de penetração ", id, " ", a, ": ", snappedf(pen * 100.0, 0.1), " cm")
				an.loop_mode = Animation.LOOP_LINEAR if a != "apontando" else Animation.LOOP_NONE
				lib.add_animation(a, an)
		var out := "res://assets/characters/meshy/anims_%s.res" % id
		var err := ResourceSaver.save(lib, out, ResourceSaver.FLAG_COMPRESS)
		print("  chaves de braço ajustadas: ", _moved, " | correções contra o tronco: ", _fixed_total)
		_fixed_total = 0
		_moved = 0
		print("ANIMS ", id, " -> ", out, " err=", err, " anims=", lib.get_animation_list().size(), " k_hip=", snappedf(k_hip, 0.01))
	quit()
