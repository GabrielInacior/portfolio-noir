extends RefCounted
## Construtores dos objetos 3D das lojas-museu (primitivas bem compostas, estilo pincelado).
## Cada função pendura o objeto num holder voltado para a sala; as funções "de ambiente" montam
## móveis soltos (abajur, cadeira, fliperama, rack de servidor, microfone, balcão).

const INK := Color("#0a0c16")


static func _mat(col: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.92
	if emit > 0.0:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	return m


static func _tex_mat(tex: Texture2D, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.roughness = 0.6
	if emit > 0.0:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission_texture = tex
		m.emission_energy_multiplier = emit
	return m


static func _box(parent: Node, pos: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node, pos: Vector3, r: float, h: float, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _img_ratio(tex: Texture2D) -> float:
	if tex == null:
		return 1.4
	return float(tex.get_width()) / maxf(1.0, tex.get_height())

## Imagem numa moldura SEM esticar nem vazar: plano (UV 0..1) do tamanho exato da tela.
## "cover" preenche a tela cortando o excesso, centralizado (telas e quadros);
## "contain" cabe inteira com fundo escuro nas sobras (prints com texto importante).
static func img(parent: Node, pos: Vector3, w: float, h: float, tex: Texture2D, emit := 0.0, mode := "cover") -> void:
	var r_img := _img_ratio(tex)
	var r_surf := w / maxf(0.001, h)
	var qw := w
	var qh := h
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if emit > 0.0 else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if emit > 0.0:
		var k := 0.75 + emit * 0.25
		m.albedo_color = Color(k, k, k)
	if mode == "contain":
		# fundo escuro do tamanho da tela e a imagem inteira por cima
		var bg := MeshInstance3D.new()
		var bq := QuadMesh.new()
		bq.size = Vector2(w, h)
		bg.mesh = bq
		bg.material_override = _mat(Color("#05060c"))
		bg.position = pos - Vector3(0, 0, 0.002)
		parent.add_child(bg)
		if r_img > r_surf:
			qh = w / r_img
		else:
			qw = h * r_img
	else:
		if r_img > r_surf:
			var su := r_surf / r_img
			m.uv1_scale = Vector3(su, 1, 1)
			m.uv1_offset = Vector3((1.0 - su) / 2.0, 0, 0)
		else:
			var sv := r_img / r_surf
			m.uv1_scale = Vector3(1, sv, 1)
			m.uv1_offset = Vector3(0, (1.0 - sv) / 2.0, 0)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(qw, qh)
	mi.mesh = q
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)



# ───────────── itens de parede (voltados para +Z do holder)

## quadro emoldurado com a imagem (foto do projeto)
static func framed(h: Node, tex: Texture2D, accent: Color, warm: Color) -> void:
	var r := clampf(_img_ratio(tex), 0.6, 2.2)
	var ph := 1.3
	var pw := ph * r
	_box(h, Vector3(0, 0, 0.0), Vector3(pw + 0.18, ph + 0.18, 0.08), _mat(Color("#120f0a")))   # moldura
	_box(h, Vector3(0, 0, 0.05), Vector3(pw + 0.26, ph + 0.26, 0.04), _mat(warm.darkened(0.3)))  # borda dourada
	if tex:
		img(h, Vector3(0, 0, 0.101), pw, ph, tex, 0.3, "cover")
	else:
		_box(h, Vector3(0, 0, 0.09), Vector3(pw, ph, 0.02), _mat(Color("#14110c")))
	# vidro com reflexo
	var glass := _box(h, Vector3(0, 0, 0.11), Vector3(pw, ph, 0.01), null)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.7, 0.8, 1.0, 0.08)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.metallic = 0.5
	gm.roughness = 0.1
	glass.material_override = gm
	# luzinha de galeria em cima
	_box(h, Vector3(0, ph / 2 + 0.2, 0.2), Vector3(pw * 0.6, 0.06, 0.12), _mat(warm, 2.0), Vector3(0.5, 0, 0))


## telão (monitor grande montado na parede) com imagem emissiva
static func screen(h: Node, tex: Texture2D, cool: Color, emit := 1.2) -> void:
	var r := clampf(_img_ratio(tex), 0.8, 2.0)
	var sh := 1.4
	var sw := sh * r
	_box(h, Vector3(0, 0, 0.0), Vector3(sw + 0.2, sh + 0.2, 0.12), _mat(Color("#080a12")))
	if tex:
		_box(h, Vector3(0, 0, 0.07), Vector3(sw, sh, 0.02), _mat(Color("#05060c")))
		img(h, Vector3(0, 0, 0.081), sw - 0.06, sh - 0.06, tex, emit, "contain")
	else:
		_box(h, Vector3(0, 0, 0.08), Vector3(sw, sh, 0.02), _mat(Color("#070a12")))
	# brilho de tela (halo)
	var halo := _box(h, Vector3(0, 0, 0.12), Vector3(sw * 1.1, sh * 1.1, 0.01), null)
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.albedo_color = Color(cool, 0.1)
	halo.material_override = hm


## monitor de desktop (base + tela), estética terminal
static func monitor(h: Node, tex: Texture2D, accent: Color) -> void:
	var r := clampf(_img_ratio(tex), 1.0, 1.9)
	var sh := 1.0
	var sw := sh * r
	_box(h, Vector3(0, 0.1, 0), Vector3(sw + 0.12, sh + 0.12, 0.08), _mat(Color("#0c0f16")))
	if tex:
		_box(h, Vector3(0, 0.1, 0.04), Vector3(sw, sh, 0.02), _mat(Color("#05060c")))
		img(h, Vector3(0, 0.1, 0.051), sw - 0.05, sh - 0.05, tex, 1.0, "contain")
	else:
		_box(h, Vector3(0, 0.1, 0.05), Vector3(sw, sh, 0.02), _mat(Color("#070a12")))
	_box(h, Vector3(0, -0.5, 0.0), Vector3(0.1, 0.3, 0.1), _mat(Color("#161a24")))   # pescoço
	_box(h, Vector3(0, -0.66, 0.1), Vector3(0.6, 0.05, 0.3), _mat(Color("#161a24")))  # base
	# fileira de LEDs
	for i in 3:
		_box(h, Vector3(-sw / 2 + 0.1 + i * 0.12, sh / 2 - 0.05, 0.06), Vector3(0.04, 0.04, 0.02),
			_mat([Color("#39ff9b"), accent, Color("#ff6a3d")][i], 2.0))


## pôster colado (imagem sem moldura, cantos com fita)
static func poster(h: Node, tex: Texture2D, accent: Color) -> void:
	var r := clampf(_img_ratio(tex), 0.6, 1.6)
	var ph := 1.5
	var pw := ph * r
	if tex:
		img(h, Vector3(0, 0, 0.026), pw, ph, tex, 0.2, "cover")
	else:
		_box(h, Vector3(0, 0, 0.02), Vector3(pw, ph, 0.01), _mat(Color("#0d0f18")))
	for c in [Vector3(-pw / 2, ph / 2, 0.03), Vector3(pw / 2, ph / 2, 0.03), Vector3(-pw / 2, -ph / 2, 0.03), Vector3(pw / 2, -ph / 2, 0.03)]:
		_box(h, c, Vector3(0.14, 0.14, 0.005), _mat(Color("#d9d2b8", 0.7)), Vector3(0, 0, 0.78))


## placa de metal gravada (número, selo)
static func plaque(h: Node, tex: Texture2D, accent: Color) -> void:
	_box(h, Vector3(0, 0, 0), Vector3(1.6, 1.0, 0.06), _mat(Color("#2a2f3c")))
	_box(h, Vector3(0, 0, 0.035), Vector3(1.5, 0.9, 0.02), _mat(accent.darkened(0.2)))
	if tex:
		img(h, Vector3(0, 0, 0.056), 1.3, 0.72, tex, 0.4, "contain")
	for sx in [-0.72, 0.72]:
		for sy in [-0.44, 0.44]:
			_cyl(h, Vector3(sx, sy, 0.05), 0.04, 0.03, _mat(accent, 1.0), Vector3(PI / 2, 0, 0))


## nicho de fliperama na parede (cartaz do jogo com luzes)
static func arcade_wall(h: Node, accent: Color) -> void:
	_box(h, Vector3(0, 0, 0), Vector3(1.6, 1.8, 0.2), _mat(Color("#14101c")))
	_box(h, Vector3(0, 0.3, 0.1), Vector3(1.3, 1.0, 0.03), _mat(accent, 1.2))
	for i in 10:
		var a := TAU * i / 10.0
		_cyl(h, Vector3(cos(a) * 0.78, 0.3 + sin(a) * 0.62, 0.12), 0.05, 0.03,
			_mat([accent, Color("#4e9bff"), Color("#ff6a3d")][i % 3], 2.0), Vector3(PI / 2, 0, 0))
	_box(h, Vector3(0, -0.55, 0.1), Vector3(1.2, 0.5, 0.05), _mat(Color("#060810"), 0.0))


## prop simbólico modelado (objeto por nome)
static func prop(h: Node, model: String, accent: Color, warm: Color) -> void:
	# pedestal
	_box(h, Vector3(0, -0.75, 0), Vector3(0.7, 0.5, 0.7), _mat(Color("#1a1e2a")))
	_box(h, Vector3(0, -0.48, 0), Vector3(0.8, 0.06, 0.8), _mat(accent.darkened(0.4)))
	var p := Node3D.new()
	p.position = Vector3(0, -0.1, 0)
	h.add_child(p)
	match model:
		"maquina_escrever": _typewriter(p, accent)
		"servidor", "server": server_rack(p, Vector3(0, -0.1, 0), accent, 0.0, true)
		"cadeado": _padlock(p, accent)
		"microfone": _mic(p, accent)
		"monitor_cv": _mini_monitor(p, accent)
		"celular": _phone(p, accent)
		"livro": _book(p, warm)
		"cartao": _card(p, accent)
		_: _box(p, Vector3(0, 0.2, 0), Vector3(0.4, 0.4, 0.4), _mat(accent.darkened(0.2)))
	# foco quente de cima
	_box(h, Vector3(0, 1.0, 0.0), Vector3(0.1, 0.1, 0.1), _mat(warm, 2.0))


static func _typewriter(p: Node, accent: Color) -> void:
	_box(p, Vector3(0, 0.1, 0), Vector3(0.5, 0.18, 0.44), _mat(Color("#20252f")))
	_box(p, Vector3(0, 0.26, 0.05), Vector3(0.44, 0.14, 0.26), _mat(Color("#161a22")), Vector3(-0.5, 0, 0))
	_box(p, Vector3(0, 0.44, -0.08), Vector3(0.34, 0.26, 0.02), _mat(Color("#efe8d6"), 0.2), Vector3(-0.3, 0, 0))  # papel
	for i in 5:
		_cyl(p, Vector3(-0.16 + i * 0.08, 0.2, 0.18), 0.02, 0.03, _mat(accent, 0.6), Vector3(PI / 2, 0, 0))


static func _padlock(p: Node, accent: Color) -> void:
	_box(p, Vector3(0, 0.1, 0), Vector3(0.3, 0.34, 0.14), _mat(accent.darkened(0.1), 0.3))
	var sh := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.09
	tm.outer_radius = 0.14
	sh.mesh = tm
	sh.material_override = _mat(Color("#c9ced9"))
	sh.position = Vector3(0, 0.33, 0)
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(sh)
	_box(p, Vector3(0, 0.08, 0.08), Vector3(0.08, 0.08, 0.02), _mat(Color("#0a0c12")))


static func _mic(p: Node, accent: Color) -> void:
	_cyl(p, Vector3(0, 0.1, 0), 0.06, 0.3, _mat(Color("#20252f")))
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.1
	sm.height = 0.2
	ball.mesh = sm
	ball.material_override = _mat(Color("#3a3f4a"))
	ball.position = Vector3(0, 0.32, 0)
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(ball)
	_cyl(p, Vector3(0, 0.44, 0), 0.015, 0.06, _mat(accent, 1.5))


static func _mini_monitor(p: Node, accent: Color) -> void:
	_box(p, Vector3(0, 0.26, 0), Vector3(0.5, 0.34, 0.05), _mat(Color("#0c0f16")))
	_box(p, Vector3(0, 0.26, 0.03), Vector3(0.44, 0.28, 0.01), _mat(accent, 1.2))
	_box(p, Vector3(0, 0.06, 0), Vector3(0.08, 0.16, 0.08), _mat(Color("#161a24")))
	_box(p, Vector3(0, 0.0, 0.05), Vector3(0.3, 0.03, 0.18), _mat(Color("#161a24")))


static func _phone(p: Node, accent: Color) -> void:
	_box(p, Vector3(0, 0.2, 0), Vector3(0.22, 0.44, 0.03), _mat(Color("#0c0f16")))
	_box(p, Vector3(0, 0.2, 0.02), Vector3(0.18, 0.38, 0.01), _mat(accent, 1.0))


static func _book(p: Node, warm: Color) -> void:
	for i in 3:
		_box(p, Vector3(0, 0.06 + i * 0.09, i * 0.01), Vector3(0.4, 0.08, 0.3),
			_mat([Color("#7a2a30"), Color("#2a4a6a"), Color("#3a5a3a")][i]))


static func _card(p: Node, accent: Color) -> void:
	for i in 3:
		_box(p, Vector3(-0.05 + i * 0.05, 0.1 + i * 0.02, 0), Vector3(0.3, 0.42, 0.01),
			_mat(Color("#efe8d6")), Vector3(0, 0, (i - 1) * 0.2))
	_box(p, Vector3(0.1, 0.2, 0.02), Vector3(0.22, 0.3, 0.005), _mat(accent, 0.4), Vector3(0, 0, 0.2))


# ───────────── móveis de ambiente (soltos na sala)

static func lamp(parent: Node, pos: Vector3, warm: Color) -> void:
	_cyl(parent, pos + Vector3(0, 0.2, 0), 0.04, 0.4, _mat(Color("#1a1420")))
	var shade := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.14
	cm.bottom_radius = 0.22
	cm.height = 0.24
	shade.mesh = cm
	shade.material_override = _mat(warm, 1.6)
	shade.position = pos + Vector3(0, 0.5, 0)
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(shade)
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0, 0.5, 0)
	l.light_color = warm
	l.light_energy = 2.0
	l.omni_range = 4.0
	parent.add_child(l)


static func chair(parent: Node, pos: Vector3, col: Color) -> void:
	_box(parent, pos + Vector3(0, 0.45, 0), Vector3(0.5, 0.1, 0.5), _mat(col))
	_box(parent, pos + Vector3(0, 0.75, -0.22), Vector3(0.5, 0.6, 0.08), _mat(col))
	for dx in [-0.2, 0.2]:
		for dz in [-0.2, 0.2]:
			_cyl(parent, pos + Vector3(dx, 0.22, dz), 0.03, 0.44, _mat(Color("#161016")))


static func arcade(parent: Node, pos: Vector3, accent: Color, yaw: float) -> void:
	var h := Node3D.new()
	h.position = pos
	h.rotation.y = yaw
	parent.add_child(h)
	_box(h, Vector3(0, 0.8, 0), Vector3(0.7, 1.6, 0.7), _mat(Color("#14101c")))
	_box(h, Vector3(0, 1.3, 0.3), Vector3(0.6, 0.5, 0.1), _mat(accent, 1.3), Vector3(-0.5, 0, 0))  # tela
	_box(h, Vector3(0, 1.75, 0.0), Vector3(0.66, 0.4, 0.5), _mat(accent.darkened(0.2), 0.6))       # marquise
	_box(h, Vector3(0, 0.95, 0.36), Vector3(0.6, 0.16, 0.12), _mat(Color("#20252f")))              # painel
	_cyl(h, Vector3(-0.12, 1.05, 0.36), 0.03, 0.12, _mat(Color("#e2384f"), 0.8))
	for i in 3:
		_cyl(h, Vector3(0.05 + i * 0.1, 1.04, 0.36), 0.04, 0.04, _mat([accent, Color("#4e9bff"), Color("#ffc83d")][i], 1.5), Vector3(PI / 2, 0, 0))
	# brilho no chão
	_box(h, Vector3(0, 0.02, 0.5), Vector3(0.6, 0.01, 0.8), _mat(accent, 0.5))


static func server_rack(parent: Node, pos: Vector3, accent: Color, yaw := 0.0, small := false) -> void:
	var h := Node3D.new()
	h.position = pos
	h.rotation.y = yaw
	parent.add_child(h)
	var hgt := 0.9 if small else 1.8
	_box(h, Vector3(0, hgt / 2, 0), Vector3(0.5, hgt, 0.5), _mat(Color("#0e1118")))
	var units := 4 if small else 8
	for i in units:
		var y := 0.2 + i * (hgt - 0.3) / units
		_box(h, Vector3(0, y, 0.26), Vector3(0.44, (hgt - 0.3) / units - 0.03, 0.02), _mat(Color("#161b24")))
		for k in 5:
			_box(h, Vector3(-0.16 + k * 0.08, y, 0.28), Vector3(0.03, 0.03, 0.01),
				_mat([accent, Color("#4e9bff"), Color("#ff6a3d")][(i + k) % 3], 1.8))


static func mic_stand(parent: Node, pos: Vector3, accent: Color) -> void:
	_cyl(parent, pos + Vector3(0, 0.0, 0), 0.18, 0.04, _mat(Color("#161016")))
	_cyl(parent, pos + Vector3(0, 0.75, 0), 0.025, 1.5, _mat(Color("#20252f")))
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	ball.mesh = sm
	ball.material_override = _mat(Color("#3a3f4a"))
	ball.position = pos + Vector3(0.0, 1.5, 0.12)
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ball)
	_cyl(parent, pos + Vector3(0, 1.5, 0.06), 0.02, 0.16, _mat(Color("#20252f")), Vector3(PI / 2, 0, 0))
	_box(parent, pos + Vector3(0, 1.5, 0.3), Vector3(0.01, 0.01, 0.01), _mat(accent, 2.0))
