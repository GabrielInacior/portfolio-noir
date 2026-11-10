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
	var t_all := Time.get_ticks_usec()
	var t_parts := 0
	var t_commit := 0
	_reads = 0
	var count := 0
	var idx := 0
	var T := [0, 0, 0, 0, 0, 0]
	var tf0 := Time.get_ticks_usec()
	var all_mi := root.find_children("*", "MeshInstance3D", true, false)
	T[0] = Time.get_ticks_usec() - tf0
	for n in all_mi:
		idx += 1
		if tick.is_valid() and idx % 12 == 0:
			await tick.call()
		if not is_instance_valid(n):
			continue
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.visible or mi.has_meta("no_merge"):
			continue
		var ta := Time.get_ticks_usec()
		var exd := mi.skin != null or _excluded(mi, ex, root)
		T[1] += Time.get_ticks_usec() - ta
		if exd:
			continue
		ta = Time.get_ticks_usec()
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
		T[2] += Time.get_ticks_usec() - ta
		ta = Time.get_ticks_usec()
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
					var tcn := Time.get_ticks_usec()
					inf = _canon(mat, canon)
					info_cache[mat.get_instance_id()] = inf
					T[4] += Time.get_ticks_usec() - tcn
					T[5] = int(T[5]) + 1 if T.size() > 5 else 1
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
		T[3] += Time.get_ticks_usec() - ta
		if not ok_all or parts.is_empty():
			continue
		for p in parts:
			var g: Dictionary = groups.get(p[0], {})
			if g.is_empty():
				# caminho rápido (sem SurfaceTool.append_from): no navegador cada leitura de malha da GPU
				# (surface_get_arrays) é síncrona; aqui cada malha distinta é lida uma vez só e as cópias
				# transformadas são juntadas em PackedArrays. Material com normal map segue o caminho antigo.
				var slow: bool = _slow or (p[2] is StandardMaterial3D and (p[2] as StandardMaterial3D).normal_enabled)
				g = {"st": SurfaceTool.new() if slow else null, "parts": [], "mat": p[2], "layers": mi.layers, "shadow": mi.cast_shadow, "range": rng, "n": 0}
				groups[p[0]] = g
			var tb := Time.get_ticks_usec()
			if g["st"] != null:
				var src_mesh: Mesh = mi.mesh
				var si: int = p[1]
				if p[3] is Array:
					src_mesh = _noir_baked(mi.mesh, si, p[3])
					si = 0
				elif p[3] != null:
					src_mesh = _tinted(mi.mesh, si, p[3])
					si = 0
				(g["st"] as SurfaceTool).append_from(src_mesh, si, xf)
			else:
				(g["parts"] as Array).append(_part(src_arrays(mi.mesh, p[1]), xf, p[3]))
			t_parts += Time.get_ticks_usec() - tb
			g["n"] = int(g["n"]) + 1
		done.append(mi)
		count += 1
	print("MERGE laço (ms): find_children %d | excluídos %d | transformação/aabb %d | materiais/formato/chave %d (material canônico %d ms, %d materiais)" % [T[0] / 1000, T[1] / 1000, T[2] / 1000, T[3] / 1000, T[4] / 1000, T[5]])
	var t_loop2 := Time.get_ticks_usec()
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
		var tcm := Time.get_ticks_usec()
		var am: ArrayMesh = (g["st"] as SurfaceTool).commit() if g["st"] != null else _commit_parts(g["parts"])
		t_commit += Time.get_ticks_usec() - tcm
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
	var t_free := Time.get_ticks_usec()
	for mi in done:
		(mi as MeshInstance3D).mesh = null
		(mi as MeshInstance3D).material_override = null
	print("MERGE fim (ms): grupos+nós %d (junção incluída) | soltar malhas originais %d" % [(t_free - t_loop2) / 1000, (Time.get_ticks_usec() - t_free) / 1000])
	_icache.clear()
	print("MERGE tempos (ms): total %d | partes %d | junção %d | leituras de malha %d | %s" % [(Time.get_ticks_usec() - t_all) / 1000, t_parts / 1000, t_commit / 1000, _reads, "antigo" if _slow else "rápido"])
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
	var arr := src_arrays(m, i)
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


# ─────────────────────────────── caminho rápido (sem ler a mesma malha da GPU várias vezes)
static var _acache := {}
static var _icache := {}   # (instância, superfície) -> arrays: _fmt e _part pedem a mesma malha em seguida
static var _pnames := {}
static var _reads := 0
## ?mergeslow=1 / PF_MERGESLOW=1: volta ao caminho antigo (SurfaceTool.append_from) para comparar
static var _slow := false
static var _gpu_read := false   # PF_MERGEGPU=1 / ?mergegpu=1: lê as primitivas da GPU como antes


## arrays de uma superfície, lidos uma vez por malha distinta (primitivas iguais por parâmetro contam como uma);
## malhas montadas por código podem trazer os arrays prontos na meta "pf_arrays"
static func src_arrays(m: Mesh, i: int) -> Array:
	var ik := m.get_instance_id() * 16 + i
	var ia: Variant = _icache.get(ik)
	if ia != null:
		return ia
	ia = _src_arrays(m, i)
	_icache[ik] = ia
	return ia


static func _src_arrays(m: Mesh, i: int) -> Array:
	if m.has_meta("pf_arrays"):
		var pa: Array = m.get_meta("pf_arrays")
		if i < pa.size():
			return pa[i]
	var k: String
	if m is PrimitiveMesh:
		var cls := m.get_class()
		var names: Array = _pnames.get(cls, [])
		if names.is_empty():
			for pr in m.get_property_list():
				var nm := str(pr["name"])
				if int(pr["usage"]) & PROPERTY_USAGE_STORAGE and not nm.begins_with("resource_") and nm != "material":
					names.append(nm)
			_pnames[cls] = names
		var vals := [cls]
		for nm in names:
			vals.append(m.get(nm))
		k = str(vals)
	else:
		k = "%d:%d" % [m.get_instance_id(), i]
	var a: Variant = _acache.get(k)
	if a == null:
		# primitiva: os arrays são gerados na CPU (get_mesh_arrays), sem ler a malha de volta da GPU
		if m is PrimitiveMesh and i == 0 and not _gpu_read:
			a = (m as PrimitiveMesh).get_mesh_arrays()
		else:
			a = m.surface_get_arrays(i)
			_reads += 1
		_acache[k] = a
	return a


## cópia transformada de uma superfície (posição, normal, cor/dados do material noir por vértice)
static func _part(arr: Array, xf: Transform3D, tint: Variant) -> Dictionary:
	var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var vc := pos.size()
	var d := {"n": vc, "v": xf * pos}
	var nr: Variant = arr[Mesh.ARRAY_NORMAL]
	if nr != null:
		var b := xf.basis
		var sc := b.get_scale()
		if absf(sc.x - sc.y) < 0.0005 and absf(sc.y - sc.z) < 0.0005:
			d["nr"] = Transform3D(b.orthonormalized(), Vector3.ZERO) * (nr as PackedVector3Array)
		else:
			var nb := b.inverse().transposed()
			var nn := nr as PackedVector3Array
			var out := PackedVector3Array()
			out.resize(vc)
			for k in vc:
				out[k] = (nb * nn[k]).normalized()
			d["nr"] = out
	if arr[Mesh.ARRAY_TEX_UV] != null:
		d["uv"] = arr[Mesh.ARRAY_TEX_UV]
	if arr[Mesh.ARRAY_TEX_UV2] != null:
		d["uv2"] = arr[Mesh.ARRAY_TEX_UV2]
	if arr[Mesh.ARRAY_INDEX] != null:
		d["i"] = arr[Mesh.ARRAY_INDEX]
	var old: Variant = arr[Mesh.ARRAY_COLOR]
	if tint == null:
		if old != null:
			d["c"] = old
	else:
		var col: Color
		var mul := true
		if tint is Array:
			col = tint[0]
			mul = bool(tint[1])
			d["c0"] = _rep4(tint[2], vc)
			d["c1"] = _rep4(tint[3], vc)
		else:
			var tc: Color = tint
			col = Color(tc.r, tc.g, tc.b, 1.0)
		var cols := PackedColorArray()
		cols.resize(vc)
		if mul and old is PackedColorArray and (old as PackedColorArray).size() == vc:
			var oc := old as PackedColorArray
			for k in vc:
				cols[k] = oc[k] * col
		else:
			cols.fill(col)
		d["c"] = cols
	return d


## junta as partes de um grupo numa ArrayMesh (índices com deslocamento; partes sem índice ganham 0..n-1)
static func _commit_parts(parts: Array) -> ArrayMesh:
	if parts.is_empty():
		return null
	var V := PackedVector3Array()
	var N := PackedVector3Array()
	var C := PackedColorArray()
	var U := PackedVector2Array()
	var U2 := PackedVector2Array()
	var C0 := PackedFloat32Array()
	var C1 := PackedFloat32Array()
	var I := PackedInt32Array()
	var p0: Dictionary = parts[0]
	var has_i := false
	for p in parts:
		if (p as Dictionary).has("i"):
			has_i = true
			break
	for p in parts:
		var vc: int = p["n"]
		var off := V.size()
		V.append_array(p["v"])
		if p0.has("nr"):
			if p.has("nr"):
				N.append_array(p["nr"])
			else:
				N.resize(N.size() + vc)
		if p0.has("c"):
			if p.has("c"):
				C.append_array(p["c"])
			else:
				var cc := PackedColorArray()
				cc.resize(vc)
				cc.fill(Color.WHITE)
				C.append_array(cc)
		if p0.has("uv"):
			if p.has("uv"):
				U.append_array(p["uv"])
			else:
				U.resize(U.size() + vc)
		if p0.has("uv2"):
			if p.has("uv2"):
				U2.append_array(p["uv2"])
			else:
				U2.resize(U2.size() + vc)
		if p0.has("c0"):
			C0.append_array(p["c0"])
			C1.append_array(p["c1"])
		if has_i:
			if p.has("i"):
				var src: PackedInt32Array = p["i"]
				var base := I.size()
				I.resize(base + src.size())
				for k in src.size():
					I[base + k] = src[k] + off
			else:
				I.append_array(PackedInt32Array(range(off, off + vc)))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = V
	if p0.has("nr"):
		arrays[Mesh.ARRAY_NORMAL] = N
	if p0.has("c"):
		arrays[Mesh.ARRAY_COLOR] = C
	if p0.has("uv"):
		arrays[Mesh.ARRAY_TEX_UV] = U
	if p0.has("uv2"):
		arrays[Mesh.ARRAY_TEX_UV2] = U2
	var flags := 0
	if p0.has("c0"):
		arrays[Mesh.ARRAY_CUSTOM0] = C0
		arrays[Mesh.ARRAY_CUSTOM1] = C1
		flags = NOIR_FMT
	if has_i:
		arrays[Mesh.ARRAY_INDEX] = I
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	# posições e índices ficam na CPU para os oclusores da passada nítida (sem ler a malha de volta da GPU)
	am.set_meta("pf_occ", [V, I if has_i else null])
	return am
