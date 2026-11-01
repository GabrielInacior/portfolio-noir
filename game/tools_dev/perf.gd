extends Node
## Mede draw calls, objetos, memória de vídeo e FPS na rua e numa loja-museu.
var frames := 0
var fps_acc := 0.0
var phase := 0
var main
func _ready() -> void:
	main = load("res://scenes/city.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.0).timeout
	_report("RUA")
	# entra numa loja-museu
	if main._gate: main.hud.visible = true; main._gate.queue_free()
	await get_tree().process_frame
	main.hud.enter_museum(Data.projects[0])
	await get_tree().create_timer(2.0).timeout
	_report("MUSEU rumor")
	get_tree().quit()
func _report(tag: String) -> void:
	var dc := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var obj := Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var prim := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var vram := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	print("PERF %s | draw_calls=%d objetos=%d prims=%d vram=%.1fMB fps=%d" % [tag, dc, obj, prim, vram, fps])
