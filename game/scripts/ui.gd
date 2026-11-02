extends Node
## DESIGN SYSTEM NOIR (autoload UI). Tokens (cor, tipo, espaço, raio, brilho), regras de tamanho por
## FORMATO de tela e componentes reutilizáveis (botão, ícone-botão, cartão, chip, toast, tecla).
## A tela lógica muda por orientação (main.gd): celular em pé 720x1280, celular deitado 960x540 e
## PC 1280x720. Por isso os tamanhos vêm de ff() + tabelas: no celular em pé 2 unidades lógicas = 1 px
## real (alvo de toque de 88 = 44 px reais), no deitado ~1,4 e no PC ~0,67 a 1,5.
## Regras: nada cortado (quebra de linha, rolagem por toque, largura máxima no PC), alvos de toque
## >= 44 px reais, contraste legível, foco visível no teclado, microanimações curtas.

# ─────────────── cores (tokens)
const INK := Color("#06070d")        # fundo mais escuro
const NIGHT := Color("#0b1020")      # fundo de painel opaco
const PANEL := Color("#0f1528")      # superfície
const PANEL_2 := Color("#151d36")    # superfície elevada (cartão)
const STROKE := Color(0.62, 0.70, 0.95, 0.16)   # borda discreta
const MIST := Color("#9aa9cf")       # texto secundário
const DIM := Color("#66729a")        # texto terciário
const PAPER := Color("#eef1fb")      # texto principal
const AMBER := Color("#ffc83d")      # acento principal (ação)
const PINK := Color("#ff4f9a")
const CYAN := Color("#4ec9ff")
const VIOLET := Color("#9b7bff")
const RED := Color("#ff4d63")
const GREEN := Color("#5fe0a0")

var _fonts := {}


func font(kind := "body") -> Font:
	if _fonts.is_empty():
		_fonts = {
			"title": load("res://assets/fonts/BebasNeue-Regular.ttf"),
			"body": load("res://assets/fonts/Nunito-Var.ttf"),
			"type": load("res://assets/fonts/SpecialElite-Regular.ttf"),
			"marker": load("res://assets/fonts/PermanentMarker-Regular.ttf"),
		}
		# símbolos (✕ ↗ ▶ ★ ...) vêm de uma fonte própria: no navegador não há fonte do sistema e
		# eles viravam quadrados
		var sym: Font = load("res://assets/fonts/NoirSymbols.ttf")
		for k in _fonts:
			var f: Font = _fonts[k]
			if f and sym and not f.fallbacks.has(sym):
				var fb: Array[Font] = []
				fb.assign(f.fallbacks)
				fb.append(sym)
				f.fallbacks = fb
		# corpo um pouco mais encorpado (variável Nunito): leitura melhor sobre fundo escuro
		var fv := FontVariation.new()
		fv.base_font = _fonts["body"]
		fv.variation_opentype = {"wght": 560}
		_fonts["body"] = fv
		var fb2 := FontVariation.new()
		fb2.base_font = fv.base_font
		fb2.variation_opentype = {"wght": 800}
		_fonts["bold"] = fb2
	return _fonts.get(kind, _fonts["body"])


# ─────────────── formato de tela e escalas
## "phone" (em pé), "land" (celular deitado, tela baixa) ou "desk" (PC/tablet deitado)
func ff(ctrl: CanvasItem = null) -> String:
	var vs := _vs(ctrl)
	if vs.y > vs.x:
		return "phone"
	if vs.y < 600.0:
		return "land"
	return "desk"


func _vs(ctrl: CanvasItem = null) -> Vector2:
	if ctrl and ctrl.is_inside_tree():
		return ctrl.get_viewport_rect().size
	var t := Engine.get_main_loop() as SceneTree
	if t and t.root:
		return t.root.get_visible_rect().size
	return Vector2(1280, 720)


const _FS := {
	"display": {"phone": 104, "land": 66, "desk": 84},
	"h1": {"phone": 56, "land": 40, "desk": 44},
	"h2": {"phone": 40, "land": 30, "desk": 30},
	"h3": {"phone": 32, "land": 23, "desk": 23},
	"body": {"phone": 28, "land": 20, "desk": 19},
	"small": {"phone": 23, "land": 17, "desk": 16},
	"cap": {"phone": 19, "land": 14, "desk": 13},
}


## tamanho de fonte pelo papel tipográfico
func fs(role: String, ctrl: CanvasItem = null) -> int:
	return int(_FS.get(role, _FS["body"])[ff(ctrl)])


## espaçamento na escala de 4 (n = 1,2,3...): celular em pé maior
func sp(n: float, ctrl: CanvasItem = null) -> int:
	var u: float = float({"phone": 8.0, "land": 5.0, "desk": 6.0}[ff(ctrl)])
	return int(round(u * n))


## alvo de toque/clique mínimo (44 px reais no celular)
func tap(ctrl: CanvasItem = null) -> int:
	return int({"phone": 88, "land": 60, "desk": 46}[ff(ctrl)])


func radius(ctrl: CanvasItem = null) -> int:
	return int({"phone": 22, "land": 14, "desk": 14}[ff(ctrl)])


## largura máxima de leitura de um painel no PC
func max_w(ctrl: CanvasItem = null) -> float:
	return {"phone": 99999.0, "land": 900.0, "desk": 940.0}[ff(ctrl)]


# ─────────────── estilos
func box(bg: Color, border := Color.TRANSPARENT, bw := 0, rad := 12, pad := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	s.set_corner_radius_all(rad)
	s.anti_aliasing = true
	if pad > 0:
		s.set_content_margin_all(pad)
	return s


## superfície de vidro escuro com borda fina e brilho de acento (painéis e barras)
func glass(accent := Color.TRANSPARENT, rad := -1, pad := 0, alpha := 0.9) -> StyleBoxFlat:
	var s := box(Color(PANEL, alpha), STROKE, 1, rad if rad >= 0 else radius(), pad)
	if accent.a > 0.0:
		s.border_color = Color(accent, 0.55)
		s.shadow_color = Color(accent, 0.18)
		s.shadow_size = 18
	else:
		s.shadow_color = Color(0, 0, 0, 0.45)
		s.shadow_size = 14
	return s


func label(text: String, size := 24, col := PAPER, kind := "body") -> Label:
	var l := Label.new()
	l.text = L.t(text)
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## texto pelo papel tipográfico do design system (tamanho automático pelo formato)
func text(t: String, role := "body", col := PAPER, kind := "") -> Label:
	var k := kind
	if k == "":
		k = "title" if role in ["display", "h1", "h2", "h3"] else "body"
	return label(t, fs(role), col, k)


## sobretítulo em caixa alta espaçada (kicker)
func kicker(t: String, col := AMBER) -> Label:
	var l := label(L.t(t).to_upper(), fs("cap"), col, "bold")
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	l.add_theme_constant_override("line_spacing", 0)
	l.uppercase = true
	return l


func title(t: String, size := 48, col := AMBER) -> Label:
	return label(t, size, col, "title")


func vbox(sep := 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


func hbox(sep := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func margin(all: int, top := -1, bottom := -1) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", all)
	m.add_theme_constant_override("margin_right", all)
	m.add_theme_constant_override("margin_top", all if top < 0 else top)
	m.add_theme_constant_override("margin_bottom", all if bottom < 0 else bottom)
	return m


# ─────────────── botões
## Botão principal (preenchido com o acento). h = 0 usa o alvo de toque do formato.
func button(t: String, neon := AMBER, h := 0) -> Button:
	var b := Button.new()
	b.text = L.t(t)
	var hh := h if h > 0 else tap()
	b.custom_minimum_size.y = hh
	b.add_theme_font_override("font", font("title"))
	b.add_theme_font_size_override("font_size", int(clampf(hh * 0.4, 18, 38)))
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_focus_color", INK)
	var r := int(clampf(hh * 0.22, 8, 18))
	var n := box(neon, neon, 0, r, int(hh * 0.22))
	n.shadow_color = Color(neon, 0.35)
	n.shadow_size = 10
	b.add_theme_stylebox_override("normal", n)
	var hv := box(neon.lightened(0.14), neon, 0, r, int(hh * 0.22))
	hv.shadow_color = Color(neon, 0.6)
	hv.shadow_size = 18
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", box(neon.darkened(0.18), neon, 0, r, int(hh * 0.22)))
	b.add_theme_stylebox_override("focus", _focus_ring(r))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_press_anim(b)
	return b


## Botão secundário (contorno de neon, fundo escuro)
func ghost(t: String, neon := CYAN, h := 0) -> Button:
	var b := button(t, neon, h)
	var hh := b.custom_minimum_size.y
	var r := int(clampf(hh * 0.22, 8, 18))
	b.add_theme_color_override("font_color", neon.lightened(0.15))
	b.add_theme_color_override("font_hover_color", PAPER)
	b.add_theme_color_override("font_pressed_color", PAPER)
	b.add_theme_color_override("font_focus_color", PAPER)
	b.add_theme_stylebox_override("normal", box(Color(NIGHT, 0.82), Color(neon, 0.7), 2, r, int(hh * 0.22)))
	var hv := box(Color(neon, 0.18), neon, 2, r, int(hh * 0.22))
	hv.shadow_color = Color(neon, 0.35)
	hv.shadow_size = 12
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", box(Color(neon, 0.32), neon, 2, r, int(hh * 0.22)))
	return b


## Botão quadrado só com ícone desenhado (Icon) e dica de texto
func icon_btn(icon: String, neon := PAPER, side := 0, tip := "") -> Button:
	var s := side if side > 0 else tap()
	var b := Button.new()
	b.custom_minimum_size = Vector2(s, s)
	b.tooltip_text = L.t(tip)
	b.focus_mode = Control.FOCUS_ALL
	var r := int(clampf(s * 0.28, 8, 20))
	b.add_theme_stylebox_override("normal", box(Color(PANEL, 0.78), STROKE, 1, r))
	var hv := box(Color(neon, 0.16), Color(neon, 0.8), 1, r)
	hv.shadow_color = Color(neon, 0.3)
	hv.shadow_size = 10
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", box(Color(neon, 0.3), neon, 1, r))
	b.add_theme_stylebox_override("focus", _focus_ring(r))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var ic := Icon.make(icon, neon, s * 0.46)
	ic.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	b.add_child(ic)
	b.set_meta("icon", ic)
	_press_anim(b)
	return b


func _focus_ring(r: int) -> StyleBoxFlat:
	var f := box(Color.TRANSPARENT, Color(CYAN, 0.9), 2, r + 2)
	f.set_expand_margin_all(3)
	f.draw_center = false
	return f


## microanimação de toque: encolhe de leve ao pressionar
func _press_anim(b: Button) -> void:
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size / 2.0
		b.create_tween().tween_property(b, "scale", Vector2(0.96, 0.96), 0.06))
	b.button_up.connect(func() -> void:
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK))


# ─────────────── cartão, chip, tecla, toast
func card(accent := Color.TRANSPARENT, pad := -1) -> PanelContainer:
	var p := PanelContainer.new()
	var s := box(Color(PANEL_2, 0.92), STROKE if accent.a == 0.0 else Color(accent, 0.45), 1, radius(), pad if pad >= 0 else sp(2))
	p.add_theme_stylebox_override("panel", s)
	return p


func chip(t: String, col := AMBER) -> PanelContainer:
	var p := PanelContainer.new()
	var pad := sp(1.2)
	var s := box(Color(col, 0.14), Color(col, 0.55), 1, 999, 0)
	s.content_margin_left = pad * 1.6
	s.content_margin_right = pad * 1.6
	s.content_margin_top = pad * 0.5
	s.content_margin_bottom = pad * 0.6
	p.add_theme_stylebox_override("panel", s)
	var l := label(t, fs("cap"), col.lightened(0.2), "bold")
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	p.add_child(l)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return p


## ícone de tecnologia do atlas compartilhado do cenário (assets/tech_icons + tech_icons.json).
## Aceita no JSON: {"<nome ou id>": "arquivo.png"} ou {"<nome>": {"id"|"file"|"atlas"+"rect"}}.
## Sem atlas ou sem o ícone: devolve null e o chip mostra só o nome.
var _tech := {}
var _tech_loaded := false
var _tech_cache := {}


func _tech_key(s: String) -> String:
	var k := s.to_lower().strip_edges()
	for ch in [" ", ".", "-", "_", "/", "(", ")", "+"]:
		k = k.replace(ch, "")
	return k


func tech_icon(name: String) -> Texture2D:
	if not _tech_loaded:
		_tech_loaded = true
		for p in ["res://assets/data/tech_icons.json", "res://assets/tech_icons/tech_icons.json"]:
			if FileAccess.file_exists(p):
				var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
				if v is Dictionary:
					var src: Dictionary = v.get("icons", v)
					for k in src:
						_tech[_tech_key(str(k))] = src[k]
						if src[k] is Dictionary:
							for al in (src[k] as Dictionary).get("aliases", []):
								_tech[_tech_key(str(al))] = src[k]
				break
	var key := _tech_key(name.split(" (")[0])
	if _tech_cache.has(key):
		return _tech_cache[key]
	var tex: Texture2D = null
	var e: Variant = _tech.get(key)
	var path := ""
	if e is String:
		path = str(e)
	elif e is Dictionary:
		var d: Dictionary = e
		if d.has("atlas") and d.has("rect"):
			var at := "res://assets/tech_icons/" + str(d["atlas"]) if not str(d["atlas"]).begins_with("res://") else str(d["atlas"])
			if ResourceLoader.exists(at):
				var a := AtlasTexture.new()
				a.atlas = load(at)
				var r: Array = d["rect"]
				a.region = Rect2(r[0], r[1], r[2], r[3])
				tex = a
		path = str(d.get("file", str(d.get("id", "")) + ".png" if d.has("id") else ""))
	elif ResourceLoader.exists("res://assets/tech_icons/%s.png" % key):
		path = key + ".png"
	if tex == null and path != "":
		if not path.begins_with("res://"):
			path = "res://assets/tech_icons/" + path
		if ResourceLoader.exists(path):
			tex = load(path)
	_tech_cache[key] = tex
	return tex


## chip de tecnologia: ícone do atlas + nome (cai para chip simples se o ícone não existir)
func tech_chip(t: String, col := AMBER) -> PanelContainer:
	var p := chip(t, col)
	var tex := tech_icon(t)
	if tex:
		var lbl := p.get_child(0)
		p.remove_child(lbl)
		var h := hbox(sp(0.6))
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var s := fs("cap") * 1.35
		tr.custom_minimum_size = Vector2(s, s)
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(tr)
		h.add_child(lbl)
		p.add_child(h)
	return p


## tecla desenhada (keycap) para as legendas de comandos
func keycap(t: String, col := PAPER) -> PanelContainer:
	var p := PanelContainer.new()
	var hh: int = {"phone": 46, "land": 30, "desk": 30}[ff()]
	var s := box(Color(PANEL_2, 1.0), Color(col, 0.55), 1, 7, 0)
	s.border_width_bottom = 3
	s.content_margin_left = hh * 0.28
	s.content_margin_right = hh * 0.28
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(hh, hh)
	var l := label(t, int(hh * 0.5), col, "bold")
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## aviso curto no rodapé (some sozinho)
func toast(host: Control, msg: String, col := AMBER, secs := 2.4) -> void:
	if host == null or not host.is_inside_tree():
		return
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", glass(col, 999, sp(1.6)))
	var h := hbox(sp(1))
	h.add_child(Icon.make("dot", col, fs("small") * 0.7))
	var l := label(msg, fs("small"), PAPER, "bold")
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	p.add_child(h)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(p)
	await host.get_tree().process_frame
	var vs := host.get_viewport_rect().size
	p.position = Vector2((vs.x - p.size.x) / 2.0, vs.y * 0.2)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.18)
	tw.tween_interval(secs)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)


func full(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


## o dispositivo tem toque (para escolher a legenda de comandos)
func is_touch() -> bool:
	return is_mobile() or OS.get_environment("PF_TOUCH") != "" or DisplayServer.is_touchscreen_available() and _vs().y > _vs().x


## área segura de cima (entalhe/barra do navegador), em unidades lógicas
func safe_top(ctrl: CanvasItem = null) -> int:
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_position()
	var real := safe.position.y - win.y
	var k := _vs(ctrl).y / maxf(1.0, float(DisplayServer.window_get_size().y))
	return clampi(int(real * k), 0, 80)


# ───────────────────────────────── preferência: sensibilidade da câmera no toque
static var _look_sens := -1.0


static func look_sens() -> float:
	if _look_sens < 0.0:
		_look_sens = 1.0
		if OS.has_feature("web"):
			var v: Variant = JavaScriptBridge.eval("(function(){try{return localStorage.getItem('pf_look_sens')||''}catch(e){return ''}})()", true)
			if str(v) != "" and str(v).is_valid_float():
				_look_sens = clampf(float(str(v)), 0.3, 2.0)
	return _look_sens


static func set_look_sens(v: float) -> void:
	_look_sens = clampf(v, 0.3, 2.0)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try{localStorage.setItem('pf_look_sens','%s')}catch(e){}" % str(snappedf(_look_sens, 0.05)), true)


# ───────────────────────────────── perfil de qualidade (performance)
## 2 = alto (PC nativo), 1 = padrão (navegador no PC), 0 = batata (celular, GPU fraca ou FPS baixo).
## PF_QUALITY=batata|padrao|alto (capturas), ?q= na página ou pf_q no navegador forçam.
static var _quality := -1


static func quality() -> int:
	if _quality >= 0:
		return _quality
	var force := OS.get_environment("PF_QUALITY")
	if OS.has_feature("web") and force == "":
		var v: Variant = JavaScriptBridge.eval("(function(){try{var q=new URLSearchParams(location.search).get('q');return q||localStorage.getItem('pf_q')||''}catch(e){return ''}})()", true)
		force = str(v) if v != null else ""
	match force:
		"batata", "low", "0":
			_quality = 0
		"padrao", "medium", "1":
			_quality = 1
		"alto", "high", "2":
			_quality = 2
		_:
			var gpu := RenderingServer.get_video_adapter_name().to_lower()
			var weak := false
			for w in ["intel(r) hd", "intel hd", "uhd graphics 6", "mali-4", "mali-t", "adreno (tm) 3", "adreno (tm) 4", "adreno (tm) 50", "powervr", "swiftshader", "llvmpipe", "software", "angle (google"]:
				if gpu.find(w) >= 0:
					weak = true
			if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") or weak:
				_quality = 0
			elif OS.has_feature("web"):
				_quality = 1
			else:
				_quality = 2
	return _quality


static func set_quality(q: int) -> void:
	_quality = clampi(q, 0, 2)
