"""Gera os roteiros das lojas-museu (game/assets/museum/<loja>.json). Cada loja conta a história de um
projeto com objetos 3D examináveis. Formato documentado em docs/MUSEU_FORMATO.md.
Uso: python tools/museum/build_data.py"""
import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "museum")


def it(id, title, kind, text, image="", model="", stack=None, links=None, slot=""):
    d = {"id": id, "title": title, "kind": kind, "text": text}
    if image:
        d["image"] = image
    if model:
        d["model"] = model
    if stack:
        d["stack"] = stack
    if links:
        d["links"] = links
    if slot:
        d["slot"] = slot
    return d


SHOPS = {
    "rumor": {
        "theme": "detetive", "name": "Agência Rumor", "neon": "#ffc83d",
        "intro": "Um escritório de detetive onde cada objeto guarda um pedaço da história do RUMOR.",
        "items": [
            it("quadro", "O quadro de cortiça", "objeto", "O coração do jogo. A equipe fixa pessoas, lugares e fatos e liga tudo com barbante: estava em, mentiu sobre, acobertou. Cada fio recebe as pistas que provam. A teoria entregue é o próprio quadro, e o servidor confere.", model="cortica", stack=["Godot", "GDScript"]),
            it("telas", "No celular de cada aluno", "quadro", "Feito para a sala de aula: cada aluno joga no navegador do próprio celular, em equipe. Cenas 3D da escola, interrogatórios e o quadro compartilhado, tudo em retrato.", image="telas.jpg"),
            it("rostos", "Cada fala, uma reação", "quadro", "Os personagens mudam de expressão e de gesto a cada fala. Mostrar a pista certa na hora certa desmonta uma versão; perguntar errado fecha a porta por um tempo.", image="expressoes.jpg", stack=["Blender", "Mixamo"]),
            it("maquina", "Casos escritos à mão", "objeto", "Doze casos escritos à mão, sem IA gerando história. Scripts conferem cada um: toda pista existe, toda conversa leva a algum lugar e todo objetivo pode ser provado.", model="maquina_escrever"),
            it("professor", "O professor vê tudo", "tela", "A tela do professor acompanha a sala ao vivo: radar das equipes, ocorrências com ícones, quem está parado, dicas e o guia do caso em formato de dossiê.", image="professor.jpg"),
            it("servidor", "Servidor autoritativo", "objeto", "Por trás, um servidor Node com WebSocket que é dono do jogo: salas, equipes, quadro compartilhado, votação da entrega e conferência da teoria. Ações simultâneas da equipe resolvidas sem conflito.", model="rack", stack=["Node.js", "WebSocket"]),
            it("cenas", "A escola pintada", "quadro", "Doze cômodos e a fachada da escola em 3D, com shader toon, contorno, céu pintado, chuva e figurantes. Tudo leve o bastante para rodar no celular.", image="cenas.jpg"),
            it("numeros", "Em números", "placa", "12 casos, 192 pistas com imagem, celular e PC, direto no navegador.", image="numeros.png"),
            it("chapeu", "Noir de quadrinho", "objeto", "Azul da noite, amarelo de abajur, chuva na janela e uma trilha original. A estética nasceu daqui e virou a cara deste portfólio.", model="chapeu"),
        ],
        "links": {"site": "https://rumor.inaciodev.online", "github": "https://github.com/GabrielInacior/rumor"},
    },
    "fortress": {
        "theme": "fliperama", "name": "Fliperama do Caos", "neon": "#ff7a3d",
        "intro": "Uma loja de jogos e fliperama dedicada ao Fortress Chaos.",
        "items": [
            it("arcade", "Erga a fortaleza", "objeto", "Roguelite medieval de construção de fortaleza e defesa de torres, em 3D low-poly com interface em pixel art feita à mão. Toda fortaleza cai um dia; o objetivo é cair mais tarde.", image="capa.jpg", model="fliperama", stack=["Godot", "Blender"]),
            it("horda", "As ondas chegam", "quadro", "Torres e tropas lutam sozinhas; você intervém com magias por clique. Chefes nas ondas 5 e 10.", image="horda.jpg"),
            it("sinergias", "Sinergias por adjacência", "quadro", "A estratégia nasce do desenho físico da fortaleza: muralhas herdam o elemento da torre ao lado, torres se alimentam em bateria. O fantasma de construção mostra o ganho antes de confirmar.", image="sinergias.jpg"),
            it("cartas", "Cartas por raridade", "objeto", "Comum, Rara, Épica, Lendária. Mutações de torre, Pactos, cartas de Caos para quem gosta de risco e a Mesa de Banimento.", model="cartas"),
            it("mapa", "Campanha em mapa de nós", "quadro", "12 biomas vivos, clima que muda o terreno, eventos raros e a dificuldade Calor, que paga mais a quem aguenta.", image="mapa.jpg"),
            it("torre", "7 civilizações", "objeto", "Valmora, Skarnheim, Kemaru, Heliora, Kagemori, Longxuan e Xolotec, cada uma com bônus, torre, tropa e arquitetura próprias.", model="torre"),
            it("loja", "Voltar mais forte", "tela", "A Prata da expedição compra civilizações, construções, magias e cosméticos para a próxima tentativa.", image="loja.jpg"),
            it("numeros", "Em números", "placa", "7 civilizações, 12 biomas, 14 magias, 9 idiomas, Windows e Android.", image="numeros.png"),
            it("vitoria", "Seguir ou resistir", "quadro", "Fase vencida: siga viagem ou fique para ondas sem fim, que pagam mais e perdoam menos.", image="vitoria.jpg"),
        ],
        "links": {},
    },
    "inaciocyber": {
        "theme": "cyber", "name": "InacioCyber", "neon": "#5fd38a",
        "intro": "Uma sala de segurança: monitores, servidores e um agente de IA que roda inteiro na sua máquina.",
        "items": [
            it("terminal", "Um agente que conversa", "t