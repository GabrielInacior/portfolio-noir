extends Node
## Paleta noir, fontes e ajudantes de interface. Tons frios de noite com neon quente.

const INK := Color("#07080f")
const NIGHT := Color("#0b1020")
const PANEL := Color("#11182b")
const MIST := Color("#8ea0c8")
const PAPER := Color("#e8ecf8")
const AMBER := Color("#ffc83d")
const PINK := Color("#ff6fae")
const CYAN := Color("#4e9bff")
const RED := Color("#e2384f")
const GREEN := Color("#5fd38a")

var _fonts := {}


func font(kind := "body") -> Font:
	if _fonts.is_empty():
		_fonts = {
			"title": load("res://assets/fonts/BebasNeue-Regular.ttf"),
			"body": load("res://assets/fonts/Nunito-Var.ttf"),
			"type": load("res://assets/fonts/SpecialElite-Regular.ttf"),
			"marker": load("res://assets/fonts/PermanentMarker-Regular.ttf"),
		}
	return _fonts.get(kind, _fonts["body"])


func box(bg: Color, border := Color.TRANSPARENT, bw := 0, rad := 12, pad := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	s.set_corner_radius_all(rad)
	if pad > 0:
		s.set_content_margin_all(pad)
	return s


func label(text: String, size := 24, col := PAPER, kind := "body") -> Label:
	var l := Label.new()
	l.text = L.t(text)
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func title(text: String, size := 48, col := AMBER) -> Label:
	var l := label(text, size, col, "title")
	return l


func vbox(sep := 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


func hbox(sep := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func button(text: String, neon := AMBER, h := 68) -> Button:
	var b := Button.new()
	b.text = L.t(text)
	b.custom_minimum_size.y = h
	b.add_theme_font_override("font", font("title"))
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_stylebox_override("normal", box(neon, neon.darkened(0.3), 0, 10, 14))
	b.add_theme_stylebox_override("hover", box(neon.lightened(0.12), neon, 0, 10, 14))
	b.add_theme_stylebox_override("pressed", box(neon.darkened(0.15), neon, 0, 10, 14))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


func ghost(text: String, neon := CYAN, h := 60) -> Button:
	var b := button(text, neon, h)
	b.add_theme_color_override("font_color", neon)
	b.add_theme_color_override("font_hover_color", PAPER)
	b.add_theme_color_override("font_pressed_color", PAPER)
	b.add_theme_stylebox_override("normal", box(Color(NIGHT, 0.9), neon, 2, 10, 14))
	b.add_theme_stylebox_override("hover", box(Color(neon, 0.2), neon, 2, 10, 14))
	b.add_theme_stylebox_override("pressed", box(Color(neon, 0.35), neon, 2, 10, 14))
	return b


func full(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
