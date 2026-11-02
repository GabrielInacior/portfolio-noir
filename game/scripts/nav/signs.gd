class_name StreetSigns
extends Control
## Placas flutuantes clicáveis acima de cada lugar da rua: pílula de vidro com ícone na cor do neon,
## nome e distância. Clicar (ou mirar e clicar com o mouse preso) leva até lá. Sem sobreposição:
## as mais perto têm prioridade. Desenhado em _draw (leve); o clique é tratado pelo HUD (hit()).

var city
var player
var world_vp: SubViewport
var _rects: Array = []      # [{rect, place}]
var _places: Array = []
var _t := 0.0
const MAX_D := 48.0
const MIN_D := 3.6


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(dt: float) -> void:
	_t += dt
	queue_redraw()


func _draw() -> void:
	_rects.clear()
	if city == null or player == null or player.cam == null or not visible:
		return
	if _places.size() != city.kiosks.size():
		_places = Nav.places(city)
	var cam: Camera3D = player.cam
	var vp_size := Vector2(world_vp.size) if world_vp else get_viewport_rect().size
	var k := get_viewport_rect().size / vp_size
	var pp: Vector3 = player.global_position
	var list := []
	for pl in _places:
		var pos: Vector3 = pl["pos"]
		var d := pp.distance_to(pos)
		if d > MAX_D or d < MIN_D:
			continue
		var top := pos + Vector3(0, 3.4, 0)
		if cam.is_position_behind(top):
			continue
		list.append([d, pl, cam.unproject_position(top) * k])
	list.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	var f := UI.font("bold")
	var fsz := UI.fs("cap", self) + 2
	var pad := Vector2(UI.sp(1.4, self), UI.sp(0.8, self))
	for it in list:
		var d: float = it[0]
		var pl: Dictionary = it[1]
		var sp: Vector2 = it[2]
		var name := str(pl["title"]).to_upper()
		var dist := "%dm" % int(round(d))
		var tw := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		var dw := f.get_string_size(dist, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz - 2).x
		var ic := fsz * 1.1
		var w := pad.x * 2 + ic + UI.sp(0.8, self) + tw + UI.sp(1, self) + dw
		var h := fsz + pad.y * 2
		var rect := Rect2(sp - Vector2(w / 2.0, h), Vector2(w, h))
		var clash := false
		for r in _rects:
			if (r["rect"] as Rect2).grow(4).intersects(rect):
				clash = true
				break
		if clash or not get_viewport_rect().grow(-4).encloses(rect):
			continue
		var neon: Color = pl["neon"]
		var fade := clampf(1.0 - (d - 30.0) / (MAX_D - 30.0), 0.35, 1.0)
		var bob := sin(_t * 2.0 + d) * 2.0
		rect.position.y += bob
		var sb := UI.box(Color(UI.PANEL, 0.86 * fade), Color(neon, 0.75 * fade), 1, int(h / 2.0))
		sb.shadow_color = Color(neon, 0.25 * fade)
		sb.shadow_size = 10
		draw_style_box(sb, rect)
		var ip := rect.position + Vector2(pad.x + ic / 2.0, h / 2.0)
		draw_circle(ip, ic * 0.42, Color(neon, fade))
		draw_circle(ip, ic * 0.16, Color("#05070d"))
		var tx := ip.x + ic / 2.0 + UI.sp(0.8, self)
		draw_string(f, Vector2(tx, rect.position.y + pad.y + fsz * 0.82), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color(UI.PAPER, fade))
		draw_string(f, Vector2(tx + tw + UI.sp(1, self), rect.position.y + pad.y + fsz * 0.8), dist, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz - 2, Color(UI.MIST, fade * 0.9))
		# haste até o lugar
		draw_line(Vector2(sp.x, rect.end.y), sp + Vector2(0, UI.sp(1.2, self) + bob), Color(neon, 0.5 * fade), 1.5)
		_rects.append({"rect": rect, "place": pl})


## lugar sob o ponto (tela lógica), ou vazio
func hit(pos: Vector2) -> Dictionary:
	for r in _rects:
		if (r["rect"] as Rect2).grow(6).has_point(pos):
			return r["place"]
	return {}
