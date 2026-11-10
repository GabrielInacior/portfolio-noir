extends Node
## MUNDO NOIR: troca os StandardMaterial3D do mundo (cidade e lojas) por 5 ShaderMaterial de um shader
## próprio (`shaders/noir/`), todos `unshaded` com a luz calculada dentro do shader, e alimenta as luzes
## como DADOS (textura 4 x 17 em half float, atualizada uma vez por quadro).
## Ganho: poucos programas de shader para compilar (na 1ª visita no Windows cada programa com luz real
## custava ~2,5 s) e nenhuma passada de luz do motor. As OmniLight/SpotLight continuam na árvore como
## fonte dos dados (o jogo segue mexendo nelas: piscar, faróis, lojas), mas o motor não as desenha.
## Também é o que deixa a fusão de malhas juntar MUITO mais: cor, emissão, rugosidade, metal, "sem luz"
## e "luz por vértice" viram dados de vértice (COLOR, CUSTOM0, CUSTOM1) e a geometria estática de cores
## e brilhos diferentes cai no mesmo material (ver merge.gd).
## Desligável para comparar: `NOIR=0` (nativo) ou `?noir=0` (web).

const SHADERS := {
	"opaque": preload("res://shaders/noir/noir_opaque.gdshader"),
	"opaque_ds": preload("res://shaders/noir/noir_opaque_ds.gdshader"),
	"scissor": preload("res://shaders/noir/noir_scissor.gdshader"),
	"blend": preload("res://shaders/noir/noir_blend.gdshader"),
	"add": preload("res://shaders/noir/noir_add.gdshader"),
}
const MAX_LIGHTS := 16
## layout da textura de luzes (igual ao de noir_core.gdshaderinc)
const NEAR0 := 1
const DYN0 := 17
const MAX_DYN := 8
const SLOT0 := 25
const MAX_SLOTS := 96
const ROWS := SLOT0 + MAX_SLOTS
## limite do Compatibility por objeto (rendering/limits/opengl/max_lights_per_object)
const PER_OBJECT := 8
## parâmetros que a geometria fundida leva por vértice (o resto continua uniforme do material)
const PER_VERTEX := ["albedo_color", "emission_c", "roughness", "metallic", "specular_amt", "unshaded", "vertex_lit", "spec_off", "use_custom", "use_vc"]

static var _on := -1
static var _map := {}          # id do material de origem -> ShaderMaterial
static var _dyn := {}          # id da origem -> [origem, destino, assinatura]
static var _img: Image
static var _tex: ImageTexture
static var max_lights := MAX_LIGHTS
static var stats := {"conv": 0, "skip": 0, "skip_why": {}}


## lojas no mundo noir (rodada 4): toon e StandardMaterial3D das lojas viram os mesmos programas da cidade
## (já compilados no carregador), luzes como dados. `?shopnoir=0` / `SHOPNOIR=0` voltam ao caminho do motor.
static var _shop_on := -1


static func shop_noir() -> bool:
	if _shop_on < 0:
		_shop_on = 1 if enabled() else 0
		if _shop_on == 1:
			if OS.get_environment("SHOPNOIR") == "0":
				_shop_on = 0
			elif OS.has_feature("web") and UI.js_flag("(/[?&]shopnoir=0/.test(location.search))?1:0"):
				_shop_on = 0
	return _shop_on == 1


static func enabled() -> bool:
	if _on < 0:
		_on = 1
		# PC sem placa: o ganho do noir é compilação de shader no driver, que o SwiftShader não tem; lá o
		# fragmento próprio custa mais por pixel (medido: 76 contra 64 ms por quadro), então fica o caminho antigo
		if OS.get_environment("NOIR") == "0" or UI.software():
			_on = 0
		elif OS.has_feature("web"):
			var v: Variant = JavaScriptBridge.eval("(/[?&]noir=0/.test(location.search))?1:0", true)
			if str(v) == "1":
				_on = 0
	return _on == 1


static var _buf := PackedFloat32Array()


static func lights_texture() -> ImageTexture:
	if _tex == null:
		_buf.resize(4 * 4 * ROWS)
		_buf.fill(0.0)
		_img = Image.create_from_data(4, ROWS, false, Image.FORMAT_RGBAF, _buf.to_byte_array())
		_tex = ImageTexture.create_from_image(_img)
	return _tex


# ───────────────────────────────────────────── conversão de materiais
## qual dos 5 programas serve para este material ("" = recurso que o shader próprio não cobre)
static func kind_of(m: BaseMaterial3D) -> String:
	var why := ""
	if m.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
		why = "billboard"
	elif m.normal_enabled and m.normal_texture != null:
		why = "normal_map"
	elif m.detail_enabled or m.refraction_enabled or m.proximity_fade_enabled or m.rim_enabled or m.clearcoat_enabled \
			or m.anisotropy_enabled or m.subsurf_scatter_enabled or m.backlight_enabled or m.heightmap_enabled or m.ao_enabled:
		why = "recurso_avancado"
	elif m.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED:
		why = "distance_fade"
	elif m.use_point_size or m.grow or m.no_depth_test or m.fixed_size or m.albedo_texture_msdf or m.use_particle_trails:
		why = "flag_especial"
	elif m.cull_mode == BaseMaterial3D.CULL_FRONT:
		why = "cull_front"
	elif m.roughness_texture != null or m.metallic_texture != null:
		why = "textura_pbr"
	elif m.emission_enabled and m.emission_texture != null and m.emission_texture != m.albedo_texture:
		why = "emissao_textura"
	elif m.uv2_triplanar or (m.emission_enabled and m.emission_operator != BaseMaterial3D.EMISSION_OP_ADD):
		why = "emissao_op"
	elif m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_HASH or m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
		why = "transparencia"
	if why != "":
		var sw: Dictionary = stats["skip_why"]
		sw[why] = int(sw.get(why, 0)) + 1
		return ""
	if m.blend_mode == BaseMaterial3D.BLEND_MODE_ADD:
		return "add"
	if m.blend_mode != BaseMaterial3D.BLEND_MODE_MIX:
		var sw2: Dictionary = stats["skip_why"]
		sw2["blend"] = int(sw2.get("blend", 0)) + 1
		return ""
	if m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
		return "blend"
	if m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		return "scissor"
	return "opaque_ds" if m.cull_mode == BaseMaterial3D.CULL_DISABLED else "opaque"


## parâmetros do shader próprio equivalentes ao StandardMaterial3D
static func params_of(m: BaseMaterial3D) -> Dictionary:
	var p := {}
	p["albedo_color"] = m.albedo_color
	var tex: Texture2D = m.albedo_texture
	p["use_tex"] = 1.0 if tex != null else 0.0
	p["albedo_tex"] = tex
	p["tex_nearest"] = 1.0 if m.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST else (2.0 if m.texture_filter in [BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS, BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC] else 0.0)
	p["use_vc"] = 1.0 if m.vertex_color_use_as_albedo else 0.0
	p["uv_scale"] = m.uv1_scale
	p["uv_offset"] = m.uv1_offset
	p["triplanar"] = (2.0 if m.uv1_world_triplanar else 1.0) if m.uv1_triplanar else 0.0
	p["tri_sharp"] = m.uv1_triplanar_sharpness
	var e := Vector4.ZERO
	if m.emission_enabled:
		var ec := m.emission * m.emission_energy_multiplier
		e = Vector4(ec.r, ec.g, ec.b, m.emission_energy_multiplier if m.emission_texture != null else 0.0)
	p["emission_c"] = e
	p["roughness"] = m.roughness
	p["metallic"] = m.metallic
	p["specular_amt"] = m.metallic_specular
	p["unshaded"] = 1.0 if m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED else 0.0
	p["vertex_lit"] = 1.0 if m.shading_mode == BaseMaterial3D.SHADING_MODE_PER_VERTEX else 0.0
	p["spec_off"] = 1.0 if m.specular_mode == BaseMaterial3D.SPECULAR_DISABLED else 0.0
	p["alpha_cut"] = m.alpha_scissor_threshold
	return p


static func conv(m: Material) -> Material:
	if m is ShaderMaterial and enabled():
		# shaders próprios com luz (toon, telas): só recebem a textura de luzes
		var shm := m as ShaderMaterial
		if shm.shader and not shm.has_meta("noir_fed") and shm.shader.code.find("noir_core") >= 0:
			shm.set_meta("noir_fed", true)
			shm.set_shader_parameter("noir_lights", lights_texture())
		if shm.next_pass:
			shm.next_pass = conv(shm.next_pass)
		return m
	if m == null or not (m is BaseMaterial3D) or not enabled():
		return m
	var id := m.get_instance_id()
	if _map.has(id):
		return _map[id]
	var bm := m as BaseMaterial3D
	var k := kind_of(bm)
	if k == "":
		stats["skip"] = int(stats["skip"]) + 1
		_map[id] = m
		return m
	var sm := ShaderMaterial.new()
	sm.shader = SHADERS[k]
	sm.render_priority = m.render_priority
	var p := params_of(bm)
	for key in p:
		if p[key] != null:
			sm.set_shader_parameter(key, p[key])
	sm.set_shader_parameter("noir_lights", lights_texture())
	sm.set_meta("noir_kind", k)
	sm.set_meta("noir_p", p)
	sm.set_meta("noir_src", m)
	if bm.next_pass:
		sm.next_pass = conv(bm.next_pass)
	stats["conv"] = int(stats["conv"]) + 1
	_map[id] = sm
	return sm


## material que o jogo continua mexendo em tempo real (neon pulsando, janelas, TVs): sincronizado por quadro
static func track(src: Material) -> void:
	if src == null or not (src is BaseMaterial3D):
		return
	var dst := conv(src)
	if dst == src:
		return
	_dyn[src.get_instance_id()] = [src, dst, []]


## só o que o jogo anima: cor (neon pulsando, janelas), emissão (TVs, piscas) e textura (telas)
static func sync_dynamic() -> void:
	for id in _dyn.keys():
		var e: Array = _dyn[id]
		var src = e[0]
		if not is_instance_valid(src):
			_dyn.erase(id)
			continue
		var m := src as BaseMaterial3D
		var last: Array = e[2]
		if last.is_empty():
			last.append_array([null, null, null])
		var ac := m.albedo_color
		var ee := m.emission_energy_multiplier if m.emission_enabled else 0.0
		var tx := m.albedo_texture
		if ac == last[0] and ee == last[1] and tx == last[2]:
			continue
		var dst: ShaderMaterial = e[1]
		var targets: Array = [dst]
		targets.append_array(dst.get_meta("noir_dups", []))
		if ac != last[0]:
			for t in targets:
				set_p(t, "albedo_color", ac)
		if ee != last[1]:
			var ec := m.emission * ee
			var v := Vector4(ec.r, ec.g, ec.b, ee if m.emission_texture != null else 0.0)
			for t in targets:
				set_p(t, "emission_c", v)
		if tx != last[2]:
			for t in targets:
				set_p(t, "albedo_tex", tx)
				set_p(t, "use_tex", 1.0 if tx else 0.0)
		last[0] = ac
		last[1] = ee
		last[2] = tx


static func _conv_mesh_res(mesh: Mesh) -> void:
	if mesh == null or mesh.has_meta("noir_done"):
		return
	mesh.set_meta("noir_done", true)
	for i in mesh.get_surface_count():
		var sm := mesh.surface_get_material(i)
		if sm:
			var c := conv(sm)
			if c != sm:
				mesh.surface_set_material(i, c)


## converte uma árvore montada (cidade antes da fusão, loja depois de montar)
static func convert_tree(root: Node) -> void:
	if not enabled() or root == null:
		return
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		convert_node(n as GeometryInstance3D)


static func convert_node(g: GeometryInstance3D) -> void:
	if g == null or g.has_meta("noir_skip"):
		return
	if g.material_override:
		var c := conv(g.material_override)
		if c != g.material_override:
			g.material_override = c
	if g is MeshInstance3D:
		var mi := g as MeshInstance3D
		if mi.mesh:
			for i in mi.get_surface_override_material_count():
				var om := mi.get_surface_override_material(i)
				if om:
					var c2 := conv(om)
					if c2 != om:
						mi.set_surface_override_material(i, c2)
			_conv_mesh_res(mi.mesh)
	elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh:
		_conv_mesh_res((g as MultiMeshInstance3D).multimesh.mesh)
	elif g is CPUParticles3D:
		_conv_mesh_res((g as CPUParticles3D).mesh)


# ───────────────────────────────────────────── conjuntos de luz por objeto (como o Compatibility faz)
static var _slots: Array = []          # vaga -> Light3D fixa (ou null)
static var _moving := {}               # id da luz -> true (faróis, placas que balançam)


static func _slot_of(l: Light3D) -> int:
	if l.has_meta("noir_slot"):
		var s0: int = l.get_meta("noir_slot")
		if s0 < _slots.size() and _slots[s0] == l:
			return s0
	for i in _slots.size():
		if _slots[i] == null or not is_instance_valid(_slots[i]):
			_slots[i] = l
			l.set_meta("noir_slot", i)
			return i
	if _slots.size() >= MAX_SLOTS:
		return -1
	_slots.append(l)
	l.set_meta("noir_slot", _slots.size() - 1)
	return _slots.size() - 1


static func _is_noir_geom(g: GeometryInstance3D) -> bool:
	var mats: Array = []
	if g.material_override:
		mats.append(g.material_override)
	if g is MeshInstance3D and (g as MeshInstance3D).mesh:
		for i in (g as MeshInstance3D).mesh.get_surface_count():
			mats.append((g as MeshInstance3D).get_active_material(i))
	elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh and (g as MultiMeshInstance3D).multimesh.mesh:
		var mm := (g as MultiMeshInstance3D).multimesh.mesh
		for i in mm.get_surface_count():
			mats.append(mm.surface_get_material(i))
	for m in mats:
		if m is ShaderMaterial and (m.has_meta("noir_kind") or m.has_meta("noir_fed")):
			return true
	return false


static func _under(n: Node, root: Node, mv: Dictionary) -> bool:
	var q := n
	while q != null and q != root:
		if mv.has(q.get_instance_id()) or q is Skeleton3D:
			return true
		q = q.get_parent()
	return false


## Para cada objeto FIXO sob `root`: as até 8 omni + 8 spot que o Compatibility daria a ele (luzes cujo
## alcance toca a caixa do objeto, menor distância centro a centro / (alcance x energia)). Luzes sob
## `moving` (faróis dos carros, placas que balançam) não entram: valem para todos, as mais perto da câmera.
## Objetos sob `moving` ficam sem conjunto (usam as 16 fixas mais relevantes para a câmera).
static func assign_sets(root: Node, moving: Array = []) -> void:
	if not enabled() or root == null:
		return
	var mv := {}
	for n in moving:
		if n is Node and is_instance_valid(n):
			mv[(n as Node).get_instance_id()] = true
	var fixed: Array = []   # [centro, alcance, alcance x energia, vaga, é spot]
	for l in root.find_children("*", "Light3D", true, false):
		if l is DirectionalLight3D:
			continue
		var lt := l as Light3D
		if _under(lt, root, mv):
			_moving[lt.get_instance_id()] = true
			continue
		var slot := _slot_of(lt)
		if slot < 0:
			_moving[lt.get_instance_id()] = true
			continue
		var rng: float = (lt as OmniLight3D).omni_range if lt is OmniLight3D else (lt as SpotLight3D).spot_range
		fixed.append([lt.global_position, rng, rng * lt.light_energy, slot, lt is SpotLight3D])
	var n_obj := 0
	var by_score := func(a: Array, b: Array) -> bool: return a[0] < b[0]
	for g in root.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if gi is Label3D or gi is CPUParticles3D or (gi is MeshInstance3D and (gi as MeshInstance3D).mesh == null) or _under(gi, root, mv) or not _is_noir_geom(gi):
			continue
		var bb := gi.global_transform * gi.get_aabb()
		var c := bb.get_center()
		var om: Array = []
		var sp: Array = []
		for f in fixed:
			var lp: Vector3 = f[0]
			if not bb.grow(float(f[1])).has_point(lp):
				continue
			var score := c.distance_to(lp) / maxf(0.01, float(f[2]))
			(sp if f[4] else om).append([score, f[3]])
		om.sort_custom(by_score)
		sp.sort_custom(by_score)
		# duas vagas por número (v = (a+1) + (b+1)*128): 16 vagas em 2 vec4 por instância
		var ids: Array = []
		for e in om.slice(0, PER_OBJECT):
			ids.append(int(e[1]) + 1)
		for e in sp.slice(0, PER_OBJECT):
			ids.append(int(e[1]) + 1)
		while ids.size() < 16:
			ids.append(0)
		var pk: Array = []
		for k in 8:
			pk.append(float(ids[k * 2] + ids[k * 2 + 1] * 128))
		_apply_set(gi, Vector4(pk[0], pk[1], pk[2], pk[3]), Vector4(pk[4], pk[5], pk[6], pk[7]), float(PER_OBJECT - mini(om.size(), PER_OBJECT)))
		n_obj += 1
	print("NOIR conjuntos de luz: %d objetos, %d luzes fixas, %d móveis" % [n_obj, fixed.size(), _moving.size()])


static var _set_cache := {}   # "id do material|conjunto" -> cópia


## muda um parâmetro e o registro dele (meta "noir_p"), que é de onde as cópias leem
static func set_p(m: ShaderMaterial, key: String, v: Variant) -> void:
	m.set_shader_parameter(key, v)
	if m.has_meta("noir_p"):
		(m.get_meta("noir_p") as Dictionary)[key] = v


## cópia de um ShaderMaterial SEM duplicate(): no 4.7.1, duplicar e mudar um parâmetro na cópia faz
## get_shader_parameter do original devolver null (visto na sonda tools_dev/merge_test)
static func clone(m: ShaderMaterial) -> ShaderMaterial:
	var d := ShaderMaterial.new()
	d.shader = m.shader
	d.render_priority = m.render_priority
	d.next_pass = m.next_pass
	var p: Dictionary = m.get_meta("noir_p", {})
	if p.is_empty():
		for u in m.shader.get_shader_uniform_list():
			var v: Variant = m.get_shader_parameter(str(u["name"]))
			if v != null:
				p[str(u["name"])] = v
	for key in p:
		if p[key] != null:
			d.set_shader_parameter(key, p[key])
	d.set_shader_parameter("noir_lights", lights_texture())
	for k in m.get_meta_list():
		if k != "noir_dups":
			d.set_meta(k, m.get_meta(k))
	if not p.is_empty():
		d.set_meta("noir_p", p.duplicate())
	return d


## o conjunto vai numa cópia do material (mesmo shader = mesmo programa; só muda o bloco de uniformes)
static func _with_set(m: Material, a: Vector4, b: Vector4, free: float) -> Material:
	if not (m is ShaderMaterial and (m.has_meta("noir_kind") or m.has_meta("noir_fed"))):
		return m
	var key := "%d|%s|%s|%d" % [m.get_instance_id(), a, b, int(free)]
	if _set_cache.has(key):
		return _set_cache[key]
	var d := clone(m as ShaderMaterial)
	set_p(d, "nl_a", a)
	set_p(d, "nl_b", b)
	set_p(d, "nl_free", free)
	# material animado pelo jogo: a cópia também recebe a sincronia
	var dups: Array = m.get_meta("noir_dups", [])
	dups.append(d)
	m.set_meta("noir_dups", dups)
	_set_cache[key] = d
	return d


static func _apply_set(g: GeometryInstance3D, a: Vector4, b: Vector4, free: float) -> void:
	if g.material_override:
		g.material_override = _with_set(g.material_override, a, b, free)
		return
	if g is MeshInstance3D:
		var mi := g as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m:
				var d := _with_set(m, a, b, free)
				if d != m:
					mi.set_surface_override_material(i, d)
	elif g is MultiMeshInstance3D:
		var mm := (g as MultiMeshInstance3D).multimesh.mesh
		if mm.get_surface_count() == 1 and mm.surface_get_material(0):
			g.material_override = _with_set(mm.surface_get_material(0), a, b, free)


# ───────────────────────────────────────────── alimentação das luzes (nó, um por jogo)
var world_vp: Viewport
var _lights: Array = []
var _envs: Array = []
var _moons: Array = []
var auto_convert := false
var _pending: Array = []
var _prof := [0, 0, 0]


func setup(vp: Viewport) -> void:
	world_vp = vp
	lights_texture()
	process_priority = 900   # depois do jogo mexer nas luzes e na câmera
	get_tree().node_added.connect(_on_added)
	if UI.software():
		max_lights = 6


## as lojas ficam no caminho do motor (luz real): a luz em faixas do toon delas não bateu com a do
## shader próprio na comparação lado a lado; a cidade é onde estava o custo de compilação e de draws
static func in_shop(n: Node) -> bool:
	var q := n
	while q != null:
		var sc: Script = q.get_script()
		if sc and str(sc.resource_path).ends_with("museum.gd"):
			return true
		q = q.get_parent()
	return false


func _on_added(n: Node) -> void:
	if not enabled():
		return
	if (n is Light3D or n is WorldEnvironment or n is GeometryInstance3D) and not shop_noir() and in_shop(n):
		return
	if n.has_meta("noir_keep"):
		return
	if n is DirectionalLight3D:
		_moons.append(n)
		(n as Light3D).editor_only = true
	elif n is Light3D:
		_lights.append(n)
		(n as Light3D).editor_only = true
	elif n is WorldEnvironment:
		_envs.append(n)
	elif auto_convert and n is GeometryInstance3D:
		_pending.append(n)


func _env() -> Environment:
	for i in range(_envs.size() - 1, -1, -1):
		var we = _envs[i]
		if not is_instance_valid(we) or not (we as Node).is_inside_tree():
			_envs.remove_at(i)
			continue
		var p: Node = (we as Node).get_parent()
		if p is Node3D and not (p as Node3D).is_visible_in_tree():
			continue
		return (we as WorldEnvironment).environment
	return null


func _process(_dt: float) -> void:
	if not enabled():
		return
	if not _pending.is_empty():
		for g in _pending:
			if is_instance_valid(g):
				convert_node(g as GeometryInstance3D)
		_pending.clear()
	var t0 := Time.get_ticks_usec()
	sync_dynamic()
	var t1 := Time.get_ticks_usec()
	_feed()
	var t2 := Time.get_ticks_usec()
	_prof[0] += t1 - t0
	_prof[1] += t2 - t1
	_prof[2] += 1
	if int(_prof[2]) >= 240:
		if OS.get_environment("NOIR_PROF") != "":
			print("NOIR feed: sync %.2f ms, luzes %.2f ms (%d luzes, %d dinâmicos)" % [_prof[0] / 240000.0, _prof[1] / 240000.0, _lights.size(), _dyn.size()])
		_prof = [0, 0, 0]


## grava a luz `lt` (com o desvanecimento por distância já aplicado) na linha `row` do buffer
func _write(row: int, lt: Light3D, rng: float, fade: float) -> void:
	var p := lt.global_position
	var k := float(fade) * (-PI if lt.light_negative else PI) * lt.light_energy
	var lc := lt.light_color.srgb_to_linear()
	if not lt.is_visible_in_tree():
		k = 0.0
	var o := row * 16
	_buf[o] = p.x
	_buf[o + 1] = p.y
	_buf[o + 2] = p.z
	_buf[o + 3] = 1.0 / maxf(0.001, rng)
	_buf[o + 4] = lc.r * k
	_buf[o + 5] = lc.g * k
	_buf[o + 6] = lc.b * k
	if lt is SpotLight3D:
		var sl := lt as SpotLight3D
		var dir := -sl.global_transform.basis.z.normalized()
		_buf[o + 7] = sl.spot_attenuation
		_buf[o + 8] = dir.x
		_buf[o + 9] = dir.y
		_buf[o + 10] = dir.z
		_buf[o + 11] = cos(deg_to_rad(sl.spot_angle))
		_buf[o + 12] = 1.0 / maxf(0.001, sl.spot_angle_attenuation)
	else:
		_buf[o + 7] = (lt as OmniLight3D).omni_attenuation
		_buf[o + 11] = -2.0
		_buf[o + 12] = 1.0
	_buf[o + 13] = lt.light_specular * 2.0


func _px(row: int, col: int, c: Color) -> void:
	var o := row * 16 + col * 4
	_buf[o] = c.r
	_buf[o + 1] = c.g
	_buf[o + 2] = c.b
	_buf[o + 3] = c.a


func _feed() -> void:
	var cam := world_vp.get_camera_3d() if world_vp else null
	var cpos := cam.global_position if cam else Vector3.ZERO
	# cabeçalho: ambiente e lua
	var amb := Color(0, 0, 0)
	var env := _env()
	if env:
		var ac := env.ambient_light_color.srgb_to_linear()
		amb = Color(ac.r, ac.g, ac.b) * env.ambient_light_energy
	_px(0, 1, Color(amb.r, amb.g, amb.b, 1.0))
	var moon_on := false
	for i in range(_moons.size() - 1, -1, -1):
		var mo = _moons[i]
		if not is_instance_valid(mo):
			_moons.remove_at(i)
			continue
		var dl := mo as DirectionalLight3D
		if dl.is_visible_in_tree() and not moon_on:
			moon_on = true
			var d := dl.global_transform.basis.z.normalized()
			var mc := dl.light_color.srgb_to_linear() * dl.light_energy * PI
			_px(0, 2, Color(d.x, d.y, d.z, 0.0))
			_px(0, 3, Color(mc.r, mc.g, mc.b, 1.0))
	if not moon_on:
		_px(0, 3, Color(0, 0, 0, 0))
	# todas as luzes: fixas na sua vaga; fixas e móveis candidatas às listas "perto da câmera"
	var near: Array = []
	var dyn: Array = []
	for i in range(_lights.size() - 1, -1, -1):
		var l = _lights[i]
		if not is_instance_valid(l):
			_lights.remove_at(i)
			continue
		var lt := l as Light3D
		var rng: float = (lt as OmniLight3D).omni_range if lt is OmniLight3D else (lt as SpotLight3D).spot_range
		var dist := cpos.distance_to(lt.global_position)
		var fade := 1.0
		if lt.distance_fade_enabled and dist > lt.distance_fade_begin:
			fade = 0.0 if dist > lt.distance_fade_begin + lt.distance_fade_length else smoothstep(0.0, 1.0, 1.0 - (dist - lt.distance_fade_begin) / maxf(0.001, lt.distance_fade_length))
		var moving := _moving.has(lt.get_instance_id())
		if not moving and lt.has_meta("noir_slot"):
			var s: int = lt.get_meta("noir_slot")
			if s < _slots.size() and _slots[s] == lt:
				_write(SLOT0 + s, lt, rng, fade)
		if not lt.is_visible_in_tree() or lt.light_energy <= 0.0 or fade <= 0.0:
			continue
		(dyn if moving else near).append([maxf(0.0, dist - rng), lt, rng, fade])
	var by_score := func(a: Array, b: Array) -> bool: return a[0] < b[0]
	near.sort_custom(by_score)
	dyn.sort_custom(by_score)
	var nn := mini(near.size(), max_lights)
	for i in nn:
		_write(NEAR0 + i, near[i][1], near[i][2], near[i][3])
	var nd := mini(dyn.size(), MAX_DYN if max_lights >= MAX_LIGHTS else 2)
	for i in nd:
		_write(DYN0 + i, dyn[i][1], dyn[i][2], dyn[i][3])
	var dbg := OS.get_environment("NOIR_DBG")
	if dbg != "":
		# depuração: 1 = só ambiente e lua, 2 = sem as vagas fixas, 3 = sem móveis e sem perto
		if dbg == "1" or dbg == "2":
			for r in range(SLOT0, ROWS):
				_px(r, 1, Color(0, 0, 0, 1))
		if dbg == "1" or dbg == "3":
			nn = 0
			nd = 0
	_px(0, 0, Color(float(nn), float(nd), 1.0 if UI.software() else 0.0, 0))
	_img.set_data(4, ROWS, false, Image.FORMAT_RGBAF, _buf.to_byte_array())
	_tex.update(_img)
