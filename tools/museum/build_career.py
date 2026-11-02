"""Prédio da CARREIRA: peças de museu das empresas e projetos profissionais do Gabriel, com
cartões/diagramas desenhados por nós (nenhum dado confidencial, só a ideia de cada sistema).
Gera game/assets/museum/carreira/*.png e game/assets/museum/_items/_carreira.json.
Uso: python tools/museum/build_career.py"""
import json
import math
import os
import random

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_IMG = os.path.join(ROOT, "game", "assets", "museum", "carreira")
OUT_JSON = os.path.join(ROOT, "game", "assets", "museum", "_items", "_carreira.json")
FONTS = os.path.join(ROOT, "game", "assets", "fonts")
os.makedirs(OUT_IMG, exist_ok=True)

BG = (11, 13, 22)
INK = (232, 236, 248)
MIST = (142, 160, 200)
COLS = [(78, 155, 255), (255, 79, 163), (95, 211, 138), (255, 200, 61), (176, 107, 255), (255, 122, 61)]


def F(size, kind="type"):
    names = {"type": "SpecialElite-Regular.ttf", "title": "BebasNeue-Regular.ttf", "body": "Nunito-Var.ttf"}
    for n in [names.get(kind, ""), "SpecialElite-Regular.ttf"]:
        p = os.path.join(FONTS, n)
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def canvas(title, col, w=1200, h=760):
    im = Image.new("RGB", (w, h), BG)
    d = ImageDraw.Draw(im)
    for y in range(0, h, 4):
        d.line([(0, y), (w, y)], fill=(14, 16, 26))
    d.rectangle([0, 0, w - 1, h - 1], outline=col, width=6)
    d.text((40, 26), title, font=F(64, "title"), fill=col)
    return im, d


def box(d, xy, text, col, font=None):
    x0, y0, x1, y1 = xy
    d.rounded_rectangle(xy, 14, fill=(20, 24, 38), outline=col, width=4)
    font = font or F(30, "type")
    tw = d.textlength(text, font=font)
    d.text(((x0 + x1 - tw) / 2, (y0 + y1) / 2 - 18), text, font=font, fill=INK)


def arrow(d, a, b, col):
    d.line([a, b], fill=col, width=4)
    ang = math.atan2(b[1] - a[1], b[0] - a[0])
    for s in (-0.5, 0.5):
        d.line([b, (b[0] - 18 * math.cos(ang + s), b[1] - 18 * math.sin(ang + s))], fill=col, width=4)


def acl():
    col = COLS[0]
    im, d = canvas("ACL · ASSISTENTE DE LICITAÇÕES", col)
    steps = ["Captura de editais", "Proposta automática", "Lances no pregão", "Monitoramento"]
    for i, s in enumerate(steps):
        x = 60 + i * 280
        box(d, (x, 220, x + 240, 340), s, COLS[i % 4], F(26))
        if i < 3:
            arrow(d, (x + 240, 280), (x + 280, 280), MIST)
    box(d, (360, 450, 840, 560), "Portais do governo", col, F(32))
    for i in range(4):
        arrow(d, (180 + i * 280, 340), (600, 450), (60, 70, 100))
    d.text((60, 620), "Fluxo completo de compras públicas, automatizado ponta a ponta.", font=F(30), fill=MIST)
    d.text((60, 670), "QA · Staging · Produção · tempo real com WebSockets", font=F(26), fill=col)
    im.save(os.path.join(OUT_IMG, "acl.png"))


def dashboard():
    col = COLS[3]
    im, d = canvas("MERCADO DE LICITAÇÕES · ANÁLISE", col)
    rnd = random.Random(3)
    # tabela virtualizada
    d.rectangle([40, 120, 690, 720], outline=(60, 70, 100), width=2)
    heads = ["órgão", "objeto", "valor", "data"]
    for i, h in enumerate(heads):
        d.text((60 + i * 160, 132), h.upper(), font=F(22), fill=col)
    for r in range(22):
        y = 170 + r * 24
        d.rectangle([44, y, 686, y + 20], fill=(18, 22, 34) if r % 2 else (14, 17, 28))
        for c in range(4):
            d.rectangle([60 + c * 160, y + 7, 60 + c * 160 + rnd.randint(40, 130), y + 13], fill=(70, 80, 110))
    d.text((60, 690), "linha 1.284.903 de 3.512.448  ·  rolagem virtualizada", font=F(20), fill=MIST)
    # gráficos
    d.rectangle([720, 120, 1160, 400], outline=(60, 70, 100), width=2)
    for i in range(12):
        hgt = rnd.randint(40, 230)
        d.rectangle([740 + i * 34, 390 - hgt, 764 + i * 34, 390], fill=COLS[i % 6])
    d.rectangle([720, 430, 1160, 720], outline=(60, 70, 100), width=2)
    pts = [(740 + i * 38, 680 - int(120 + 90 * math.sin(i * 0.7) + rnd.randint(-20, 20))) for i in range(11)]
    d.line(pts, fill=COLS[1], width=5)
    d.text((740, 440), "tendência por categoria", font=F(22), fill=MIST)
    im.save(os.path.join(OUT_IMG, "licitacoes.png"))


def streaming():
    col = COLS[1]
    im, d = canvas("SYSGUIDE · VÍDEO E STREAMING", col)
    for i in range(3):
        x = 60 + i * 190
        d.rectangle([x, 140, x + 170, 260], fill=(20, 24, 38), outline=COLS[i], width=3)
        d.ellipse([x + 70, 180, x + 100, 210], outline=COLS[i], width=3)
        d.text((x + 10, 228), "câmera %d" % (i + 1), font=F(20), fill=MIST)
        arrow(d, (x + 85, 260), (300, 360), (70, 80, 110))
    box(d, (150, 360, 460, 460), "Servidor de vídeo", col, F(28))
    arrow(d, (460, 410), (620, 410), MIST)
    box(d, (620, 340, 1140, 480), "App desktop · Rust + Tauri", COLS[3], F(30))
    box(d, (620, 540, 860, 640), "LLM local", COLS[2], F(28))
    box(d, (900, 540, 1140, 640), "Whisper", COLS[4], F(28))
    arrow(d, (740, 480), (740, 540), MIST)
    arrow(d, (1020, 480), (1020, 540), MIST)
    d.text((60, 520), "transmissão ao vivo", font=F(24), fill=MIST)
    d.text((60, 560), "gravação e busca", font=F(24), fill=MIST)
    d.text((60, 680), "transcrição e resumo sem mandar nada para fora", font=F(26), fill=col)
    im.save(os.path.join(OUT_IMG, "sysguide.png"))


def whisper():
    col = COLS[4]
    im, d = canvas("TRANSCRIÇÃO AO VIVO · WHISPER", col)
    rnd = random.Random(7)
    for i in range(90):
        x = 60 + i * 12
        hh = int(abs(math.sin(i * 0.31)) * 120 + rnd.randint(4, 40))
        d.rectangle([x, 260 - hh // 2, x + 6, 260 + hh // 2], fill=col)
    lines = ["[00:12] reunião de alinhamento do projeto", "[00:31] decisão: priorizar a rota de vídeo",
             "[01:05] próximo passo: testes de carga", "resumo gerado pelo modelo local ▌"]
    for i, ln in enumerate(lines):
        d.text((60, 400 + i * 64), ln, font=F(32), fill=INK if i < 3 else COLS[2])
    im.save(os.path.join(OUT_IMG, "whisper.png"))


def research():
    col = COLS[2]
    im, d = canvas("PESQUISA · COMPRESSOR DE CO2 SUPERCRÍTICO", col)
    rnd = random.Random(1)
    d.rectangle([60, 140, 700, 700], outline=(60, 70, 100), width=2)
    for i in range(40):
        x = 80 + rnd.random() * 600
        y = 160 + rnd.random() * 520
        d.ellipse([x - 6, y - 6, x + 6, y + 6], fill=COLS[i % 3])
    pts = [(80 + i * 30, 640 - int(400 * (1 - math.exp(-i / 7)))) for i in range(21)]
    d.line(pts, fill=COLS[3], width=5)
    for i, t in enumerate(["Planejamento fatorial fracionário", "x  SS-ANOVA", "Scripts próprios em Python", "Simulação e estatística"]):
        d.text((740, 200 + i * 80), t, font=F(30), fill=INK if i != 1 else col)
    im.save(os.path.join(OUT_IMG, "pesquisa.png"))


def it(kind, title, text, tag, img="", zone=0):
    d = {"kind": kind, "title": title, "text": text, "tag": tag, "zone": zone}
    if img:
        d["img"] = "res://assets/museum/carreira/%s" % img
    return d


ITEMS = [
    it("screen", "ACL: o assistente de licitações", "Fui o desenvolvedor original do ACL na Sys Evolution: automatiza o ciclo inteiro de compras públicas nos portais do governo, da captura dos editais ao envio de propostas, lances e monitoramento dos pregões.", "Sys Evolution · LicitaSys", "acl.png", 0),
    it("screen", "Milhões de linhas na tela", "Projeto de análise de dados sobre a base pública do mercado de licitações: telas que mostram milhões de linhas de uma vez, com rolagem virtualizada, filtros e análises detalhadas por órgão, objeto e período.", "Dados · performance de front", "licitacoes.png", 0),
    it("frame", "Liderança técnica", "Lidero um time de 3 desenvolvedores em mais de 6 projetos grandes: decisões de arquitetura, planejamento de sprint e entrega. Já entreguei o escopo de 2 semanas em 3 dias e migrei um sistema inteiro de Vue para React em menos de uma semana, sem regressão em produção.", "Sys Evolution", "", 0),
    it("frame", "SaaS multi-tenant", "Aplicações SaaS multi-tenant em Vue, React, Node e PostgreSQL, com BFF e DDD, tempo real por WebSockets, integrações entre vários sistemas e uma biblioteca de componentes usada por mais de 20 desenvolvedores.", "Vue · React · Node · Postgres", "", 0),
    it("screen", "SysGuide: vídeo e streaming", "Servidor de vídeo e streaming com transmissão ao vivo, gravação e busca, e um app desktop em Rust com Tauri que conversa com ele.", "Rust · Tauri · streaming", "sysguide.png", 1),
    it("screen", "IA local e Whisper", "No SysGuide, uma LLM rodando localmente e o Whisper transcrevendo áudio em tempo real, com resumo gerado sem mandar dados para fora.", "LLM local · Whisper", "whisper.png", 1),
    it("frame", "App Flutter e qualidade", "Um dos 2 desenvolvedores do app Flutter da empresa, que juntou vários aplicativos num só. Pipelines de CI/CD no GitLab com testes unitários e E2E, desenvolvimento guiado por especificação e Claude Code e Codex no dia a dia.", "Flutter · GitLab CI · testes", "", 1),
    it("frame", "Loop Sistemas", "Aplicações desktop em WPF com arquitetura MVVM e SQL Server, da correção de bugs a entregas prontas para produção.", "abr a jun 2024 · Jales, SP", "", 2),
    it("screen", "Pesquisa científica (CNPq / UNESP)", "Bolsista de iniciação científica: estudo de um compressor de CO2 supercrítico para o pré-sal, comparando planejamento fatorial fracionário e SS-ANOVA, com scripts próprios em Python.", "set 2022 a ago 2023", "pesquisa.png", 2),
    it("frame", "Plug4Sales (Repediu)", "Estágio em marketing digital com frontend em React e Vite, otimizando desempenho e usabilidade, além de peças visuais e estratégias de marketing para a marca.", "out 2023 a fev 2024 · React · Vite", "", 2),
    it("frame", "SistemasBr", "Primeiro contato com software pelo lado comercial: prospecção ativa, gestão do funil de vendas em CRM e negociação com clientes.", "set a out 2023 · SDR · CRM", "", 2),
    it("frame", "Freelas em produção", "Atende 360 (atn360.com.br): site institucional com CMS próprio, SSR com nota 100 de SEO, 5 idiomas e posts gerados com Gemini. BarberCore: CRM multi-tenant para barbearias com WhatsApp, agendamento, fidelidade e assinaturas no Stripe, rodando na AWS com clientes pagantes.", "Nuxt · Next · AWS · Stripe", "", 2),
]


def main():
    acl()
    dashboard()
    streaming()
    whisper()
    research()
    data = {"theme": {"room": "career", "floor": "carpete", "wall": "concreto", "warm": "#ffe0b0", "cool": "#4e9bff",
                      "accent": "#5bd0ff", "sub": "Carreira"}, "items": ITEMS}
    with open(OUT_JSON, "w", encoding="utf8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    print("ok", len(ITEMS), "peças")


if __name__ == "__main__":
    main()
