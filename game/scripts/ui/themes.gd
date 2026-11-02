class_name Themes
extends RefCounted
## Identidade visual por projeto (assets/data/themes.json): cada loja tem o seu painel. O esqueleto é
## o mesmo do design system (Sheet: cabeçalho fixo, imagem, título, texto, chips, links); o tema troca
## fundo, moldura, tipografia do título, sobretítulo e uma decoração desenhada (carimbo do dossiê,
## scanlines do terminal, moldura de fliperama, filete de cardápio, grade de planta da carreira).

static var _data := {}


static func _load() -> void:
	if not _data.is_empty():
		return
	var p := "res://assets/data/themes.json"
	if FileAccess.file_exists(p):
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
		if v is Dictionary:
			_data = v


static func id_of(project: Dictionary) -> String:
	match str(project.get("special", "")):
		"about":
			return "_lab"
		"career":
			return "_carreira"
		"contact":
			return "contato"
	return str(project.get("id", ""))


static func of(project: Dictionary) -> Dictionary:
	_load()
	var t: Dictionary = (_data.get("_default", {}) as Dictionary).duplicate()
	var own: Dictionary = _data.get(id_of(project), {})
	for k in own:
		t[k] = own[k]
	if str(t.get("accent", "")) == "":
		t["accent"] = str(project.get("neon", "#ffc83d"))
	return t


static func col(t: Dictionary, key: String, fallback := Color.WHITE) -> Color:
	var s := str(t.get(key, ""))
	return Color(s) if s != "" else fallback


## aplica o tema a um Sheet já montado (setup chamado)
static func apply(sheet: Sheet, t: Dictionary) -> void:
	if sheet == null or t.is_empty():
		return
	sheet.theme_data = t
	sheet.restyle()
