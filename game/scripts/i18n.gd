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
		var nav: Variant = JavaScriptBridge.eval("(navigator.languages&&navigator.languages[0])||navigator.language||'en'", true)
		return _norm(str(nav))
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


func set_lang(l: String) -> void:
	l = _norm(l)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try{localStorage.setItem('%s','%s')}catch(e){}" % [KEY, l], true)
	if l == lang:
		return
	lang = l
	_load()
	changed.emit()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("location.reload()", true)
	else:
		get_tree().reload_current_scene()
