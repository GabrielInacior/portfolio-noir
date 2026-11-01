extends Node
## Carrega os dados do portfólio (projetos e perfil) dos JSON embutidos.

var profile: Dictionary = {}
var projects: Array = []


func _ready() -> void:
	profile = _load("res://assets/data/profile.json")
	var p: Variant = _load("res://assets/data/projects.json")
	if p is Array:
		projects = p


func _load(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v != null else {}
