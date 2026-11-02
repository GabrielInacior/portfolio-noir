extends CharacterBody3D
## Jogador em primeira pessoa. Desktop: WASD + mouse (pointer lock depois do clique).
## Celular: alavanca virtual à esquerda, arrastar à direita para olhar, e tocar no letreiro
## para caminhar sozinho até ele. Sem pulo, sem gravidade pesada: é um passeio.

const SPEED := 4.2
const LOOK_SENS := 0.0032

var head: Node3D
var cam: Camera3D
var _yaw := 0.0
var _pitch := 0.0
var _auto_target := Vector3.INF
var _target_kiosk: Dictionary = {}
var _mouse_captured := false

# controle mobile (preenchido pelo HUD)
var move_vec := Vector2.ZERO
var look_delta := Vector2.ZERO      # mouse/legado (pixels)
var look_rad := Vector2.ZERO        # toque: já em radianos (o HUD normaliza pela tela)
var _yaw_t := 0.0                   # alvo suavizado do olhar no celular
var _pitch_t := 0.0

signal target_changed(project: Dictionary)
signal interacted(project: Dictionary)

# limites de deslocamento (rua por padrão; o museu troca para a sala)
var bound_min := Vector2(-4.2, -64.0)
var bound_max := Vector2(4.2, 4.0)
## áreas onde se pode andar (união de retângulos x,z): ruas, esquinas, beco, praça. Vazio = usa bound.
var walk_rects: Array = []


func forward() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0.0
	return f.normalized()


func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.height = 1.6
	cap.radius = 0.3
	col.shape = cap
	add_child(col)
	head = Node3D.new()
	head.position = Vector3(0, 0.0, 0)
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 74
	cam.current = true
	head.add_child(cam)


## teleporte/viagem: o alvo suavizado do olhar acompanha (senão a câmera "volta" girando)
func sync_look() -> void:
	_yaw_t = _yaw
	_pitch_t = _pitch


func set_target(k: Dictionary) -> void:
	if k.get("project", {}) != _target_kiosk.get("project", {}):
		_target_kiosk = k
		target_changed.emit(k.get("project", {}))


func auto_walk_to(target: Vector3) -> void:
	_auto_target = Vector3(target.x, global_position.y, target.z)


func try_interact() -> void:
	if not _target_kiosk.is_empty():
		interacted.emit(_target_kiosk.get("project", {}))


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		if not UI.is_mobile() and not UI.is_touch() and not _mouse_captured:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_mouse_captured = true
	elif e is InputEventMouseMotion and _mouse_captured:
		var mm := e as InputEventMouseMotion
		_yaw -= mm.relative.x * LOOK_SENS
		_pitch = clampf(_pitch - mm.relative.y * LOOK_SENS, -1.2, 1.0)
	elif e is InputEventKey and (e as InputEventKey).keycode == KEY_ESCAPE and (e as InputEventKey).pressed:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_mouse_captured = false
	if e.is_action_pressed("interact"):
		try_interact()


func _physics_process(dt: float) -> void:
	# olhar: mouse (desktop) + arrasto (mobile)
	if look_delta != Vector2.ZERO:
		_yaw -= look_delta.x * LOOK_SENS * 2.2
		_pitch = clampf(_pitch - look_delta.y * LOOK_SENS * 2.2, -1.2, 1.0)
		look_delta = Vector2.ZERO
		_yaw_t = _yaw
		_pitch_t = _pitch
	# toque: acumula num alvo e chega nele com suavização (nada de giro brusco no celular)
	if look_rad != Vector2.ZERO:
		var lr := look_rad.limit_length(0.35)
		_yaw_t -= lr.x
		_pitch_t = clampf(_pitch_t - lr.y, -1.0, 0.85)
		look_rad = Vector2.ZERO
	if UI.is_touch():
		var k := clampf(dt * 14.0, 0.0, 1.0)
		var dy := clampf(angle_difference(_yaw, _yaw_t) * k, -0.09, 0.09)
		_yaw += dy
		_pitch = lerpf(_pitch, _pitch_t, k)
	else:
		_yaw_t = _yaw
		_pitch_t = _pitch
	rotation.y = _yaw
	head.rotation.x = _pitch

	var input := Vector2.ZERO
	if not UI.is_mobile() or move_vec == Vector2.ZERO:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if move_vec != Vector2.ZERO:
		input = move_vec
	var dir := (transform.basis * Vector3(input.x, 0, input.y))
	dir.y = 0.0

	if _auto_target != Vector3.INF:
		var to := _auto_target - global_position
		to.y = 0.0
		if to.length() < 1.6:
			_auto_target = Vector3.INF
		else:
			dir = to.normalized()
			# vira o rosto suavemente para o alvo
			_yaw = lerp_angle(_yaw, atan2(-dir.x, -dir.z), clampf(dt * 3.0, 0, 1))
			_yaw_t = _yaw
		if input != Vector2.ZERO:
			_auto_target = Vector3.INF

	velocity = dir.normalized() * SPEED if dir.length() > 0.05 else Vector3.ZERO
	move_and_slide()
	# limites: união de áreas do bairro, ou a sala do museu
	if walk_rects.is_empty():
		global_position.x = clampf(global_position.x, bound_min.x, bound_max.x)
		global_position.z = clampf(global_position.z, bound_min.y, bound_max.y)
	else:
		var p2 := Vector2(global_position.x, global_position.z)
		var best := p2
		var bd := INF
		for r in walk_rects:
			var rr: Rect2 = r
			var q := Vector2(clampf(p2.x, rr.position.x, rr.end.x), clampf(p2.y, rr.position.y, rr.end.y))
			var d := q.distance_squared_to(p2)
			if d < bd:
				bd = d
				best = q
		global_position.x = best.x
		global_position.z = best.y
