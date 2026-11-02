extends Node
## Mede o tempo de cada etapa da montagem da cidade (o que segura a tela de entrada).
func _ready() -> void:
	var City := load("res://scripts/city.gd")
	var c = City.new()
	var t0 := Time.get_ticks_usec()
	for step in ["_build_env", "_build_skyline", "_build_ground", "_build_blocks", "_place_shops", "_build_plaza", "_build_landmark", "_street_props", "_dress_alley", "_commit_batches", "_commit_multi", "_build_life", "_rain", "_spawn_player"]:
		var a := Time.get_ticks_usec()
		c.call(step)
		print("ETAPA %-16s %6d ms" % [step, (Time.get_ticks_usec() - a) / 1000])
	print("TOTAL ", (Time.get_ticks_usec() - t0) / 1000, " ms")
	get_tree().quit()
