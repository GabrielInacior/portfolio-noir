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
				an.loop_mode = Animation.LOOP_LINEAR if a != "apontando" else Animation.LOOP_NONE
				lib.add_animation(a, an)
		var out := "res://assets/characters/meshy/anims_%s.res" % id
		var err := ResourceSaver.save(lib, out, ResourceSaver.FLAG_COMPRESS)
		print("  chaves de braço ajustadas: ", _moved)
		_moved = 0
		print("ANIMS ", id, " -> ", out, " err=", err, " anims=", lib.get_animation_list().size(), " k_hip=", snappedf(k_hip, 0.01))
	quit()
