extends RefCounted
## FUSÃO DE MALHAS ESTÁTICAS (performance): a cidade é montada com milhares de MeshInstance3D
## pequenos (cada um um draw call, e outro na passada nítida). Depois de montar, as malhas que não
## se mexem são fundidas por célula do mapa + material + formato + faixa de tamanho, numa ArrayMesh
## por grupo. Materiais que só diferem na COR (paredes, caixas, molduras, a mesma textura com outro
## tom) viram um material só, com a cor gravada na cor de vértice: é isso que junta as centenas de
## variações de cor do bairro. O nó original continua na árvore (filhos como luzes e textos seguem
## valendo), só perde a geometria. O que se move fica de fora (lista de exclusão, esqueleto).

const FMT_MASK := Mesh.ARRAY_FORMAT_NORMAL | Mesh.ARRAY_FORMAT_TANGENT | Mesh.ARRAY_FORMAT_COLOR \
	| Mesh.ARRAY_FORMAT_TEX_UV | Mesh.ARRAY_FORMAT_TEX_UV2
const COLOR_PROPS := ["albedo_color"]
const NoirLib := preload("res://scripts/render/noir.gd")
const NOIR_FMT := Mesh.ARRAY_FORMAT_CUSTOM0 | Mesh.ARRAY_FORMAT_CUSTOM1 \
	| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
const NOIR_PER_VERTEX := ["albedo_color", "emission_c", "roughness", "metallic", "specular_amt", "unshaded", "vertex_lit", "spec_off", "use_custom", "use_vc", "noir_lights"]


static func merge(root: Node3D, exclude: Array, near := 24.0, mid := 42.0, dyn_mats: Array = [], tick := Callable()) -> Dictionary:  # coroutine: `tick` cede o quadro quando passa do orçamento
	var dyn := {}
	for m in dyn_mats:
		if m is Material:
			dyn[(m as Material).get_instance_id()] = true
	var info_cache := {}  # material id -> [material canônico, tint Color ou null]
	var canon := {}       # assinatura sem cor -> material canônico (com cor de vértice)
	var ex := {}
	for n in exclude:
		if n is Node and is_instance_valid(n):
			ex[(n as Node).get_instance_id()] = true
	var inv := root.global_transform.affine_inverse()
	var groups := {}
	var done := []
	var count := 0
	var idx := 0
	for n in root.find_children("*", "MeshInstance3D", true, false):
		idx += 1
		if tick.is_valid() and idx % 4 == 0:
			await tick.call()
		if not is_instance_valid(n):
			continue
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.visible or mi.has_meta("no_merge"):
			continue
		if mi.skin != null or _excluded(mi, ex, root):
			continue
		if mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).get_blend_shape_count() > 0:
			continue
		var gxf := mi.global_transform
		var scl := gxf.basis.get_scale()
		if scl.x * scl.y * scl.z < 0.0:
			continue
		var size := mi.get_aabb().size.length() * maxf(scl.x, 0.01)
		var cls := 0
		var cell := 96.0
		var rng := 0.0
		if mi.visibility_range_end > 0.0:
			rng = mi.visibility_range_end
			cls = 1 if rng <= near + 0.1 else 2
			cell = 24.0 if cls == 1 else 48.0
		elif size < 0.9:
			cls = 1
			rng = near
			cell = 24.0
		elif size < 2.6:
			cls = 2
			rng = mid
			cell = 48.0
		var c := gxf.origin
		var ck := "%d,%d" % [int(floor(c.x / cell)), int(floor(c.z / cell))]
		var xf := inv * gxf
		var parts := []
		var ok_all := true
		for i in mi.mesh.get_surface_count():
			var mat: Material = mi.material_override if mi.material_override else mi.get_active_material(i)
			if mat == null:
				ok_all = false
				break
			var tint: Variant = null
			if not dyn.has(mat.get_instance_id()):
				var inf: Array = info_cache.get(mat.get_instance_id(), [])
				if inf.is_empty():
					inf = _canon(mat, canon)
					info_cache[mat.get_instance_id()] = inf
				mat = inf[0]
				tint = inf[1]
			var fmt := _fmt(mi.mesh, i)
			if fmt < 0:
				ok_all = false
				break
			if tint != null:
				fmt |= Mesh.ARRAY_FORMAT_COLOR
				if tint is Array:
					fmt |= NOIR_FMT
			var key := "%s|%d|%d|%d|%d|%d" % [ck, mat.get_instance_id(), fmt, mi.layers, int(mi.cast_shadow), cls]
			parts.append([key, i, mat, tint])
		if not ok_all or parts.is_empty():
			continue
		for p in parts:
			var g: Dictionary = groups.get(p[0], {})
			if g.is_empty():
				g = {"st": SurfaceTool.new(), "mat": p[2], "layers": mi.layers, "shadow": mi.cast_shadow, "range": rng, "n": 0}
				groups[p[0]] = g
			var src_mesh: Mesh = mi.mesh
			var si: int = p[1]
			if p[3] is Array:
				src_mesh = _noir_baked(mi.mesh, si, p[3])
				si = 0
			elif p[3] != null:
				src_mesh = _tinted(mi.mesh, si, p[3])
				si = 0
			(g["st"] as SurfaceTool).append_from(src_mesh, si, xf)
			g["n"] = int(g["n"]) + 1
		done.append(mi)
		count += 1
	var made := 0
	var holder := Node3D.new()
	holder.name = "Fundidos"
	root.add_child(holder)
	var gi := 0
	for k in groups:
		gi += 1
		if tick.is_valid():
			await tick.call()
		var g: Dictionary = groups[k]
		var am := (g["st"] as SurfaceTool).commit()
		if am == null or am.get_surface_count() == 0:
			continue
		var out := MeshInstance3D.new()
		out.mesh = am
		out.material_override = g["mat"]
		out.layers = g["layers"]
		out.cast_shadow = g["shadow"]
		if float(g["range"]) > 0.0:
			out.visibility_range_end = float(g["range"])
			out.visibility_range_end_margin = 4.0
		out.set_meta("merged", true)
		holder.add_child(out)
		made += 1
	for mi in done:
		(mi as MeshInstance3D).mesh = null
		(mi as MeshInstance3D).material_override = null
	if OS.get_environment("MERGE_DEBUG") != "":
		var emis := 0
		var tex := 0
		var tr := 0
		for k in canon:
			var cm = canon[k]
			if cm is StandardMaterial3D:
				if cm.emission_enabled:
					emis += 1
				if cm.albedo_texture:
					tex += 1
				if cm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					tr += 1
		print("MERGE materiais canônicos=%d (emissivos=%d, texturizados=%d, transparentes=%d) grupos=%d" % [canon.size(), emis, tex, tr, made])
	return {"in": count, "out": made}


## material canônico: StandardMaterial3D que só difere na cor vira um com cor de vértice (a cor
## original vai para os vértices). Retorna [material, tint ou null].
static func _canon(m: Material, canon: Dictionary) -> Array:
	if m is ShaderMaterial and m.has_meta("noir_kind"):
		# mundo noir: cor, emissão, rugosidade, metal, "sem luz" e "luz por vértice" vão para o vértice
		var sm0 := m as ShaderMaterial
		var sgn := _noir_sig(sm0)
		if not canon.has(sgn):
			var cm0: ShaderMaterial = NoirLib.clone(sm0)
			NoirLib.set_p(cm0, "albedo_color", Color(1, 1, 1, 1))
			NoirLib.set_p(cm0, "use_vc", 1.0)
			NoirLib.set_p(cm0, "use_custom", 1.0)
			cm0.set_meta("noir_canon", true)
			canon[sgn] = cm0
		var acv: Variant = _sp(sm0, "albedo_color", Color.WHITE)
		var ac: Color = Color(acv.x, acv.y, acv.z, acv.w) if acv is Vector4 else acv
		var ec: Vector4 = _sp(sm0, "emission_c", Vector4.ZERO)
		var c0 := Color(ec.x, ec.y, ec.z, -1.0 if float(_sp(sm0, "unshaded", 0.0)) > 0.5 else float(_sp(sm0, "roughness", 1.0)))
		var c1 := Color(float(_sp(sm0, "metallic", 0.0)), float(_sp(sm0, "specular_amt", 0.5)), float(_sp(sm0, "vertex_lit", 0.0)), float(_sp(sm0, "spec_off", 0.0)))
		return [canon[sgn], [ac, float(_sp(sm0, "use_vc", 0.0)) > 0.5, c0, c1]]
	if m is StandardMaterial3D:
		var sm := m as StandardMaterial3D
		if not sm.vertex_color_use_as_albedo:
			var sg := _sig(m, true)
			if not canon.has(sg):
				var cm := sm.duplicate() as StandardMaterial3D
				cm.vertex_color_use_as_albedo = true
				cm.vertex_color_is_srgb = true
				cm.albedo_color = Color(1, 1, 1, sm.albedo_color.a)
				canon[sg] = cm
			return [canon[sg], sm.albedo_color]
	var sg2 := _sig(m, false)
	if not canon.has(sg2):
		canon[sg2] = m
	return [canon[sg2], null]


## assinatura pelo conteúdo (propriedades salvas); texturas pelo RID; sem a cor se no_color
static func _sig(m: Material, no_color: bool) -> String:
	var parts := PackedStringArray([m.get_class()])
	for pr in m.get_property_list():
		if not (int(pr["usage"]) & PROPERTY_USAGE_STORAGE):
			continue
		var nm := str(pr["name"])
		if nm.begins_with("resource_") or (no_color and nm in COLOR_PROPS):
			continue
		var v: Variant = m.get(nm)
		if v is Texture2D:
			parts.append(nm + "=" + str((v as Texture2D).get_rid().get_id()))
		elif v is Resource:
			parts.append(nm + "=" + str((v as Resource).get_instance_id()))
		else:
			parts.append(nm + "=" + str(v))
	return "|".join(parts)


## cópia da superfície com a cor gravada nos vértices (multiplica a cor de vértice existente)
static func _tinted(m: Mesh, i: int, col: Color) -> ArrayMesh:
	var arr := m.surface_get_arrays(i)
	var vc: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var cols := PackedColorArray()
	cols.resize(vc)
	var old: Variant = arr[Mesh.ARRAY_COLOR]
	var c := Color(col.r, col.g, col.b, 1.0)
	if old is PackedColorArray and (old as PackedColorArray).size() == vc:
		var oc := old as PackedColorArray
		for k in vc:
			cols[k] = oc[k] * c
	else:
		cols.fill(c)
	arr[Mesh.ARRAY_COLOR] = cols
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am


## formato da superfície (só os canais que importam para juntar); -1 = não dá para fundir
static func _fmt(m: Mesh, i: int) -> int:
	if m is ArrayMesh:
		var am := m as ArrayMesh
		if am.surface_get_primitive_type(i) != Mesh.PRIMITIVE_TRIANGLES:
			return -1
		return am.surface_get_format(i) & FMT_MASK
	var arr := m.surface_get_arrays(i)
	if arr.is_empty() or arr[Mesh.ARRAY_VERTEX] == null:
		return -1
	var f := 0
	if arr[Mesh.ARRAY_NORMAL] != null:
		f |= Mesh.ARRAY_FORMAT_NORMAL
	if arr[Mesh.ARRAY_TANGENT] != null:
		f |= Mesh.ARRAY_FORMAT_TANGENT
	if arr[Mesh.ARRAY_COLOR] != null:
		f |= Mesh.ARRAY_FORMAT_COLOR
	if arr[Mesh.ARRAY_TEX_UV] != null:
		f |= Mesh.ARRAY_FORMAT_TEX_UV
	if arr[Mesh.ARRAY_TEX_UV2] != null:
		f |= Mesh.ARRAY_FORMAT_TEX_UV2
	return f


static func _excluded(n: Node, ex: Dictionary, root: Node) -> bool:
	var q := n
	while q != null and q != root:
		if ex.has(q.get_instance_id()) or q is Skeleton3D or q.has_meta("no_merge"):
			return true
		q = q.get_parent()
	return false


static func _sp(m: ShaderMaterial, k: String, d: Variant) -> Variant:
	var p: Dictionary = m.get_meta("noir_p", {})
	var v: Variant = p.get(k, null) if p.has(k) else m.get_shader_parameter(k)
	return d if v == null else v


## assinatura do material noir sem o que vai por vértice (shader + textura + UV + flags que sobram)
static func _noir_sig(m: ShaderMaterial) -> String:
	var parts := PackedStringArray(["NOIR", str(m.shader.get_instance_id()), str(m.render_priority)])
	for u in m.shader.get_shader_uniform_list():
		var nm := str(u["name"])
		if nm in NOIR_PER_VERTEX:
			continue
		var v: Variant = _sp(m, nm, null)
		if v is Texture2D:
			parts.append(nm + "=" + str((v as Texture2D).get_rid().get_id()))
		else:
			parts.append(nm + "=" + str(v))
	if m.next_pass:
		parts.append("np=" + str(m.next_pass.get_instance_id()))
	return "|".join(parts)


static func _rep4(c: Color, n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array([c.r, c.g, c.b, c.a])
	var total := 4 * n
	while out.size() < total:
		out.append_array(out.slice(0, mini(out.size(), total - out.size())))
	return out


## cópia da superfície com os parâmetros do material noir gravados nos vértices:
## COLOR = cor (x cor de vértice se o material usava), CUSTOM0 = emissão + rugosidade (-1 = sem luz),
## CUSTOM1 = metal, especular, luz por vértice, especular desligado
static func _noir_baked(m: Mesh, i: int, d: Array) -> ArrayMesh:
	var arr := m.surface_get_arrays(i)
	var vc: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var col: Color = d[0]
	var cols := PackedColorArray()
	cols.resize(vc)
	var old: Variant = arr[Mesh.ARRAY_COLOR]
	if bool(d[1]) and old is PackedColorArray and (old as PackedColorArray).size() == vc:
		var oc := old as PackedColorArray
		for k in vc:
			cols[k] = oc[k] * col
	else:
		cols.fill(col)
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_CUSTOM0] = _rep4(d[2], vc)
	arr[Mesh.ARRAY_CUSTOM1] = _rep4(d[3], vc)
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, NOIR_FMT)
	if OS.get_environment("MT_DEBUG") != "":
		print("MT baked col=", col, " out=", (am.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray).slice(0, 1), " fmt=", am.surface_get_format(0))
	return am
