extends Node3D
## NPC guia noir: personagem riggado (malha orgânica + animações Mixamo) reaproveitado do RUMOR,
## em versão ADULTA e séria (sobretudo escuro, barba, cabelo grisalho, acento de neon do projeto).
## Fica em idle; ao se aproximar mostra um marcador; interagir abre a conversa.

const Character := preload("res://scripts/scene3d/character.gd")

var look_yaw := 0.0
var project: Dictionary = {}
var role := ""
var greet := ""
var lines: Array = []
var ch                       # Character
var _t := 0.0


func setup(p: Dictionary) -> void:
	project = p
	_dialog_for(p)


func _ready() -> void:
	rotation.y = look_yaw
	ch = Character.new()
	ch.setup(_card_for(project))
	add_child(ch)
	# marcador "fale comigo"
	var b := Label3D.new()
	b.text = "?"
	b.font = UI.font("title")
	b.font_size = 90
	b.pixel_size = 0.006
	b.modulate = Color(str(project.get("neon", "#ffc83d")))
	b.position = Vector3(0, 2.35, 0)
	b.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	b.shaded = false
	add_child(b)


## Monta a "ficha" (look) que o Character entende: adulto, roupa escura, barba, acento do projeto.
func _card_for(p: Dictionary) -> Dictionary:
	var neon := str(p.get("neon", "#8899aa"))
	# cada guia tem um visual próprio, mas sempre adulto e noir
	var seed := hash(str(p.get("id", "x")))
	var skins := ["#c99a74", "#a9784f", "#8a5a3a", "#d6ad86"]
	var coats := ["#1a1f33", "#20222e", "#161a24", "#241c2c"]
	var hairs := ["curto", "raspado", "coque"]
	var beards := ["barba", "cavanhaque", "bigode"]
	return {
		"id": p.get("id", "guia"),
		"adult": true,
		"gender": "m",
		"look": {
			"skin": skins[seed % skins.size()],
			"top": coats[seed % coats.size()],
			"pants": "#14161f",
			"hair": hairs[seed % hairs.size()],
			"hair_color": "#3a3340",
			"facial_hair": beards[seed % beards.size()],
			"accent": neon,
			"accessory": "nenhum",
			"outfit": "formal",
		},
		"talk": {"mood": "neutro"},
	}


func set_expression(e: String) -> void:
	if ch:
		ch.set_expression(e)


func _process(dt: float) -> void:
	_t += dt
	# leve rotação do tronco para "olhar" em volta já vem do idle; aqui só um respiro no marcador


func _dialog_for(p: Dictionary) -> void:
	var id := str(p.get("id", ""))
	if p.get("special", "") == "about":
		role = "o guia da cidade"
		greet = "Então você quer saber quem construiu essa cidade."
		lines = [
			{"q": "Quem é o Gabriel?", "expr": "neutro", "a": "Dev full-stack, cinco anos nisso. Do front pixel-perfect ao back que aguenta carga. Cada prédio aqui é coisa que ele ergueu."},
			{"q": "Com o que ele trabalha?", "expr": "nervoso", "a": "Vue, React, Nuxt, Next e Flutter na frente. Node, Fastify, NestJS, Spring e Prisma atrás. Postgres, Redis, Docker e AWS na base. E Godot, quando a ideia pede jogo."},
			{"q": "Por que uma cidade?", "expr": "feliz", "a": "Porque portfólio em lista todo mundo tem. Aqui você caminha pelo trabalho dele. Dá um passo e vê."},
		]
		return
	role = "conhece esse projeto"
	match id:
		"rumor":
			role = "detetive da esquina"
			greet = "RUMOR. Melhor caso que já passou por essa rua."
			lines = [
				{"q": "O que é o RUMOR?", "expr": "neutro", "a": "Jogo de detetive multiplayer pra sala de aula. Cada aluno no próprio celular, investigando o mesmo mistério em 3D."},
				{"q": "Qual foi o desafio?", "expr": "desconfiado", "a": "Servidor autoritativo em Node pra turma inteira ao mesmo tempo, quadro compartilhado com fios e provas, e cenas 3D que rodam lisas no navegador do celular."},
				{"q": "Dá pra jogar?", "expr": "feliz", "a": "Dá. Abre o dossiê e toca em VER SITE. Roda direto no navegador."},
			]
		"fortress":
			role = "o mestre de obras"
			greet = "Fortress Chaos. Ergue a fortaleza e aguenta o caos."
			lines = [
				{"q": "Que jogo é esse?", "expr": "neutro", "a": "Roguelite 3D low-poly de construção de fortaleza e tower defense, com interface em pixel art feita à mão."},
				{"q": "Como foi feito?", "expr": "nervoso", "a": "Godot puro, modelos em Blender por script, cartas e sinergias, civilizações e biomas. Windows e Android."},
				{"q": "Qual foi o difícil?", "expr": "desconfiado", "a": "Equilíbrio. Roguelite que nunca é fácil demais nem injusto. Isso se ajusta no detalhe, partida após partida."},
			]
		"labia":
			role = "o vigarista"
			greet = "Lábia. Aqui a conversa é a arma."
			lines = [
				{"q": "Como assim?", "expr": "desconfiado", "a": "Jogo cooperativo de golpe em que você fala de verdade, pelo microfone, com NPCs de IA local. Eles entendem, se irritam e chamam a segurança."},
				{"q": "Qual a sacada técnica?", "expr": "nervoso", "a": "A IA interpreta a fala. O código decide as consequências. Cinco fases, primeira pessoa, três idiomas."},
			]
		_:
			greet = "Esse projeto aqui tem história."
			lines = [{"q": "Me conta", "expr": "neutro", "a": str(p.get("desc", ""))}]
