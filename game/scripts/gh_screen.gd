extends Node3D
## Telão do GitHub dentro da loja: nome do repositório, estrelas, último commit e barra de
## linguagens no topo, e o README rolando devagar embaixo. Renderizado UMA vez numa SubViewport
## (barato) e rolado mexendo só o UV. Usa GithubLive (ao vivo sem token, com snapshot de reserva).

var repo_id := ""
var accent := Color("#ffc83d")
var _vp: SubViewport
var _mat: StandardMaterial3D
var _t := 0.0
const VW := 520
const VH := 1400
const WIN := 0.38      # fração da altura visível na tela


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(VW, VH)
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_vp)
	_build_card(GithubLive.readme(repo_id))
	GithubLive.fetch_readme(repo_id, func(txt: String) -> void:
		for c in _vp.get_children():
			c.queue_free()
		_build_card(txt)
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE)
	# moldura e tela
	var frame := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.32, 1.02, 0.05)
	frame.mesh = bm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#06070b")
	frame.material_override = fm
	frame.position = Vector3(0, 0, -0.03)
	add_child(frame)
	var edge := MeshInstance3D.new()
	var em := BoxMesh.new()
	em.size = Vector3(1.38, 1.08, 0.02)
	edge.mesh = em
	var eg := StandardMaterial3D.new()
	eg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eg.albedo_color = accent * 1.8
	edge.material_override = eg
	edge.position = Vector3(0, 0, -0.06)
	add_child(edge)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.24, 0.94)
	q.mesh = qm
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_texture = _vp.get_texture()
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mat.albedo_color = Color(1.25, 1.25, 1.25)
	_mat.uv1_scale = Vector3(1, WIN * 1.0, 1)
	q.material_override = _mat
	add_child(q)
	var tag := Label3D.new()
	tag.text = "GITHUB"
	tag.font = UI.font("title")
	tag.font_size = 40
	tag.pixel_size = 0.0024
	tag.modulate = accent * 1.8
	tag.position = Vector3(-0.48, 0.6, 0.0)
	tag.shaded = false
	add_child(tag)


func _process(dt: float) -> void:
	_t += dt
	# rola o README devagar (parte de baixo do cartão) e volta ao topo
	var travel := 1.0 - WIN
	var k := fmod(_t * 0.018, travel + 0.12)
	_mat.uv1_offset = Vector3(0, clampf(k - 0.06, 0.0, travel), 0)


func _build_card(md: String) -> void:
	var r := GithubLive.repo(repo_id)
	var root := ColorRect.new()
	root.color = Color("#0b0d14")
	root.size = Vector2(VW, VH)
	_vp.add_child(root)
	var v := VBoxContainer.new()
	v.position = Vector2(22, 18)
	v.size = Vector2(VW - 44, VH - 30)
	v.add_theme_constant_override("separation", 10)
	root.add_child(v)
	var name := Label.new()
	name.text = str(r.get("full", "GabrielInacior/" + repo_id))
	name.add_theme_font_override("font", UI.font("type"))
	name.add_theme_font_size_override("font_size", 24)
	name.add_theme_color_override("font_color", accent)
	v.add_child(name)
	var info := Label.new()
	var priv: bool = r.get("private", false)
	info.text = ("★ %d   ·   %s   ·   %s" % [int(r.get("stars", 0)), L.t("privado") if priv else L.t("público"), L.t("atualizado") + " " + str(r.get("pushed", r.get("updated", "")))])
	info.add_theme_font_override("font", UI.font("body"))
	info.add_theme_font_size_override("font_size", 20)
	info.add_theme_color_override("font_color", Color("#cfd6ee"))
	v.add_child(info)
	v.add_child(_lang_bar(r.get("languages", {})))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.custom_minimum_size = Vector2(VW - 44, 0)
	rt.add_theme_font_override("normal_font", UI.font("body"))
	rt.add_theme_font_override("bold_font", UI.font("bold"))
	rt.add_theme_font_override("mono_font", UI.font("type"))
	rt.add_theme_font_size_override("normal_font_size", 19)
	rt.add_theme_font_size_override("bold_font_size", 20)
	rt.add_theme_color_override("default_color", Color("#e6eaf6"))
	rt.text = md_to_bbcode(md if md != "" else str(r.get("desc", "")), accent)
	v.add_child(rt)


func _lang_bar(langs: Dictionary) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(VW - 44, 34)
	var total := 0.0
	for k in langs:
		total += float(langs[k])
	var pal := [Color("#4e9bff"), Color("#ffc83d"), Color("#5fd38a"), Color("#ff4fa3"), Color("#b06bff"), Color("#ff7a3d")]
	var x := 0.0
	var i := 0
	for k in langs:
		var w := (float(langs[k]) / maxf(total, 1.0)) * (VW - 44)
		var r := ColorRect.new()
		r.color = pal[i % pal.size()]
		r.position = Vector2(x, 0)
		r.size = Vector2(maxf(w - 2, 1), 10)
		c.add_child(r)
		if w > 60:
			var l := Label.new()
			l.text = "%s %d%%" % [k, int(round(float(langs[k]) / maxf(total, 1.0) * 100))]
			l.add_theme_font_size_override("font_size", 14)
			l.add_theme_color_override("font_color", pal[i % pal.size()])
			l.position = Vector2(x, 12)
			c.add_child(l)
		x += w
		i += 1
	return c


## markdown/HTML de README -> bbcode: títulos, parágrafos, listas, negrito, código e links; badges
## (shields) viram selos coloridos; imagens e tags HTML saem do texto (as imagens vão para a galeria
## do painel via readme_images); tabelas viram linhas legíveis.
static func md_to_bbcode(md: String, accent: Color) -> String:
	var out := PackedStringArray()
	var in_code := false
	var hexa := accent.to_html(false)
	var n := 0
	var re_badge := RegEx.create_from_string(r"\[?!\[([^\]]*)\]\(https?://img\.shields\.io[^)]*\)\]?(\([^)]*\))?")
	var re_htmlimg := RegEx.create_from_string(r"<img[^>]*alt=\"([^\"]*)\"[^>]*>")
	var re_tag := RegEx.create_from_string(r"<[^>]+>")
	var re_img := RegEx.create_from_string(r"!\[([^\]]*)\]\([^)]*\)")
	var re_link := RegEx.create_from_string(r"\[([^\]]+)\]\([^)]*\)")
	var re_b := RegEx.create_from_string(r"\*\*([^*]+)\*\*")
	var re_c := RegEx.create_from_string(r"`([^`]+)`")
	var re_ent := RegEx.create_from_string(r"&[a-z]+;")
	for raw in md.split("
"):
		n += 1
		if n > 220:
			break
		var line := raw.strip_edges(false, true)
		if line.strip_edges().begins_with("```"):
			in_code = not in_code
			continue
		if in_code:
			out.append("[color=#8fe3a8][code]" + line.replace("[", "(").replace("]", ")") + "[/code][/color]")
			continue
		# selos (shields.io) -> texto em destaque; HTML de imagem e tags somem
		var badges := PackedStringArray()
		for m in re_badge.search_all(line):
			var t := m.get_string(1).strip_edges()
			if t != "":
				badges.append("[color=#%s][b] %s [/b][/color]" % [hexa, t])
		line = re_badge.sub(line, "", true)
		line = re_htmlimg.sub(line, "", true)
		line = line.replace("<br>", " ").replace("<br/>", " ")
		line = re_tag.sub(line, "", true)
		line = re_ent.sub(line, "", true)
		line = re_img.sub(line, "", true)
		if not badges.is_empty():
			out.append("  ".join(badges))
		if line.strip_edges() == "":
			if out.size() > 0 and out[out.size() - 1] != "":
				out.append("")
			continue
		if line.strip_edges().begins_with("|"):
			if line.find("---") >= 0:
				continue
			var cells := []
			for c in line.split("|"):
				if c.strip_edges() != "":
					cells.append(c.strip_edges())
			line = "  ·  ".join(cells)
			line = re_link.sub(line, "[color=#5bd0ff]$1[/color]", true)
			line = re_b.sub(line, "[b]$1[/b]", true)
			out.append("[color=#c6cee6]" + line + "[/color]")
			continue
		line = re_link.sub(line, "[color=#5bd0ff]$1[/color]", true)
		line = re_b.sub(line, "[b]$1[/b]", true)
		line = re_c.sub(line, "[color=#ffc83d]$1[/color]", true)
		var st := line.strip_edges()
		if st.begins_with("#"):
			var lvl := st.length() - st.lstrip("#").length()
			out.append("[b][color=#%s][font_size=%d]%s[/font_size][/color][/b]" % [hexa, 30 - lvl * 3, st.lstrip("#").strip_edges()])
		elif st.begins_with("- ") or st.begins_with("* "):
			out.append("  [color=#%s]▸[/color] %s" % [hexa, st.substr(2)])
		elif st.begins_with(">"):
			out.append("[i][color=#9aa6c8]" + st.lstrip("> ") + "[/color][/i]")
		else:
			out.append(st)
	return "
".join(out)


## URLs das imagens do README (markdown e <img>), resolvidas para o raw do GitHub (repo público)
static func readme_images(md: String, repo: String) -> Array:
	var out := []
	var re1 := RegEx.create_from_string(r"!\[[^\]]*\]\(([^)\s]+)")
	var re2 := RegEx.create_from_string(r"<img[^>]*src=\"([^\"]+)\"")
	for rx in [re1, re2]:
		for m in rx.search_all(md):
			var u: String = m.get_string(1)
			if u.find("shields.io") >= 0 or u.ends_with(".svg") or u.ends_with(".gif"):
				continue
			if not u.begins_with("http"):
				u = "https://raw.githubusercontent.com/GabrielInacior/%s/HEAD/%s" % [repo, u.lstrip("./")]
			if not out.has(u):
				out.append(u)
	return out.slice(0, 6)
