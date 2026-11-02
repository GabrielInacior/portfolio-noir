extends Node3D
## Personagem NOIR low-poly estilo PS1 (tools/blender/char_ps1_build.py).
## Malha construída em volta do esqueleto Mixamo, na pose de repouso dele: TODOS os personagens usam o
## mesmo esqueleto, então uma única biblioteca de animações (ps1/anims.glb) serve a todos sem conversão
## (fim dos braços torcendo). Braços nascem separados do tronco; pesos limpos por anel.
## Cor por vértice (sem textura, como no PS1) e rosto por decalque com atlas 8x2 (expressões x boca
## fechada/aberta, tools/blender/char_ps1_faces.py). ~900 triângulos por personagem.
## Interface: setup(card), set_expression(), set_talking(), set_rim(), play().

const DIR := "res://assets/characters/ps1/"
## ficha (cast.gd / city.gd) -> modelo
const MODELS := {"detetive": "vance", "couro": "lena", "lena": "lena", "bartender": "otto", "hacker": "kai",
	"vance": "vance", "otto": "otto", "kai": "kai", "extra1": "extra1", "extra2": "extra2"}
const SCALE := {"lena": 0.95, "kai": 0.98, "extra2": 0.95}
const EXPRS := ["serio", "desconfiado", "intrigado", "pensativo", "sorriso_canto", "cansado", "firme", "neutro"]
const ALIAS := {"feliz": "sorriso_canto", "satisfeito": "sorriso_canto", "surpreso": "intrigado",
	"bravo": "firme", "triste": "cansado", "nervoso": "pensativo"}
## gesto que acompanha a expressão (as falas pedem expressão; o corpo responde junto)
const GESTO := {"pensativo": "pensativo", "desconfiado": "nao", "intrigado": "olhando", "sorriso_canto": "sim",
	"firme": "bracos_cruzados", "cansado": "respirando", "serio": "idle"}
## nomes pedidos pelo resto do jogo -> animação existente na biblioteca
const SUBST := {"idle": "idle_serio", "walking": "andando", "apontando": "falando", "encostado": "maos_bolsos",
	"sentado": "idle_serio", "digitando": "olhando"}
## bartender se curva sobre um balcão: só o Otto (os outros respiram)
const ONLY_FOR := {"bartender": ["otto"]}

static var _lib: AnimationLibrary

var card: Dictionary = {}
var expression := "serio"
var talking := false
var model: Node3D
var anim: AnimationPlayer
var face_mat: StandardMaterial3D
var body_mat: StandardMaterial3D
var rim := Color("#ff3d8a")
var _talk_t := 0.0
var _mouth_open := false
var _id := "vance"


func setup(p_card: Dictionary) -> void:
	card = p_card
	var key := str(card.get("id", "detetive"))
	_id = str(MODELS.get(key, ""))
	if _id == "":
		_id = ["vance", "otto", "kai", "lena", "extra1", "extra2"][absi(hash(key)) % 6]
	rim = Color(str(card.get("rim", card.get("look", {}).get("accent", "#ff3d8a"))))
	for c in get_children():
		c.queue_free()
	model = (load(DIR + _id + ".glb") as PackedScene).instantiate()
	add_child(model)
	model.scale = Vector3.ONE * float(SCALE.get(_id, 1.0))
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		m3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if _is_mobile() else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var is_face := String(m3.name).begins_with("Face")
		if is_face:
			m3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			face_mat = _make_face_mat()
			m3.material_override = face_mat
		else:
			body_mat = _make_body_mat()
			m3.material_override = body_mat
	_setup_anim()
	var vis := VisibleOnScreenNotifier3D.new()
	vis.aabb = AABB(Vector3(-0.6, 0, -0.6), Vector3(1.2, 1.95, 1.2))
	vis.screen_exited.connect(func() -> void:
		if anim:
			anim.pause())
	vis.screen_entered.connect(func() -> void:
		if anim and not anim.is_playing():
			anim.play())
	add_child(vis)
	set_rim(rim)
	set_expression(str(card.get("talk", {}).get("mood", "serio")))
	play("idle")


static func _is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func _make_body_mat() -> StandardMaterial3D:
	# o mesmo grão PS1 do cenário: cor de vértice, luz por vértice, sem brilho; contorno de neon fraco
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	# o glTF guarda cor de vértice linear: não converter de novo (sem isso a pele fica laranja)
	m.vertex_color_is_srgb = false
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.roughness = 1.0
	m.metallic = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.rim_enabled = true
	m.rim = 0.5
	m.rim_tint = 0.8
	return m


func _make_face_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(DIR + "face_%s.png" % _id)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


func _setup_anim() -> void:
	var skel: Skeleton3D = null
	for s in model.find_children("*", "Skeleton3D", true, false):
		skel = s
		break
	if skel == null:
		return
	if _lib == null:
		# esqueleto idêntico em todos: a biblioteca é carregada uma vez e só o nome do nó muda
		var src := (load(DIR + "anims.glb") as PackedScene).instantiate()
		var ap: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
		_lib = AnimationLibrary.new()
		for lib_name in ap.get_animation_library_list():
			var lib := ap.get_animation_library(lib_name)
			for a in lib.get_animation_list():
				var r := lib.get_animation(a).duplicate(true) as Animation
				for t in range(r.get_track_count() - 1, -1, -1):
					var tp := r.track_get_type(t)
					var pth := String(r.track_get_path(t))
					# escala nunca; posição só do quadril (balanço do corpo), e sem andar para fora do lugar
					if tp == Animation.TYPE_SCALE_3D or (tp == Animation.TYPE_POSITION_3D and not pth.ends_with("Hips")):
						r.remove_track(t)
				for t in r.get_track_count():
					var p := String(r.track_get_path(t))
					var i := p.find(":")
					if i >= 0:
						r.track_set_path(t, NodePath("%SKEL" + p.substr(i)))
				r.loop_mode = Animation.LOOP_LINEAR
				var nm := String(a).split("|")[0]
				_lib.add_animation(nm, r)
		src.free()
	anim = AnimationPlayer.new()
	add_child(anim)
	anim.root_node = anim.get_path_to(skel.get_parent())
	var lib2 := AnimationLibrary.new()
	var skel_name := String(skel.name)
	for a in _lib.get_animation_list():
		var r := _lib.get_animation(a).duplicate() as Animation
		for t in r.get_track_count():
			r.track_set_path(t, NodePath(String(r.track_get_path(t)).replace("%SKEL", skel_name)))
		lib2.add_animation(a, r)
	anim.add_animation_library("", lib2)
	anim.playback_default_blend_time = 0.3


func set_rim(c: Color, strength := 0.9) -> void:
	rim = c
	if body_mat:
		body_mat.rim = 0.3 + 0.35 * strength


func set_expression(e: String) -> void:
	e = ALIAS.get(e, e)
	expression = e if EXPRS.has(e) else "serio"
	_apply_face()
	var g: String = GESTO.get(expression, "idle")
	if g != "idle":
		play(g)


func set_talking(t: bool) -> void:
	talking = t
	if t:
		play("falando")
	else:
		_mouth_open = false
		_apply_face()


func _apply_face() -> void:
	if face_mat == null:
		return
	var col := EXPRS.find(expression)
	face_mat.uv1_offset = Vector3(col / 8.0, 0.5 if _mouth_open else 0.0, 0.0)


func play(name: String) -> void:
	if anim == null:
		return
	if ONLY_FOR.has(name) and not (ONLY_FOR[name] as Array).has(_id):
		name = "respirando"
	if not anim.has_animation(name):
		name = SUBST.get(name, "idle_serio")
		if not anim.has_animation(name):
			name = "idle_serio"
	if anim.current_animation != name:
		anim.play(name, 0.35)


func _process(dt: float) -> void:
	if not talking or face_mat == null:
		return
	# fala: boca abre e fecha em sílabas irregulares
	_talk_t -= dt
	if _talk_t <= 0.0:
		_mouth_open = not _mouth_open if randf() > 0.25 else _mouth_open
		_talk_t = randf_range(0.08, 0.16)
		_apply_face()
