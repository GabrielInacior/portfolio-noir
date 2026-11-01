extends Node
## Captura os painéis de interação (inspeção, terminal, galeria, documento, skills, linha do tempo,
## contato, fliperama) no tamanho da janela atual.
## RUMOR_SHOT=<pasta> TAG=<sufixo> godot --audio-driver Dummy --path . --resolution WxH res://tools_dev/panel_shot.tscn
const Panels := preload("res://scripts/panels.gd")
const Exhibit := preload("res://scripts/exhibit.gd")
var dir := ""
var tag := ""

func _ready() -> void:
	dir = OS.get_environment("RUMOR_SHOT")
	tag = OS.get_environment("TAG")
	var proj: Dictionary = Data.projects[0]
	var cases := [
		["inspect", {"title": "Casos à mão", "model": "maquina_escrever", "text": "Cada caso foi escrito à mão e verificado por scripts.", "tag": "Design de jogo"}],
		["terminal", {"title": "GitHub ao vivo", "repo": "rumor"}],
		["gallery", {"title": "Mais da história", "gallery": [{"img": "res://assets/museum/rumor/telas.jpg", "title": "Quatro telas", "text": "Explorar, interrogar, ligar fios e compartilhar."}, {"img": "res://assets/museum/rumor/cenas.jpg", "title": "Cenário", "text": "Doze cômodos pintados."}]}],
		["doc", {"title": "Máquina de escrever", "doc_style": "typewriter", "text": "GABRIEL INÁCIO\nengenharia de software · games · IA"}],
		["doc", {"title": "Telefone tocando", "doc_style": "phone", "text": "Alô, detetive? A turma inteira jogou o RUMOR hoje."}],
		["skills", {"title": "Tecnologias que eu domino"}],
		["timeline", {"title": "Linha do tempo"}],
		["contact", {"title": "Contato"}],
		["arcade", {"title": "COBRA NEON", "game": "snake"}],
		["arcade", {"title": "DEFENDA A FORTALEZA", "game": "fortress"}],
	]
	var bg := ColorRect.new()
	bg.color = Color("#1a1420")
	add_child(UI.full(bg))
	var layer := CanvasLayer.new()
	add_child(layer)
	var i := 0
	for c in cases:
		var p := Panels.new()
		p.setup(c[0], c[1], Color("#ffc83d"), proj)
		layer.add_child(UI.full(p))
		await get_tree().create_timer(1.6 if c[0] != "arcade" else 2.5).timeout
		if c[0] == "skills":
			p._show_projects("Godot", Color("#5fd38a"))
			await get_tree().create_timer(0.5).timeout
		get_viewport().get_texture().get_image().save_png(dir.path_join("panel_%02d_%s%s.png" % [i, c[0], tag]))
		print("SHOT ", c[0])
		p.queue_free()
		i += 1
	get_tree().quit()
