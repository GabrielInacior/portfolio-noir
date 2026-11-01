"""Define o conteúdo das lojas-museu: cada loja tem um ambiente (tema) e uma lista de itens 3D
examináveis (tipo de objeto, posição na parede/sala, título, texto da história, imagem e link).
Gera game/assets/museum/_items/<projeto>.json lido pelo museu em Godot.
Uso: python tools/museum/build_items.py"""
import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "museum", "_items")
os.makedirs(OUT, exist_ok=True)


def img(pid, name):
    return "res://assets/museum/%s/%s" % (pid, name)


# tema: cores e textura de cada loja (piso, parede, luz quente/fria, neon do letreiro)
THEMES = {
    "rumor": {"room": "escritorio", "floor": "madeira", "wall": "papel_parede", "warm": "#ffb23d", "cool": "#4e9bff",
              "accent": "#ffc83d", "sub": "Escritório de detetive"},
    "fortress": {"room": "fliperama", "floor": "ladrilho", "wall": "tijolo", "warm": "#ff7a3d", "cool": "#8a5bff",
                 "accent": "#ff7a3d", "sub": "Loja de jogos e fliperama"},
    "inaciocyber": {"room": "lab", "floor": "metal", "wall": "concreto", "warm": "#39ff9b", "cool": "#1f7a4a",
                    "accent": "#39ff9b", "sub": "Sala de segurança"},
    "buscavagas": {"room": "escritorio", "floor": "carpete", "wall": "concreto", "warm": "#ffc83d", "cool": "#4e9bff",
                   "accent": "#4e9bff", "sub": "Agência de empregos"},
    "orbix": {"room": "escritorio", "floor": "carpete", "wall": "concreto", "warm": "#ffd36a", "cool": "#b06bff",
              "accent": "#b06bff", "sub": "Central de operações"},
    "formataai": {"room": "estudio", "floor": "madeira", "wall": "papel_parede", "warm": "#ff6fae", "cool": "#4e9bff",
                  "accent": "#ff6fae", "sub": "Estúdio de voz"},
    "labia": {"room": "bar", "floor": "ladrilho", "wall": "papel_parede", "warm": "#ff3d7f", "cool": "#5bd0ff",
              "accent": "#ff3d7f", "sub": "Bar dos vigaristas"},
    "ankiana": {"room": "estudio", "floor": "madeira", "wall": "papel_parede", "warm": "#ffc83d", "cool": "#5fd38a",
                "accent": "#5fd38a", "sub": "Sala de estudos"},
    "airmessage": {"room": "escritorio", "floor": "carpete", "wall": "concreto", "warm": "#ffd36a", "cool": "#5bd0ff",
                   "accent": "#5bd0ff", "sub": "Central de mensagens"},
    "sitembm": {"room": "escritorio", "floor": "carpete", "wall": "concreto", "warm": "#ffd36a", "cool": "#4e9bff",
                "accent": "#4e9bff", "sub": "Agência"},
}

# kinds de objeto 3D (o museu sabe montar cada um): quadro (frame), telao (screen), poster,
# monitor, caixa (crate), livro (book), placa (plaque), objeto (prop com modelo), fliperama (arcade)
ITEMS = {
    "rumor": [
        {"kind": "frame", "img": img("rumor", "banner.jpg"), "title": "O caso RUMOR",
         "text": "Jogo de detetive multiplayer para a sala de aula. Equipes exploram a escola em 3D, interrogam personagens que mudam de expressão e montam juntas um quadro com fios e provas.", "tag": "Godot · Node · WebSocket"},
        {"kind": "screen", "img": img("rumor", "telas.jpg"), "title": "Quatro telas do jogo",
         "text": "Explorar em 3D, interrogar, ligar os fios do quadro e compartilhar a vitória. Tudo no navegador do celular de cada aluno.", "tag": "Mobile e desktop"},
        {"kind": "frame", "img": img("rumor", "expressoes.jpg"), "title": "Expressões",
         "text": "O rosto do suspeito muda a cada fala: desconfiado, nervoso, triste. Mostrar a prova certa na hora certa desmonta a versão dele.", "tag": "Atlas de rostos"},
        {"kind": "screen", "img": img("rumor", "professor.jpg"), "title": "O professor vê tudo",
         "text": "Do celular ou do telão, o professor acompanha as equipes ao vivo: radar, pistas achadas, provas e quem está parado.", "tag": "Painel ao vivo"},
        {"kind": "frame", "img": img("rumor", "cenas.jpg"), "title": "Cenário pintado",
         "text": "Doze cômodos da escola em 3D com estilo pincelado, feitos por código e Blender. Nada de asset pronto de terceiro.", "tag": "Arte própria"},
        {"kind": "plaque", "img": img("rumor", "numeros.png"), "title": "Em números",
         "text": "12 casos escritos à mão, 192 pistas com imagem, servidor autoritativo em Node, reconexão e votação da equipe.", "tag": "Escopo"},
        {"kind": "prop", "model": "maquina_escrever", "title": "Casos à mão",
         "text": "Cada caso foi escrito à mão, sem IA gerando história, e verificado por scripts para não ter furo: toda pista existe e todo objetivo pode ser provado.", "tag": "Design de jogo"},
    ],
    "fortress": [
        {"kind": "frame", "img": img("fortress", "capa.jpg"), "title": "Fortress Chaos",
         "text": "Roguelite medieval de construção de fortaleza e defesa de torres, 3D low-poly com interface em pixel art feita à mão.", "tag": "Godot · Steam"},
        {"kind": "screen", "img": img("fortress", "horda.jpg"), "title": "A horda chega",
         "text": "As ondas vêm cada vez mais fortes. Torres e tropas lutam sozinhas; você intervém com magias por clique. Chefes nas ondas 5 e 10.", "tag": "Tower defense"},
        {"kind": "frame", "img": img("fortress", "sinergias.jpg"), "title": "Sinergias por adjacência",
         "text": "A muralha herda o elemento da torre ao lado: elétrica, fogo, gelo, veneno. A estratégia nasce do desenho físico da fortaleza.", "tag": "Sistemas"},
        {"kind": "frame", "img": img("fortress", "mapa.jpg"), "title": "Campanha com Calor",
         "text": "Mapa de nós com 12 biomas, clima que muda o terreno e baús trancados. O Calor é a dificuldade opcional que paga mais Prata.", "tag": "Meta"},
        {"kind": "screen", "img": img("fortress", "loja.jpg"), "title": "Progresso permanente",
         "text": "A Prata de cada expedição compra civilizações, construções, magias e cosméticos para a próxima.", "tag": "Progressão"},
        {"kind": "frame", "img": img("fortress", "vitoria.jpg"), "title": "Seguir ou resistir",
         "text": "Fase vencida: siga viagem ou fique para ondas sem fim, que pagam mais e perdoam menos.", "tag": "Risco"},
        {"kind": "plaque", "img": img("fortress", "numeros.png"), "title": "Em números",
         "text": "7 civilizações, 12 biomas, 14 magias, cartas por raridade com mutações, 9 idiomas, Windows e Android.", "tag": "Escopo"},
        {"kind": "arcade", "title": "No fliperama",
         "text": "Civilizações com arquitetura e tropas próprias, cartas de Caos para quem gosta de risco e a Oficina do Estandarte, onde você desenha o brasão pixel a pixel.", "tag": "Conteúdo"},
    ],
    "inaciocyber": [
        {"kind": "monitor", "img": img("inaciocyber", "arquitetura.png"), "title": "Como funciona",
         "text": "Você conversa num chat de estética terminal, define um alvo autorizado e um modelo local encadeia ferramentas reais de reconhecimento, varredura e auditoria, terminando com um relatório.", "tag": "Python · Ollama · Docker"},
        {"kind": "monitor", "img": img("inaciocyber", "autorizacao.png"), "title": "Só com autorização",
         "text": "Cada sessão pede uma confirmação escrita de que o alvo é seu ou autorizado. Sem isso, nenhuma ferramenta roda. É uma ferramenta de defesa e teste autorizado.", "tag": "Uso responsável"},
        {"kind": "monitor", "img": img("inaciocyber", "metricas.png"), "title": "Painel ao vivo",
         "text": "CPU e RAM do host e dos containers, GPU e VRAM, tokens usados no contexto e histórico de sessões na lateral.", "tag": "Observabilidade"},
        {"kind": "prop", "model": "servidor", "title": "Tudo local",
         "text": "Roda inteiro na sua máquina, em containers Docker. Nada sai para fora, exceto as requisições do agente contra o alvo que você autorizar.", "tag": "Privacidade"},
        {"kind": "prop", "model": "cadeado", "title": "Relatório final",
         "text": "O agente registra cada comando no Postgres e entrega um relatório em markdown com o que encontrou e onde esbarrou em limitações.", "tag": "Auditoria"},
        {"kind": "plaque", "img": img("inaciocyber", "icone.jpg"), "title": "Blackwall",
         "text": "App desktop de verdade em Electron, janela sem moldura, tema terminal. Segurança ofensiva usada para o lado certo.", "tag": "Desktop"},
    ],
    "buscavagas": [
        {"kind": "screen", "img": img("buscavagas", "dashboard.jpg"), "title": "Oportunidades",
         "text": "Cruza seu currículo com vagas de 17 fontes e põe no topo o que combina com você, tem poucos candidatos e foi publicado há pouco.", "tag": "Nuxt · Fastify · Postgres"},
        {"kind": "frame", "img": img("buscavagas", "poucos.jpg"), "title": "Poucos candidatos",
         "text": "Vagas do LinkedIn com o número real de candidatos. Aqui, todas com menos de 25 e match alto.", "tag": "Sinal de chance"},
        {"kind": "frame", "img": img("buscavagas", "detalhe.jpg"), "title": "Por que essa vaga",
         "text": "Match, concorrência com cada motivo, elegibilidade e o link da vaga original. A nota de oportunidade sai de embeddings locais.", "tag": "Ranking"},
        {"kind": "screen", "img": img("buscavagas", "aovivo.jpg"), "title": "Tempo real sem lacunas",
         "text": "Sequência atômica no Redis, WebSocket com heartbeat, polling de reserva e ressincronização. Tudo muda em todas as abas, sem recarregar.", "tag": "Arquitetura"},
        {"kind": "frame", "img": img("buscavagas", "kanban.jpg"), "title": "Kanban",
         "text": "Arraste os cards entre colunas; o quadro sincroniza entre abas e janelas.", "tag": "UX"},
        {"kind": "frame", "img": img("buscavagas", "fontes.jpg"), "title": "17 fontes",
         "text": "Fontes brasileiras primeiro, liga e desliga cada uma, vagas abertas e o resultado da última execução, ao vivo.", "tag": "Coleta"},
        {"kind": "prop", "model": "monitor_cv", "title": "Roda na sua máquina",
         "text": "Tudo local e de graça. A chave da OpenAI é opcional: sem ela o ranking funciona por completo com o modelo local.", "tag": "IA local"},
    ],
    "orbix": [
        {"kind": "monitor", "img": img("orbix", "rls.png"), "title": "Multi-tenant de verdade",
         "text": "Isolamento por Row-Level Security no próprio PostgreSQL: cada empresa só enxerga o que é dela, mesmo se a aplicação errar.", "tag": "Postgres RLS"},
        {"kind": "monitor", "img": img("orbix", "arquitetura.png"), "title": "Uma API, vários produtos",
         "text": "O orbix-api centraliza login, OTP, tokens e finanças e serve vários produtos, como CRM e gestão de oficinas.", "tag": "NestJS · Flutter"},
        {"kind": "frame", "img": img("orbix", "login.jpg"), "title": "Entrada única",
         "text": "Toda a camada de autenticação é delegada ao orbix-api via proxy. Um só lugar para login e segurança.", "tag": "Auth"},
        {"kind": "prop", "model": "servidor", "title": "Monorepo",
         "text": "NestJS e Flutter no mesmo repositório, com Docker. Plataforma SaaS pensada para crescer com muitos clientes.", "tag": "Infra"},
    ],
    "formataai": [
        {"kind": "monitor", "img": img("formataai", "fluxo.png"), "title": "Da voz ao texto pronto",
         "text": "Grava a voz, o Whisper transcreve, o GPT-4o-mini formata e você compartilha em um toque.", "tag": "Flutter · OpenAI"},
        {"kind": "monitor", "img": img("formataai", "formatos.png"), "title": "Nove formatos",
         "text": "WhatsApp, e-mail, documento, orçamento, receita, currículo, post social, lista ou outro, da mesma fala.", "tag": "Versatilidade"},
        {"kind": "monitor", "img": img("formataai", "arquitetura.png"), "title": "Arquitetura",
         "text": "Flutter no celular, Nginx com SSL, Node com Express, Prisma e Postgres. A IA é orquestrada, não embutida.", "tag": "Backend"},
        {"kind": "frame", "img": img("formataai", "tcc.png"), "title": "Trabalho de conclusão",
         "text": "Feito como TCC, para quem tem menos fluência digital. Basta falar e o texto formal sai pronto.", "tag": "Propósito"},
        {"kind": "prop", "model": "microfone", "title": "Acessibilidade",
         "text": "Pensado para maior faixa etária e rotinas corridas: elimina a barreira de redigir mensagens formais.", "tag": "Inclusão"},
    ],
    "labia": [
        {"kind": "frame", "img": img("labia", "golpe.jpg"), "title": "Lábia",
         "text": "Jogo cooperativo de comédia para um a quatro jogadores: vocês são vigaristas e aplicam golpes falando pelo microfone com personagens movidos por IA local.", "tag": "Godot · IA local · Voz"},
        {"kind": "frame", "img": img("labia", "deu_ruim.jpg"), "title": "Eles reagem",
         "text": "Os personagens entendem o que você fala, se irritam, riem e chamam a segurança. Cinco fases, primeira pessoa.", "tag": "NPCs com IA"},
        {"kind": "prop", "model": "microfone", "title": "Fale para jogar",
         "text": "O jogo roda IA local para ouvir e responder em tempo real. A graça está em convencer, improvisar e não ser pego.", "tag": "Voz"},
    ],
    "ankiana": [
        {"kind": "prop", "model": "livro", "title": "AnkiAna",
         "text": "App de estudos que transforma tema, texto ou PDF em dezenas de flashcards com IA, usando repetição espaçada.", "tag": "Flutter · OpenAI"},
        {"kind": "prop", "model": "cartao", "title": "Repetição espaçada",
         "text": "Algoritmo SM-2 decide quando rever cada cartão. Interface Material 3 moderna e acessível.", "tag": "Aprendizado"},
    ],
    "airmessage": [
        {"kind": "prop", "model": "celular", "title": "AirMessage",
         "text": "SaaS de CRM e campanhas por WhatsApp e SMS para clínicas, estúdios e oficinas: mensagens diretas, campanhas agendadas e reengajamento.", "tag": "Node · Flutter · AWS"},
        {"kind": "prop", "model": "servidor", "title": "Operação",
         "text": "Billing mensal e deploy em AWS. Pensado para pequenos negócios manterem contato com os clientes.", "tag": "SaaS"},
    ],
    "sitembm": [
        {"kind": "prop", "model": "monitor_cv", "title": "MBM",
         "text": "Plataforma de landing pages e blog institucional para empresa de telecom, com CMS, newsletter, analytics e SEO dinâmico.", "tag": "Nuxt · Vue · AWS"},
        {"kind": "prop", "model": "cadeado", "title": "Segurança",
         "text": "Backend com autenticação JWT e 2FA, papéis de acesso e upload para S3.", "tag": "Auth"},
    ],
}

# o LAB de skills (lugar dedicado às habilidades do Gabriel)
SKILLS_LAB = {
    "theme": {"room": "lab", "floor": "metal", "wall": "concreto", "warm": "#ffc83d", "cool": "#4e9bff",
              "accent": "#ff3d7f", "sub": "Laboratório"},
    "items": [
        {"kind": "monitor", "title": "Game dev", "model": "", "tag": "Godot · Blender · 3D web",
         "text": "Jogos completos em Godot: 3D para web e celular, modelos e animação em Blender, servidor autoritativo em tempo real. RUMOR, Fortress Chaos e Lábia saíram daqui."},
        {"kind": "monitor", "title": "IA aplicada", "tag": "Claude · agentes · IA local",
         "text": "Orquestração de agentes de IA (uso o Claude e o Claude Code a fundo), modelos locais via Ollama, geração de arte por IA e automação. IA como ferramenta de trabalho, não enfeite."},
        {"kind": "monitor", "title": "Integrações e APIs", "tag": "WebSocket · REST · filas",
         "text": "Tempo real com WebSocket, filas, webhooks e integrações com GitHub, WhatsApp, OpenAI e Hugging Face. Dados que batem em todas as telas, sem recarregar."},
        {"kind": "monitor", "title": "Arquitetura", "tag": "multi-tenant · Docker · Postgres",
         "text": "Multi-tenant com Row-Level Security, monorepos, Docker, Postgres e Redis. Sistemas pensados para crescer e não quebrar com muitos usuários."},
        {"kind": "prop", "model": "servidor", "title": "Full-stack",
         "text": "Do banco ao pixel: back-end em Node e NestJS, front em Nuxt, Vue e Flutter, e a camada 3D em Godot. Entrego a coisa inteira funcionando.", "tag": "Ponta a ponta"},
        {"kind": "prop", "model": "cadeado", "title": "Segurança",
         "text": "Autenticação com JWT e 2FA, isolamento de dados, e segurança ofensiva autorizada no InacioCyber para encontrar falhas antes de quem quer explorá-las.", "tag": "Defesa"},
    ],
}


KIND_BY_TIPO = {"quadro": "frame", "telao": "screen", "tela": "screen", "placa_stack": "plaque", "placa": "plaque",
                "relatorio": "frame", "objeto": "frame", "poster": "poster"}
MODEL_BY_ID = {"airmessage": "telefone", "ankiana": "livro", "sitembm": "monitor_cv", "labia": "microfone", "orbix": "servidor"}


def enrich(pid, items):
    """Lojas com poucas peças recebem as peças do roteiro (data/museum/<id>.json); as que não têm
    imagem viram cartões de texto na própria tela/quadro (o museu desenha o texto)."""
    path = os.path.join(ROOT, "data", "museum", pid + ".json")
    if not os.path.exists(path):
        return items
    have = {i["title"].lower() for i in items}
    out = list(items)
    for pc in json.load(open(path, encoding="utf8")).get("pieces", []):
        t = pc.get("titulo", "")
        if not t or t.lower() in have or len(out) >= 9:
            continue
        kind = KIND_BY_TIPO.get(pc.get("tipo", "quadro"), "frame")
        out.append({"kind": kind, "title": t, "text": pc.get("texto", ""), "tag": pc.get("tag", "")})
        have.add(t.lower())
    return out


def main():
    for pid in list(ITEMS.keys()):
        ITEMS[pid] = enrich(pid, ITEMS[pid])
    for pid, items in ITEMS.items():
        theme = THEMES.get(pid, {"room": "escritorio", "floor": "carpete", "wall": "concreto",
                                 "warm": "#ffd36a", "cool": "#4e9bff", "accent": "#ffc83d", "sub": ""})
        json.dump({"theme": theme, "items": items}, open(os.path.join(OUT, pid + ".json"), "w", encoding="utf8"),
                  ensure_ascii=False, indent=1)
        print(pid, len(items), "itens")
    json.dump(SKILLS_LAB, open(os.path.join(OUT, "_lab.json"), "w", encoding="utf8"), ensure_ascii=False, indent=1)
    print("lab", len(SKILLS_LAB["items"]), "itens")


if __name__ == "__main__":
    main()
