"""Imagens das lojas-museu: copia e reduz prints reais dos projetos (repos locais) e gera cartões
noir de texto para itens sem imagem (arquitetura e destaques extraídos dos READMEs).
Saída: game/assets/museum/<projeto>/*. Uso: python tools/museum/build_images.py"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "museum")
FONTS = os.path.join(ROOT, "game", "assets", "fonts")
P = "C:/Project"

COPIES = {
    "rumor": [(f"{P}/detetive/docs/img/telas.png", "telas"), (f"{P}/detetive/docs/img/expressoes.png", "expressoes"),
              (f"{P}/detetive/docs/img/professor.png", "professor"), (f"{P}/detetive/docs/img/banner.png", "banner"),
              (f"{P}/detetive/docs/arte_exploracao/cenas_pintadas_folha.png", "cenas")],
    "fortress": [(f"{P}/game/docs/readme/capa.png", "capa"), (f"{P}/game/docs/readme/horda_na_neve.png", "horda"),
                 (f"{P}/game/docs/readme/sinergias_muralha.png", "sinergias"), (f"{P}/game/docs/readme/mapa_campanha_calor.png", "mapa"),
                 (f"{P}/game/docs/readme/loja_progressao.png", "loja"), (f"{P}/game/docs/readme/pergaminho_vitoria.png", "vitoria"),
                 (f"{P}/game/docs/readme/menu_principal.png", "menu")],
    "buscavagas": [(f"{P}/BuscaVagas/docs/assets/screenshots/dashboard.png", "dashboard"),
                   (f"{P}/BuscaVagas/docs/assets/screenshots/dashboard-poucos-candidatos.png", "poucos"),
                   (f"{P}/BuscaVagas/docs/assets/screenshots/vaga-detalhe.png", "detalhe"),
                   (f"{P}/BuscaVagas/docs/assets/screenshots/fontes.png", "fontes"),
                   (f"{P}/BuscaVagas/docs/assets/screenshots/kanban.png", "kanban"),
                   (f"{P}/BuscaVagas/docs/assets/screenshots/mobile.png", "mobile"),
                   (f"{P}/BuscaVagas/docs/assets/screenshots/ao-vivo.png", "aovivo")],
    "orbix": [(f"{ROOT}/game/assets/covers/orbix.png", "capa"), (f"{P}/Orbix/login-page.png", "login")],
    "labia": [(f"{P}/GameOnline/assets/ui/title_background.png", "titulo"), (f"{P}/GameOnline/assets/ui/banner_golpe_perfeito.png", "golpe"),
              (f"{P}/GameOnline/assets/ui/banner_deu_ruim.png", "deu_ruim")],
    "inaciocyber": [(f"{P}/InacioCyber/desktop/icon.png", "icone")],
}

# cartões de texto (título, linhas) para o que não tem print
CARDS = {
    "inaciocyber": [
        ("arquitetura", "ARQUITETURA", ["Chat em tempo real (WebSocket)", "Agente com modelo local via Ollama",
                                         "Ferramentas em containers Docker", "Registro de cada passo no Postgres",
                                         "App desktop em Electron", "Nada sai da sua máquina"]),
        ("autorizacao", "SÓ COM AUTORIZAÇÃO", ["Cada sessão pede confirmação escrita",
                                                "de que o alvo é seu ou autorizado.", "Sem isso, nenhuma ferramenta roda.",
                                                "Relatório final em markdown."]),
        ("metricas", "PAINEL AO VIVO", ["CPU e RAM do host e dos containers", "GPU e VRAM da placa", "Tokens usados no contexto",
                                         "Histórico de sessões na lateral"]),
    ],
    "orbix": [
        ("rls", "MULTI-TENANT DE VERDADE", ["Isolamento por Row-Level Security", "no próprio PostgreSQL:",
                                             "cada empresa só enxerga o que é dela,", "mesmo se a aplicação errar."]),
        ("arquitetura", "UMA API, VÁRIOS PRODUTOS", ["orbix-api: login, OTP, tokens, finanças", "CRM, gestão de oficinas, barbearias",
                                                      "Monorepo NestJS + Flutter", "Docker e WhatsApp integrados"]),
    ],
    "formataai": [
        ("fluxo", "DA VOZ AO TEXTO PRONTO", ["1  grava a voz no app", "2  Whisper transcreve", "3  GPT-4o-mini formata",
                                             "4  compartilha em um toque"]),
        ("formatos", "NOVE FORMATOS", ["WhatsApp · E-mail · Documento", "Orçamento · Receita · Currículo", "Post social · Lista · Outro"]),
        ("arquitetura", "ARQUITETURA", ["Flutter no celular", "Nginx com SSL", "Node.js + Express 5", "Prisma + PostgreSQL",
                                        "IA orquestrada, não embutida"]),
        ("tcc", "TRABALHO DE CONCLUSÃO", ["Feito para quem tem menos", "fluência digital: basta falar."]),
    ],
    "buscavagas": [
        ("tempo_real", "SEM LACUNAS, POR CONSTRUÇÃO", ["Sequência atômica no Redis", "WebSocket com heartbeat",
                                                        "Polling de reserva", "Detecção de lacuna e ressincronização"]),
    ],
    "fortress": [
        ("numeros", "EM NÚMEROS", ["7 civilizações · 12 biomas", "14 magias · cartas por raridade", "Sinergias por adjacência",
                                   "9 idiomas · Windows e Android"]),
    ],
    "rumor": [
        ("numeros", "EM NÚMEROS", ["12 casos escritos à mão", "192 pistas com imagem", "Servidor autoritativo em Node",
                                   "Celular e PC, direto no navegador"]),
    ],
}


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def fit(img, w=1024):
    img = img.convert("RGB")
    if img.width > w:
        img = img.resize((w, int(img.height * w / img.width)), Image.LANCZOS)
    return img


def card(path, title, lines, accent=(255, 200, 61)):
    W, H = 1024, 640
    img = Image.new("RGB", (W, H), (8, 10, 20))
    d = ImageDraw.Draw(img)
    for y in range(0, H, 4):
        d.line([(0, y), (W, y)], fill=(12, 15, 28))
    d.rectangle([24, 24, W - 24, H - 24], outline=accent, width=4)
    d.rectangle([24, 24, W - 24, 84], fill=(16, 20, 36))
    for i, c in enumerate([(226, 56, 79), (255, 200, 61), (95, 211, 138)]):
        d.ellipse([46 + i * 34, 44, 66 + i * 34, 64], fill=c)
    d.text((W // 2, 112 + 30), title, font=font("BebasNeue-Regular.ttf", 76), fill=accent, anchor="mm")
    y = 220
    for ln in lines:
        d.text((80, y), ln, font=font("SpecialElite-Regular.ttf", 38), fill=(232, 236, 248))
        y += 62
    img.save(path)


def main():
    for pid, items in COPIES.items():
        os.makedirs(os.path.join(OUT, pid), exist_ok=True)
        for src, name in items:
            if not os.path.exists(src):
                print("falta", src)
                continue
            fit(Image.open(src)).save(os.path.join(OUT, pid, name + ".jpg"), quality=86)
            print(pid, name)
    for pid, cards in CARDS.items():
        os.makedirs(os.path.join(OUT, pid), exist_ok=True)
        for name, title, lines in cards:
            card(os.path.join(OUT, pid, name + ".png"), title, lines)
            print(pid, name, "(cartão)")


if __name__ == "__main__":
    main()
