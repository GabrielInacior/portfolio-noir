extends Node
## Internacionalização: o português é o texto-fonte (chave); os outros idiomas vêm de
## res://assets/data/i18n/<lang>.json ({"texto em português": "tradução"}). O idioma sai da
## escolha salva (localStorage), do ?lang= da página, do navegador (navigator.languages) ou do
## sistema; qualquer idioma que não seja português cai no inglês.
##
##   L.t("texto")            -> texto traduzido (ou o original se não houver tradução)
##   L.tf("%d de %d", [a,b]) -> traduz o modelo e depois formata
##   L.tx(dict, "title")     -> dict["title_en"] se existir, senão L.t(dict["title"])
##   L.set_lang("en")        -> salva a escolha e recarrega

signal changed

const SUPPORTED := ["pt", "en"]
const KEY := "pf_lang"

var lang := "pt"
var _dict: Dictionary = {}


func _ready() -> void:
	print("PFT %5d ms  autoload L" % Time.get_ticks_msec())
	lang = _detect()
	_load()


func _detect() -> String:
	var env := OS.get_environment("PF_LANG")
	if env != "":
		return _norm(env)
	if OS.has_feature("web"):
		var saved: Variant = JavaScriptBridge.eval("(function(){try{return localStorage.getItem('%s')||''}catch(e){return ''}})()" % KEY, true)
		if saved != null and str(saved) != "":
			return _norm(str(saved))
		var q: Variant = JavaScriptBridge.eval("(new URLSearchParams(location.search)).get('lang')||''", true)
		if q != null and str(q) != "":
			return _norm(str(q))
		var path: Variant = JavaScriptBridge.eval("location.pathname", true)
		if path != null and str(path).begins_with("/en"):
			return "en"
		# padrão do usuário: abre em INGLÊS (tela de carregamento, entrada e cidade) até a pessoa
		# escolher outro idioma no seletor (a escolha fica salva e passa a valer)
		return "en"
	return _norm(OS.get_locale())


func _norm(s: String) -> String:
	return "pt" if s.to_lower().begins_with("pt") else "en"


func _load() -> void:
	_dict = {}
	if lang == "pt":
		return
	var path := "res://assets/data/i18n/%s.json" % lang
	if FileAccess.file_exists(path):
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if v is Dictionary:
			_dict = v


func t(s: String) -> String:
	if lang == "pt" or s == "":
		return s
	if _dict.has(s):
		return str(_dict[s])
	# rótulo com seta/ícone no fim ("ABRIR O SITE  ↗"): traduz a base e devolve o sufixo
	for suf in ["  ↗", " ↗", "  ▶", " ▶"]:
		if s.ends_with(suf):
			var base := s.substr(0, s.length() - suf.length())
			var tb := t(base)
			if tb != base:
				return tb + suf
	# tenta sem diferença de caixa (rótulos em maiúsculas)
	var low := s.to_lower()
	if _dict.has(low):
		var r := str(_dict[low])
		return r.to_upper() if s == s.to_upper() else r
	return s


func tf(fmt: String, args: Array) -> String:
	return t(fmt) % args


func tx(d: Dictionary, field: String) -> String:
	if lang != "pt":
		var k := field + "_" + lang
		if d.has(k) and str(d[k]) != "":
			return str(d[k])
	return t(str(d.get(field, "")))


func tarr(a: Array) -> Array:
	var out := []
	for x in a:
		out.append(t(str(x)))
	return out


## idioma imposto pela página (/en/ abre em inglês): sem salvar e sem recarregar
func force(l: String) -> void:
	l = _norm(l)
	if l == lang:
		return
	lang = l
	_load()
	changed.emit()


func set_lang(l: String) -> void:
	l = _norm(l)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try{localStorage.setItem('%s','%s')}catch(e){}" % [KEY, l], true)
	if l == lang:
		return
	if live_ok():
		switch_live(l)
		return
	lang = l
	_load()
	changed.emit()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("location.reload()", true)
	else:
		get_tree().reload_current_scene()


# ───────────────────────────────── troca AO VIVO (rodada 4): sem recarregar a página nem o motor
## Mantém posição, câmera e loja aberta. Textos já montados (HUD, painéis, letreiros 3D) são trocados pelo
## par pt/en (dicionário + campos *_en dos dados + literais da cidade); imagens com _pt/_en no nome (anúncios,
## outdoors) trocam de textura com o pacote do outro idioma (baixado em segundo plano depois do ENTRAR).
## `?live=0` volta a recarregar.
signal switching(to: String)
var busy := false
## literais montados com `if L.lang` (cidade, HUD) que não estão no dicionário: pt -> en
const EXTRA := {
	"LAB · SOBRE MIM": "LAB · ABOUT ME", "CARREIRA": "CAREER", "CONTATO": "CONTACT", "PROJETOS": "PROJECTS",
	"VOCÊ ESTÁ AQUI": "YOU ARE HERE", "CAFÉ DEV": "DEV CAFÉ", "café · git push · deploy": "cold brew · git push · deploy",
	"STACK DO GABRIEL": "GABRIEL'S STACK", "ENTRANDO...": "ENTERING...", "Carregando a loja...": "Loading the shop...",
	"English": "Português", "EN": "PT",
}


func live_ok() -> bool:
	if OS.get_environment("PF_LIVE") == "0":
		return false
	if OS.has_feature("web"):
		return not UI.js_flag("/[?&]live=0/.test(location.search)?1:0")
	return true


## pares pt -> en de tudo que já pode estar escrito na tela
func _pairs() -> Dictionary:
	var en: Dictionary = {}
	var f := "res://assets/data/i18n/en.json"
	if FileAccess.file_exists(f):
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(f))
		if v is Dictionary:
			en = v
	var out := {}
	for k in en:
		out[str(k)] = str(en[k])
	for k in EXTRA:
		out[k] = EXTRA[k]
	var data := get_node_or_null("/root/Data")
	if data:
		_pairs_from(data.get("projects"), out, 0)
		_pairs_from(data.get("profile"), out, 0)
	var up := {}
	for k in out:
		var ku := str(k).to_upper()
		if ku != k and not out.has(ku):
			up[ku] = str(out[k]).to_upper()
	out.merge(up)
	return out


## campos "x" e "x_en" dos dados (projetos, perfil) viram pares
func _pairs_from(v: Variant, out: Dictionary, depth: int) -> void:
	if depth > 6:
		return
	if v is Dictionary:
		var d := v as Dictionary
		for k in d:
			var ks := str(k)
			if d.has(ks + "_en") and d[k] is String and d[ks + "_en"] is String and str(d[k]) != "":
				out[str(d[k])] = str(d[ks + "_en"])
			elif d[k] is Dictionary or d[k] is Array:
				_pairs_from(d[k], out, depth + 1)
	elif v is Array:
		for x in v:
			if x is Dictionary or x is Array:
				_pairs_from(x, out, depth + 1)


var _pairs_cache := {}


var _tex_idx: Array = []      # [material, chave] com textura de idioma (_pt/_en), achados uma vez
var _idx_ready := false


## monta com antecedência: pares de texto, índice dos materiais com imagem de idioma e (no PC) as texturas do
## outro idioma já carregadas. main.gd chama ainda com o carregador na tela (`now`, sem fatias: decodificar as
## páginas de anúncio custa ~80 ms cada e não pode cair no meio do jogo); sem o pacote, fica para a troca.
var _prepared := false


func prepare(now := false) -> void:
	if _prepared:
		return
	_prepared = true
	var t0 := Time.get_ticks_usec()
	if _pairs_cache.is_empty():
		_pairs_cache = _pairs()
	if not now:
		await get_tree().process_frame
	var world: Array = get_tree().root.find_children("*", "GeometryInstance3D", true, false)
	var seen := {}
	var t := Time.get_ticks_usec()
	for g in world:
		if not now and Time.get_ticks_usec() - t > 4000:
			await get_tree().process_frame
			t = Time.get_ticks_usec()
		if is_instance_valid(g) and not _in_shop_tree(g):
			_index_geom(g as GeometryInstance3D, seen, _tex_idx)
	_idx_ready = true
	var n := 0
	var ui := get_node_or_null("/root/UI")
	var packs := get_node_or_null("/root/Packs")
	var other := "pt" if lang == "en" else "en"
	if now and not (ui and ui.is_mobile()) and packs and packs.ready_pack("lang_" + other):
		for e in _tex_idx:
			var v: Variant = _get_tex(e[0], e[1])
			if v is Texture2D and swap_tex(v, lang, other) != v:
				n += 1
	print("PFT idioma preparado: %d pares, %d materiais com imagem de idioma, %d texturas do outro idioma, %d ms" % [_pairs_cache.size(), _tex_idx.size(), n, (Time.get_ticks_usec() - t0) / 1000])


func _in_shop_tree(n: Node) -> bool:
	var q := n
	while q != null:
		if q.is_in_group("pf_shop"):
			return true
		q = q.get_parent()
	return false


func _get_tex(m: Material, k: String) -> Variant:
	if k == "@albedo":
		return (m as BaseMaterial3D).albedo_texture
	if k == "@emission":
		return (m as BaseMaterial3D).emission_texture
	return (m as ShaderMaterial).get_shader_parameter(k)


static var _lang_re: RegEx


func _is_lang_tex(t: Variant) -> bool:
	if not (t is Texture2D):
		return false
	if t is AtlasTexture:
		return _is_lang_tex((t as AtlasTexture).atlas)
	if _lang_re == null:
		_lang_re = RegEx.create_from_string("_(pt|en)(?=[_.])")
	return _lang_re.search(str((t as Texture2D).resource_path).get_file()) != null


func _index_geom(gi: GeometryInstance3D, seen: Dictionary, out: Array) -> void:
	var mats: Array = []
	if gi.material_override:
		mats.append(gi.material_override)
	if gi is MeshInstance3D and (gi as MeshInstance3D).mesh:
		var mi := gi as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i)
			if m:
				mats.append(m)
			m = mi.mesh.surface_get_material(i)
			if m:
				mats.append(m)
	elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh and (gi as MultiMeshInstance3D).multimesh.mesh:
		var mm := (gi as MultiMeshInstance3D).multimesh.mesh
		for i in mm.get_surface_count():
			if mm.surface_get_material(i):
				mats.append(mm.surface_get_material(i))
	for m in mats:
		_index_mat(m, seen, out)


func _index_mat(m: Material, seen: Dictionary, out: Array) -> void:
	if m == null or seen.has(m.get_instance_id()):
		return
	seen[m.get_instance_id()] = true
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		if sm.shader:
			for u in sm.shader.get_shader_uniform_list():
				if _is_lang_tex(sm.get_shader_parameter(str(u["name"]))):
					out.append([m, str(u["name"])])
		if sm.has_meta("noir_src"):
			_index_mat(sm.get_meta("noir_src"), seen, out)
	elif m is BaseMaterial3D:
		if _is_lang_tex((m as BaseMaterial3D).albedo_texture):
			out.append([m, "@albedo"])
		if _is_lang_tex((m as BaseMaterial3D).emission_texture):
			out.append([m, "@emission"])
	if m.next_pass:
		_index_mat(m.next_pass, seen, out)


func switch_live(l: String) -> void:
	if busy:
		return
	busy = true
	var t0 := Time.get_ticks_usec()
	switching.emit(l)
	var packs := get_node_or_null("/root/Packs")
	if packs and packs.has_method("need"):
		await packs.need("lang_" + l)
	var t1 := Time.get_ticks_usec()
	var from := lang
	if _pairs_cache.is_empty():
		_pairs_cache = _pairs()
	var map := {}
	if l == "en":
		map = _pairs_cache
	else:
		for k in _pairs_cache:
			map[_pairs_cache[k]] = k
	lang = l
	_load()
	var root := get_tree().root
	var n_txt := _retext(root, map)
	changed.emit()
	if OS.has_feature("web"):
		JavaScriptBridge.eval(_JS_URL % ("true" if l == "en" else "false"), true)
	# textos prontos: é isto que o jogador lê primeiro (as imagens vêm logo atrás)
	last_ms = (Time.get_ticks_usec() - t1) / 1000
	var n_tex := 0
	if _idx_ready:
		var idx: Array = _tex_idx.duplicate()
		var seen := {}
		for sh in get_tree().get_nodes_in_group("pf_shop"):
			for g in (sh as Node).find_children("*", "GeometryInstance3D", true, false):
				_index_geom(g as GeometryInstance3D, seen, idx)
		var tq := Time.get_ticks_usec()
		for e in idx:
			var v: Variant = _get_tex(e[0], e[1])
			if v is Texture2D:
				# imagem ainda não carregada (celular não guarda as do outro idioma): uma por quadro,
				# para a troca não congelar a tela
				var fresh := not _swap_cache.has("%d|%s" % [(v as Texture2D).get_instance_id(), l])
				var nt := swap_tex(v, from, l)
				if nt != v:
					_set_tex(e[0], e[1], nt)
					n_tex += 1
				if fresh and Time.get_ticks_usec() - tq > 30000:
					await get_tree().process_frame
					tq = Time.get_ticks_usec()
		for c in get_tree().get_nodes_in_group("pf_lang_tex"):
			n_tex += int(c.call("lang_textures", from, l))
	else:
		n_tex = _retexture(root, from, l)
	var all_ms := (Time.get_ticks_usec() - t1) / 1000
	print("PFT idioma ao vivo %s -> %s: %d textos em %d ms, %d texturas (tudo em %d ms; +%d ms esperando o pacote)" % [from, l, n_txt, last_ms, n_tex, all_ms, (t1 - t0) / 1000])
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__pfLangMs=%d;window.__pfLangAllMs=%d" % [last_ms, all_ms], true)
	busy = false


var last_ms := 0


const _JS_URL := """(function(en){try{
var p=location.pathname, q=location.search.replace(/([?&])lang=[a-z]+&?/,'$1').replace(/[?&]$/,''), h=location.hash;
var home=(p==='/'||p==='/index.html'||p==='/en'||p==='/en/'||p==='/en/index.html');
if(home){p=en?'/en/':'/';}
history.replaceState(history.state,'',p+q+h);
document.documentElement.lang=en?'en':'pt-BR';
if(home){document.title=en?'Gabriel Inácio · Portfolio · Full-Stack Software Engineer, Game Dev and AI':'Gabriel Inácio · Portfólio · Desenvolvedor Full-Stack, Game Dev e IA';}
}catch(e){}})(%s)"""


func _retext(n: Node, map: Dictionary) -> int:
	var c := 0
	for x in n.get_children():
		if x is Label or x is Button or x is Label3D or x is LineEdit:
			var t: String = x.text
			if t != "" and map.has(t):
				x.text = map[t]
				c += 1
		elif x is RichTextLabel:
			var rt := x as RichTextLabel
			if map.has(rt.text):
				rt.text = map[rt.text]
				c += 1
		if x is Control and (x as Control).tooltip_text != "" and map.has((x as Control).tooltip_text):
			(x as Control).tooltip_text = map[(x as Control).tooltip_text]
		c += _retext(x, map)
	return c


var _swap_cache := {}


## textura do outro idioma (mesmo nome com _pt/_en trocado); AtlasTexture troca a página e mantém a região
func swap_tex(t: Texture2D, from: String, to: String) -> Texture2D:
	if t == null:
		return null
	var key := "%d|%s" % [t.get_instance_id(), to]
	if _swap_cache.has(key):
		return _swap_cache[key]
	var out: Texture2D = t
	if t is AtlasTexture and (t as AtlasTexture).atlas:
		var pg := swap_tex((t as AtlasTexture).atlas, from, to)
		if pg != (t as AtlasTexture).atlas:
			var a := AtlasTexture.new()
			a.atlas = pg
			a.region = (t as AtlasTexture).region
			out = a
	else:
		var p := t.resource_path
		var re := RegEx.create_from_string("_%s(?=[_.])" % from)
		if p != "" and re.search(p.get_file()) != null:
			var np := p.get_base_dir().path_join(re.sub(p.get_file(), "_" + to))
			if ResourceLoader.exists(np):
				out = load(np)
	_swap_cache[key] = out
	return out


func _set_tex(m: Material, k: String, t: Texture2D) -> void:
	if k == "@albedo":
		(m as BaseMaterial3D).albedo_texture = t
	elif k == "@emission":
		(m as BaseMaterial3D).emission_texture = t
	else:
		(m as ShaderMaterial).set_shader_parameter(k, t)
		if m.has_meta("noir_p"):
			(m.get_meta("noir_p") as Dictionary)[k] = t


func _retexture(root: Node, from: String, to: String) -> int:
	var c := 0
	var seen := {}
	for g in root.find_children("*", "GeometryInstance3D", true, false):
		var mats: Array = []
		var gi := g as GeometryInstance3D
		if gi.material_override:
			mats.append(gi.material_override)
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh:
			var mi := gi as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				var m := mi.get_surface_override_material(i)
				if m:
					mats.append(m)
				m = mi.mesh.surface_get_material(i)
				if m:
					mats.append(m)
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh and (gi as MultiMeshInstance3D).multimesh.mesh:
			var mm := (gi as MultiMeshInstance3D).multimesh.mesh
			for i in mm.get_surface_count():
				if mm.surface_get_material(i):
					mats.append(mm.surface_get_material(i))
		for m in mats:
			if seen.has(m.get_instance_id()):
				continue
			seen[m.get_instance_id()] = true
			c += _retex_mat(m, from, to)
	# telões que alternam anúncios guardam listas de texturas (city.gd)
	for n in get_tree().get_nodes_in_group("pf_lang_tex"):
		c += int(n.call("lang_textures", from, to))
	return c


func _retex_mat(m: Material, from: String, to: String) -> int:
	var c := 0
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		if sm.shader:
			for u in sm.shader.get_shader_uniform_list():
				var v: Variant = sm.get_shader_parameter(str(u["name"]))
				if v is Texture2D:
					var nt := swap_tex(v, from, to)
					if nt != v:
						sm.set_shader_parameter(str(u["name"]), nt)
						if sm.has_meta("noir_p"):
							(sm.get_meta("noir_p") as Dictionary)[str(u["name"])] = nt
						c += 1
		if sm.has_meta("noir_src"):
			c += _retex_mat(sm.get_meta("noir_src"), from, to)
	elif m is BaseMaterial3D:
		var bm := m as BaseMaterial3D
		var nt := swap_tex(bm.albedo_texture, from, to)
		if nt != bm.albedo_texture:
			bm.albedo_texture = nt
			c += 1
		var ne := swap_tex(bm.emission_texture, from, to)
		if ne != bm.emission_texture:
			bm.emission_texture = ne
			c += 1
	if m.next_pass:
		c += _retex_mat(m.next_pass, from, to)
	return c
