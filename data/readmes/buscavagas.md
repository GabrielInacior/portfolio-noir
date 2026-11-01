<div align="center">

<img src="docs/assets/banner.svg" alt="BuscaVagas — vagas de dev onde você tem chance real" width="100%">

**Encontre vagas de dev em que você tem chance real.** O BuscaVagas cruza seu currículo com vagas de 17 fontes e coloca no topo o que combina com você, tem poucos candidatos e foi publicado há pouco tempo. O link da vaga original fica sempre visível.

![Node.js](https://img.shields.io/badge/Node.js-20-339933?logo=nodedotjs&logoColor=white)
![TypeScript](https://img.shields.io/badge/TypeScript-5-3178C6?logo=typescript&logoColor=white)
![Nuxt 3](https://img.shields.io/badge/Nuxt-3-00DC82?logo=nuxtdotjs&logoColor=white)
![Fastify](https://img.shields.io/badge/Fastify-API-000000?logo=fastify&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql&logoColor=white)
![Redis / BullMQ](https://img.shields.io/badge/Redis-BullMQ-DC382D?logo=redis&logoColor=white)
![Hugging Face](https://img.shields.io/badge/Hugging%20Face-embeddings%20locais-FFD21E?logo=huggingface&logoColor=black)
![Docker](https://img.shields.io/badge/Docker-compose-2496ED?logo=docker&logoColor=white)

[Como funciona](#-como-funciona) ·
[Início rápido](#-início-rápido) ·
[Comando `buscavagas`](#-jeito-mais-fácil-o-comando-buscavagas) ·
[Fontes](#-fontes-de-vagas) ·
[Ranking](#-como-a-nota-de-oportunidade-é-calculada) ·
[Configuração](#%EF%B8%8F-configuração) ·
[Testes](#-testes) ·
[Tempo real](#-sincronização-em-tempo-real) ·
[Limitações](#-limitações-e-roadmap)

<br>

<img src="docs/assets/screenshots/dashboard.png" alt="Painel de Oportunidades do BuscaVagas com vagas ranqueadas por chance real" width="100%">

<sub>Painel <b>Oportunidades</b> com dados reais: 17 fontes, ranking por match + pouca concorrência + vaga recente, e o link da vaga original em todo card.</sub>

</div>

---

## 💡 A ideia

Mandar currículo para uma vaga com 800 candidatos publicada há um mês rende pouco. O BuscaVagas ordena as vagas pelo que de fato aumenta suas chances:

| | Sinal | De onde vem |
|---|---|---|
| 🧩 | **Match com o seu currículo** | Embeddings locais (Hugging Face) + skills + senioridade; opcionalmente refinado por LLM |
| 👥 | **Pouca concorrência** | Nº de candidatos (LinkedIn, Trampos), alcance da fonte, idioma, porte da empresa |
| 🆕 | **Publicada há pouco tempo** | Data de publicação; vagas que somem da fonte são encerradas |
| 🌎 | **Você pode se candidatar** | Elegibilidade: vagas "US only", "must be based in EU" etc. vão para o fim da lista |

Tudo roda **na sua máquina**, de graça. A chave da OpenAI é **opcional**: sem ela o ranking funciona por completo com o modelo local. Com ela, só as melhores candidatas vão para o LLM. A candidatura assistida (bot que preenche o formulário) é um extra.

## 📸 Telas

<table>
  <tr>
    <td width="50%" valign="top">
      <img src="docs/assets/screenshots/dashboard-poucos-candidatos.png" alt="Atalho Poucos candidatos">
      <p align="center"><b>👥 Poucos candidatos</b><br><sub>Vagas do LinkedIn com o nº real de candidatos — aqui, todas com menos de 25 e match alto.</sub></p>
    </td>
    <td width="50%" valign="top">
      <img src="docs/assets/screenshots/vaga-detalhe.png" alt="Detalhe da vaga com o porquê da nota">
      <p align="center"><b>🔍 Por que essa oportunidade</b><br><sub>Match, concorrência com cada motivo (+/−), elegibilidade e "Abrir vaga original ↗".</sub></p>
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <img src="docs/assets/screenshots/busca.png" alt="Tela Busca com preferências">
      <p align="center"><b>🔎 Busca</b><br><sub>Palavras-chave (com sugestão a partir do perfil), exclusões, modalidade, níveis, agendamento e IA.</sub></p>
    </td>
    <td width="50%" valign="top">
      <img src="docs/assets/screenshots/fontes.png" alt="Tela Fontes com status de cada fonte">
      <p align="center"><b>🌐 Fontes</b><br><sub>17 fontes (BR primeiro), liga/desliga, vagas abertas e o resultado da última execução — ao vivo.</sub></p>
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <img src="docs/assets/screenshots/kanban.png" alt="Kanban de candidaturas">
      <p align="center"><b>📋 Kanban</b><br><sub>Arraste os cards entre colunas; o quadro sincroniza entre abas e janelas.</sub></p>
    </td>
    <td width="50%" valign="top" align="center">
      <img src="docs/assets/screenshots/mobile.png" alt="Versão mobile" width="62%">
      <p align="center"><b>📱 Celular</b><br><sub>Layout responsivo: o menu vira uma barra no topo.</sub></p>
    </td>
  </tr>
</table>

O painel **Oportunidades** tem atalhos prontos: 🎯 Melhores chances · 🆕 Últimas 48h · 🤫 Pouca concorrência · 👥 Poucos candidatos (LinkedIn) · 🧩 Maior match.

## ⚡ Sincronização em tempo real

<p align="center">
  <img src="docs/assets/screenshots/ao-vivo.gif" alt="Frontend sincronizado em tempo real: busca rodando no painel Atividade, toasts e uma vaga ocultada em outra janela sumindo na hora" width="90%">
</p>

<p align="center"><sub>Gravação real: uma vaga é ocultada em <i>outra janela</i> e some aqui na hora; ao clicar em <b>Buscar agora</b>, o painel <b>Atividade</b> mostra cada fonte rodando, o ranking progride e os toasts avisam das vagas novas — sem recarregar a página.</sub></p>

Tudo o que muda no sistema aparece em todas as abas abertas, sem recarregar: scrapes de cada fonte (início, fim, falha, intervalo mínimo), progresso do ranking, scores da IA, currículos gerados, scans de projetos, notificações enviadas — e qualquer alteração feita em outra aba (ocultar vaga, kanban, perfil, preferências, fontes, configurações).

**Sem lacunas, por construção:**

| Camada | Como garante |
|---|---|
| 🔢 **Sequência** | Todo evento recebe um `seq` crescente, gerado atomicamente no Redis (script Lua: `INCR` + buffer + `PUBLISH` numa operação só) — a ordem é a mesma para todos os clientes, mesmo com backend e worker publicando ao mesmo tempo. |
| ⚡ **WebSocket** | Canal principal (`/ws`), com checagem de origem e heartbeat (ping a cada 15 s; sem resposta em 8 s ⇒ reconecta). |
| 🔁 **Polling de reserva** | Se o WebSocket cair, o cliente busca **o mesmo fluxo** em `/sync/events?since=<último seq>` a cada 3 s enquanto reconecta. |
| 🧩 **Detecção de lacuna** | Se um `seq` pular, o cliente busca o intervalo que faltou; se ele não estiver mais no buffer (500 eventos), faz uma **ressincronização completa** — toda tela recarrega o que mostra. |
| 🛟 **Rede de segurança** | Catch-up a cada 30 s mesmo conectado, ao voltar para a aba e quando a internet volta. |
| ✍️ **Sem perder o que você digita** | Formulários (Perfil, Busca) com alterações não salvas mostram "alterado em outra aba — recarregar?" em vez de sobrescrever. |

O indicador **● Ao vivo** no topo da barra lateral mostra o estado da conexão (passe o mouse para ver o último evento; clique para forçar uma ressincronização). Tudo isso é coberto por testes de integração (Redis + WebSocket reais) e por um E2E com dois navegadores, incluindo **uma janela que fica offline enquanto a outra faz mudanças e precisa se atualizar sozinha ao voltar**.

```mermaid
sequenceDiagram
    participant W as worker / backend
    participant R as Redis (seq + buffer)
    participant B as backend /ws
    participant F as navegador
    W->>R: publishEvent (Lua: INCR seq, LPUSH, PUBLISH)
    R-->>B: evento #42
    B-->>F: frame {seq: 42}
    Note over F: seq 42 = último+1 → aplica (anima a lista, toast)
    F--xB: conexão cai
    F->>B: GET /sync/events?since=42 (polling)
    B-->>F: eventos 43..47 (ou gap → ressincroniza tudo)
```

---

## 🔄 Como funciona

```mermaid
flowchart LR
    A["🕸️ Scrape<br/>17 fontes"] --> B["🔁 Dedupe<br/>empresa + título"]
    B --> C["🤗 Embedding local<br/>multilingual-e5-small"]
    C --> D{"🌎 Elegível?<br/>dá pra aplicar do Brasil"}
    D --> E["👥 Concorrência<br/>0–100 + motivos"]
    E --> F["🧩 Match<br/>semântico + skills + senioridade"]
    F --> G["🎯 Oportunidade<br/>ordena o painel"]
    G -->|"só as melhores<br/>(opcional)"| H["🤖 LLM OpenAI<br/>gpt-4o-mini"]
    H -->|"match refinado"| G
    G --> I["📱 Telegram<br/>vagas novas boas"]
```

1. **Scrape**: o worker busca vagas nas fontes ativas, de forma educada (limite de páginas, atraso entre requisições, cooldown por fonte, detalhes só de vagas novas). Um agendador repete a busca sozinho (padrão: **a cada 6h**).
2. **Dedupe**: a mesma vaga publicada em várias fontes vira **um card só**, com "também em: …" e o link de cada fonte.
3. **Embedding local**: [`Xenova/multilingual-e5-small`](https://huggingface.co/Xenova/multilingual-e5-small) via `@huggingface/transformers` (ONNX na CPU, sem custo, cache no volume `hf-cache`). Ele compara o *headline* do seu perfil com título + stack de cada vaga. O modelo foi escolhido medindo em 600 vagas reais: **AUC 0,826**, contra 0,612 do MiniLM multilíngue.
4. **Elegibilidade**: `eligible` / `ineligible` / `unknown`, com o motivo escrito ("restrita a outro país ("us only")", "vaga brasileira", "não diz de quais países aceita").
5. **Concorrência**: nota de 0 a 100 (menor = menos gente disputando) com motivos legíveis.
6. **Match**: se a vaga já tem nota do LLM, ela é usada. Senão, vale o match semântico calibrado, misturado com a sobreposição de skills e ajustado pela senioridade.
7. **Oportunidade**: a ordenação padrão do painel. Só as vagas elegíveis com match local acima do limiar (padrão ≥ 45, até 120 por rodada) vão para o LLM.
8. **Encerramento**: vaga que não aparece na fonte há **7 dias**, ou cujo prazo de inscrição passou, é marcada como encerrada e sai do painel.

---

## 🚀 Início rápido

> Pré-requisito: Docker Desktop (ou Docker + Compose v2).

### ⚡ Jeito mais fácil: o comando `buscavagas`

Instale uma vez e depois ligue o projeto de **qualquer terminal** (cmd, PowerShell ou Git Bash), sem abrir editor nenhum:

```powershell
git clone https://github.com/GabrielInacior/BuscaVagas.git C:\Project\BuscaVagas
cd C:\Project\BuscaVagas
powershell -ExecutionPolicy Bypass -File scripts\install-command.ps1
```

Abra um **terminal novo** e rode:

```text
buscavagas
```

Ele faz tudo sozinho: liga o Docker Desktop se estiver desligado, cria o `.env` com segredos aleatórios na primeira vez, sobe os containers, espera o app ficar pronto e **abre o navegador** em <http://localhost:3000>.

| Comando | O que faz |
|---|---|
| `buscavagas` | Liga tudo e abre o navegador (o mesmo que `buscavagas start`) |
| `buscavagas stop` | Desliga os containers — seus dados ficam salvos |
| `buscavagas restart` | Reinicia os containers |
| `buscavagas status` | Mostra o que está rodando |
| `buscavagas logs` | Acompanha os logs (`buscavagas logs worker` para um serviço só; Ctrl+C sai) |
| `buscavagas update` | Baixa a versão nova do GitHub (`git pull`) e reconstrói as imagens |
| `buscavagas open` | Só abre o navegador |
| `buscavagas code` | Abre o projeto no VS Code |
| `buscavagas help` | Ajuda |

<details>
<summary>Detalhes: como funciona, desinstalar, macOS/Linux</summary>

- O instalador só adiciona a pasta `scripts\` do projeto ao **PATH do seu usuário** (sem admin). Rodar de novo não duplica. Para remover: `powershell -ExecutionPolicy Bypass -File scripts\install-command.ps1 -Uninstall`.
- `scripts\buscavagas.cmd` (cmd/PowerShell) chama `scripts\buscavagas.ps1`, onde fica a lógica. `scripts/buscavagas` é a versão bash: no Git Bash ela delega para o `.ps1`; no **macOS/Linux** roda nativa — adicione a pasta ao PATH (`export PATH="$PATH:/caminho/BuscaVagas/scripts"` no `~/.bashrc`/`~/.zshrc`).
- O start diário **não reconstrói** as imagens (leva ~30 s); elas só são construídas na primeira vez ou com `buscavagas update`.

</details>

### Passo a passo manual

**1. Configure o `.env`**

```bash
cp .env.example .env
```

Preencha pelo menos `ENCRYPTION_KEY` (32+ caracteres aleatórios) e `INTERNAL_API_TOKEN` (segredo compartilhado entre backend e worker). Para gerar um valor:

```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

Deixe `OPENAI_API_KEY` **vazio**: qualquer valor não vazio (até um placeholder) faz o worker enfileirar chamadas ao LLM que falham. Se quiser usar a OpenAI, cole a chave real depois, na tela de Configurações.

**2. Suba tudo**

```bash
docker compose up -d --build
```

As migrations do Prisma e o seed das 17 fontes **rodam sozinhos** toda vez que o backend sobe (os dois são idempotentes). Não precisa rodar nada à mão.

**3. Abra o app** → <http://localhost:3000>

**4. Perfil → "Enviar currículo" (PDF) → Oportunidades → "Buscar agora"**

O currículo vira o perfil usado no ranking e nos currículos adaptados. Reenviar substitui a versão atual. A primeira busca baixa o modelo do Hugging Face (uma vez só, fica em cache).

> 🔒 Todas as portas ficam presas a `127.0.0.1`: a API não tem login (é um app local de um usuário só), então nada na sua rede alcança o app nem o banco.

### Passos opcionais

<details>
<summary><b>🤖 Chave da OpenAI (refinar o match + currículo adaptado)</b></summary>

Abra <http://localhost:3000/settings> e cole sua chave. Gere uma nova em platform.openai.com/api-keys e **nunca reaproveite uma chave que já foi exposta em texto puro**. A chave fica criptografada no banco.

Com a chave salva:
- as melhores vagas recebem uma nota do LLM (modelo padrão `gpt-4o-mini`, configurável na tela **Busca**);
- dá para gerar **currículo + carta adaptados por vaga** em PDF (modelo padrão `gpt-4o`).

Sem a chave, o app funciona normalmente: o match vem só do modelo local.
</details>

<details>
<summary><b>💼 LinkedIn exportado em PDF</b></summary>

Em Perfil, envie também o export do LinkedIn ("Mais → Salvar como PDF" no seu perfil). Ele costuma ter descrições de experiência mais completas e vira material extra para a IA, sem precisar editar nada à mão.
</details>

<details>
<summary><b>📁 Projetos locais</b></summary>

Vá em **Projetos → "Escanear C:\Project"** e espere terminar. O worker escaneia o diretório montado em `PROJECTS_SCAN_ROOT` (`/scan-target`), que por padrão é `C:/Project` no host (somente leitura, ver `docker-compose.yml`). Os projetos entram no perfil e ajudam no currículo adaptado.
</details>

<details>
<summary><b>🐙 GitHub OAuth (escanear seus repositórios)</b></summary>

Conecte o GitHub em Configurações para escanear seus próprios repositórios (não-fork e não-arquivados) junto com os projetos locais. Isso exige registrar um OAuth App uma única vez:

1. github.com/settings/developers → **New OAuth App**
2. *Authorization callback URL*: `http://localhost:3001/auth/github/callback`
3. Coloque o Client ID/Secret em `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` no `.env` **antes** de subir os containers.

Sem isso configurado, o app funciona normalmente, só sem o scan do GitHub (a tela de Configurações mostra o passo a passo).
</details>

<details>
<summary><b>🔑 Sessões de login (plataformas com "Entrar com Google")</b></summary>

Se você entra numa plataforma de vagas via "Entrar com Google" (sem senha própria), usuário e senha na tela de **Credenciais** não funcionam. Nesse caso, capture uma sessão real de navegador. Há duas formas:

- **Um clique só (recomendado)**: rode uma vez, **no host** (fora do Docker), e deixe o terminal aberto:
  ```bash
  npm run local-agent --workspace=@buscavagas/worker
  ```
  Isso sobe um agente local só na sua máquina. A partir daí, clicar em **"Capturar sessão"** em Credenciais abre o navegador sozinho e salva a sessão automaticamente quando você termina de logar.
- **Manual**: sem o agente rodando, "Capturar sessão" abre a página de login numa aba e copia para o clipboard o comando equivalente. Cole no terminal, na raiz do projeto, fora do Docker:
  ```bash
  npm run login --workspace=@buscavagas/worker -- linkedin   # troque pela plataforma
  ```

Nos dois casos abre uma janela de navegador de verdade para você logar normalmente (inclusive com Google). A sessão fica salva criptografada e aparece em Credenciais.
</details>

<details>
<summary><b>✍️ Candidatura assistida (Greenhouse, Lever, Ashby)</b></summary>

Em vagas de Greenhouse, Lever ou Ashby, a página da vaga mostra o botão **"Aplicar com assistência"**. Com o agente local rodando (`npm run local-agent --workspace=@buscavagas/worker`, o mesmo de cima), ele abre uma janela de navegador de verdade na página real de candidatura e:

| ✅ Preenche | 🚫 Nunca toca |
|---|---|
| Nome, email, telefone, LinkedIn | Identificação demográfica (gênero, pronomes, raça/etnia, status de veterano, deficiência) |
| Currículo (upload) | Captcha |
| Perguntas de triagem **em texto livre**, respondidas por IA com base no seu perfil real | Perguntas em menu suspenso / múltipla escolha (ficam para você) |
| | **O botão final de enviar**: o bot para um passo antes, e você revisa e envia |

Vagas com site de carreira customizado (por exemplo, empresas que usam a API do Greenhouse mas têm um formulário próprio) são detectadas e marcadas como "não suportado", em vez de serem preenchidas errado. Código: `packages/worker/scripts/applyAssist.ts` (orquestrador) e `packages/worker/scripts/applyBots/` (um módulo por plataforma, com o DOM real de cada uma verificado ao vivo via Playwright).
</details>

<details>
<summary><b>📄 Documentos</b></summary>

Todo PDF que passa pelo app (currículo e LinkedIn enviados, currículo + carta gerados por vaga) fica listado e disponível para baixar em **Documentos**. Os PDFs gerados usam o bloco de contato editável do Perfil.
</details>

---

## 🌐 Fontes de vagas

17 fontes, todas **sem login**. Ative ou desative cada uma na tela **Fontes**.

| | Fonte | Tipo | O que traz de especial |
|:-:|---|---|---|
| 🇧🇷 | **Gupy** | Portal (API JSON) | Busca por palavra-chave, modalidade, senioridade, contrato, **prazo de inscrição** |
| 🇧🇷 | **LinkedIn** (guest) | Busca pública | **Nº de candidatos**, salário (quando informado), senioridade, modalidade |
| 🇧🇷 | **Remotar** | Board remoto (API JSON) | Salário, senioridade, prazo |
| 🇧🇷 | **Trampos** | Board (API JSON) | **Nº de candidatos**, salário, regime de contratação |
| 🇧🇷 | **Programathor** | Board (HTML) | **Porte da empresa**, salário, senioridade, contrato |
| 🇧🇷 | **GitHubVagas** | Issues do GitHub | `backend-br/vagas`, `frontendbr/vagas`, `react-brasil/vagas` (configurável); salário, CLT/PJ |
| 🇧🇷 | **InfoJobs** | Portal (HTML) | Salário, senioridade, contrato, prazo |
| 🇧🇷 | **Vagas.com.br** | Portal (HTML) | Salário, senioridade, contrato, prazo |
| 🇧🇷 | **Catho** | Portal (HTML) | Salário, senioridade, contrato |
| 🌍 | **RemoteOK** | Feed global | Vagas remotas internacionais |
| 🌍 | **Remotive** | Feed global | Vagas remotas internacionais |
| 🌍 | **WeWorkRemotely** | Feed global | Categoria de programação |
| 🌍 | **Greenhouse** | ATS por empresa | Site de carreiras direto (seed: Stripe, Databricks, Figma); **candidatura assistida** |
| 🌍 | **Lever** | ATS por empresa | Site de carreiras direto; **candidatura assistida** |
| 🌍 | **Ashby** | ATS por empresa | Site de carreiras direto (seed: Ramp, Linear, Vanta); **candidatura assistida** |
| 🌍 | **Workable** | ATS por empresa | Site de carreiras direto |
| 🌍 | **SmartRecruiters** | ATS por empresa | Site de carreiras direto |

> As empresas dos boards de ATS são configuráveis: edite `Source.config` no banco para trocar as empresas do seed por outras. O seed fica em `packages/db/prisma/seed.ts` e só adiciona fontes que ainda não existem.

---

## 🧮 Como a nota de oportunidade é calculada

Tudo é determinístico e explicável. O código está em [`packages/shared/src/ranking.ts`](packages/shared/src/ranking.ts).

### Concorrência (0–100, menor = melhor)

A nota parte de **50** e cada sinal soma ou subtrai pontos (o resultado fica entre 0 e 100):

| Sinal | Efeito |
|---|---|
| 👥 Candidatos: <10 / <25 / <50 / <100 / <200 / ≥200 | −30 / −20 / −10 / +5 / +20 / +35 |
| 🕐 Idade: ≤24h / ≤3d / ≤7d / ≤14d / ≤30d / >30d | −20 / −12 / −5 / +3 / +10 / +20 |
| 📣 Agregador global (RemoteOK, WWR, Remotive) | +15 |
| 📣 LinkedIn | +5 |
| 📣 Site de carreiras da empresa (ATS) | 0 |
| 📣 Board brasileiro de nicho (Programathor, Trampos, Remotar, GitHub) | −10 |
| 📣 Portal brasileiro (Gupy, InfoJobs, Catho, Vagas) | −3 |
| 🌍 Remota aberta ao mundo todo | +10 |
| 🇧🇷 Restrita a Brasil/LATAM ou em português | −8 |
| 🏢 Empresa pequena/média (quando a fonte informa) | −5 |
| 🔁 Publicada em ≥3 fontes | +5 |

O nº de candidatos **nunca é inventado**. Quando a fonte não informa, o motivo diz "fonte não informa nº de candidatos".

### Match (0–100)

- **Com nota do LLM**: usa a nota do LLM (marcada como "· IA" no card).
- **Sem LLM**: `0,65 × semântico calibrado + 0,35 × sobreposição de skills`, com penalidade de senioridade (−15 fora do que você busca, −25 lead/staff, −30 estágio). Se a vaga não cita nenhuma tecnologia detectável, o match fica limitado a 80 (só o título é evidência fraca). Títulos que não são de desenvolvimento (professor, vendas, recrutamento, suporte) perdem 40 pontos; funções adjacentes (QA, RPA, DevOps/SRE, segurança, dados/ML, produto) perdem 15. A sobreposição de skills é suavizada (uma única tecnologia em comum não conta como 100%).

> **Qualidade medida** nas 11 mil vagas reais (só com o modelo local): das vagas no seu stack, 88% têm match ≥ 70; de outros stacks, 15%; de outras áreas (dados/ML/infra), 3%. O cosseno do e5-small é calibrado para 0–100 pela distribuição medida nas vagas reais.

### Oportunidade

```text
frescor      = 100 (≤ 1 dia) → 0 (30 dias), linear
oportunidade = 0,60 · match + 0,25 · (100 − concorrência) + 0,15 · frescor

match < 40          → × 0,6
inelegível          → × 0,3
elegibilidade "?"   → × 0,9
```

### 🧪 Exemplo

Duas vagas com o **mesmo match (78)**:

| | 🅰️ LinkedIn, remota Brasil | 🅱️ RemoteOK, remota mundial |
|---|---|---|
| Candidatos | 18 → **−20** | não informado → 0 |
| Publicada | há 2 dias → **−12** | há 20 dias → **+10** |
| Fonte | LinkedIn → **+5** | agregador global → **+15** |
| Alcance | Brasil / português → **−8** | mundo todo → **+10** |
| **Concorrência** | 50 − 20 − 12 + 5 − 8 = **15** | 50 + 10 + 15 + 10 = **85** |
| **Frescor** | **97** | **34** |
| **Oportunidade** | 0,6·78 + 0,25·85 + 0,15·97 ≈ **83** 🟢 | 0,6·78 + 0,25·15 + 0,15·34 ≈ **56** 🟡 |

A vaga A vai para o topo, mesmo com o mesmo match: menos gente disputando e publicada há pouco.

---

## 🏗️ Arquitetura

```mermaid
flowchart TB
    user(["🧑‍💻 Você<br/>navegador"])
    subgraph host["Sua máquina (127.0.0.1)"]
        direction TB
        fe["🖼️ frontend<br/>Nuxt 3 · :3000"]
        be["⚙️ backend<br/>Fastify · :3001<br/>migrations + seed no boot"]
        wk["🛠️ worker<br/>BullMQ · scrape · rank<br/>score · tailor · scheduler"]
        pg[("🐘 postgres 16<br/>:5433")]
        rd[("🟥 redis 7<br/>:6379")]
        agent["🖥️ agente local (opcional)<br/>fora do Docker · Playwright"]
    end
    ext["🌐 17 fontes de vagas"]
    hf["🤗 Hugging Face<br/>download do modelo (1x)"]
    oa["🤖 OpenAI (opcional)"]
    tg["📱 Telegram (opcional)"]

    user --> fe --> be
    be --> pg
    be -->|filas| rd
    rd --> wk
    wk --> pg
    wk -->|"chave descriptografada<br/>(X-Internal-Token)"| be
    wk --> ext
    wk --> hf
    wk --> oa
    wk --> tg
    wk -->|"eventos (seq)"| rd
    rd -->|pub/sub| be
    be <-->|"⚡ WebSocket /ws<br/>+ /sync/events"| fe
    fe -.->|"capturar sessão /<br/>aplicar com assistência"| agent
```

| Serviço | Papel | Volumes |
|---|---|---|
| `postgres` | Vagas, perfil, preferências, candidaturas, segredos criptografados | `pgdata` |
| `redis` | Filas BullMQ (`scrape`, `rank`, `score`, `tailor`, scans, agendador) + barramento de eventos em tempo real (seq + buffer de 500) | – |
| `backend` | API REST (Fastify + Prisma), WebSocket `/ws` e `/sync/*`; aplica migrations e seed ao subir | `resume-data` |
| `worker` | Scrapers, embeddings, ranking, LLM, PDFs, agendador, Telegram | `resume-data`, `hf-cache`, `C:/Project` (ro) |
| `frontend` | Interface Nuxt 3 | – |

---

## ✨ Funcionalidades

- ⚡ **Tudo em tempo real**: WebSocket + sequência + polling de reserva — nenhuma tela fica desatualizada, entre abas e janelas
- ✨ **Interface animada**: cards entram/saem/reordenam com transição, vagas novas brilham, números contam, toasts, painel de Atividade ao vivo
- 🎯 **Ranking de oportunidade**: match + pouca concorrência + frescor, com motivos legíveis
- 🤗 **IA local e gratuita**: embeddings multilíngues (PT + EN) na CPU, sem chave
- 🤖 **LLM só onde vale a pena**: OpenAI opcional, só para as melhores candidatas (modelo e limites configuráveis)
- 🌐 **17 fontes**: 9 brasileiras + 8 internacionais
- 🌎 **Elegibilidade**: identifica vagas que não aceitam quem mora no Brasil
- 🔁 **Deduplicação entre fontes**: um card por vaga, com "também em: …"
- 🔗 **Link original sempre visível**: "Abrir vaga ↗" em todo card
- 🗓️ **Busca automática**: agendador configurável (padrão a cada 6h, respeitando o cooldown de cada fonte)
- 🧹 **Vagas encerradas somem**: 7 dias sem aparecer na fonte, ou prazo vencido
- ✕ **"Não tenho interesse"**: oculta a vaga (e as cópias dela em outras fontes)
- 📱 **Notificações no Telegram**: vagas novas acima do limiar de oportunidade
- 👤 **Perfil editável**: contato usado nos PDFs, *headline* para o match, skills
- 🔎 **Tela Busca**: palavras-chave (com sugestão a partir do perfil), exclusões, modalidade, localidades, senioridades, idade máxima, IA
- 📋 **Kanban** de candidaturas com arrastar-e-soltar (e remover do quadro)
- 📱 **Responsivo**: funciona no celular
- 🔌 **Fontes liga/desliga** na tela Fontes
- 📝 **Currículo + carta adaptados por vaga** em PDF (com OpenAI)
- ✍️ **Candidatura assistida** para Greenhouse, Lever e Ashby (para antes do envio)
- 📁 **Projetos locais e do GitHub** como material para o perfil
- 🔒 **Local e privado**: portas em `127.0.0.1`, segredos criptografados com `ENCRYPTION_KEY`
- 🧪 **Trava nos testes**: só rodam contra bancos `*_test`; CI no GitHub Actions

---

## ⚙️ Configuração

### Variáveis do `.env`

| Variável | Obrigatória | Descrição |
|---|:-:|---|
| `ENCRYPTION_KEY` | ✅ | 32+ caracteres aleatórios; criptografa chave da OpenAI, token do Telegram, sessões e credenciais |
| `INTERNAL_API_TOKEN` | ✅ | Segredo compartilhado: o worker o envia (`X-Internal-Token`) para ler segredos descriptografados do backend |
| `DATABASE_URL` | – | Já aponta para `postgres:5432` (rede interna do Docker) |
| `REDIS_URL` | – | Já aponta para `redis:6379` |
| `OPENAI_API_KEY` | – | Deixe o placeholder; cadastre a chave real em Configurações (este valor é só um fallback) |
| `FRONTEND_ORIGIN` | – | Única origem autorizada a chamar a API (padrão `http://localhost:3000`); também é o link nas notificações |
| `PROJECTS_SCAN_ROOT` | – | Diretório escaneado dentro do container (`/scan-target` → `C:/Project` no host) |
| `RESUME_OUTPUT_DIR` | – | Onde os PDFs ficam (`/data/resumes`, volume `resume-data`) |
| `BACKEND_PORT` / `FRONTEND_PORT` | – | `3001` / `3000` |
| `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` | – | OAuth App do GitHub (ver passos opcionais); em branco desliga o scan do GitHub |
| `AI_QUEUE_CONCURRENCY` | – | Chamadas simultâneas à OpenAI (padrão `3`; use `1` se receber muitos 429) |
| `EMBEDDING_MODEL` | – | Troca o modelo local (padrão `Xenova/multilingual-e5-small`) |
| `SCRAPE_CONCURRENCY` | – | Fontes raspadas em paralelo (padrão `4`) |
| `SCRAPE_POLITE_DELAY_MS` | – | Atraso entre requisições HTML (padrão `800`) |
| `GITHUB_TOKEN` | – | Token opcional para o limite de taxa da API ao ler as issues do GitHubVagas |

### 🔎 Preferências de busca (tela **Busca**)

| Grupo | Opção | Padrão |
|---|---|---|
| Palavras-chave | Termos enviados às fontes com busca (Gupy, LinkedIn, InfoJobs…) + botão "sugerir a partir do perfil" | `desenvolvedor full stack`, `desenvolvedor node`, `desenvolvedor vue`, `full stack developer` |
| | Termos a excluir (no título → inelegível) | – |
| Onde você tem chance | Modalidades aceitas | Remoto |
| | Localidades para híbrido/presencial | – |
| | Senioridades | Júnior, Pleno, Sênior |
| | Ignorar vagas com mais de N dias | 30 |
| Busca automática | Buscar sozinho a cada N horas (`0` desliga) | 6 |
| IA | Refinar as melhores com OpenAI | ligado (só tem efeito com chave) |
| | Modelo do score / modelo do currículo | `gpt-4o-mini` / `gpt-4o` |
| | Só enviar ao LLM vagas com match local ≥ N, no máximo M por rodada | 45 / 120 |

Mudar o perfil ou as preferências de busca recalcula o ranking de todas as vagas abertas.

### 📱 Notificações no Telegram

1. No Telegram, fale com **@BotFather**, mande `/newbot` e copie o token.
2. Em **Configurações → Notificações no Telegram**, cole o token e clique em **"Salvar token"** (fica criptografado).
3. Mande qualquer mensagem para o seu bot e clique em **"Descobrir chat"**.
4. Ative, ajuste a oportunidade mínima (padrão **70**) e clique em **"Testar"**.

A cada rodada chegam até 10 vagas novas, elegíveis, não ocultadas e acima do limiar. Vagas vistas antes de ativar as notificações nunca são enviadas, para não chegar um backlog inteiro de uma vez.

---

## 🧪 Testes

```bash
npm test   # unitários + integração de todos os pacotes
```

> ⚠️ **Os testes que tocam banco precisam de um banco separado do de desenvolvimento.** Vários `afterEach` fazem `deleteMany()` sem filtro em tabelas como `Profile`, `AppSetting` e `Source`. Rodar isso contra o banco `buscavagas` de verdade apaga seu perfil, sua chave da OpenAI e as fontes cadastradas (isso já aconteceu uma vez).
>
> Agora há uma **trava** (`test-support/dbGuard.js`, carregada pelo Jest): os testes **se recusam a rodar** se o nome do banco em `DATABASE_URL` não terminar em `_test`. Sem `DATABASE_URL` definida, eles usam `buscavagas_test` em `localhost:5433`.

Crie o banco de teste **uma vez**, com a stack no ar (`docker compose up -d postgres`):

```bash
docker compose exec postgres psql -U buscavagas -d buscavagas -c "CREATE DATABASE buscavagas_test;"
DATABASE_URL="postgresql://buscavagas:buscavagas@localhost:5433/buscavagas_test?schema=public" npx prisma migrate deploy
```

Depois exporte essa mesma `DATABASE_URL` (apontando para `buscavagas_test`, **não** `buscavagas`) antes de rodar os testes. A porta é **`5433`**, não `5432`: veja o comentário no `docker-compose.yml` sobre o conflito com o Postgres nativo do Windows.

**E2E (Playwright)**, contra a stack rodando em Docker:

```bash
npx playwright install --with-deps chromium   # só na primeira vez
npm run test:e2e --workspace=@buscavagas/frontend
```

O E2E não precisa de chave da OpenAI, porque o ranking roda com o modelo local. Ele precisa de vagas já buscadas no painel.

O CI no GitHub Actions fica em `.github/workflows/ci.yml`.

---

## 🗂️ Estrutura do projeto

```text
BuscaVagas/
├── docker-compose.yml          # postgres · redis · backend · worker · frontend
├── .env.example
├── test-support/dbGuard.js     # trava: testes só em banco *_test
├── docs/
│   ├── assets/                 # imagens do README
│   └── superpowers/specs/      # specs da Fase 1 e da Fase 2
└── packages/
    ├── shared/                 # tipos, zod, ranking.ts, preferences.ts (puro, testável)
    ├── db/                     # Prisma: schema, migrations, seed das 17 fontes
    ├── backend/                # Fastify: rotas jobs, profile, preferences, settings, scrapes,
    │                           #   applications, applyAttempts, documents, github, sessões…
    ├── worker/
    │   ├── src/adapters/       # 17 scrapers (+ httpFetch / politeFetch)
    │   ├── src/processors/     # scrape · rank · score · tailor · scheduler · scans
    │   ├── src/services/       # scrapeService, rankService, embeddings, notifications, IA, PDF
    │   └── scripts/            # localAgent, captura de login, applyAssist + applyBots/
    └── frontend/               # Nuxt 3: Oportunidades, Busca, Kanban, Fontes, Projetos,
                                #   Perfil, Documentos, Configurações, Credenciais
```

---

## 🧭 Limitações e roadmap

**Limitações conhecidas (sendo honesto):**

- ✍️ A candidatura assistida cobre **só Greenhouse, Lever e Ashby**. LinkedIn Easy Apply e os formulários de Gupy/Catho/InfoJobs ainda não têm bot.
- ☑️ Perguntas de triagem de **múltipla escolha / menu suspenso** ficam para você responder. Campos demográficos e captcha nunca são tocados, e o envio final é sempre seu.
- 🚦 O **LinkedIn guest** responde rajadas com HTTP 429. Quando isso acontece, o adapter para de consultar o LinkedIn naquela rodada e tenta de novo na próxima.
- 🛡️ **Catho, Vagas.com.br e InfoJobs** às vezes servem uma página anti-bot (Cloudflare). Quando aparece, a fonte é pausada naquela rodada.
- 👥 Só **LinkedIn** e **Trampos** informam nº de candidatos. Nas outras fontes, a concorrência é estimada pelos demais sinais.
- 🖥️ App local de um usuário só: sem login, sem deploy em nuvem.

**Próximos passos possíveis:**

- [ ] Bot de candidatura para LinkedIn Easy Apply e Gupy (as sessões de login já ficam salvas para isso)
- [ ] Mais empresas nos boards de ATS editáveis pela interface
- [x] Fontes brasileiras + LinkedIn
- [x] Ranking de oportunidade com IA local
- [x] Telegram, agendador, dedupe, encerramento de vagas

Specs completas: [Fase 1](docs/superpowers/specs/2026-08-24-motor-busca-vagas-fase1-design.md) · [Fase 2 — Motor de Oportunidades](docs/superpowers/specs/2026-11-01-buscavagas-fase2-oportunidades-design.md)

---

## 🤖 Para agentes de IA

Se você é um agente (Claude Code etc.) trabalhando neste repositório, comece pelo [`CLAUDE.md`](CLAUDE.md) e pelos guias em [`docs/agents/`](docs/agents/): convenções, como rodar os testes com segurança (banco `*_test`!) e as decisões do ranking.

<div align="center">

Feito no Brasil 🇧🇷 para quem está procurando a próxima vaga.

</div>
