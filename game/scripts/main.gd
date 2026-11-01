extends Node
## Monta a cidade e a interface, com entrada cinematográfica (preto -> ENTRAR -> fade na cidade).
## O ENTRAR destrava o áudio (exigência da web) e o pointer lock no desktop.

const City := preload("res://scripts/city.gd")
const Hud := preload("res://scripts/hud.gd")

var city
var hud
var _gate: Control


func _ready() -> void:
	city = City.new()
	add_child(city)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.visible = false
	layer.add_child(hud)
	await get_tree().process_frame
	hud.setup(city.player, city)
	_build_gate(layer)


func _build_gate(layer: CanvasLayer) -> void:
	_gate = Control.new()
	_gate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gate.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("#05060c")
	_gate.add_child(UI.full(bg))
	var center := CenterContainer.new()
	_gate.add_child(UI.full(center))
	var v := UI.vbox(18)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)
	var logo := UI.title("GABRIEL INÁCIO", 86, UI.PAPER)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(logo)
	var sub := UI.label("PORTFÓLIO · UMA CIDADE NOIR DE PROJETOS", 24, UI.AMBER, "type")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 30
	v.add_child(spacer)
	var enter := UI.button("ENTRAR NA CIDADE", UI.AMBER, 86)
	enter.custom_minimum_size.x = 420
	enter.pressed.connect(_enter)
	v.add_child(enter)
	var hint := UI.label("ative o som para a experiência completa", 18, UI.MIST, "body")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	layer.add_child(_gate)
	# respiração do título
	var tw := create_tween().set_loops()
	tw.tween_property(logo, "modulate:a", 0.6, 1.4)
	tw.tween_property(logo, "modulate:a", 1.0, 1.4)


func _enter() -> void:
	Audio.start()
	hud.visible = true
	if not UI.is_mobile():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var tw := create_tween()
	tw.tween_property(_gate, "modulate:a", 0.0, 0.9)
	tw.tween_callback(_gate.queue_free)
