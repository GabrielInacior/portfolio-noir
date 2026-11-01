extends Node
## Trilha do portfólio (OST própria do Gabriel) em loop, com fade e ducking nos diálogos.
## Começa só depois do gesto ENTRAR (web exige interação para tocar áudio).

var _player: AudioStreamPlayer
var _on := true
var _duck := false
var _target := 0.0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	var s := load("res://assets/audio/music/bloodlines_ost.mp3")
	if s is AudioStream:
		if s is AudioStreamMP3:
			(s as AudioStreamMP3).loop = true
		_player.stream = s
	_player.volume_db = -60.0
	_player.bus = "Master"
	add_child(_player)


func start() -> void:
	if not _player.playing:
		_player.play()
	_target = 0.0


func set_enabled(on: bool) -> void:
	_on = on
	if on and not _player.playing:
		_player.play()


func duck(active: bool) -> void:
	_duck = active


func is_on() -> bool:
	return _on


func _process(dt: float) -> void:
	if _player == null:
		return
	var want := -60.0
	if _on and _player.playing:
		want = -16.0 if _duck else -6.0
	_player.volume_db = lerpf(_player.volume_db, want, clampf(dt * 3.0, 0, 1))
