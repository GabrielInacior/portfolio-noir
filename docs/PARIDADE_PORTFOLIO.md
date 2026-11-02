# Paridade com o portfólio antigo (inaciodev.com.br)

Fonte: `C:\Project\portfolio` (site de arquivo único `index.html` em Three.js, mais `assets/`).
Objetivo do usuário: "tudo que está no portfólio antigo precisa estar no novo, com as mesmas informações".

## 1. Inventário do portfólio antigo

**Seções:** carregador ("CARREGANDO CIDADE... 0%", "PORTFOLIO 3D INTERATIVO"), tela de entrada ("G. INÁCIO",
"Cyberpunk Portfolio • 3D Interactive City", "ENTRAR NA CIDADE", "Ative o volume para experiência completa"),
navegação (INÍCIO, SOBRE, STACK, PROJETOS, CONTATO, seletor PT/EN), player de música (play e pular),
aviso sem WebGL, toast "EMAIL COPIADO", indicador "▼ NAVEGUE PELA CIDADE" e coordenadas da câmera.

**Hero:** "// FULLSTACK DEVELOPER", "GABRIEL INÁCIO", "> Dev FullStack • +5 anos de experiência",
números 5+ Anos de XP, 10+ Tecnologias, ∞ Curiosidade, botão "↓ CURRÍCULO" (assets/docs/Resume_Gabriel.pdf).

**Sobre ("QUEM HABITA ESSA CIDADE", câmera CAM_01 REC, [ID: GABRIEL]):** três parágrafos (fullstack do
frontend pixel-perfect ao backend, código limpo e arquitetura inteligente com pentest em Kali Linux, "cada
prédio nessa cidade representa um pedaço do que sei construir").

**Stack ("MEU ARSENAL"), por grupo com descrição e link oficial de cada uma:** Frontend (React, Vue.js,
Next.js, Nuxt, TypeScript), Mobile (Flutter, React Native), Backend (Node.js, Spring, Prisma), Banco
(PostgreSQL, MongoDB, Redis), Cloud e Infra (AWS, Linux, Docker, Nginx), Segurança (Kali Linux).

**Projetos ("CONSTRUÇÕES DIGITAIS"), com status e tags:**
1. ATENDE360, PRODUÇÃO: site corporativo com GSAP, painel admin e IA gerando blogposts. Nuxt, GSAP, Node.js,
   Prisma, Express, PostgreSQL, IA. Ver site (atn360.com.br), privado.
2. BARBERCORE, EM DEV: CRM para barbearias (clientes, mensagens, financeiro, estoque, agendamentos).
   FastAPI, Node.js, PostgreSQL, Next.js. Privado.
3. FORMATAI: app mobile de transcrição e formatação inteligente. Flutter, OpenAI, Node.js, Prisma,
   PostgreSQL. GitHub.
4. ANKIANA: flashcards com IA inspirado no Anki. Flutter, IA. GitHub.

**Contato ("VAMOS CONSTRUIR?"):** "Tem um projeto em mente? Vamos dar vida a ele juntos.",
gabrielinaciodev47@gmail.com (clique copia), github.com/GabrielInacior, linkedin.com/in/gabriel-inácio.

**SEO:** título "Gabriel Inácio — Dev FullStack | Vue, React, Node.js, Flutter", descrição, palavras-chave,
OG e Twitter com a foto, JSON-LD Person/ProfilePage/WebSite/BreadcrumbList, versão EN completa.

**Assets:** foto (assets/img/foto_teste.png, 1024x1272), currículo PDF, 7 músicas, skybox, cena GLB.

## 2. O que faltava ou divergia no novo, e o que foi feito

| Item do antigo | Situação no novo | Feito nesta frente |
|---|---|---|
| Números do hero (anos, tecnologias, curiosidade) | não existiam | `profile.stats` (ver divergência abaixo) |
| Os 3 parágrafos do "Sobre" com a frase da cidade e Kali Linux | bio diferente | `profile.about_city` |
| Grupo Mobile (Flutter, React Native) | ausente nas skills | grupo "Mobile" criado |
| Next.js, TypeScript, Linux, Kali Linux, Spring | faltavam ou só como variante | adicionados |
| Descrição e site oficial de cada tecnologia | não existia | `profile.tech_info` + `tech_groups_old` |
| CTA de contato e toast de e-mail copiado | texto diferente | `profile.contact` |
| Projeto BarberCore | só citado na experiência | projeto `barbercore` criado (privado, em desenvolvimento) |
| Atende 360 com status PRODUÇÃO e link do site | estava como "MBM Site" (site-mbm.vercel.app) | título, descrição, stack, link atn360.com.br, status, capa e 3 imagens |
| Status por projeto (produção, em dev) | não existia | campo `status` nos projetos citados |
| Descrições curtas antigas de FormataAI e AnkiAna | textos novos mais longos | `desc_old` guardado |
| LinkedIn com o caminho completo | link sem acento | link igual ao antigo + versão curta |
| Experiências do currículo antigo (Plug4Sales, SistemasBr) e skills de design | ausentes | adicionadas (experiência e grupo "Design") |
| Palavras-chave de SEO | ausentes | `profile.meta_keywords` |
| Foto | já existe (game/assets/foto_gabriel.png e web/assets/foto.jpg) | nada |

**Divergência para o usuário decidir:** o site antigo diz "+5 anos" no hero e no SEO, mas a versão PT do
dicionário dizia "+3 anos" e o currículo/LinkedIn indicam cerca de 4 anos (desde 2022). Usei "4+" e anotei.

**Não trazido (de propósito):**
- Currículo PDF: tem telefone e endereço. Não entra no repositório público. Para ter o botão "Currículo",
  é preciso um PDF sem esses dados (posso gerar um a partir do profile.json, se o usuário quiser).
- 7 músicas do site antigo: o novo usa a trilha própria "Bloodlines like 3"; não sei se as antigas são dele.
- Skybox, cena GLB e ícones Simple Icons (CDN de terceiros): substituídos pela arte própria do jogo.

## 3. Onde cada coisa deve aparecer (para as frentes donas)

**Frente de UI/UX + navegação (hud.gd, ui.gd, painéis, menus, telas de entrada):**
- Painel CONTATO: título "VAMOS CONSTRUIR?", subtítulo de `profile.contact`, e-mail com clique que copia
  e toast "E-mail copiado", GitHub e LinkedIn (`links.linkedin_short` como texto). Botão "Currículo" só
  quando `profile.resume.available` for verdadeiro.
- Tela de entrada/carregamento: "Ative o volume para experiência completa" e o hero_tag "// FULLSTACK DEVELOPER".
- Menu de lugares e painéis de projeto: mostrar `status` (PRODUÇÃO, EM DEV, PRIVADO) como selo, como no antigo.
- Painel "Sobre mim" (LAB): os 3 parágrafos de `profile.about_city` e os números de `profile.stats`.

**Frente de cenário (city.gd, museum*.gd, outdoors, data/museum, SEO):**
- LAB: parede "MEU ARSENAL" agrupada como `tech_groups_old` (Frontend, Mobile, Backend, Banco de dados,
  Cloud e infra, Segurança), cada placa abrindo descrição e site oficial de `tech_info`; incluir o grupo Design.
- Outdoor/telão na praça com os números de `profile.stats` (4+ anos, 40+ tecnologias, ∞ curiosidade).
- Nova loja ou vitrine para BarberCore (privado, em desenvolvimento) e peças de museu para ela.
- Atende 360: migrar o id `sitembm` para `atende360` (data/museum, colagem, letreiro, slug /projetos/atende360/
  com 301 do antigo na vercel.json); capa já em game/assets/covers/atende360.jpg e prints em data/captures/atn360/.
- CARREIRA: incluir Plug4Sales (estágio em marketing digital, React/Vite) e SistemasBr (SDR) como portas menores.
- SEO: acrescentar `profile.meta_keywords`, o título com "Vue, React, Node.js, Flutter" e a página do BarberCore.

**Traduções:** `game/assets/data/i18n/en.json` está com mudanças não commitadas da frente de UI; depois que ela
commitar, rodar `python tools/i18n/build_i18n.py` para traduzir os textos novos (o dicionário EN antigo tem as
versões em inglês de hero, sobre, contato e projetos, que podem ser usadas como referência).
