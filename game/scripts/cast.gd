extends RefCounted
## Elenco noir do portfólio: as fichas dos personagens (visual + estilo). Usadas pelos NPCs da cidade,
## pelos interiores e pela tela de diálogo.

const CAST := {
	"detetive": {"id": "detetive", "name": "Vance", "role": "detetive particular", "adult": true, "style": "noir", "gender": "m",
		"look": {"skin": "#b98a66", "top": "#4a3c2e", "pants": "#1a1a22", "hair": "grisalho_curto", "hair_color": "#2a2428",
			"facial_hair": "barba", "accent": "#5a1f2a", "kit": "detetive", "coat": "#4a3c2e", "outfit": "formal"}},
	"couro": {"id": "couro", "name": "Lena", "role": "produtora de jogos", "adult": true, "style": "noir", "gender": "f",
		"look": {"skin": "#d2a07c", "top": "#17131a", "pants": "#1c1a24", "hair": "longo", "hair_color": "#4a1a20",
			"accent": "#b02a4a", "kit": "couro", "coat": "#17131a", "outfit": "formal"}},
	"bartender": {"id": "bartender", "name": "Otto", "role": "dono do bar", "adult": true, "style": "noir", "gender": "m",
		"look": {"skin": "#8a5a3a", "top": "#d9d3c6", "pants": "#16141c", "hair": "raspado", "hair_color": "#18141a",
			"facial_hair": "bigode", "accent": "#7a1a24", "kit": "bartender", "vest": "#2a1c22", "outfit": "formal"}},
	"hacker": {"id": "hacker", "name": "Kai", "role": "arquiteto de sistemas", "adult": true, "style": "noir", "gender": "m",
		"look": {"skin": "#c49272", "top": "#1d2230", "pants": "#15171f", "hair": "curto", "hair_color": "#121018",
			"facial_hair": "cavanhaque", "accessory": "oculos", "accent": "#1d2230", "kit": "hacker", "coat": "#1d2230", "outfit": "formal"}},
}


static func card(id: String) -> Dictionary:
	return (CAST.get(id, CAST["detetive"]) as Dictionary).duplicate(true)
