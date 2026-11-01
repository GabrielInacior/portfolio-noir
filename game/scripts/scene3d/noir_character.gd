extends Node3D
## Personagem NOIR (modelos estilizados: arte conceito por IA, malha pelo Meshy, rig Mixamo; ver
## docs/CONTEXTO_E_DECISOES.md). Um GLB leve por personagem (12k tris, textura JPEG 1024, shape keys
## de rosto) e UMA biblioteca de animações comum (anims.glb, esqueleto Mixamo).
## Interface: setup(card), set_expression(), set_talking(), set_rim(), play().
## Desempenho: material único sem brilho; animação pausa quando o personagem sai da tela
## (VisibleOnScreenNotifier3D); LOD de malha gerado na importação.

const MODELS := {
	"detetive": "res://assets/characters/meshy/vance.glb",
	"couro": "res://assets/characters/meshy/lena.glb",
	"bartender": "res://assets/characters/meshy/otto.glb",
	"hacker": "res://assets/characters/meshy/kai.glb",
}
const ANIMS := "res://assets/characters/meshy/anims.glb"
## biblioteca já convertida para o esqueleto de cada um (tools_dev/char_bake_anims.gd): sem isso a
## mesma rotação aplicada a esqueletos com repouso diferente torce ombros e braços
const BAKED := {"detetive": "vance", "couro": "lena", "bartender": "otto", "hacker": "kai"}
static var _baked := {}
## Restrição de animações por personagem. O rig da Lena foi refeito e encaixado no corpo
## (tools/blender/char_rig_fit.py) e faz todos os gestos, menos "pensativo": com o antebraço
## cruzando a barriga a barra da jaqueta ainda acompanha o braço.
const SAFE_ANIMS := {"couro": ["idle", "respirando", "falando", "perguntando", "apontando", "sim", "nao", "olhando",
	"encostado", "digitando", "bartender", "fumando", "sentado", "andando"]}
## expressão -> pesos das shape keys (contidas, adultas)
const EXPR := {
	"serio": {"brow_down": 0.55},
	"desconfiado": {"brow_down": 1.0, "squint": 0.9},
	"intrigado": {"brow_up": 1.0},
	"pensativo": {"brow_down": 0.35, "squint": 0.4, "smile_r": 0.15},
	"sorriso_canto": {"smile_r": 1.0, "brow_up": 0.2},
	"cansado": {"squint": 1.0, "brow_up": 0.35},
	"firme": {"brow_down": 0.85},
}
const ALIAS := {"neutro": "serio", "feliz": "sorriso_canto", "satisfeito": "sorriso_canto", "surpreso": "intrigado",
	"bravo": "firme", "triste": "cansado", "nervoso": "pensativo"}
## gesto que acompanha a expressão (as falas pedem expressão; o corpo responde junto)
const GESTO := {"pensativo": "pensativo", "desconfiado": "nao", "intrigado": "olhando", "sorriso_canto": "sim",
	"firme": "apontando", "cansado": "respirando", "serio": "idle"}

static var _anim_lib: AnimationLibrary

var card: Dictionary = {}
var expression := "serio"
var talking := false
var model: Node3D
var anim: AnimationPlayer
var body: MeshInstance3D          # a malha com shape keys (cabeça)
var meshes: Array = []
var _mat: StandardMaterial3D
var rim := Color("#ff3d8a")
var _target := {}
var _cur := {}
var _talk_t := 0.0
var _jaw := 0.0
var _id := "detetive"


func setup(p_card: Dictionary) -> void:
	card = p_card
	_id = str(card.get("id", "detetive"))
	if not MODELS.has(_id):
		_id = ["detetive", "bartender", "hacker", "couro"][absi(hash(_id)) % 4]
	rim = Color(str(card.get("rim", card.get("look", {}).get("accent", "#ff3d8a"))))
	for c in get_children():
		c.queue_free()
	model = (load(MODELS[_id]) as PackedScene).instantiate()
	add_child(model)
	# o material é um só (mesma textura) para corpo e cabeça; a cabeça tem as shape keys
	var shared: StandardMaterial3D = null
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		meshes.append(m3)
		if m3.mesh.get_blend_shape_count() > 0:
			body = m3
		m3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if _is_mobile() else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for s in m3.mesh.get_surface_count():
			var src := m3.mesh.surface_get_material(s)
			if src is StandardMaterial3D:
				if shared == null:
					shared = (src as StandardMaterial3D).duplicate() as StandardMaterial3D
					shared.metallic = 0.0
					shared.roughness = 0.9
					shared.metallic_specular = 0.15
					shared.rim_enabled = true
					shared.rim = 0.55
					shared.rim_tint = 0.85
					# textura da Meshy é um mosaico de ilhas coladas: com mipmaps as cores vizinhas
					# vazam nas emendas e viram riscos no rosto. Personagem é visto de perto: sem mipmap.
					shared.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
				m3.set_surface_override_material(s, shared)
	_mat = shared
	_setup_anim()
	# animação para quando sai da tela
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


func _setup_anim() -> void:
	var skel: Skeleton3D = null
	for s in model.find_children("*", "Skeleton3D", true, false):
		skel = s
		break
	if skel == null:
		return
	var baked_path := "res://assets/characters/meshy/anims_%s.res" % BAKED.get(_id, "vance")
	if ResourceLoader.exists(baked_path):
		if not _baked.has(_id):
			_baked[_id] = load(baked_path)
		anim = AnimationPlayer.new()
		add_child(anim)
		anim.root_node = anim.get_path_to(skel.get_parent())
		var blib := AnimationLibrary.new()
		var bsk := String(skel.name)
		var srcb: AnimationLibrary = _baked[_id]
		for a in srcb.get_animation_list():
			var r := srcb.get_animation(a).duplicate() as Animation
			for t in r.get_track_count():
				r.track_set_path(t, NodePath(String(r.track_get_path(t)).replace("%SKEL", bsk)))
			blib.add_animation(a, r)
		anim.add_animation_library("", blib)
		anim.playback_default_blend_time = 0.3
		return
	if _anim_lib == null:
		var src := (load(ANIMS) as PackedScene).instantiate()
		var ap: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
		_anim_lib = AnimationLibrary.new()
		for lib_name in ap.get_animation_library_list():
			var lib := ap.get_animation_library(lib_name)
			for a in lib.get_animation_list():
				var anim_res := lib.get_animation(a).duplicate(true) as Animation
				# só rotação (e posição do quadril): posição/escala dos outros ossos imporiam as
				# proporções do esqueleto de origem aos outros personagens
				for t in range(anim_res.get_track_count() - 1, -1, -1):
					var tp := anim_res.track_get_type(t)
					var pth := String(anim_res.track_get_path(t))
					if tp == Animation.TYPE_SCALE_3D or (tp == Animation.TYPE_POSITION_3D and not pth.ends_with("Hips")):
						anim_res.remove_track(t)
				# trilhas apontam para o esqueleto pelo caminho relativo; deixa só o nome do osso
				for t in anim_res.get_track_count():
					var p := String(anim_res.track_get_path(t))
					var i := p.find(":")
					if i >= 0:
						anim_res.track_set_path(t, NodePath("%SKEL" + p.substr(i)))
				anim_res.loop_mode = Animation.LOOP_LINEAR if a != "apontando" else Animation.LOOP_NONE
				_anim_lib.add_animation(a, anim_res)
		src.free()
	anim = AnimationPlayer.new()
	add_child(anim)
	anim.root_node = anim.get_path_to(skel.get_parent())
	var lib := AnimationLibrary.new()
	var skel_name := String(skel.name)
	for a in _anim_lib.get_animation_list():
		var r := _anim_lib.get_animation(a).duplicate() as Animation
		for t in r.get_track_count():
			r.track_set_path(t, NodePath(String(r.track_get_path(t)).replace("%SKEL", skel_name)))
		lib.add_animation(a, r)
	anim.add_animation_library("", lib)
	anim.playback_default_blend_time = 0.3


func set_rim(c: Color, strength := 0.9) -> void:
	rim = c
	if _mat:
		_mat.rim = 0.35 + 0.4 * strength


func set_expression(e: String) -> void:
	e = ALIAS.get(e, e)
	expression = e if EXPR.has(e) else "serio"
	_target = EXPR[expression]
	var g: String = GESTO.get(expression, "idle")
	if g != "idle":
		play(g)


func set_talking(t: bool) -> void:
	talking = t
	if t:
		play("falando" if not SAFE_ANIMS.has(_id) else "respirando")


func play(name: String) -> void:
	if anim == null:
		return
	if SAFE_ANIMS.has(_id) and not (SAFE_ANIMS[_id] as Array).has(name):
		name = "idle"
	if not anim.has_animation(name):
		name = "idle"
	if anim.current_animation != name:
		anim.play(name, 0.35)
		if name == "apontando":
			anim.animation_finished.connect(func(_n: StringName) -> void: play("idle"), CONNECT_ONE_SHOT)


func _process(dt: float) -> void:
	if body == null or body.mesh == null:
		return
	# fala: queixo abre e fecha em sílabas irregulares
	if talking:
		_talk_t -= dt
		if _talk_t <= 0.0:
			_jaw = randf_range(0.25, 1.0) if _jaw < 0.2 else randf_range(0.0, 0.15)
			_talk_t = randf_range(0.07, 0.14)
	else:
		_jaw = 0.0
	var k := clampf(dt * 10.0, 0.0, 1.0)
	for key in ["brow_down", "brow_up", "smile_r", "squint", "jaw"]:
		var want: float = _jaw if key == "jaw" else float(_target.get(key, 0.0))
		var v: float = lerpf(float(_cur.get(key, 0.0)), want, k)
		_cur[key] = v
		var idx := body.find_blend_shape_by_name(key)
		if idx >= 0:
			body.set_blend_shape_value(idx, v)
