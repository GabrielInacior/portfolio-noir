# -*- coding: utf-8 -*-
"""Gera data/museum/<id>.json: 6 a 12 pecas de museu por projeto (o roteiro contado dentro da loja).
Tipos de objeto: quadro, telao, objeto, placa_stack, linha_do_tempo, relatorio, foto.
Texto em portugues, sem travessao, publico leigo com stack clara. Uso: python tools/content_museum.py"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

M = {
 "rumor": {"loja": "Bar do Detetive", "obj": "Um bar noir onde cada mesa conta um caso.", "pieces": [
   ("O caso", "RUMOR e um jogo de detetive multiplayer feito para a sala de aula. A turma se divide em equipes e cada aluno investiga pelo proprio celular.", "quadro", "banner.png"),
   ("A escola em 3D", "Doze comodos da escola em 3D para explorar. O aluno arrasta para olhar em volta e toca no que brilha para achar pistas.", "telao", "telas.png"),
   ("Interrogatorios", "Os personagens mudam de expressao conforme a conversa aperta. Mostrar a prova certa na hora certa desmonta uma mentira.", "foto", "expressoes.png"),
   ("O quadro de fios", "As equipes montam juntas um quadro com fotos ligadas por barbante e prendem as provas em cada fio. A teoria entregue e o proprio quadro.", "objeto", None),
   ("O servidor", "Um servidor Node autoritativo cuida de salas, equipes, votacao e da conferencia das teorias, com a turma inteira jogando ao mesmo tempo.", "placa_stack", None),
   ("O painel do professor", "O professor acompanha tudo ao vivo pelo celular ou pelo projetor: radar das equipes, pistas achadas e provas cumpridas.", "telao", "professor.png"),
   ("Desafio tecnico", "Manter dezenas de celulares em tempo real, com reconexao e estado retomado, e ainda rodar 3D nitido e leve no navegador do aluno.", "relatorio", None),
   ("Como foi feito", "Cliente em Godot 4.7 exportado para web, servidor Node com WebSocket, personagens e cenarios criados em Blender por codigo.", "placa_stack", None)
 ]},
 "fortress": {"loja": "Fliperama Fortaleza", "obj": "Um fliperama com gabinetes e cartas na parede.", "pieces": [
   ("O jogo", "Fortress Chaos e um roguelite 3D de construir fortaleza e defender de ondas de inimigos. Voce ergue muralhas, posiciona torres e sobrevive.", "quadro", None),
   ("Cartas e sinergias", "Entre as batalhas voce escolhe cartas que se combinam. Cada partida monta um baralho diferente e abre novas estrategias.", "objeto", None),
   ("Civilizacoes e biomas", "Varias civilizacoes, biomas e chefes, cada um mudando o jeito de jogar. Arte 3D low-poly com interface em pixel art feita a mao.", "telao", None),
   ("Chefes", "Chefes grandes fecham cada ciclo e exigem que o jogador leia o campo e adapte a fortaleza na hora.", "objeto", None),
   ("Plataformas", "Em desenvolvimento ativo para Windows e Android, pensado desde o inicio para rodar bem nos dois.", "placa_stack", None),
   ("Como foi feito", "Godot e GDScript no jogo, Blender para os modelos 3D, com preparo para publicar na Steam.", "placa_stack", None)
 ]},
 "buscavagas": {"loja": "Agencia de Empregos", "obj": "Uma agencia com murais de vagas e fichas.", "pieces": [
   ("A ideia", "BuscaVagas cruza o seu curriculo com vagas de desenvolvedor e coloca no topo aquelas em que voce tem chance real: combina com voce, tem poucos candidatos e foi publicada ha pouco.", "quadro", None),
   ("17 fontes", "Reune vagas de 17 fontes diferentes num lugar so, sempre atualizadas por uma fila de sincronizacao em segundo plano.", "telao", None),
   ("Nota de oportunidade", "Uma nota de match calculada com embeddings locais compara a sua experiencia com cada vaga, sem mandar seus dados para fora.", "relatorio", None),
   ("Tempo real", "Novas vagas e mudancas de status aparecem na hora, sem precisar recarregar a pagina.", "objeto", None),
   ("Desafio tecnico", "Padronizar vagas de 17 fontes com formatos diferentes e rankear por relevancia de forma rapida e barata.", "relatorio", None),
   ("Como foi feito", "Nuxt 3 e TypeScript no front, Fastify no back, PostgreSQL e Redis com filas BullMQ, embeddings da Hugging Face e Docker.", "placa_stack", None)
 ]},
 "orbix": {"loja": "Escritorio Orbix", "obj": "Um escritorio corporativo com servidores e paineis.", "pieces": [
   ("A plataforma", "OrbixHub e um SaaS multi-tenant onde varios produtos, como um CRM e uma gestao de oficinas, nascem sobre uma base comum.", "quadro", None),
   ("Isolamento por tenant", "Cada cliente fica isolado no proprio espaco usando Row-Level Security do Postgres, entao os dados de um nunca alcancam o do outro.", "relatorio", None),
   ("API central", "Uma orbix-api cuida de autenticacao, OTP, tokens e financas e serve todos os produtos, evitando reescrever o mesmo nucleo.", "objeto", None),
   ("Monorepo", "Backend em NestJS e apps em Flutter convivem num monorepo organizado, facil de evoluir em equipe.", "placa_stack", None),
   ("Desafio tecnico", "Servir produtos diferentes a partir de um nucleo so, mantendo seguranca, financas e isolamento de dados por cliente.", "relatorio", None),
   ("Como foi feito", "NestJS e Fastify no back, Flutter no mobile, PostgreSQL com RLS e Docker.", "placa_stack", None)
 ]},
 "formataai": {"loja": "Estudio de Voz", "obj": "Um estudio com microfones e telas de transcricao.", "pieces": [
   ("O app", "FormataAI transforma uma fala informal em e-mail, mensagem, orcamento ou receita prontos para usar. Foi o meu trabalho de conclusao de curso.", "quadro", None),
   ("Voz vira texto", "Voce grava a voz, o app transcreve com o Whisper e formata com o GPT-4o-mini, entregando um texto estruturado e limpo.", "telao", None),
   ("Pensado para incluir", "Feito para quem tem menos fluencia digital: em vez de digitar e formatar, a pessoa so fala e recebe o texto pronto.", "foto", None),
   ("Design de prompt", "O segredo esta no desenho dos prompts e na gestao de contexto, para a saida sair sempre no formato certo.", "relatorio", None),
   ("Como foi feito", "App em Flutter, backend Node com Prisma e PostgreSQL, OpenAI Whisper e GPT, armazenamento em AWS S3 e notificacoes push.", "placa_stack", None)
 ]},
 "labia": {"loja": "Beco dos Vigaristas", "obj": "Um beco com cartazes de golpes e cabines de escuta.", "pieces": [
   ("O jogo", "Labia e um jogo cooperativo de comedia para 1 a 4 jogadores. Voces sao vigaristas e aplicam golpes falando de verdade, pelo microfone, com personagens de IA.", "quadro", None),
   ("NPCs que ouvem", "Os personagens sao movidos por IA rodando localmente: eles entendem o que voce fala, se irritam, riem e podem chamar a seguranca.", "telao", None),
   ("Fale para enganar", "Nao tem menu de dialogo. O jogador convence na conversa, improvisando, enquanto os colegas ajudam nos bastidores.", "objeto", None),
   ("Cinco fases", "Cinco fases em primeira pessoa, cada uma com um golpe e um alvo diferente.", "objeto", None),
   ("Como foi feito", "Godot e GDScript, com IA local para a fala e a compreensao dos personagens, sem depender de nuvem.", "placa_stack", None)
 ]},
 "airmessage": {"loja": "Central de Mensagens", "obj": "Uma central telefonica com paineis de campanha.", "pieces": [
   ("O produto", "AirMessage e um SaaS de CRM e disparo multicanal por WhatsApp e SMS, feito para clinicas, estudios e oficinas.", "quadro", None),
   ("Campanhas e reengajamento", "Mensagens diretas, campanhas agendadas e reengajamento pos-venda, tudo organizado por cliente.", "telao", None),
   ("Um codigo, duas plataformas", "Um unico app em Flutter roda no Android e no Windows, com autenticacao em duas etapas por SMS e e-mail.", "objeto", None),
   ("Como foi feito", "Backend Node com Fastify, app Flutter, PostgreSQL, integracao com a API do WhatsApp, cobranca por assinatura e deploy em AWS.", "placa_stack", None)
 ]},
 "inaciocyber": {"loja": "Laboratorio Blackwall", "obj": "Um laboratorio escuro com terminais verdes e relatorios.", "pieces": [
   ("A ferramenta", "InacioCyber e um agente de seguranca que roda inteiro na sua maquina. Voce conversa num chat com estetica de terminal e define um alvo que voce possui ou tem autorizacao para testar.", "quadro", None),
   ("Agente que encadeia ferramentas", "Um modelo de IA local, via Ollama, decide e encadeia ferramentas de reconhecimento, varredura e auditoria de codigo, e no fim escreve um relatorio em markdown.", "telao", None),
   ("Tudo local", "Roda em containers Docker na sua maquina. Nada sai para fora, so as requisicoes que o proprio agente faz contra o alvo autorizado.", "relatorio", None),
   ("Uso responsavel", "Feito apenas para uso autorizado. Cada sessao exige uma confirmacao por escrito de que voce tem permissao para testar aquele alvo, e tudo fica auditado.", "placa_stack", None),
   ("App de verdade", "Tem app desktop proprio em Electron, chat em tempo real por WebSocket, historico de sessoes e barra de metricas de maquina.", "objeto", None),
   ("Como foi feito", "Python no agente e nas ferramentas, modelo local via Ollama, Docker para tudo, Postgres para auditoria e Electron no desktop.", "placa_stack", None)
 ]},
 "ankiana": {"loja": "Sala de Estudos", "obj": "Uma biblioteca silenciosa com fichas e lousas.", "pieces": [
   ("O app", "AnkiAna vira um tema, um texto ou um PDF em dezenas de flashcards com IA, para voce estudar sem montar os cartoes na mao.", "quadro", None),
   ("Repeticao espacada", "Usa repeticao espacada, o metodo SM-2, para mostrar cada cartao na hora certa de lembrar e fixar melhor o conteudo.", "telao", None),
   ("Interface moderna", "Visual Material 3 moderno e acessivel, pensado para estudar no celular com conforto.", "foto", None),
   ("Como foi feito", "App em Flutter com Dart, integracao com IA para gerar os cartoes e design Material 3.", "placa_stack", None)
 ]},
 "sitembm": {"loja": "Redacao MBM", "obj": "Uma redacao com bancas de jornal e paineis de analytics.", "pieces": [
   ("A plataforma", "MBM Site e uma plataforma de landing pages e blog institucional para uma empresa de telecom, com um painel administrativo completo.", "quadro", None),
   ("CMS proprio", "Um CMS feito do zero deixa a equipe criar e editar paginas e posts, com newsletter e analytics integrados.", "telao", None),
   ("SEO dinamico", "Cada pagina gera seu proprio SEO de forma dinamica, para ranquear melhor nas buscas.", "relatorio", None),
   ("Seguranca", "Login com JWT e duas etapas, papeis de acesso e upload de arquivos para a AWS S3.", "placa_stack", None),
   ("Como foi feito", "Nuxt 4 e Vue 3 no front, Node no back, PostgreSQL e armazenamento em AWS S3.", "placa_stack", None)
 ]}
}

os.makedirs(os.path.join(ROOT, "data", "museum"), exist_ok=True)
for pid, d in M.items():
    pieces = [{"titulo": t, "texto": x, "tipo": tp, **({"img": im} if im else {})} for (t, x, tp, im) in d["pieces"]]
    out = {"id": pid, "loja": d["loja"], "ambiente": d["obj"], "pieces": pieces}
    with open(os.path.join(ROOT, "data", "museum", pid + ".json"), "w", encoding="utf8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
print("museu:", len(M), "projetos,", sum(len(d["pieces"]) for d in M.values()), "pecas")
