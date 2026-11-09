extends Node3D
## Confere a luz do shader próprio (noir) contra o StandardMaterial3D do motor, lado a lado, com a
## mesma luz omni, spot, lua e ambiente. Imprime a cor dos dois lados em alguns pontos e salva captura.
## NOIR_TEST=<arquivo.png> godot --audio-driver Dummy --path . --resolution 800x400 res://tools_dev/noir_test.tscn
const Noir := preload("res://scripts/render/noir.gd")
var feed


func _ready() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.BLACK
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#4a4478")
	e.ambient_light_energy = 1.7
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = e
	feed = Noir.new()
	add_child(feed)
	feed.setup(get_viewport())
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("#7f90d0")
	moon.light_energy = 0.35
	moon.rotation_degrees = Vector3(-48, 128, 0)
	add_child(moon)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 8, 8)
	add_child(cam)
	cam.look_at(Vector3.ZERO)
	var mats := []
	for k in 3:
		var m := StandardMaterial3D.new()
		m.albedo_color = [Color("#8a90b8"), Color("#a8acd0"), Color("#5a4a40")][k]
		m.roughness = [0.9, 0.22, 0.6][k]
		m.metallic = [0.0, 0.25, 0.0][k]
		mats.append(m)
	# 4ª e 5ª linhas: textura pintada triplanar (fachada) e o mesmo com cor de vértice (material canônico da fusão)
	var pt := StandardMaterial3D.new()
	pt.albedo_texture = load("res://assets/tex/concreto.png")
	pt.albedo_color = Color("#8a90c8")
	pt.roughness = 0.8
	pt.metallic_specular = 0.7
	pt.uv1_triplanar = true
	pt.uv1_world_triplanar = true
	pt.uv1_scale = Vector3(0.5, 0.5, 0.5)
	pt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mats.append(pt)
	for k in 4:
		for side in 2:
			var mi := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(2.4, 2.4)
			mi.mesh = pm
			mi.position = Vector3((side * 2 - 1) * 1.3, 0, (k - 1.5) * 2.5)
			mi.material_override = mats[k] if side == 0 else Noir.conv(mats[k])
			add_child(mi)
			if side == 0:
				mi.set_meta("noir_skip", true)
	# 5ª linha: malha com cor de vértice (vermelho) + material com vertex_color_use_as_albedo
	var vcm := StandardMaterial3D.new()
	vcm.vertex_color_use_as_albedo = true
	for side in 2:
		var arr := PlaneMesh.new()
		arr.size = Vector2(2.4, 2.4)
		var a2 := arr.get_mesh_arrays()
		var cols := PackedColorArray()
		cols.resize((a2[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
		cols.fill(Color(0.8, 0.1, 0.1))
		a2[Mesh.ARRAY_COLOR] = cols
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
		var mi2 := MeshInstance3D.new()
		mi2.mesh = am
		mi2.position = Vector3((side * 2 - 1) * 1.3, 0, 2.5 * 2.5)
		mi2.material_override = vcm if side == 0 else Noir.conv(vcm)
		add_child(mi2)
	# prop do kit (saco de lixo, cor de vértice + luz por vértice) em MultiMesh, como na rua
	var sc: Node = (load("res://assets/props/sd_saco_lixo.glb") as PackedScene).instantiate()
	var pmesh: Mesh = (sc.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	sc.free()
	load("res://scripts/ps1.gd").mesh(pmesh)
	for i in pmesh.get_surface_count():
		var sm0 := pmesh.surface_get_material(i)
		print("NOIRTEST prop surf ", i, " ", sm0.resource_name if sm0 else "-", " vc=", (sm0 as StandardMaterial3D).vertex_color_use_as_albedo if sm0 is StandardMaterial3D else "?", " fmt_color=", pmesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR)
	var pm2 := pmesh.duplicate() as Mesh
	for i in pm2.get_surface_count():
		pm2.surface_set_material(i, Noir.conv(pmesh.surface_get_material(i)))
	for side in 2:
		var mmm := MultiMesh.new()
		mmm.transform_format = MultiMesh.TRANSFORM_3D
		mmm.mesh = pmesh if side == 0 else pm2
		mmm.instance_count = 1
		mmm.set_instance_transform(0, Transform3D(Basis().scaled(Vector3.ONE * 2.0), Vector3((side * 2 - 1) * 3.6, 0, 0)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mmm
		add_child(mmi)
		if side == 0:
			mmi.set_meta("noir_skip", true)
	# aditivo com alfa baixo (feixe de luz do poste) por cima da primeira linha
	var addm := StandardMaterial3D.new()
	addm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	addm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	addm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	addm.albedo_color = Color(1.0, 0.85, 0.5, 0.1)
	addm.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side in 2:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(1.5, 1.5)
		q.mesh = qm
		q.position = Vector3((side * 2 - 1) * 1.3, 1.0, -3.75)
		q.material_override = addm if side == 0 else Noir.conv(addm)
		add_child(q)
	# toon (lojas): original com light() do motor x versão noir, mesma cor, perto da luz da esquerda/direita
	for side in 2:
		var tm := ShaderMaterial.new()
		tm.shader = load("res://tools_dev/toon_ref.gdshader") if side == 0 else load("res://shaders/toon.gdshader")
		tm.set_shader_parameter("albedo", Color("#8a6040"))
		var tq := MeshInstance3D.new()
		var tp := PlaneMesh.new()
		tp.size = Vector2(2.4, 2.4)
		tq.mesh = tp
		tq.position = Vector3((side * 2 - 1) * 3.9, 0, 0)
		tq.material_override = tm if side == 0 else Noir.conv(tm)
		add_child(tq)
	for side in 2:
		var l := OmniLight3D.new()
		l.light_color = Color("#ffcf99")
		l.light_energy = 2.5
		l.omni_range = 5.0
		l.position = Vector3((side * 2 - 1) * 1.3, 1.2, 0)
		add_child(l)
	await get_tree().process_frame
	# os lados de referência precisam da luz real do motor; os noir leem a textura
	for l in find_children("*", "Light3D", true, false):
		(l as Light3D).editor_only = false
	for i in 8:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	for py in [0.25, 0.4, 0.55, 0.7, 0.85, 0.95]:
		var a := img.get_pixel(int(w * 0.45), int(h * py))
		var b := img.get_pixel(int(w * 0.55), int(h * py))
		if py == 0.55:
			print("NOIRTEST toon motor=%s noir=%s" % [img.get_pixel(int(w * 0.2), int(h * py)), img.get_pixel(int(w * 0.8), int(h * py))])
		print("NOIRTEST y=%.1f  motor=%s  noir=%s" % [py, a, b])
	var out := OS.get_environment("NOIR_TEST")
	if out != "":
		img.save_png(out)
	get_tree().quit()
