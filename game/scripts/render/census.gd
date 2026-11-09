extends RefCounted
## CENSO DE RENDERIZAÇÃO (só depuração: `?perf=1` na web ou CENSUS=1 nativo).
## Conta, numa cena montada, os PROGRAMAS de shader distintos (o que custa compilação na 1ª visita) e
## as superfícies desenhadas por categoria (o que custa draw call por quadro).
## Programa distinto: StandardMaterial3D com o mesmo conjunto de flags/texturas presentes compartilha o
## shader (cor, número e textura são só uniformes); ShaderMaterial conta pelo código; MultiMesh e
## material com luz real dobram (variante instanciada / passadas aditivas de omni e spot).

const OCC_LAYER := 1 << 18


static func _mat_key(m: Material) -> String:
	if m == null:
		return "nulo"
	if m is ShaderMaterial:
		var sh := (m as ShaderMaterial).shader
		return "SH:" + (str(sh.resource_path) if sh and sh.resource_path != "" else str(hash(sh.code) if sh else 0))
	var parts := PackedStringArray([m.get_class()])
	for pr in m.get_property_list():
		if not (int(pr["usage"]) & PROPERTY_USAGE_STORAGE):
			continue
		var nm := str(pr["name"])
		if nm.begins_with("resource_") or nm == "render_priority" or nm == "next_pass":
			continue
		var t := int(pr["type"])
		var v: Variant = m.get(nm)
		if t == TYPE_BOOL or t == TYPE_INT:
			parts.append(nm + "=" + str(v))
		elif t == TYPE_OBJECT:
			parts.append(nm + "=" + str(v != null))
	return "|".join(parts)


static func _lit(m: Material) -> bool:
	if m is BaseMaterial3D:
		return (m as BaseMaterial3D).shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED
	if m is ShaderMaterial and (m as ShaderMaterial).shader:
		return (m as ShaderMaterial).shader.code.find("unshaded") < 0
	return false


static func _category(g: GeometryInstance3D, root: Node, cars: Dictionary) -> String:
	if g.layers & OCC_LAYER:
		return "nitida_oclusor"
	if g is Label3D:
		return "textos3d"
	if g is CPUParticles3D or g is GPUParticles3D:
		return "chuva_particulas"
	var q: Node = g
	while q and q != root:
		if cars.has(q.get_instance_id()):
			return "carros"
		if q is Skeleton3D:
			return "pessoas"
		q = q.get_parent()
	if g.has_meta("merged"):
		return "fundidos_estaticos"
	if g is MultiMeshInstance3D:
		return "multimesh"
	if g is MeshInstance3D:
		var mi := g as MeshInstance3D
		for i in (mi.mesh.get_surface_count() if mi.mesh else 0):
			var m := mi.get_active_material(i)
			if m is ShaderMaterial:
				return "teloes_telas"
			if m is StandardMaterial3D and (m as StandardMaterial3D).albedo_texture:
				var p := str((m as StandardMaterial3D).albedo_texture.resource_path)
				for h in ["/ads/", "/billboards/", "/flyers/", "atlas"]:
					if p.find(h) >= 0:
						return "anuncios"
	return "outros_dinamicos"


static func run(root: Node, label: String, cars_nodes: Array = []) -> String:
	var cars := {}
	for c in cars_nodes:
		if c is Node and is_instance_valid(c):
			cars[(c as Node).get_instance_id()] = true
	var progs := {}       # chave do programa -> [lit, instanced]
	var mats := {}        # instance id do material
	var cat_draws := {}
	var cat_mats := {}
	var has_omni := false
	var has_spot := false
	for l in root.find_children("*", "Light3D", true, false):
		if (l as Light3D).is_visible_in_tree():
			if l is OmniLight3D:
				has_omni = true
			elif l is SpotLight3D:
				has_spot = true
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var cat := _category(g, root, cars)
		var surf_mats: Array = []
		var inst := false
		if g is Label3D:
			surf_mats.append(null)
			var lb := g as Label3D
			progs["LABEL3D:bb=%d|shaded=%s|ds=%s|ac=%d|nd=%s|fx=%s" % [lb.billboard, lb.shaded, lb.double_sided, lb.alpha_cut, lb.no_depth_test, lb.fixed_size]] = [lb.shaded, false]
		elif g is MeshInstance3D and (g as MeshInstance3D).mesh:
			var mi := g as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				surf_mats.append(mi.material_override if mi.material_override else mi.get_active_material(i))
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh and (g as MultiMeshInstance3D).multimesh.mesh:
			inst = true
			var mm := (g as MultiMeshInstance3D).multimesh
			for i in mm.mesh.get_surface_count():
				surf_mats.append(g.material_override if g.material_override else mm.mesh.surface_get_material(i))
		elif g is CPUParticles3D and (g as CPUParticles3D).mesh:
			inst = true
			var pm := (g as CPUParticles3D).mesh
			for i in pm.get_surface_count():
				surf_mats.append(g.material_override if g.material_override else pm.surface_get_material(i))
		cat_draws[cat] = int(cat_draws.get(cat, 0)) + surf_mats.size()
		for m in surf_mats:
			if m == null:
				continue
			var mm2: Material = m
			while mm2:
				mats[mm2.get_instance_id()] = true
				var cm: Dictionary = cat_mats.get(cat, {})
				cm[mm2.get_instance_id()] = true
				cat_mats[cat] = cm
				var k := _mat_key(mm2) + ("|INST" if inst else "")
				progs[k] = [_lit(mm2), inst]
				mm2 = mm2.next_pass
	var unlit := 0
	var lit := 0
	for k in progs:
		if progs[k][0]:
			lit += 1
		else:
			unlit += 1
	var light_mult := 1 + int(has_omni) + int(has_spot)
	var lines := PackedStringArray()
	lines.append("CENSO %s: programas base=%d (sem luz %d, com luz %d) | variantes compiladas ~%d (omni=%s spot=%s) | materiais distintos=%d" % [label, progs.size(), unlit, lit, unlit + lit * light_mult, has_omni, has_spot, mats.size()])
	var cats := cat_draws.keys()
	cats.sort()
	for c in cats:
		lines.append("CENSO %s  %-20s superficies=%5d materiais=%4d" % [label, c, cat_draws[c], (cat_mats.get(c, {}) as Dictionary).size()])
	for k in progs:
		lines.append("CENSO %s  programa%s %s" % [label, " (COM LUZ)" if progs[k][0] else "", str(k).substr(0, 160)])
	var txt := "\n".join(lines)
	print(txt)
	return txt
