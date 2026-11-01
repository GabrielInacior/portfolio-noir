# FormataAI

> Aplicativo móvel de formatação de texto por voz com inteligência artificial, desenvolvido como Trabalho de Conclusão de Curso (TCC).

---

## Demonstração

<!-- ▼ ADICIONE O LINK DO VÍDEO AQUI ▼ -->

> https://github.com/user-attachments/assets/245c52c1-b264-469d-b281-bc5e85547d2c


>
> O vídeo percorre o fluxo completo: gravação de áudio → transcrição pelo Whisper → formatação pelo GPT-4o-mini → compartilhamento do resultado.

<!-- ▲ ————————————————————————— ▲ -->



---

## Sobre o Projeto

O **FormataAI** resolve um problema cotidiano de comunicação: transformar falas informais e desorganizadas em textos profissionais e prontos para uso. O usuário grava sua voz diretamente no aplicativo e recebe, em segundos, um documento formatado — seja um e-mail, mensagem de WhatsApp, orçamento, receita ou outro formato.

O servidor **não realiza processamento de IA internamente**. Sua função é orquestrar chamadas a serviços externos especializados: a API **Whisper** (OpenAI) realiza a transcrição do áudio, e o modelo **GPT-4o-mini** (OpenAI) interpreta a intenção do usuário e retorna o texto devidamente formatado para uso imediato.

### Problema que resolve

Pessoas com menor fluência digital, maior faixa etária ou rotinas intensas têm dificuldade em redigir mensagens formais e estruturadas. O FormataAI elimina essa barreira: basta falar.

---

## Funcionalidades

- Gravação de áudio diretamente no aplicativo
- Transcrição automática de voz para texto (Whisper — português com suporte a sotaques e ruídos)
- Formatação inteligente por IA com identificação de intenção e categoria
- Formatos suportados: WhatsApp, E-mail, Documento, Orçamento, Receita, Currículo, Post Social, Lista, Outro
- Reprocessamento da mesma transcrição em formatos diferentes
- Histórico de conversas com busca, favoritos e arquivamento
- Compartilhamento do texto gerado com outros aplicativos
- Autenticação via e-mail/senha ou Google OAuth 2.0
- Alternância de tema claro/escuro global e persistente
- Sistema de cotas de uso por plano (Gratuito / Premium)

---

## Arquitetura

```
┌─────────────────────────────────────────────────────────┐
│                    Cliente Flutter                       │
│         (Gravação · Histórico · Compartilhamento)        │
└───────────────────────┬─────────────────────────────────┘
                        │ HTTPS / JSON
                        ▼
┌─────────────────────────────────────────────────────────┐
│              Nginx (Reverse Proxy + SSL)                 │
└───────────────────────┬─────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│           Servidor Node.js — Express.js v5               │
│                                                          │
│  AuthMiddleware → UploadMiddleware → Controller          │
│                                                          │
│   ┌──────────┐  ┌──────────────┐  ┌─────────────────┐  │
│   │   Auth   │  │      IA      │  │    Usuários     │  │
│   │Controller│  │  Controller  │  │   Controller    │  │
│   └──────────┘  └──────┬───────┘  └─────────────────┘  │
│                         │                                │
│              ┌──────────▼──────────┐                    │
│              │    IaRepository     │                     │
│              │  (Prisma ORM)       │                     │
│              └──────────┬──────────┘                    │
└─────────────────────────┼───────────────────────────────┘
                          │
          ┌───────────────┼────────────────┐
          ▼               ▼                ▼
   ┌────────────┐  ┌────────────┐  ┌────────────┐
   │ PostgreSQL │  │  OpenAI    │  │   AWS S3   │
   │    (DB)    │  │Whisper+GPT │  │  (Áudios)  │
   └────────────┘  └────────────┘  └────────────┘
```

O diagrama de classes completo com fluxo de dados está disponível em [`diagrama-classes-backend.md`](./diagrama-classes-backend.md).

### Figura 1 — Diagrama de Classes e Fluxo de Dados do Backend

<!-- ▼ ADICIONE A IMAGEM DO DIAGRAMA AQUI ▼ -->
<!-- Arraste a imagem para este arquivo no editor do GitHub, ou use o caminho relativo: -->
<!-- ![Diagrama de Classes e Fluxo de Dados do Backend – FormataAI](./assets/diagrama-classes.png) -->

><img width="1536" height="1024" alt="DiagramaFormataAI" src="https://github.com/user-attachments/assets/ab398784-8142-410d-9645-178aa6440905" />


<!-- ▲ ————————————————————————————————— ▲ -->

---

## Stack Tecnológico

### Backend

| Camada | Tecnologia |
|---|---|
| Runtime | Node.js 22 + TypeScript |
| Framework | Express.js v5 |
| ORM | Prisma 7 |
| Banco de dados | PostgreSQL 16 |
| IA — Transcrição | OpenAI Whisper-1 |
| IA — Formatação | OpenAI GPT-4o-mini |
| Armazenamento | AWS S3 |
| Autenticação | JWT + Google OAuth 2.0 |
| Infraestrutura | Docker + docker-compose |
| Gateway | Nginx + Let's Encrypt |
| Agendamento | node-cron |
| Testes | Vitest |

### Frontend

| Camada | Tecnologia |
|---|---|
| Framework | Flutter (Dart) |
| Gerência de estado | MobX |
| HTTP Client | Dio |
| Áudio | flutter_sound |
| Armazenamento local | shared_preferences |
| Tema | Claro / Escuro (persistente) |

---

## Estrutura do Repositório

```
FormataAI/
├── FormataAIBackend/          # API REST — Node.js + TypeScript
│   ├── src/
│   │   ├── core/              # Servidor, roteador, logger, S3, cron
│   │   ├── database/          # Prisma client
│   │   ├── middlewares/       # Auth, upload, erro, logging
│   │   └── modules/
│   │       ├── auth/          # Cadastro, login, Google OAuth
│   │       ├── ia/            # Processamento de áudio e IA (core)
│   │       └── usuarios/      # Perfil e estatísticas
│   ├── prisma/
│   │   └── schema.prisma      # Modelos do banco de dados
│   ├── Dockerfile
│   └── docker-compose.yml
│
└── FormataAIFrontEnd/         # App móvel — Flutter
    └── lib/
        ├── core/              # Constants, stores globais, tema
        ├── features/
        │   ├── auth/          # Login, cadastro
        │   ├── conversas/     # Tela principal, histórico, gravação
        │   └── perfil/        # Configurações, tema
        └── main.dart
```

---

## Como Executar

### Pré-requisitos

- Docker e docker-compose instalados
- Flutter SDK instalado
- Chaves de API: OpenAI, AWS S3, Google OAuth

### Backend

```bash
cd FormataAIBackend

# Copie e preencha as variáveis de ambiente
cp .env.example .env

# Suba os containers (app, banco, nginx)
docker-compose up -d

# Execute as migrations do banco
docker exec -it formataai-app npx prisma migrate deploy
```

### Frontend

```bash
cd FormataAIFrontEnd

# Instale as dependências
flutter pub get

# Aponte para o backend no arquivo de constantes
# lib/core/constants.dart → baseUrl

# Execute o app
flutter run
```

---

## Endpoints da API

| Método | Rota | Descrição |
|---|---|---|
| POST | `/api/auth/registrar` | Cadastro com e-mail/senha |
| POST | `/api/auth/login` | Login com e-mail/senha |
| POST | `/api/auth/google` | Login com Google OAuth |
| POST | `/api/ia/processar` | **Transcrever áudio + formatar com IA** |
| POST | `/api/ia/reprocessar` | Reformatar em outro estilo |
| GET | `/api/ia/conversas` | Listar histórico (paginado) |
| GET | `/api/ia/conversas/:id` | Buscar conversa com mensagens |
| DELETE | `/api/ia/conversas/:id` | Deletar conversa |
| GET | `/api/usuarios/buscar-perfil` | Perfil do usuário |
| GET | `/api/usuarios/estatisticas` | Cotas de uso |
| GET | `/health` | Health check |

---

## Modelos do Banco de Dados

```
Usuario ──────< Conversa ──────< Mensagem
    └──────────< RefreshToken
```

- **Usuario** — dados de conta, provedor (email/Google), plano e cotas
- **Conversa** — agrupamento de mensagens por tema, com categoria e flags
- **Mensagem** — par usuário/assistente com áudio (S3), transcrição e resposta formatada
- **RefreshToken** — sessões de longa duração

---

## Validação com Usuários

O FormataAI foi avaliado por quatro usuários reais com perfil de faixa etária mais elevada e menor familiaridade com ferramentas digitais — exatamente o público-alvo da solução. Por consenso, os participantes relataram que o aplicativo contribui positivamente para o cotidiano, especialmente ao possibilitar a síntese de conversas em textos objetivos e ao agilizar tarefas comunicativas rotineiras.

---

## Contexto Acadêmico

Este projeto foi desenvolvido como **Trabalho de Conclusão de Curso (TCC)** e documenta a concepção, arquitetura, implementação e validação de um sistema de produtividade baseado em inteligência artificial aplicada ao processamento de linguagem natural por voz.

---

## Autor

**Gabriel Inácio**
GitHub: [@GabrielInacior](https://github.com/GabrielInacior)
