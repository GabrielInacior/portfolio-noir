extends Node
## Áudio do portfólio: trilha própria (OST do Gabriel), ambientes em loop por zona, emissores 3D
## (neon, vapor, carros), passos por piso e efeitos de interação. Nada toca antes do ENTRAR
## (o navegador só libera áudio depois de um gesto) e o botão de som da interface cala tudo.
##
## API para o resto do jogo (ver docs/AUDIO.md):
##   Audio.play("porta_loja")                 efeito 2D (interface, objeto perto do jogador)
##   Audio.play_at("buzina", posição)          efeito 3D numa posição do mundo
##   Audio.loop_at(nó, "loop_neon")            loop 3D preso a um nó (some com ele)
##   Audio.on_action("phone", item)            objetos interativos das lojas (hud chama)
##   Audio.set_music_volume(0..1) / set_sfx_volume(0..1)
## O resto (zona rua/loja, passos, emissores da cidade, telefone tocando, mira) é automático:
## este nó observa o jogador e a cena, sem precisar de chamadas espalhadas pelo código.

const SFX := "res://assets/audio/sfx/%s_%d.ogg"
const AMB := "res://assets/audio/amb/%s.ogg"
const MAX_VOICES := 14

# ambiente de cada estilo de loja (museum_dress.style_of) e o que toca por baixo
const ROOM_BED := {
	"detetive": "amb_escritorio", "cyber": "amb_servidores", "arcade": "amb_fliperama", "bar": "amb_bar",
	"studio": "amb_estudio", "study": "amb_escritorio", "startup": "amb_lab", "lab": "amb_lab",
	"career": "amb_escritorio",
}
# piso de cada estilo (passos)
const ROOM_FLOOR := {
	"detetive": "passo_madeira", "cyber": "passo_piso", "arcade": "passo_piso", "bar": "passo_madeira",
	"studio": "passo_carpete", "study": "passo_madeira", "startup": "passo_madeira", "lab": "passo_piso",
	"career": "passo_carpete",
}

var _player: AudioStreamPlayer
var _on := true
var _duck := false
var _started := false
var _music_lin := 1.0
var _sfx_lin := 1.0

var _beds := {}            # nome do ambiente -> AudioStreamPlayer (2D, loop)
var _bed_want := {}        # nome -> volume alvo em dB (ausente = desligar)
var _cache := {}           # caminho -> AudioStream (ou null se não existe)
var _voices: Array = []    # players 2D de efeito em uso
var _zone := ""            # "rua" ou estilo da loja
var _pc: Node3D = null     # o jogador (CharacterBody3D)
var _pc_parent: Node = null
var _city: Node = null
var _city_done := false
var _step_acc := 0.0
var _scan_t := 0.0
var _car_cool := {}
var _hot_node: Node = null
var _ring_players := {}    # entrada de telefone -> AudioStreamPlayer3D
var _bus_ok := false
var _toggle_y := {}


func _ready() -> void:
	_setup_buses()
	_player = AudioStreamPlayer.new()
	_player.volume_db = -60.0
	_player.bus = "Music"
	add_child(_player)
	_load_prefs()
	_load_music()


## No site a trilha toca pelo NAVEGADOR (<audio> + ganho do Web Audio), fora do mixer do Godot: no celular o
## mixer sem threads ficava sem CPU e a música saía lenta e distorcida. O jogo só controla tocar, volume,
## mudo e fade (window.pfMus, abaixo). Nativo/sem URL: segue o AudioStreamPlayer do pacote "music".
var _web := false
var _web_vol := -1.0
const WEB_JS := """(function(){
if (window.pfMus) return 1;
var url = window.pfMusicUrl; if (!url) return 0;
var a = new Audio(); a.src = url; a.loop = true; a.preload = 'auto'; a.crossOrigin = 'anonymous';
var M = { a: a, ctx: null, g: null, vol: 0, started: false };
M.start = function () {
  try {
    if (!M.ctx) {
      var AC = window.AudioContext || window.webkitAudioContext;
      if (AC) { M.ctx = new AC(); var src = M.ctx.createMediaElementSource(a); M.g = M.ctx.createGain(); M.g.gain.value = M.vol; src.connect(M.g); M.g.connect(M.ctx.destination); }
    }
    if (M.ctx && M.ctx.state === 'suspended') M.ctx.resume();
  } catch (e) { M.ctx = null; M.g = null; }
  M.started = true;
  var p = a.play(); if (p && p.catch) p.catch(function () {});
};
M.setVol = function (v) {
  M.vol = v;
  if (M.g) { M.g.gain.setTargetAtTime(v, M.ctx.currentTime, 0.08); } else { a.volume = Math.max(0, Math.min(1, v)); }
  if (v <= 0.0005 && !a.paused && M.started && !M.g) a.pause();
};
M.setOn = function (on) { if (on) { if (M.started && a.paused) a.play().catch(function () {}); } else { a.pause(); } };
M.state = function () { return JSON.stringify({ t: a.currentTime, paused: a.paused, rate: M.ctx ? M.ctx.sampleRate : 0, ctx: M.ctx ? M.ctx.state : 'none', vol: M.vol }); };
// aba escondida: pausa; volta: continua (o Godot também pausa o áudio dele)
document.addEventListener('visibilitychange', function () { if (!M.started) return; if (document.hidden) a.pause(); else if (M.vol > 0.0005) a.play().catch(function () {}); });
window.pfMus = M; return 1;
})()"""


func _web_ok() -> bool:
	if not OS.has_feature("web"):
		return false
	var r: Variant = JavaScriptBridge.eval(WEB_JS, true)
	return r != null and int(r) == 1


## a trilha vem num pacote baixado em segundo plano (Packs); começa a tocar assim que chega
func _load_music() -> void:
	if _web_ok():
		_web = true
		return
	await Packs.need("music")
	var s := load("res://assets/audio/music/bloodlines_ost.mp3")
	if s is AudioStream:
		if s is AudioStreamMP3:
			(s as AudioStreamMP3).loop = true
		_player.stream = s
		if _started and not _player.playing:
			_player.volume_db = -10.0 + linear_to_db(maxf(_music_lin, 0.001)) if _on else -60.0
			_player.play()


# ─────────────────────────────────────────────────────────── barramentos ──
## Music | Amb (ambientes 2D, com passa-baixa quando a rua fica do lado de fora) | SFX (efeitos e 3D,
## com reverb cuja sala muda por zona). Criados por código para não depender de um .tres.
func _setup_buses() -> void:
	if AudioServer.get_bus_index("Music") >= 0:
		_bus_ok = true
		return
	for n in ["Music", "Amb", "SFX"]:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, n)
		AudioServer.set_bus_send(i, "Master")
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Amb"), lp)
	var rv := AudioEffectReverb.new()
	rv.room_size = 0.25
	rv.damping = 0.6
	rv.wet = 0.06
	rv.dry = 1.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"), rv)
	_bus_ok = true


func _bus_fx(bus: String, idx: int) -> AudioEffect:
	var b := AudioServer.get_bus_index(bus)
	return AudioServer.get_bus_effect(b, idx) if b >= 0 and AudioServer.get_bus_effect_count(b) > idx else null


# ───────────────────────────────────────────────────────────────── API ──
func start() -> void:
	_started = true
	if _web:
		_web_vol = _web_target()
		JavaScriptBridge.eval("window.pfMus&&(window.pfMus.setVol(%f),window.pfMus.start())" % _web_vol, true)
		_set_zone("rua")
		_report.call_deferred()
		return
	# a música já entra audível (antes começava em -60 dB e subia por quadro; no navegador isso podia
	# ficar mudo) e o modo de reprodução do web é "stream" (project.godot), para os barramentos e
	# efeitos funcionarem como no desktop
	_player.volume_db = -10.0 + linear_to_db(maxf(_music_lin, 0.001)) if _on else -60.0
	if not _player.playing:
		_player.play()
	_set_zone("rua")
	_report.call_deferred()


## log do estado do áudio (aparece no console do navegador): confere se está tocando sem precisar ouvir
func _report() -> void:
	if _web:
		await get_tree().create_timer(2.5).timeout
		var t0 := Time.get_ticks_msec()
		var a := str(JavaScriptBridge.eval("window.pfMus?window.pfMus.state():''", true))
		await get_tree().create_timer(2.0).timeout
		var b := str(JavaScriptBridge.eval("window.pfMus?window.pfMus.state():''", true))
		print("AUDIO web (navegador): %s -> %s em %d ms de relógio" % [a, b, Time.get_ticks_msec() - t0])
		return
	await get_tree().create_timer(2.5).timeout
	var a := _player.get_playback_position()
	await get_tree().create_timer(1.0).timeout
	print("AUDIO estado: tocando=%s posicao=%.2f->%.2f vol=%.1f dB mudo_master=%s mix=%d Hz latencia=%.3f s buses=%d on=%s" % [
		_player.playing, a, _player.get_playback_position(), _player.volume_db, AudioServer.is_bus_mute(0),
		int(AudioServer.get_mix_rate()), AudioServer.get_output_latency(), AudioServer.bus_count, _on])


func set_enabled(on: bool) -> void:
	_on = on
	AudioServer.set_bus_mute(0, not on)
	if _web:
		JavaScriptBridge.eval("window.pfMus&&window.pfMus.setOn(%s)" % ("true" if on else "false"), true)
	elif on and not _player.playing and _started:
		_player.play()
	_save_prefs()


func is_on() -> bool:
	return _on


## Painel/diálogo aberto: a música e os ambientes descem, e o som de abrir/fechar painel toca aqui
## (todos os painéis já chamam duck), sem precisar de chamada extra em cada tela.
func duck(active: bool) -> void:
	if active != _duck and _started:
		play("ui_abrir" if active else "ui_fechar")
	_duck = active


func _hot_entry() -> Dictionary:
	var m := _pc_parent
	if m == null or not is_instance_valid(m) or _hot_node == null:
		return {}
	var items = m.get("items")
	if items is Array:
		for e in items:
			if e is Dictionary and e.get("node") == _hot_node:
				return e
	return {}


## volume alvo da trilha no navegador (mesma curva do player do Godot: -6 dB, -16 dB com painel aberto)
func _web_target() -> float:
	if not _on:
		return 0.0
	return db_to_linear((-16.0 if _duck else -6.0) + linear_to_db(maxf(_music_lin, 0.001)))


func set_music_volume(v: float) -> void:
	_music_lin = clampf(v, 0.0, 1.0)
	_save_prefs()


func set_sfx_volume(v: float) -> void:
	_sfx_lin = clampf(v, 0.0, 1.0)
	_save_prefs()


func music_volume() -> float:
	return _music_lin


func sfx_volume() -> float:
	return _sfx_lin


func play(id: String, vol_db := 0.0, pitch_var := 0.03) -> void:
	if not _started:
		return
	var st := _pick(id)
	if st == null:
		return
	_voices = _voices.filter(func(p) -> bool: return is_instance_valid(p) and (p as AudioStreamPlayer).playing)
	if _voices.size() >= MAX_VOICES:
		return
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.bus = "SFX"
	_sample_mode(p)
	p.volume_db = vol_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	_voices.append(p)


func play_at(id: String, pos: Vector3, vol_db := 0.0, unit := 6.0, parent: Node = null) -> AudioStreamPlayer3D:
	if not _started:
		return null
	var st := _pick(id)
	if st == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.bus = "SFX"
	_sample_mode(p)
	p.volume_db = vol_db
	p.unit_size = unit
	p.max_distance = unit * 8.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.pitch_scale = 1.0 + randf_range(-0.03, 0.03)
	var host: Node = parent if parent else get_tree().current_scene
	if host == null:
		return null
	host.add_child(p)
	if parent:
		p.position = Vector3.ZERO
	else:
		p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
	return p


func loop_at(node: Node3D, id: String, vol_db := -6.0, unit := 3.0, offset := Vector3.ZERO) -> AudioStreamPlayer3D:
	var st := _loop_stream(id)
	if st == null or node == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.bus = "SFX"
	_sample_mode(p)
	p.volume_db = vol_db
	p.unit_size = unit
	p.max_distance = unit * 7.0
	p.position = offset
	node.add_child(p)
	if _started:
		p.play(randf() * 4.0)
	else:
		p.add_to_group("_audio_wait")
	return p


## Efeitos e ambientes no navegador: modo "sample" (o Web Audio do navegador toca e posiciona cada som).
## No modo "stream" o mixer do Godot sem threads roda na thread do jogo e, com a CPU do celular (4x mais
## lenta), entregava ~96% das amostras: buracos e estalos. Sem os efeitos de barramento (reverb leve) no
## navegador. `?sfx=stream` volta ao mixer do Godot.
static var _sample_on := -1


func _sample_mode(p: Node) -> void:
	if _sample_on < 0:
		_sample_on = 0
		if OS.has_feature("web"):
			_sample_on = 0 if str(JavaScriptBridge.eval("/[?&]sfx=stream/.test(location.search)?1:0", true)) == "1" else 1
	if _sample_on == 1:
		p.set("playback_type", AudioServer.PLAYBACK_TYPE_SAMPLE)


## Objetos interativos das lojas (hud._activate chama com a "action" do item).
func on_action(action: String, _item: Dictionary = {}) -> void:
	match action:
		"switch":
			play("interruptor")
		"phone":
			play("telefone_atende")
		"drawer":
			play("gaveta")
		"typewriter":
			_typewriter_burst()
		"monitor", "github", "terminal":
			play("monitor_liga", -4.0)
		"arcade":
			play("fliper_moeda")
		"doc", "timeline":
			play("papel", -4.0)


## Minijogos do fliperama: bip a cada ponto.
func arcade_bleep() -> void:
	play("fliper_bleep", -6.0, 0.08)


func examined() -> void:
	play("ui_contador")


# ─────────────────────────────────────────────────────────── utilitários ──
func _stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var st: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_cache[path] = st
	return st


func _variants(id: String) -> int:
	var key := "#n:" + id
	if _cache.has(key):
		return _cache[key]
	var n := 0
	while n < 8 and ResourceLoader.exists(SFX % [id, n]):
		n += 1
	_cache[key] = n
	return n


func _pick(id: String) -> AudioStream:
	var n := _variants(id)
	if n == 0:
		return null
	return _stream(SFX % [id, randi() % n])


func _loop_stream(id: String) -> AudioStream:
	var st := _stream(AMB % id)
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	return st


func _typewriter_burst() -> void:
	for i in 9:
		get_tree().create_timer(0.08 + i * randf_range(0.09, 0.16)).timeout.connect(func() -> void: play("maquina_tecla", 0.0, 0.06))
	get_tree().create_timer(1.55).timeout.connect(func() -> void: play("maquina_sineta"))


# ─────────────────────────────────────────────────────────── zonas e camas ─
func _bed(name: String) -> AudioStreamPlayer:
	if _beds.has(name):
		return _beds[name]
	var st := _loop_stream(name)
	if st == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.bus = "Amb"
	_sample_mode(p)
	p.volume_db = -60.0
	add_child(p)
	_beds[name] = p
	return p


func _set_zone(z: String) -> void:
	if z == _zone:
		return
	var from := _zone
	_zone = z
	_bed_want.clear()
	var lp := _bus_fx("Amb", 0) as AudioEffectLowPassFilter
	var rv := _bus_fx("SFX", 0) as AudioEffectReverb
	if z == "rua":
		_bed_want["amb_chuva_rua"] = -3.0
		_bed_want["amb_cidade_noite"] = -8.0
		if lp:
			lp.cutoff_hz = 20000.0
		if rv:
			rv.room_size = 0.55
			rv.wet = 0.05
	else:
		# dentro da loja: a chuva vira "chuva na janela" e a rua some atrás da porta
		_bed_want["amb_chuva_interior"] = -10.0
		_bed_want[str(ROOM_BED.get(z, "amb_escritorio"))] = -4.0
		if lp:
			lp.cutoff_hz = 20000.0
		if rv:
			rv.room_size = 0.22
			rv.wet = 0.11
	if from != "" and _started:
		play("porta_loja" if z != "rua" else "porta_fecha")


func _room_style(museum: Node) -> String:
	var Dress = load("res://scripts/museum_dress.gd")
	var pid := str(museum.call("pid")) if museum.has_method("pid") else ""
	var dd: Dictionary = museum.get("data") if museum.get("data") is Dictionary else {}
	var room := str((dd.get("theme", {}) as Dictionary).get("room", "escritorio")) if dd.get("theme") is Dictionary else "escritorio"
	if Dress:
		return str(Dress.style_of(pid, room))
	return "startup"


# ──────────────────────────────────────────────────────────── observador ──
func _process(dt: float) -> void:
	if _player == null:
		return
	var want := -60.0
	if _web:
		# o fade roda no navegador (setTargetAtTime); aqui só manda o alvo quando muda
		if _started:
			var tv := _web_target()
			if absf(tv - _web_vol) > 0.004:
				_web_vol = tv
				JavaScriptBridge.eval("window.pfMus&&window.pfMus.setVol(%f)" % tv, true)
	else:
		if _on and _player.playing:
			want = (-16.0 if _duck else -6.0) + linear_to_db(maxf(_music_lin, 0.001))
		_player.volume_db = lerpf(_player.volume_db, want, clampf(dt * 3.0, 0, 1))
	var sfx_bus := AudioServer.get_bus_index("SFX")
	var amb_bus := AudioServer.get_bus_index("Amb")
	if sfx_bus >= 0:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(maxf(_sfx_lin, 0.001)))
	if amb_bus >= 0:
		AudioServer.set_bus_volume_db(amb_bus, linear_to_db(maxf(_sfx_lin, 0.001)) + (-7.0 if _duck else 0.0))
	if not _started:
		return
	# camas: sobem/descem suave até o alvo da zona (troca de zona sem corte)
	for name in _bed_want:
		var b := _bed(name)
		if b and not b.playing:
			b.play(randf() * 8.0)
	for name in _beds:
		var p: AudioStreamPlayer = _beds[name]
		var tgt: float = _bed_want.get(name, -60.0)
		p.volume_db = lerpf(p.volume_db, tgt, clampf(dt * 1.6, 0, 1))
		if not _bed_want.has(name) and p.volume_db < -55.0 and p.playing:
			p.stop()
	_scan_t -= dt
	if _scan_t <= 0.0:
		_scan_t = 0.5
		_scan()
	_footsteps(dt)
	_cars_near()
	_watch_hot()


func _scan() -> void:
	if _pc == null or not is_instance_valid(_pc):
		_pc = null
		for n in get_tree().root.find_children("*", "CharacterBody3D", true, false):
			if n.has_method("try_interact"):
				_pc = n
				break
	if _pc == null:
		return
	var par := _pc.get_parent()
	if par != _pc_parent:
		_pc_parent = par
		if par and par.has_method("at_exit"):
			_set_zone(_room_style(par))
			_hook_museum(par)
		else:
			_set_zone("rua")
	if not _city_done:
		for n in get_tree().root.find_children("*", "Node3D", true, false):
			if n.get("kiosks") is Array and n.get("_cars") is Array:
				_city = n
				break
		if _city:
			_city_done = true
			_hook_city(_city)
	# esperando o ENTRAR: loops criados antes começam agora
	for n in get_tree().get_nodes_in_group("_audio_wait"):
		if n is AudioStreamPlayer3D and not (n as AudioStreamPlayer3D).playing:
			(n as AudioStreamPlayer3D).play(randf() * 4.0)
		n.remove_from_group("_audio_wait")


func _hook_city(c: Node) -> void:
	# zumbido de neon em cada fachada de loja e vapor em cada bueiro
	for k in c.get("kiosks"):
		var host := Node3D.new()
		c.add_child(host)
		host.global_position = (k["pos"] as Vector3) + Vector3(0, 3.2, 0)
		loop_at(host, "loop_neon", -12.0, 2.2)
	for n in c.find_children("*", "CPUParticles3D", true, false):
		var cp := n as CPUParticles3D
		if cp.direction.y > 0.9 and absf(cp.direction.x - 0.15) < 0.02 and cp.lifetime > 3.0:
			loop_at(cp, "loop_vapor", -8.0, 2.0)


func _hook_museum(m: Node) -> void:
	if m.has_signal("examined") and not m.is_connected("examined", _on_examined):
		m.connect("examined", _on_examined)
	_ring_players.clear()


func _on_examined(_c: int, _t: int) -> void:
	examined()


func _footsteps(dt: float) -> void:
	if _pc == null or not is_instance_valid(_pc) or not (_pc is CharacterBody3D):
		return
	var v := (_pc as CharacterBody3D).velocity
	v.y = 0.0
	if v.length() < 0.6:
		_step_acc = 0.0
		return
	_step_acc += v.length() * dt
	if _step_acc >= 1.55:
		_step_acc = 0.0
		var id := "passo_asfalto"
		if _zone != "rua":
			id = str(ROOM_FLOOR.get(_zone, "passo_madeira"))
		elif randf() < 0.12:
			id = "passo_poca"
		play(id, -6.0, 0.05)


func _cars_near() -> void:
	if _city == null or not is_instance_valid(_city) or _pc == null or _zone != "rua":
		return
	var now := Time.get_ticks_msec()
	for c in _city.get("_cars"):
		var node: Node3D = c.get("node")
		if node == null or not is_instance_valid(node):
			continue
		var d := node.global_position.distance_to(_pc.global_position)
		var id := node.get_instance_id()
		if d < 16.0 and now - int(_car_cool.get(id, 0)) > 9000:
			_car_cool[id] = now
			play_at("carro_passa", node.global_position, -2.0, 7.0, node)
			if randf() < 0.15:
				play_at("buzina", node.global_position, -8.0, 9.0, node)


func _watch_hot() -> void:
	# tique sutil quando a mira passa a apontar um objeto examinável (museu: set_hot guarda o nó)
	var m := _pc_parent
	if m == null or not is_instance_valid(m) or not m.has_method("at_exit"):
		return
	var h = m.get("_hot_node")
	if h != _hot_node:
		_hot_node = h
		if h != null:
			play("ui_mira", -8.0)
	# telefone tocando (entrada com "ring" ligado): som de campainha preso ao aparelho
	# (o som de cada objeto acionado vem do hud._activate → on_action)
	var items = m.get("items")
	if items is Array:
		for e in items:
			if e is Dictionary and e.has("ring"):
				var on: bool = bool((e["ring"] as Dictionary).get("on", false))
				var p = _ring_players.get(e.get("node"))
				if on and (p == null or not is_instance_valid(p)) and e.get("node") is Node3D:
					p = loop_at(e["node"], "telefone_toca_loop", -4.0, 2.5)
					if p == null:
						var one := play_at("telefone_toca", Vector3.ZERO, -2.0, 3.0, e["node"])
						if one:
							_ring_players[e.get("node")] = one
							one.finished.connect(func() -> void: _ring_players.erase(e.get("node")))
				elif not on and p != null and is_instance_valid(p):
					(p as Node).queue_free()
					_ring_players.erase(e.get("node"))


# ─────────────────────────────────────────────────────────────── preferências ─
func _save_prefs() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "on", _on)
	cf.set_value("audio", "music", _music_lin)
	cf.set_value("audio", "sfx", _sfx_lin)
	cf.save("user://audio.cfg")


func _load_prefs() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://audio.cfg") != OK:
		return
	_on = bool(cf.get_value("audio", "on", true))
	_music_lin = float(cf.get_value("audio", "music", 1.0))
	_sfx_lin = float(cf.get_value("audio", "sfx", 1.0))
	AudioServer.set_bus_mute(0, not _on)
