extends Node3D
## Personagem NOIR low-poly (estilo POLYGON, modelado por nós em tools/blender/noir_cast.py):
## um só glb com o rig Mixamo e as malhas Cast_<id>; mostra a do personagem pedido. Cor chapada por
## face, luz de borda neon, rosto com expressões em atlas (olhos/sobrancelhas/boca).
## Interface igual à do personagem antigo: setup(card), set_expression(), set_talking(), play().

const MODEL := "res://assets/characters/noir_cast.glb"
const SHADER := preload("res://shaders/poly_char.gdshader")
const FACE := preload("res://shaders/face_atlas.gdshader")
const EYES := {"serio": Vector2(0, 0), "sorriso_canto": Vector2(1, 0), "intrigado": Vector2(2, 0), "desconfiado": Vector2(3, 0),
	"pensativo": Vector2(0, 1), "cansado": Vector2(1, 1), "firme": Vector2(2, 1), "piscando": Vector2(3, 1)}
const MOUTH := {"serio": Vector2(0, 0), "sorriso_canto": Vector2(1, 0), "falaA": Vector2(2, 0), "intrigado": Vector2(3, 0),
	"cansado": Vector2(0, 1), "desconfiado": Vector2(1, 1), "pensativo": Vector2(2, 1), "falaE": Vector2(3, 1), "firme": Vector2(0, 0)}
const ALIAS := {"neutro": "serio", "feliz": "sorriso_canto", "satisfeito": "sorriso_canto", "surpreso": "intrigado",
	"bravo": "firme", "triste": "cansado", "nervoso": "pensativo"}

var card: Dictionary = {}
var expression := "serio"
var talking := false
var model: Node3D
var anim: AnimationPlayer
var eyes_mat: ShaderMaterial
var mouth_mat: ShaderMaterial
var rim := Color("#ff3d8a")
var _blink := 2.5
var _talk_t := 0.0
var _flip := false


func setup(p_card: Dictionary) -> void:
	card = p_card
	rim = Color(str(card.get("rim", card.get("look", {}).get("accent", "#ff3d8a"))))
	for c in get_children():
		c.queue_free()
	model = (load(MODEL) as PackedScene).instantiate()
	add_child(model)
	var want := "Cast_" + str(card.get("id", "detetive"))
	var fem := str(card.get("gender", "m")) == "f"
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.visible = String(m.name) == want
		if not m.visible:
			continue
		for s in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(s)
			var nm := src.resource_name if src else ""
			if nm.begins_with("M_face_eyes") or nm.begins_with("M_face_mouth"):
				var fm := ShaderMaterial.new()
				fm.shader = FACE
				var which := "eyes" if nm.begins_with("M_face_eyes") else "mouth"
				fm.set_shader_parameter("atlas", load("res://assets/characters/%s_atlas_noir%s.png" % [which, "_f" if fem else ""]))
				m.set_surface_override_material(s, fm)
				if which == "eyes":
					eyes_mat = fm
				else:
					mouth_mat = fm
			else:
				var sm := ShaderMaterial.new()
				sm.shader = SHADER
				var col := Color("#808080")
				if src is BaseMaterial3D:
					col = (src as BaseMaterial3D).albedo_color
				sm.set_shader_parameter("albedo", col)
				sm.set_shader_parameter("rim_color", rim)
				m.set_surface_override_material(s, sm)
	var aps := model.find_children("*", "AnimationPlayer", true, false)
	if aps.size() > 0:
		anim = aps[0]
	set_expression(str(card.get("talk", {}).get("mood", "serio")))
	play("idle")


func set_rim(c: Color, strength := 0.9) -> void:
	rim = c
	if model == null:
		return
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.get_surface_override_material_count():
			var sm := m.get_surface_override_material(s)
			if sm is ShaderMaterial and (sm as ShaderMaterial).shader == SHADER:
				sm.set_shader_parameter("rim_color", c)
				sm.set_shader_parameter("rim_strength", strength)


func set_expression(e: String) -> void:
	e = ALIAS.get(e, e)
	expression = e if EYES.has(e) else "serio"
	_apply()


func set_talking(t: bool) -> void:
	talking = t
	_apply()


func _apply(blink := false) -> void:
	if eyes_mat:
		eyes_mat.set_shader_parameter("cell", EYES["piscando"] if blink else EYES.get(expression, Vector2.ZERO))
	if mouth_mat:
		var m: Vector2 = MOUTH.get(expression, Vector2.ZERO)
		if talking:
			m = MOUTH["falaA"] if _flip else MOUTH["falaE"]
		mouth_mat.set_shader_parameter("cell", m)


func play(name: String) -> void:
	if anim == null:
		return
	var target := ""
	for a in anim.get_animation_list():
		if String(a).to_lower().ends_with(name):
			target = a
	if target == "":
		for a in anim.get_animation_list():
			if String(a).to_lower().ends_with("idle"):
				target = a
	if target != "":
		var res := anim.get_animation(target)
		if res and name != "apontando":
			res.loop_mode = Animation.LOOP_LINEAR
		anim.play(target, 0.3)


func _process(dt: float) -> void:
	_blink -= dt
	if _blink <= 0.0:
		_apply(true)
		get_tree().create_timer(0.11).timeout.connect(func() -> void:
			if is_instance_valid(self):
				_apply())
		_blink = randf_range(2.4, 5.0)
	if talking:
		_talk_t -= dt
		if _talk_t <= 0.0:
			_flip = not _flip
			_talk_t = randf_range(0.08, 0.16)
			_apply()
