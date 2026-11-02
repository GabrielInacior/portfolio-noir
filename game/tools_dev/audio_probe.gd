extends Node
## Sonda muda do áudio: confere que todos os sons do catálogo carregam e que zona/efeitos não quebram.
func _ready() -> void:
	var ok := 0
	var bad := []
	for f in DirAccess.get_files_at("res://assets/audio/sfx"):
		if f.ends_with(".ogg") or f.ends_with(".ogg.import"):
			var p := "res://assets/audio/sfx/" + f.replace(".import", "")
			if load(p) is AudioStream: ok += 1
			else: bad.append(p)
	for f in DirAccess.get_files_at("res://assets/audio/amb"):
		if f.ends_with(".ogg.import"):
			var p := "res://assets/audio/amb/" + f.replace(".import", "")
			if load(p) is AudioStream: ok += 1
			else: bad.append(p)
	Audio.start()
	Audio.play("porta_loja"); Audio.play("passo_asfalto"); Audio.on_action("typewriter"); Audio.duck(true); Audio.duck(false)
	await get_tree().create_timer(2.0).timeout
	print("AUDIO_PROBE ok=", ok, " ruins=", bad, " camas=", Audio._beds.keys())
	get_tree().quit()
