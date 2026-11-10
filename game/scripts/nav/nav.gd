class_name Nav
extends RefCounted
## Navegação por clique: lista de lugares da cidade (lojas, LAB, CARREIRA, contato) com ícone,
## cor de neon, miniatura e posição; e a viagem (escurece, leva o jogador até a porta e entra).

const STREETS := [
	# [nome, x, z, rotação do rótulo (rad)]: as ruas nomeiam as SEÇÕES do portfólio
	["AV. DOS PROJETOS", 0.0, -30.0, -PI / 2],
	["RUA DA CARREIRA", 26.0, -42.0, 0.0],
	["BECO DA SEGURANÇA", 18.0, -20.0, 0.0],
	["PRAÇA DO CONTATO", -57.0, -42.0, 0.0],
	["RUA DOS GAMES", -26.0, -42.0, 0.0],
	["RUA SOBRE MIM", 0.0, -66.0, 0.0],
]


## tipo do lugar -> ícone desenhado
static func kind_icon(project: Dictionary) -> String:
	match str(project.get("special", "")):
		"about":
			return "star"
		"career":
			return "compass"
		"contact":
			return "pin"
	var k := str(project.get("kind", "")).to_lower()
	if "game" in k or "jogo" in k:
		return "play"
	if "segur" in k or "secur" in k or "cyber" in k:
		return "eye"
	return "places"


static func places(city) -> Array:
	var out := []
	if city == null:
		return out
	for k in city.kiosks:
		var pr: Dictionary = k["project"]
		var sp := str(pr.get("special", ""))
		var neon: Color = k.get("neon", Color(str(pr.get("neon", "#ffc83d"))))
		var sub := ""
		match sp:
			"about":
				sub = L.t("Habilidades, IA e trajetória")
			"career":
				sub = L.t("Empresas e projetos profissionais")
			"contact":
				sub = L.t("LinkedIn, GitHub e e-mail")
			_:
				sub = L.tx(pr, "tagline")
		out.append({"title": L.t(str(pr.get("title", ""))), "sub": sub, "neon": neon, "project": pr,
			"pos": k["pos"], "visited": k.get("visited", false), "icon": kind_icon(pr), "thumb": thumb(pr),
			"order": {"about": 0, "career": 1, "contact": 99}.get(sp, 10)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["order"] < b["order"] if a["order"] != b["order"] else str(a["title"]) < str(b["title"]))
	return out


static func thumb(pr: Dictionary) -> Texture2D:
	var id := str(pr.get("id", ""))
	var paths := ["res://assets/data/collages/%s.png" % id, "res://assets/covers/%s" % str(pr.get("cover", ""))]
	if str(pr.get("special", "")) == "about":
		paths.push_front("res://assets/photo/gabriel.jpg")
	for p in paths:
		if p.ends_with("/") or not FastTex.exists(p):
			continue
		var t = FastTex.get_tex(p)
		if t is Texture2D:
			return t
	return null


## leva o jogador até a porta do lugar (com escurecimento) e entra (ou abre o contato)
static func travel(hud, place: Dictionary) -> void:
	# entrando numa loja (véu na tela): a viagem espera a porta terminar, nunca mexe no jogador no meio
	if hud == null or hud.player == null or hud._entering:
		return
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(UI.full(fade))
	var tw := fade.create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.22)
	await tw.finished
	if hud._museum != null:
		hud.exit_museum()
	var p: Vector3 = place["pos"]
	var player = hud.player
	# fica na calçada, olhando para a porta
	var away := Vector3(p.x, 0, p.z) - Vector3(signf(p.x) * 2.2 if absf(p.x) > 4.0 else 0.0, 0, 0)
	player.global_position = Vector3(p.x, player.global_position.y, p.z)
	var to := Vector3(p.x, 0, p.z) - away
	if to.length() > 0.01:
		player._yaw = atan2(-to.x, -to.z)
		player.rotation.y = player._yaw
	if player.has_method("sync_look"):
		player.sync_look()
	var pr: Dictionary = place["project"]
	if str(pr.get("special", "")) == "contact":
		hud.open_dossier(pr)
	else:
		hud.enter_museum(pr)
	var tw2 := fade.create_tween()
	tw2.tween_property(fade, "color:a", 0.0, 0.3)
	tw2.tween_callback(fade.queue_free)


## selo de status do projeto (PRODUÇÃO / EM DEV / CONCLUÍDO)
static func status_chip(st: String) -> Control:
	var s := st.to_lower()
	if "produ" in s:
		return UI.chip(L.t("PRODUÇÃO"), UI.GREEN)
	if "desenv" in s or "dev" in s:
		return UI.chip(L.t("EM DEV"), UI.AMBER)
	return UI.chip(L.t(st.to_upper()), UI.CYAN)
