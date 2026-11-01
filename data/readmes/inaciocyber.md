# InacioCyber

Agente de pentest autônomo, 100% local: você conversa num chat (estética terminal/hacker,
tema "Blackwall"), define um alvo que você possui ou tem autorização pra testar, confirma
por escrito que tem essa autorização, e um agente de IA (Qwen, rodando localmente via Ollama)
encadeia ferramentas reais — recon, enumeração, varredura de vulnerabilidades, exploração
ativa (SQLi/XSS/upload/CVEs conhecidas/credenciais fracas) e auditoria de repositórios de
código (segredos vazados/dependências vulneráveis/SAST) — terminando com um relatório em
markdown. Tudo roda em containers Docker na sua máquina; nada sai pra fora, exceto as próprias
requisições que o agente faz contra o alvo que você autorizar.

![status](https://img.shields.io/badge/uso-apenas%20autorizado-red)

## ⚠️ Leia antes de usar

Este agente executa **ataques reais** contra o alvo que você informar — incluindo tentativas
de exploração de SQL injection, XSS, upload de arquivo, exploits de CVEs conhecidas
(Metasploit) e força bruta de credenciais (Hydra). **Só use contra sistemas que você possui
ou tem autorização explícita, por escrito, para testar.** Testar sistemas de terceiros sem
autorização é crime na maioria das jurisdições.

Não existe allow-list técnica bloqueando alvos — por design, a única barreira é você digitar
uma frase de confirmação por sessão antes do agente agir. A responsabilidade de só confirmar
alvos que você está autorizado a testar é sua.

---

## Índice

- [O que tem aqui](#o-que-tem-aqui)
- [Requisitos](#requisitos)
- [Setup (primeira vez)](#setup-primeira-vez)
- [Uso no dia a dia](#uso-no-dia-a-dia)
- [Como usar o chat](#como-usar-o-chat)
- [Arquitetura](#arquitetura)
- [Ferramentas disponíveis](#ferramentas-disponíveis)
- [Personalização](#personalização)
- [Troubleshooting](#troubleshooting)

## O que tem aqui

- **Chat em tempo real** (WebSocket) com o agente, com histórico de sessões (estilo
  Claude/Claude Code) na lateral — crie, troque e exclua conversas.
- **Barra de métricas** sempre visível: CPU/RAM do host, CPU/RAM agregada dos containers
  Docker do projeto, GPU/VRAM (NVIDIA).
- **Barra de contexto**: quantos tokens da janela de contexto do modelo a conversa atual está
  usando.
- **App desktop de verdade** (Electron): janela sem moldura do Windows, botões próprios de
  minimizar/maximizar/fechar, cantos arredondados, ícone customizado.
- **Confirmação de autorização** por sessão antes de qualquer ferramenta real rodar.
- **Auditoria completa**: todo comando executado (ferramenta, argumentos, stdout/stderr
  completo) fica logado no Postgres.
- **Relatório de limitações**: um botão no chat pede pro agente avaliar onde ele esbarrou em
  limitações do próprio toolkit — útil pra saber o que adicionar depois.

## Requisitos

| Requisito | Pra quê |
|---|---|
| Windows 10/11 | Testado nesse ambiente |
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) com backend WSL2 | Roda todos os containers |
| [Node.js](https://nodejs.org/) (LTS) | Só pro wrapper desktop (Electron) |
| GPU NVIDIA (opcional, recomendado) | Acelera o modelo de IA e habilita métricas de GPU/VRAM |
| ~15GB de disco livre | Imagens Docker + modelo de IA (~9GB o `qwen2.5:14b`) |
| ~8–16GB de RAM livre | Depende do tamanho do modelo escolhido |

## Setup (primeira vez)

```powershell
git clone https://github.com/<seu-usuario>/InacioCyber.git
cd InacioCyber
copy .env.example .env
```

Abra o `.env` e ajuste pelo menos `POSTGRES_PASSWORD` (não deixe o valor de exemplo) e, se
quiser, `OLLAMA_MODEL` (veja a tabela de modelos nos comentários do próprio arquivo — o
padrão já é um bom equilíbrio pra GPUs com 16GB de VRAM).

Instale as dependências do app desktop (uma vez só):

```powershell
cd desktop
npm install
cd ..
```

Adicione `bin\` ao PATH do usuário (uma vez só), pra poder digitar `inaciocyber` de qualquer
terminal:

```powershell
[Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path","User") + ";$PWD\bin", "User")
```

Abra um terminal **novo** depois disso (o PATH só atualiza em sessões novas) e rode o build
completo — builda as imagens, sobe tudo, baixa o modelo de IA e abre o app:

```powershell
inaciocyber build
```

Na primeira vez isso demora bastante (build do toolbox com Kali + ferramentas, e o download
do modelo de IA, ~9GB por padrão) — acompanhe o progresso no próprio terminal.

## Uso no dia a dia

Depois do setup inicial, só isso:

```powershell
inaciocyber        # liga tudo e abre o app
inaciocyberoff      # desliga tudo (containers param, nada é apagado)
```

Outros comandos úteis:

```powershell
inaciocyber build [serviço]     # rebuilda (tudo, ou só um serviço: backend/frontend/toolbox)
inaciocyber compose <args...>   # passthrough pro "docker compose" (ex: inaciocyber compose logs -f backend)
```

## Como usar o chat

1. Abra o app — o chat já funciona livremente (sem ferramentas) pra você conversar com o
   Qwen, tirar dúvidas, etc.
2. No campo "target", digite o alvo: URL completa pra sites (`https://meusite.com`), host
   pra varredura de rede (`meuservidor.com`), ou URL de um repositório Git
   (`https://github.com/voce/projeto`) pra auditoria de código.
3. Copie a frase de confirmação exibida e cole de volta — isso autoriza o agente a agir
   contra esse alvo **nesta sessão**.
4. O agente começa sozinho: reconhecimento → enumeração → varredura de vulnerabilidades →
   exploração ativa (se fizer sentido) → relatório final em markdown.
5. Continue a conversa normalmente depois — "foca só no endpoint /api/login", "roda sqlmap
   com level 3 nesse parâmetro", "faz também uma auditoria de segredos no repositório X".
6. Use o botão **relatório de limitações** quando quiser uma auto-avaliação do agente sobre
   onde ele não conseguiu avançar e o que melhoraria o toolkit.
7. Use o painel lateral pra ver sessões anteriores, trocar de conversa, ou excluir (com
   confirmação) uma sessão que não precisa mais.

Todo comando real executado (ferramenta, argumentos, saída completa) fica em `tool_runs` no
Postgres. Pra inspecionar direto:

```powershell
docker exec -it inaciocyber-postgres-1 psql -U pentest -d pentest -c "select tool, command, exit_code, started_at from tool_runs order by started_at desc limit 20;"
```

## Arquitetura

```
┌─────────────┐   WebSocket/HTTP   ┌─────────────┐   HTTP   ┌─────────────┐
│  frontend   │ ─────────────────▶ │   backend   │ ───────▶ │   ollama    │  (Qwen local)
│ React+Vite  │                    │  FastAPI /  │          └─────────────┘
│  (:8080)    │                    │   agente    │
└─────────────┘                    │   (:8000)   │   HTTP   ┌─────────────┐
       ▲                           │             │ ───────▶ │   toolbox   │  (Kali + API)
       │ Electron (desktop/)       │             │          └─────────────┘
       │                           │             │
       └── janela nativa           └──────┬──────┘
                                           │
                                     ┌─────▼──────┐
                                     │  postgres  │  (histórico + auditoria)
                                     └────────────┘
```

- **toolbox**: container Kali com uma API FastAPI interna. Nenhum comando é montado como
  string de shell livre — cada endpoint valida/tipa os parâmetros antes de executar.
- **backend**: o agente em si (loop estilo ReAct) — manda o histórico + schemas das
  ferramentas pro Ollama, executa as tool calls que ele pedir no toolbox, registra tudo,
  repete até ter um relatório final (ou até `MAX_AGENT_ITERATIONS`).
- **ollama**: roda o modelo de IA localmente, com GPU se disponível.
- **postgres**: sessões, mensagens do chat, e log completo de cada execução de ferramenta.
- **desktop/**: wrapper Electron — janela sem moldura do Windows, carrega o mesmo app React
  servido pelo container `frontend`.

Limites de segurança/estabilidade configuráveis no `.env`: `TOOL_TIMEOUT_SECONDS` (timeout
por execução de ferramenta) e `MAX_AGENT_ITERATIONS` (limite de rodadas do agente por
execução). O system prompt do agente também proíbe explicitamente ações destrutivas (DoS,
backdoor persistente, `sqlmap --os-shell`/`--os-pwn`, etc.) — isso é uma instrução ao modelo,
não uma barreira técnica, então acompanhe o log de `tool_runs` nos primeiros usos.

## Ferramentas disponíveis

| Categoria | Ferramentas |
|---|---|
| Reconhecimento | nmap, whatweb, sslscan |
| Enumeração | gobuster, wpscan |
| Vulnerabilidades conhecidas | nikto, nuclei, metasploit (action `check`/`run`) |
| Exploração ativa | sqlmap (SQLi), xsser/ffuf (XSS), upload_test, http_request |
| Credenciais | hydra (força bruta), john (quebra de hash) |
| Auditoria de repositórios | gitleaks (segredos vazados), osv-scanner (deps vulneráveis), semgrep (SAST) |

Cada ferramenta tem parâmetros validados no `toolbox/app.py` e um schema correspondente em
`backend/app/tools.py` que o agente usa pra decidir quando chamar.

## Personalização

- **Trocar o modelo de IA**: mude `OLLAMA_MODEL` no `.env` (precisa suportar tool calling no
  Ollama, ex: família `qwen2.5`) e rode `inaciocyber build` de novo.
- **Adicionar uma ferramenta nova**: instale o binário no `toolbox/Dockerfile`, crie o
  endpoint em `toolbox/app.py` (com validação de parâmetros), e adicione o schema
  correspondente em `backend/app/tools.py` (`TOOL_SCHEMAS` + `ENDPOINTS`). Mencione a
  ferramenta no `SYSTEM_PROMPT` em `backend/app/agent.py` se quiser orientar quando usá-la.
- **Wordlists do gobuster/ffuf/hydra**: por padrão usa listas pequenas (`toolbox/payloads/`
  e `/usr/share/wordlists/dirb/`). Pra listas maiores, instale `seclists` no
  `toolbox/Dockerfile` e ajuste os caminhos.
- **Tema visual**: as cores ficam em `frontend/tailwind.config.js` (paleta `term.*`) — troque
  os valores hex pra mudar o tema sem precisar renomear classes.

## Troubleshooting

- **Ollama trava em "pulling manifest" com `Error: EOF`**: normalmente é estado de resume
  corrompido de um download anterior interrompido. Limpe os blobs parciais e baixe de novo:
  ```powershell
  docker exec inaciocyber-ollama-1 sh -c "rm -f /root/.ollama/models/blobs/*-partial*"
  docker exec inaciocyber-ollama-1 ollama pull <seu-modelo>
  ```
- **Agente nunca chama ferramentas / sempre só conversa**: confirme que `OLLAMA_MODEL`
  suporta tool calling no Ollama. Modelos muito pequenos ou sem suporte a function calling
  vão ignorar o campo `tools`.
- **sqlmap/nuclei/semgrep muito lentos**: aumente `TOOL_TIMEOUT_SECONDS` no `.env`.
- **nmap sem resultados de SYN scan**: confira se `cap_add: NET_RAW/NET_ADMIN` do serviço
  `toolbox` está ativo (`docker compose config` pra revisar).
- **Métricas de GPU mostrando "n/d"**: precisa do NVIDIA Container Toolkit configurado com
  Docker Desktop + WSL2. Teste com `docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi`;
  se não mostrar sua GPU, revise a instalação do toolkit ou comente o bloco `deploy:` dos
  serviços `ollama`/`backend` no `docker-compose.yml` pra rodar só em CPU.
- **Métricas de temperatura de CPU mostrando "n/d"**: esperado em Docker Desktop + WSL2 — o
  WSL2 geralmente não expõe os sensores de hardware do Windows pros containers. Não é um bug.
