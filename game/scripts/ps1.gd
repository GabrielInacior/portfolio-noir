extends RefCounted
## Material único "PS1" para os props (kit Blender): textura com filtro NEAREST, luz por
## vértice, sem PBR (rugosidade total, sem metal, sem especular, sem normal map). Aplicado uma vez
## por malha (o recurso é compartilhado), então custa nada por instância.

static var _done := {}


static func mesh(m: Mesh) -> void:
	if m == null or _done.has(m.get_rid()):
		return
	_done[m.get_rid()] = true
	for i in m.get_surface_count():
		var src := m.surface_get_material(i)
		if src is StandardMaterial3D:
			m.surface_set_material(i, to_ps1(src as StandardMaterial3D))


static func to_ps1(src: StandardMaterial3D) -> StandardMaterial3D:
	var d := src.duplicate() as StandardMaterial3D
	d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	d.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	d.metallic = 0.0
	d.roughness = 1.0
	d.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	d.normal_enabled = false
	d.metallic_texture = null
	d.roughness_texture = null
	d.ao_enabled = false
	# kit Blender: cor por vértice (material "vc"); o que brilha vem como "glow_<cor>" e ignora a luz
	if src.resource_name.begins_with("vc"):
		d.vertex_color_use_as_albedo = true
		d.vertex_color_is_srgb = false
		d.albedo_texture = null
		d.albedo_color = Color.WHITE
	elif src.resource_name.begins_with("glow_"):
		d.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		d.emission_enabled = false
	return d


static func node(n: Node) -> void:
	for c in n.find_children("*", "MeshInstance3D", true, false):
		mesh((c as MeshInstance3D).mesh)
