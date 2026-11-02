class_name ControlsCard
extends PanelContainer
## Cartão "COMO JOGAR": comandos visuais (teclas desenhadas e ícones) para o dispositivo atual.
## PC: WASD/setas, mouse, E, M, Esc e clique nas placas. Celular: alavanca, arrastar, tocar.
## Mostra também o atalho de quem não quer andar (menu de lugares e mapa).

var touch := false
var compact := false


static func make(is_touch: bool, is_compact := false) -> ControlsCard:
	var c := ControlsCard.new()
	c.touch = is_touch
	c.compact = is_compact
	return c


func _ready() -> void:
	add_theme_stylebox_override("panel", UI.glass(Color.TRANSPARENT, UI.radius(self), UI.sp(2.4), 0.72))
	var v := UI.vbox(UI.sp(1.6))
	add_child(v)
	v.add_child(UI.kicker("como explorar", UI.CYAN))
	var rows: Array = []
	if touch:
		rows = [
			[["stick"], "Alavanca à esquerda para andar"],
			[["drag"], "Arraste à direita para olhar"],
			[["tap"], "Toque nos objetos, letreiros e pessoas"],
			[["places"], "Menu de lugares: vá direto, sem andar"],
		]
	else:
		rows = [
			[["W", "A", "S", "D"], "Andar (ou setas)"],
			[["mouse"], "Olhar em volta"],
			[["E"], "Interagir, entrar, examinar"],
			[["M"], "Mapa  ·  clique num lugar para ir"],
			[["places"], "Menu de lugares: vá direto, sem andar"],
			[["Esc"], "Soltar o mouse / fechar"],
		]
	var grid := GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.columns = 2 if not compact else 1
	grid.add_theme_constant_override("h_separation", UI.sp(3))
	grid.add_theme_constant_override("v_separation", UI.sp(1.4))
	v.add_child(grid)
	for r in rows:
		grid.add_child(_row(r[0], r[1]))


func _row(keys: Array, txt: String) -> Control:
	var h := UI.hbox(UI.sp(1.2))
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var keys_box := UI.hbox(UI.sp(0.5))
	keys_box.custom_minimum_size.x = UI.sp(15) if not touch else UI.sp(7)
	for k in keys:
		var ks := str(k)
		if ks in ["mouse", "stick", "drag", "tap", "places"]:
			var holder := PanelContainer.new()
			holder.add_theme_stylebox_override("panel", UI.box(Color(UI.CYAN, 0.12), Color(UI.CYAN, 0.5), 1, 8, UI.sp(0.6)))
			holder.add_child(Icon.make(ks, UI.CYAN, UI.fs("body") * 1.15))
			keys_box.add_child(holder)
		else:
			keys_box.add_child(UI.keycap(ks, UI.PAPER))
	h.add_child(keys_box)
	var l := UI.text(txt, "small", UI.PAPER.darkened(0.12))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = UI.sp(28) if not compact else UI.sp(34)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	return h
