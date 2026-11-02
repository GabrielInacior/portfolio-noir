extends Control
## Peça da loja-museu (modal do design system): imagem grande encaixada na proporção certa, título,
## texto da história, etiqueta e links no rodapé fixo. Fecha no X, Esc ou clique fora.

signal closed

var _accent := UI.AMBER
var item: Dictionary = {}
var project: Dictionary = {}
var _sheet: Sheet


func setup(it: Dictionary, accent: Color, proj: Dictionary) -> void:
	item = it
	_accent = accent
	project = proj


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet = Sheet.new()
	add_child(UI.full(_sheet))
	_sheet.setup(L.t(str(project.get("title", ""))), L.tx(item, "title"), _accent)
	_sheet.closed.connect(func() -> void:
		closed.emit()
		queue_free())
	var img_path := str(item.get("img", ""))
	if img_path != "" and ResourceLoader.exists(img_path):
		_sheet.add_image(load(img_path))
	var tag := str(item.get("tag", ""))
	if tag != "":
		_sheet.add_chips([L.t(tag)])
	_sheet.add_text(L.tx(item, "text"), "body")
	var links: Dictionary = project.get("links", {}) if project.get("links") is Dictionary else {}
	if links.has("site"):
		_sheet.add_link(L.t("ABRIR O SITE"), str(links["site"]), true)
	if links.has("github"):
		_sheet.add_link("GITHUB", str(links["github"]), not links.has("site"))
	if links.is_empty() and bool(project.get("private", false)):
		var l := UI.text("Repositório privado", "small", UI.MIST)
		_sheet.footer.add_child(l)


func _close() -> void:
	if _sheet:
		_sheet.close()
