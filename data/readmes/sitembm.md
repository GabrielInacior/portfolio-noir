# 🚀 MBM Site - Sistema Completo de Blog e Landing Pages

Sistema moderno e escalável para a MBM, empresa líder em soluções de telecomunicações e atendimento ao cliente no Brasil. Desenvolvido com **Nuxt 4**, **Vue 3**, **TypeScript** e **Nuxt UI**, integrado com backend Node.js + PostgreSQL.

## 📋 Índice

- [Sobre o Projeto](#sobre-o-projeto)
- [Funcionalidades](#funcionalidades)
- [Tecnologias](#tecnologias)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Setup e Instalação](#setup-e-instalação)
- [Variáveis de Ambiente](#variáveis-de-ambiente)
- [Scripts Disponíveis](#scripts-disponíveis)
- [Desenvolvimento](#desenvolvimento)
- [Deploy](#deploy)
- [Documentação Adicional](#documentação-adicional)

## 🎯 Sobre o Projeto

O **MBM Site** é uma plataforma completa que combina:

### 🌐 Frontend (Nuxt 4)
- **Landing Pages** institucionais e de produtos
- **Blog** profissional com sistema de categorias, tags e busca
- **CMS Admin** completo para gerenciamento de conteúdo
- **Sistema de Newsletter** integrado
- **Analytics** e tracking de eventos
- **SEO** otimizado com meta tags dinâmicas

### ⚙️ Backend (Node.js + Express)
- **API RESTful** completa
- **Autenticação JWT** com 2FA (TOTP)
- **Sistema de roles** (SUPER_ADMIN, ADMIN, EDITOR, AUTHOR)
- **Gerenciamento de posts** com revisões e versionamento
- **Upload de imagens** para AWS S3
- **Analytics detalhado** com eventos customizados
- **Auditoria completa** de ações

## ✨ Funcionalidades

### 📝 Blog
- ✅ Editor de posts rico (TipTap) com suporte a markdown e HTML
- ✅ **Geração de conteúdo com IA** (Google Gemini AI)
- ✅ Categorias e tags
- ✅ Posts em destaque
- ✅ Busca avançada
- ✅ Posts relacionados
- ✅ Sistema de comentários (planejado)
- ✅ Table of Contents automático
- ✅ Tempo de leitura calculado
- ✅ SEO otimizado por post
- ✅ Imagens responsivas e otimizadas

### 🎨 Landing Pages
- ✅ Gestão de Telefonia VoIP
- ✅ Gestão de WhatsApp Business
- ✅ Páginas institucionais customizadas
- ✅ Animações avançadas (GSAP + AOS)
- ✅ Formulários de contato
- ✅ Integração com Newsletter

### 👥 CMS Admin
- ✅ Dashboard com estatísticas
- ✅ Gerenciamento de posts (criar, editar, deletar)
- ✅ Editor fullscreen
- ✅ **IA integrada para geração de conteúdo**
- ✅ Preview de posts
- ✅ Publicação e agendamento
- ✅ Gerenciamento de categorias e tags
- ✅ Gerenciamento de usuários
- ✅ Analytics em tempo real
- ✅ Logs de auditoria

### 🤖 Inteligência Artificial
- ✅ **Geração automática de posts** com Google Gemini AI
- ✅ Prompts otimizados para conteúdo MBM
- ✅ Suporte a diferentes tons (formal, casual, técnico, inspirador)
- ✅ Tamanhos configuráveis (curto, médio, longo)
- ✅ Geração de metadados SEO automáticos
- ✅ Melhoria de conteúdo existente

### 🔐 Autenticação e Segurança
- ✅ Login com email/senha
- ✅ 2FA com Google Authenticator
- ✅ Refresh tokens seguros
- ✅ Rate limiting
- ✅ CORS configurado
- ✅ Helmet para security headers
- ✅ Input validation completa

## 🛠️ Tecnologias

### Frontend
- **Framework**: Nuxt 4.1.3 (Vue 3.5.22)
- **UI Library**: Nuxt UI 4 (componentes prontos)
- **Styling**: Tailwind CSS 4
- **Animações**: GSAP, AOS (Animate On Scroll)
- **Editor**: TipTap (rich text editor)
- **State**: Pinia 2.x
- **HTTP Client**: Axios
- **Icons**: Iconify (mdi, ph collections)
- **AI**: Google Gemini API (@google/genai)

### Backend
- **Runtime**: Node.js 20 LTS
- **Framework**: Express.js 4.x
- **Language**: TypeScript 5.x
- **Database**: PostgreSQL 15+
- **ORM**: Prisma 5.x
- **Auth**: JWT + bcrypt + speakeasy (2FA)
- **Storage**: AWS S3
- **Logs**: Winston

### DevOps
- **Package Manager**: npm
- **Linting**: ESLint 9.x
- **Type Checking**: TypeScript strict mode
- **Version Control**: Git

## 📁 Estrutura do Projeto

```
siteMbm/
├── siteMbm/                    # Frontend (Nuxt)
│   ├── app/
│   │   ├── components/
│   │   │   ├── Admin/         # Componentes do CMS
│   │   │   │   ├── AIGenerateModal.vue    # Modal de IA
│   │   │   │   ├── PostEditor.vue         # Editor TipTap
│   │   │   │   └── ...
│   │   │   ├── Blog/          # Componentes do Blog
│   │   │   └── ...
│   │   ├── composables/       # Composables Vue
│   │   │   ├── useGeminiAI.ts # Integração com Gemini AI
│   │   │   └── ...
│   │   ├── layouts/           # Layouts
│   │   ├── pages/             # Páginas
│   │   │   ├── Admin/         # CMS Admin
│   │   │   ├── Blog/          # Blog público
│   │   │   └── LandingPages/  # Landing pages
│   │   ├── stores/            # Pinia stores
│   │   ├── middleware/        # Middlewares
│   │   └── plugins/           # Plugins
│   ├── assets/
│   │   ├── css/               # Estilos globais
│   │   └── img/               # Imagens
│   ├── public/                # Assets estáticos
│   ├── nuxt.config.ts         # Configuração Nuxt
│   ├── tailwind.config.ts     # Configuração Tailwind
│   └── package.json
│
├── mbm-backend/               # Backend (Node.js)
│   ├── src/
│   │   ├── controllers/       # Controllers
│   │   │   ├── ai.controller.ts      # Controller de IA
│   │   │   └── ...
│   │   ├── routes/            # Rotas da API
│   │   ├── middleware/        # Middlewares
│   │   ├── services/          # Serviços
│   │   ├── utils/             # Utilitários
│   │   └── server.ts          # Entry point
│   ├── prisma/
│   │   ├── schema.prisma      # Schema do banco
│   │   └── migrations/        # Migrations
│   ├── .env                   # Variáveis de ambiente
│   └── package.json
│
└── docs/                      # Documentação
    ├── README.md              # Docs do backend
    ├── GEMINI_AI_INTEGRATION.md  # Docs da IA
    └── ...
```

## 🚀 Setup e Instalação

### Pré-requisitos

- **Node.js** 20 LTS ou superior
- **PostgreSQL** 15+
- **npm** ou **yarn**
- **Git**
- Conta na **AWS** (para S3)
- Conta no **Google AI Studio** (para Gemini API)

### 1. Clonar o Repositório

```bash
git clone https://github.com/GabrielInacior/SiteMbm.git
cd siteMbm
```

### 2. Instalar Dependências

#### Frontend
```bash
cd siteMbm
npm install
```

#### Backend
```bash
cd ../mbm-backend
npm install
```

### 3. Configurar PostgreSQL

**Opção 1: Docker (recomendado)**
```bash
docker run --name mbm-postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=mbm_blog \
  -p 5432:5432 \
  -d postgres:15
```

**Opção 2: PostgreSQL Local**
```sql
CREATE DATABASE mbm_blog;
```

### 4. Configurar Variáveis de Ambiente

#### Backend (.env)
```bash
cd mbm-backend
cp .env.example .env
```

Edite o arquivo `.env` com suas configurações (ver seção [Variáveis de Ambiente](#variáveis-de-ambiente)).

#### Frontend (.env)
```bash
cd siteMbm
```

Crie arquivo `.env`:
```env
# API Backend
NUXT_PUBLIC_API_URL=http://localhost:3001/api

# Google Gemini AI (opcional - para geração de conteúdo)
# Obtenha em: https://makersuite.google.com/app/apikey
GEMINI_API_KEY=sua_chave_aqui
```

### 5. Rodar Migrations do Banco

```bash
cd mbm-backend
npm run prisma:migrate
```

### 6. (Opcional) Popular Banco com Dados de Teste

```bash
npm run prisma:seed
```

### 7. Obter API Key do Google Gemini (Opcional)

Para usar a geração de conteúdo com IA:

1. Acesse https://makersuite.google.com/app/apikey
2. Crie uma nova API key (gratuita)
3. Adicione no `.env` do backend:
```env
GEMINI_API_KEY=sua_chave_aqui
```

### 8. Configurar AWS S3 (Opcional)

Para upload de imagens:

1. Crie um bucket S3 na AWS
2. Configure as credenciais no `.env`:
```env
AWS_ACCESS_KEY_ID=sua_key
AWS_SECRET_ACCESS_KEY=seu_secret
AWS_S3_BUCKET=nome_do_bucket
AWS_REGION=us-east-1
```

## 🔐 Variáveis de Ambiente

### Backend (.env)

```env
# Ambiente
NODE_ENV=development
PORT=3001

# Database
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/mbm_blog

# JWT
JWT_ACCESS_SECRET=your-super-secret-key-min-32-chars
JWT_REFRESH_SECRET=your-refresh-secret-key-min-32-chars
JWT_ACCESS_EXPIRATION=15m
JWT_REFRESH_EXPIRATION=7d

# AWS S3 (Opcional)
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
AWS_S3_BUCKET=mbm-blog-images
AWS_REGION=us-east-1

# Google Gemini AI (Opcional)
GEMINI_API_KEY=your_gemini_api_key

# CORS
FRONTEND_URL=http://localhost:3000

# Rate Limiting
RATE_LIMIT_MAX=100
RATE_LIMIT_WINDOW_MS=900000
```

### Frontend (.env)

```env
# API Backend URL
NUXT_PUBLIC_API_URL=http://localhost:3001/api

# Site Info (para SEO)
NUXT_PUBLIC_SITE_NAME=MBM
NUXT_PUBLIC_SITE_URL=https://atn360.com.br
```

## 📜 Scripts Disponíveis

### Frontend (siteMbm/)

```bash
# Desenvolvimento
npm run dev              # Inicia em http://localhost:3000

# Build
npm run build           # Build para produção
npm run generate        # Gera site estático (SSG)
npm run preview         # Preview da build

# Linting
npm run lint            # Verifica código
npm run lint:fix        # Corrige automaticamente

# Type Checking
npm run typecheck       # Verifica tipos TypeScript
```

### Backend (mbm-backend/)

```bash
# Desenvolvimento
npm run dev             # Inicia em http://localhost:3001

# Build
npm run build          # Compila TypeScript
npm start              # Produção (requer build)

# Prisma
npm run prisma:generate # Gera Prisma Client
npm run prisma:migrate  # Cria migrations
npm run prisma:deploy   # Deploy migrations (produção)
npm run prisma:studio   # UI visual do banco
npm run prisma:seed     # Popula dados iniciais

# Linting
npm run lint           # Verifica código
npm run lint:fix       # Corrige automaticamente
```

## 💻 Desenvolvimento

### Iniciar Ambiente de Desenvolvimento

**Terminal 1 - Backend:**
```bash
cd mbm-backend
npm run dev
```

**Terminal 2 - Frontend:**
```bash
cd siteMbm
npm run dev
```

Acesse:
- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:3001/api
- **Prisma Studio**: `npm run prisma:studio` (http://localhost:5555)

### Criar Primeiro Usuário Admin

Após popular o banco (`npm run prisma:seed`), use:
- Email: `admin@atn360.com.br`
- Senha: `Admin@123456`

Ou crie via Prisma Studio.

### Usando o Gerador de IA

1. Certifique-se que `GEMINI_API_KEY` está configurada
2. Acesse o Admin: http://localhost:3000/atende-core/posts
3. Crie ou edite um post
4. Clique em "✨ Gerar com IA"
5. Descreva o que quer gerar
6. Escolha tom e tamanho
7. Clique em "Gerar Conteúdo"

Exemplos de prompts:
- "Artigo sobre benefícios da telefonia VoIP para empresas"
- "Guia completo de WhatsApp Business API"
- "5 tendências em atendimento ao cliente para 2025"

## 🚢 Deploy

### Frontend (Vercel - Recomendado)

```bash
# Instalar Vercel CLI
npm i -g vercel

# Deploy
cd siteMbm
vercel
```

### Backend (AWS EC2 / Railway / Render)

Ver documentação detalhada em `docs/README.md`.

**Build para produção:**
```bash
cd mbm-backend
npm run build
npm start
```

### Variáveis de Ambiente em Produção

Certifique-se de configurar todas as variáveis em seu provedor:
- `NODE_ENV=production`
- `DATABASE_URL` (PostgreSQL de produção)
- `JWT_ACCESS_SECRET` e `JWT_REFRESH_SECRET` (únicos e seguros)
- `AWS_*` (credenciais S3)
- `GEMINI_API_KEY` (se usar IA)
- `FRONTEND_URL` (URL do frontend em produção)

## 📚 Documentação Adicional

- **Backend**: [`docs/README.md`](./docs/README.md)
- **Integração Gemini AI**: [`docs/GEMINI_AI_INTEGRATION.md`](./docs/GEMINI_AI_INTEGRATION.md)
- **GitHub Copilot Instructions**: [`.github/copilot-instructions.md`](./.github/copilot-instructions.md)

## 🎨 Design System

O projeto segue o **design system MBM** com cores e componentes padronizados:

### Cores Principais
- **Azul MBM**: `#0991cc` (`bg-mbm-500`)
- **Cyan Gradiente**: `#05c3de` (`bg-gradient-left-500`)
- **Azul Gradiente**: `#028fb7` (`bg-gradient-right-500`)

### Componentes Nuxt UI (128+ disponíveis)
- Dashboard, Blog, Forms, Data, Navigation, Overlays, etc.
- Todos começam com `U` (ex: `UButton`, `UCard`, `UModal`)

### Animações
- **GSAP**: Para animações complexas e interativas
- **AOS**: Para revelar elementos ao rolar a página
- **Transitions Vue**: Para mostrar/ocultar elementos

## 🧪 Testes

```bash
# Frontend
cd siteMbm
npm run test              # Rodar testes
npm run test:coverage     # Com coverage

# Backend
cd mbm-backend
npm test                  # Rodar testes
npm run test:coverage     # Com coverage
```

## 🤝 Contribuindo

1. Fork o projeto
2. Crie uma branch (`git checkout -b feature/NovaFuncionalidade`)
3. Commit suas mudanças (`git commit -m 'Adiciona nova funcionalidade'`)
4. Push para a branch (`git push origin feature/NovaFuncionalidade`)
5. Abra um Pull Request

### Convenção de Commits

```bash
feat: adiciona geração de IA no editor
fix: corrige bug de autenticação
refactor: reorganiza estrutura de pastas
style: atualiza cores do tema
docs: atualiza README
test: adiciona testes para postStore
chore: atualiza dependências
```

## 📄 Licença

MIT © 2025 MBM

## 📞 Suporte

- **Email**: suporte@atn360.com.br
- **Website**: https://atn360.com.br
- **GitHub Issues**: https://github.com/GabrielInacior/SiteMbm/issues

## 🙏 Agradecimentos

- **Nuxt Team** pelo framework incrível
- **Nuxt UI** pelos componentes prontos
- **Google** pela API Gemini gratuita
- **Vercel** pelo hosting frontend
- Toda a equipe MBM! 🚀

---

**Desenvolvido com ❤️ pela equipe MBM**
