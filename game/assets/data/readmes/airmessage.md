# AirMessage

Plataforma SaaS multi-canal de CRM e disparo de mensagens para **pequenas empresas de serviços** (clínicas, estúdios, oficinas, pet shops, etc.).

Permite mensagens diretas, campanhas recorrentes/agendadas e reengajamento automático pós-venda via **WhatsApp** e **SMS**, com cobrança de mensalidade via Mercado Pago.

---

## Índice

- [Visão geral](#visão-geral)
- [Estrutura do repositório](#estrutura-do-repositório)
- [Backend](#backend)
  - [Stack](#stack-backend)
  - [Variáveis de ambiente](#variáveis-de-ambiente)
  - [Banco de dados e migrations](#banco-de-dados-e-migrations)
  - [Rodar localmente](#rodar-localmente)
  - [Testes](#testes)
  - [Swagger / OpenAPI](#swagger--openapi)
  - [Logging — Betterstack](#logging--betterstack)
- [Frontend (Flutter)](#frontend-flutter)
  - [Stack](#stack-flutter)
  - [Features](#features)
  - [Rodar localmente](#rodar-localmente-1)
- [Infraestrutura e Deploy](#infraestrutura-e-deploy)
  - [AWS EC2](#aws-ec2)
  - [GitHub Actions](#github-actions)
  - [Deploy remoto — script idempotente](#deploy-remoto--script-idempotente)
- [SaaS / Billing](#saas--billing)
- [Anti-ban](#anti-ban)
- [Segurança](#segurança)

---

## Visão geral

| Item | Detalhe |
|---|---|
| Plano | `pro_monthly` — R$ 39,90/mês |
| Trial | 7 dias grátis |
| Grace period | 3 dias após vencimento |
| Canais | WhatsApp (WPPConnect) + SMS (AWS SNS) |
| Backend | Node.js 20 + Fastify 4 — porta `4002` |
| Frontend | Flutter 3.x — Desktop Windows + Android |
| Banco | PostgreSQL 16 (mesmo host que o backend em prod) |
| Pagamentos | Mercado Pago Preapproval (assinatura recorrente) |
| Infra | AWS EC2 t3.micro (us-east-2) — Ubuntu 24.04 |

---

## Estrutura do repositório

```
AirMessage/
├── .github/
│   ├── copilot-instructions.md        ← instruções globais do Copilot
│   ├── instructions/                  ← instruções por domínio (applyTo)
│   └── workflows/
│       └── deploy.yml                 ← CI/CD completo (quality + deploy)
├── .vscode/
│   ├── launch.json
│   ├── tasks.json
│   └── settings.json
├── airmessage-backend/                ← API REST Node.js
│   ├── app.ts / index.ts
│   ├── migrations/                    ← 13 SQL idempotentes
│   ├── scripts/
│   │   ├── migrate.ts
│   │   ├── seed.ts
│   │   └── deploy_remote.sh           ← bootstrap idempotente no EC2
│   └── src/
│       ├── db.ts                      ← pg.Pool singleton + query<T>()
│       ├── logger.ts                  ← Pino singleton (pretty dev / JSON prod)
│       ├── routes.ts                  ← registro declarativo via route()
│       ├── controllers/               ← 12 handlers Fastify
│       ├── repositories/              ← SQL puro (sempre recebem userId)
│       ├── services/
│       │   ├── campaign-runner.ts     ← scheduler tick 60s
│       │   ├── dispatch.service.ts    ← WhatsApp + SMS unificado
│       │   ├── wppconnect.service.ts
│       │   ├── sms.service.ts         ← AWS SNS (lazy import)
│       │   ├── mercadopago.service.ts ← Preapproval REST direto
│       │   ├── billing.service.ts     ← gate logic (trial/grace/status)
│       │   └── storage.service.ts     ← S3 presigned URLs
│       ├── middleware/
│       │   ├── auth.ts                ← Bearer JWT
│       │   └── subscription.ts        ← requireActiveSubscription (402)
│       └── __tests__/                 ← 88 testes Vitest
├── airmessage-flutter/                ← App Flutter
│   └── lib/
│       ├── main.dart
│       ├── core/                      ← theme, router, http client
│       └── features/                  ← auth, dashboard, clients, ...
├── docs/
│   ├── 2026-04-13-airmessage-design.md
│   ├── 2026-04-13-airmessage-backend.md
│   └── 2026-04-13-airmessage-flutter.md
└── AirMessageKey.pem                  ← chave SSH EC2 (gitignored)
```

---

## Backend

### Stack backend

| Tecnologia | Uso |
|---|---|
| Node.js 20 ESM | runtime |
| TypeScript NodeNext via `tsx` | compilação/watch |
| Fastify 4 | framework HTTP |
| `pg` (Pool) | PostgreSQL sem ORM |
| zod | validação de entrada |
| jsonwebtoken | JWT manual (access 15min + refresh 7d cookie) |
| bcryptjs | hash de senhas |
| WPPConnect | sessões WhatsApp multi-usuário |
| @aws-sdk/client-sns | envio de SMS |
| @aws-sdk/client-s3 | upload de mídia/logo |
| Pino + @logtail/pino | logging estruturado + Betterstack |
| Vitest | testes unitários e de integração |

### Variáveis de ambiente

Copie `.env.example` para `.env` e preencha:

```ini
# Banco
DATABASE_URL=postgresql://user:pass@localhost:5432/airmessage_db

# Servidor
PORT=4002
NODE_ENV=development
LOG_LEVEL=info
CORS_ORIGIN=http://localhost:3000

# JWT
JWT_SECRET=<min 32 chars>

# SMS (AWS SNS)
SMS_PROVIDER=aws_sns          # ou mock para dev
AWS_REGION=us-east-2
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
SMS_SENDER_ID=AirMsg

# S3 (mídia opcional)
S3_BUCKET_NAME=
S3_REGION=us-east-2
S3_PUBLIC_BASE_URL=           # CDN opcional

# Mercado Pago
MP_ACCESS_TOKEN=
MP_WEBHOOK_SECRET=
DEFAULT_PLAN_ID=pro_monthly
BILLING_BACK_URL=https://seudominio.com/billing/return
BILLING_GRACE_DAYS=3
FREE_TRIAL_DAYS=7

# Swagger Basic Auth
SWAGGER_USER=
SWAGGER_PASSWORD=

# SMTP (2FA por e-mail)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=
SMTP_PASS=

# Logging remoto (opcional)
BETTERSTACK_SOURCE_TOKEN=     # https://logs.betterstack.com
```

### Banco de dados e migrations

13 migrations SQL idempotentes em `migrations/`:

| # | Descrição |
|---|---|
| 001 | users |
| 002 | companies |
| 003 | clients |
| 004 | message_templates |
| 005 | services |
| 006 | expenses |
| 007 | sales |
| 008 | scheduled_messages |
| 009 | message_campaigns |
| 010 | message_logs |
| 011 | anti_ban + SMS (send_tracker, channel) |
| 012 | subscriptions + subscription_plans |
| 013 | company_users, roles, 2FA, onboarding |

Todas usam `IF NOT EXISTS` / `ADD COLUMN IF NOT EXISTS` — seguras para reexecutar.

### Rodar localmente

```powershell
cd airmessage-backend
npm install
npm run migrate      # aplica migrations pendentes
npm run dev          # tsx watch — porta 4002
```

Outros comandos:

```powershell
npm run seed         # cria usuário/empresa de teste
npm test             # vitest run (88 testes)
npm run test:watch   # modo interativo
npm run test:coverage
npx tsc --noEmit     # typecheck
```

### Testes

- **88 testes** — 100% passando
- Arquivos em `src/__tests__/`:
  - `auth.test.ts` — registro, login, refresh, 2FA
  - `billing.service.test.ts` — lógica de trial/grace/gate
  - `subscription.middleware.test.ts` — HTTP 402 em send endpoints
  - `interpolate.test.ts` — substituição de variáveis em templates
  - `routes.integration.test.ts` — 70 testes de integração via `app.inject()`
- Cobertura gerada com `@vitest/coverage-v8` (JSON summary para CI)

### Swagger / OpenAPI

Disponível em `http://localhost:4002/docs` protegido por Basic Auth (`SWAGGER_USER` / `SWAGGER_PASSWORD`).

- Spec JSON em `/docs/json`
- Todas as rotas autenticadas têm o header `Authorization: Bearer` documentado
- Rotas gated (`requireActiveSubscription`) retornam `402` documentado

### Logging — Betterstack

O backend usa **Pino** como logger (o mais rápido do ecossistema Node.js):

- **Desenvolvimento**: saída colorizada via `pino-pretty`
- **Produção**: JSON para `stdout` (capturado pelo `journalctl`) + stream opcional para [Betterstack Logtail](https://logs.betterstack.com)

Para ativar o Betterstack:
1. Crie uma conta em https://logs.betterstack.com
2. Vá em **Sources → Connect source → Node.js**
3. Copie o **Source token**
4. Adicione `BETTERSTACK_SOURCE_TOKEN=seu_token` no `.env` de produção

Ver logs em produção sem Betterstack:
```bash
sudo journalctl -u airmessage-backend -f
```

---

## Frontend (Flutter)

### Stack Flutter

| Tecnologia | Uso |
|---|---|
| Flutter 3.x | framework UI |
| Dart 3 | linguagem |
| flutter_riverpod | gerenciamento de estado |
| go_router | navegação declarativa |
| Dio | cliente HTTP |
| flutter_secure_storage | armazenamento seguro de tokens |
| fl_chart | gráficos (dashboard) |
| flutter_local_notifications | notificações locais |

### Features

| Feature | Módulo |
|---|---|
| Login / Registro / 2FA | `features/auth/` |
| Dashboard com métricas | `features/dashboard/` |
| Clientes (CRM) | `features/clients/` |
| Templates de mensagem | `features/templates/` |
| Campanhas | `features/messaging/` |
| Mensagens agendadas | `features/messaging/` |
| Serviços | `features/services/` |
| Vendas | `features/sales/` |
| Despesas | `features/expenses/` |
| Configurações + WhatsApp QR | `features/settings/` |
| Onboarding empresa | `features/company/` |
| Billing / Assinatura | `features/billing/` |

### Rodar localmente

```bash
cd airmessage-flutter
flutter pub get
flutter run -d windows     # Desktop Windows
flutter run -d <device-id> # Android (emulador ou físico)
```

Testes:
```bash
flutter test
flutter analyze --no-fatal-infos --no-fatal-warnings
```

---

## Infraestrutura e Deploy

### AWS EC2

| Item | Valor |
|---|---|
| Instância | `AirMessage` — t3.micro |
| Region | us-east-2 (Ohio) |
| IP Elástico | `18.190.244.143` |
| OS | Ubuntu 24.04 LTS |
| User | `ubuntu` |
| App dir | `/home/ubuntu/apps/airmessage-backend` |
| Serviço | `airmessage-backend` (systemd) |
| SSH key | `AirMessageKey.pem` (raiz do repo, **gitignored**) |

Conectar manualmente:
```powershell
# Ajustar permissões no Windows (necessário uma vez)
icacls .\AirMessageKey.pem /inheritance:r /grant:r "${env:USERNAME}:R"

ssh -i AirMessageKey.pem ubuntu@18.190.244.143
```

Ver logs em prod:
```bash
sudo journalctl -u airmessage-backend -f --since "1 hour ago"
sudo systemctl status airmessage-backend
```

### GitHub Actions

Workflow em `.github/workflows/deploy.yml` — **Platform CI/CD**:

**Triggers**: PR/push em `main`/`master` + `workflow_dispatch`  
**Concurrency**: cancela runs anteriores do mesmo branch automaticamente

```
┌─────────────────────────────────────────────────────┐
│                     changes                          │
│  (dorny/paths-filter — detecta o que mudou)          │
└───────────────┬─────────────────┬───────────────────┘
                │                 │
     ┌──────────▼───────┐  ┌──────▼──────────┐
     │  backend-quality │  │ frontend-quality │
     │  npm ci          │  │ flutter pub get  │
     │  npm test ✅ gate │  │ flutter test ✅  │
     │  test:coverage 📊 │  │ flutter analyze  │
     │  tsc --noEmit ✅  │  └─────────────────┘
     │  artifact upload  │
     └──────────┬────────┘
                │ (só em push, não em PR)
     ┌──────────▼────────┐
     │  deploy-backend   │
     │  tar + scp        │
     │  inject .env      │
     │  deploy_remote.sh │
     │  healthcheck curl │
     └───────────────────┘
```

**Secrets necessários no GitHub** (`Settings → Secrets → Actions`):

| Secret | Conteúdo |
|---|---|
| `EC2_SSH_PRIVATE_KEY` | Conteúdo completo do `AirMessageKey.pem` |
| `BACKEND_ENV_FILE` | Conteúdo completo do `.env` de produção |

### Deploy remoto — script idempotente

`airmessage-backend/scripts/deploy_remote.sh` executa no EC2 a cada deploy:

1. **`ensure_postgres()`** — instala PostgreSQL se ausente; lê `DATABASE_URL` do `.env` e cria role + banco automaticamente
2. **`ensure_node()`** — instala Node.js 20 via NodeSource se ausente ou versão errada
3. **`ensure_system_service()`** — cria unit systemd, faz `daemon-reload` e `enable` se ainda não existir
4. **Main** — `npm ci` → `npm run migrate` → `systemctl restart`

O script é seguro para reexecutar — cada função verifica o estado antes de agir.

---

## SaaS / Billing

- **Provedor**: Mercado Pago — Preapproval (assinatura recorrente)
- **Plano único**: `pro_monthly` — R$ 39,90/mês
- **Trial automático**: 7 dias a partir do `users.created_at` (sem necessidade de cartão)
- **Grace period**: 3 dias após `current_period_end` antes de bloquear envios

Estados de assinatura (`billing.service.ts`):

| Estado | `can_send` | Descrição |
|---|---|---|
| `active` | ✅ | Assinatura ativa e em dia |
| `trial` | ✅ | Dentro do período de trial |
| `grace_period` | ✅ | Pagamento vencido, dentro do grace |
| `pending_payment` | ❌ | Aguardando pagamento |
| `paused` | ❌ | Assinatura pausada pelo usuário |
| `cancelled` | ❌ | Assinatura cancelada |
| `expired` | ❌ | Grace period esgotado |
| `no_subscription` | ❌ | Nunca assinou |

O gate `requireActiveSubscription` aplica **HTTP 402** apenas nos endpoints de envio e no scheduler. O painel (CRM, relatórios) permanece sempre acessível.

Endpoints:
- `GET /billing/plans` — lista planos disponíveis
- `GET /billing/me` — status atual da assinatura
- `POST /billing/subscribe` — cria preapproval, retorna `init_point` para redirect
- `POST /billing/cancel` — cancela assinatura
- `POST /billing/webhook/mercadopago` — webhook público com verificação HMAC-SHA256

---

## Anti-ban

Para WhatsApp, o sistema implementa limites de warmup inspirados no BarberCore:

| Dias de uso | Limite diário |
|---|---|
| 0 (primeiro dia) | 50 mensagens |
| 1 dia | 100 mensagens |
| ≥ 2 dias | 200 mensagens |

Mecanismos:
- **Delay anti-ban**: 5–10s aleatório entre mensagens (modo seguro) ou 1.5s (modo `risky_mode`)
- **Lock atômico de campanha**: `UPDATE … WHERE locked_at IS NULL RETURNING` — evita double-processing
- **`clearStaleLocks(30min)`**: libera locks travados por crash a cada tick do scheduler
- **Tracker diário**: tabela `message_send_tracker (user_id, channel, send_date, messages_sent)` com UPSERT

---

## Segurança

- Senhas com `bcryptjs` (hash + salt)
- JWT: access token 15min via `Authorization: Bearer`; refresh token 7d em cookie `httpOnly`
- 2FA com TOTP (`otplib`) — setup, enable, disable e verificação no login
- Webhook Mercado Pago com verificação de assinatura HMAC-SHA256
- Helmet, CORS restrito por origem, rate-limit global (100 req/min)
- `.env` nunca commitado (listado no `.gitignore`)
- `AirMessageKey.pem` nunca commitado (`.gitignore` raiz com `*.pem`)
- SQL via placeholders `$1, $2, ...` — sem interpolação de string (previne SQL injection)
- Todos os endpoints do painel isolados por `userId` como tenant key
