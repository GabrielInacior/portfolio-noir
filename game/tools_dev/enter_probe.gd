extends Node
## Simula o ENTRAR e mede o tempo dos quadros seguintes (procura travamento depois da entrada).
var main
func _ready() -> void:
	main = load("res://scenes/city.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.0).timeout
	var t := Time.get_ticks_msec()
	main._enter()
	print("ENTER chamado em ", Time.get_ticks_msec() - t, " ms")
	var worst := 0
	for i in 240:
		var a := Time.get_ticks_msec()
		await get_tree().process_frame
		var d := Time.get_ticks_msec() - a
		worst = maxi(worst, d)
		if d > 200:
			print("QUADRO LENTO ", i, " = ", d, " ms")
	print("PIOR QUADRO ", worst, " ms; fps=", Engine.get_frames_per_second())
	get_tree().quit()
