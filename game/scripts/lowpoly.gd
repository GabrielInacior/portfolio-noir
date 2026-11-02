extends RefCounted
## Teto de segmentos para malhas primitivas criadas por código (estética PS1 e performance).
## A SphereMesh padrão tem 64x32 segmentos (~4 mil triângulos) e a CylinderMesh 64 lados: em
## lâmpadas, respingos, faróis e varais isso virava centenas de milhares de triângulos por quadro.
## Rodar uma vez depois de montar uma cena (cidade, loja); recursos compartilhados mudam uma vez só.

static var _seen := {}


static func cap_mesh(m: Mesh, small := false) -> void:
	if m == null or _seen.has(m.get_rid()):
		return
	_seen[m.get_rid()] = true
	if m is SphereMesh:
		var s := m as SphereMesh
		s.radial_segments = mini(s.radial_segments, 6 if small else 10)
		s.rings = mini(s.rings, 3 if small else 6)
	elif m is CapsuleMesh:
		var c := m as CapsuleMesh
		c.radial_segments = mini(c.radial_segments, 8)
		c.rings = mini(c.rings, 2)
	elif m is CylinderMesh:
		var y := m as CylinderMesh
		y.radial_segments = mini(y.radial_segments, 10 if small else 14)
		y.rings = 0
	elif m is TorusMesh:
		var t := m as TorusMesh
		t.rings = mini(t.rings, 16)
		t.ring_segments = mini(t.ring_segments, 6)


static func node(root: Node) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		cap_mesh((n as MeshInstance3D).mesh)
	for n in root.find_children("*", "MultiMeshInstance3D", true, false):
		var mm := (n as MultiMeshInstance3D).multimesh
		if mm:
			cap_mesh(mm.mesh, mm.instance_count > 20)
	for n in root.find_children("*", "CPUParticles3D", true, false):
		var p := n as CPUParticles3D
		cap_mesh(p.mesh, true)
		# partícula nunca projeta sombra (dobrava o custo na passada de sombra)
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Distância de visibilidade por tamanho: peça pequena some de longe (com fade), letreiro de texto
## pequeno também. A geometria fundida dos quarteirões fica sempre (é ela que dá a silhueta).
## Na avenida isso tirou centenas de draw calls de objetos que nem se distinguiam a 40 m.
static func cull_by_size(root: Node, near := 22.0, mid := 38.0) -> void:
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g is CPUParticles3D or g.visibility_range_end > 0.0:
			continue
		var aabb := g.get_aabb()
		var size := aabb.size.length() * maxf(g.global_transform.basis.get_scale().x, 0.01)
		var lim := 0.0
		if g is Label3D:
			lim = mid
		elif size < 0.9:
			lim = near
		elif size < 2.6:
			lim = mid
		if lim > 0.0:
			g.visibility_range_end = lim
			g.visibility_range_end_margin = 4.0
			g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			# objeto pequeno também não projeta sombra (custo na passada de sombra)
			if size < 0.9:
				g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
