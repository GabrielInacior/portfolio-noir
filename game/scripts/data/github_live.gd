extends Node
## Dados do GitHub ao vivo, sem token (funciona no navegador). Busca perfil, repositorios,
## estrelas, linguagens, atividade e READMEs pela API publica do GitHub (limite de 60 por hora
## por IP). Guarda em cache no navegador (localStorage via window) e, se a API falhar ou estourar
## o limite, cai no snapshot gerado no build (res://assets/data/github_snapshot.json).
##
## Como usar (a cidade/telões chamam):
##   GithubLive.ready_data.connect(_on_data)   # emitido quando o snapshot/cache ja da para desenhar
##   GithubLive.fetch()                         # tenta atualizar ao vivo; emite updated se vier mais novo
##   GithubLive.repo(id)                        # Dictionary do repo (ao vivo ou snapshot)
##   GithubLive.readme(id)                      # texto markdown do README (snapshot do build)
##   GithubLive.activity()                      # Array de {repo,msg,at} para o ticker de LED
##   GithubLive.languages()                     # Dictionary linguagem->bytes agregado
##
## Nunca coloque token aqui: isto roda no cliente. Repos privados aparecem so pelo snapshot.

signal ready_data
signal updated

const USER := "GabrielInacior"
const SNAPSHOT := "res://assets/data/github_snapshot.json"
const CACHE_KEY := "pf_gh_cache_v1"
const CACHE_TTL := 1000 * 60 * 60 * 6   # 6 horas

var data: Dictionary = {}          # o que a interface usa (snapshot, cache ou ao vivo)
var _readmes: Dictionary = {}
var _by_id: Dictionary = {}
var _http: HTTPRequest


func _ready() -> void:
	# 1) snapshot do build: garante que sempre ha o que mostrar, mesmo offline
	var snap: Variant = _load(SNAPSHOT)
	if snap is Dictionary:
		data = snap
		_index()
	# 2) cache do navegador por cima (dados mais novos da ultima visita)
	var cached := _cache_get()
	if not cached.is_empty() and int(cached.get("_at", 0)) > int(data.get("_at", 0)):
		data = cached
		_index()
	ready_data.emit()


func _index() -> void:
	_by_id.clear()
	for r in data.get("repos", []):
		_by_id[str(r.get("id", ""))] = r


func repo(id: String) -> Dictionary:
	return _by_id.get(id, {})


func activity() -> Array:
	return data.get("activity", [])


func languages() -> Dictionary:
	return data.get("languages", {})


func total_stars() -> int:
	return int(data.get("total_stars", 0))


func readme(id: String) -> String:
	if _readmes.has(id):
		return _readmes[id]
	var path := "res://assets/data/readmes/%s.md" % id
	var txt := ""
	if FileAccess.file_exists(path):
		txt = FileAccess.get_file_as_string(path)
	_readmes[id] = txt
	return txt


## README ao vivo de um repo publico (raw). cb recebe o texto; se falhar (privado, limite, offline),
## cb recebe o README do snapshot do build.
func fetch_readme(id: String, cb: Callable) -> void:
	var r := repo(id)
	var name := str(r.get("repo", id))
	if r.get("private", false) or not OS.has_feature("web") and OS.get_environment("PF_LIVE") == "":
		cb.call(readme(id))
		return
	var h := HTTPRequest.new()
	add_child(h)
	h.timeout = 8.0
	h.request_completed.connect(func(_r: int, code: int, _hh: PackedStringArray, body: PackedByteArray) -> void:
		h.queue_free()
		if code == 200 and body.size() > 20:
			_readmes[id] = body.get_string_from_utf8()
		cb.call(readme(id)))
	var err := h.request("https://api.github.com/repos/%s/%s/readme" % [USER, name], ["Accept: application/vnd.github.raw", "User-Agent: portfolio-noir"])
	if err != OK:
		h.queue_free()
		cb.call(readme(id))


## Tenta atualizar ao vivo. So no web vale a pena (navegador tem o IP do visitante); no editor
## tambem funciona, util para testar. Atualiza estrelas e atividade sem bloquear a cidade.
func fetch() -> void:
	if _http == null:
		_http = HTTPRequest.new()
		add_child(_http)
	_fetch_json("https://api.github.com/users/%s/repos?per_page=100&sort=updated" % USER, _on_repos)


func _fetch_json(url: String, cb: Callable) -> void:
	var h := HTTPRequest.new()
	add_child(h)
	h.request_completed.connect(func(_r: int, code: int, _hh: PackedStringArray, body: PackedByteArray) -> void:
		h.queue_free()
		if code == 200:
			var v: Variant = JSON.parse_string(body.get_string_from_utf8())
			cb.call(v)
	)
	var err := h.request(url, ["Accept: application/vnd.github+json", "User-Agent: portfolio-noir"])
	if err != OK:
		h.queue_free()


func _on_repos(v: Variant) -> void:
	if not (v is Array):
		return
	var live := {}
	var stars := 0
	for r in v:
		stars += int(r.get("stargazers_count", 0))
		live[str(r.get("name", "")).to_lower()] = r
	# atualiza estrelas e datas dos repos que ja conhecemos (mantem o resto do snapshot)
	var changed := false
	for rep in data.get("repos", []):
		var m: Dictionary = live.get(str(rep.get("repo", "")).to_lower(), {})
		if m.is_empty():
			continue
		var s := int(m.get("stargazers_count", 0))
		if s != int(rep.get("stars", 0)):
			rep["stars"] = s
			changed = true
		rep["updated"] = str(m.get("updated_at", rep.get("updated", ""))).substr(0, 10)
	if changed or stars != total_stars():
		data["total_stars"] = stars
		data["_at"] = Time.get_unix_time_from_system() * 1000.0
		_index()
		_cache_set(data)
		updated.emit()


# ---- cache no navegador (localStorage); silencioso fora do web ----
func _cache_get() -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	var raw: Variant = JavaScriptBridge.eval("window.localStorage.getItem('%s')" % CACHE_KEY, true)
	if raw == null or str(raw) == "":
		return {}
	var v: Variant = JSON.parse_string(str(raw))
	if v is Dictionary and Time.get_unix_time_from_system() * 1000.0 - float(v.get("_at", 0)) < CACHE_TTL:
		return v
	return {}


func _cache_set(d: Dictionary) -> void:
	if not OS.has_feature("web"):
		return
	var s := JSON.stringify(d).replace("\\", "\\\\").replace("'", "\\'")
	JavaScriptBridge.eval("window.localStorage.setItem('%s','%s')" % [CACHE_KEY, s], true)


func _load(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v != null else {}
