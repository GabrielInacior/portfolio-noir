# Contexto e decisões do usuário (Gabriel)

Tudo que o Gabriel pediu e decidiu para este portfólio, na ordem em que foi pedido. Leia antes de mexer
em qualquer frente. Quem continuar o trabalho numa sessão nova começa por aqui, pelo `CLAUDE.md` e por
`docs/PROXIMOS_PASSOS.md`.

## Quem é o usuário e como ele trabalha
- Gabriel Inácio (GitHub `GabrielInacior`), fala português. Autor do RUMOR (`C:\Project\detetive`),
  do FortressChaos (`C:\Project\game`), BuscaVagas, OrbixHub, FormataAI, InacioCyber e outros.
- Quer ver o progresso em **imagens a cada marco** (capturas mudas), como no RUMOR.
- Régua muito alta: "capriche", "me impressione", "só pare quando o resultado for caprichoso e
  deslumbrante". Avaliação honesta sempre; nunca dizer que está bom quando a imagem não mostra.
- Pode usar todas as ferramentas, tempo e subagentes. Commits regulares com push estão autorizados.
- Texto ao jogador sem travessão "—" e sem termos de dev.

## Visão do portfólio
- Portfólio web como **jogo 3D em primeira pessoa**: cidade noir noturna adulta, clima de Vampire:
  The Masquerade Bloodlines, tons escuros, **muitos neons** (ele adora neon), chuva, asfalto molhado,
  céu noturno chamativo, sombras e clima de iluminação. Estilo **pincelado**, mais trabalhado que o
  RUMOR.
- Desktop e celular de primeira (PC: WASD + mouse; celular: alavanca + arrastar para olhar + tocar
  no letreiro para ir até lá). **Performance é prioridade**: pode ir ao nível mais baixo necessário
  (ver `docs/PERFORMANCE.md`).
- **Cidade viva**: figurantes, carros com faróis, vapor de bueiro, neon falhando, janelas acendendo,
  boa iluminação (quente e fria, neon tingindo paredes, névoa, feixes, glow no PC).
- **Bairro com esquinas** (não rua reta), mapinha legível, prédios ao fundo.
- **Cada projeto é uma LOJA-MUSEU** cheia de objetos, quadros e coisas usadas. Objetos 3D com
  interação ([E] / toque) abrem um modal contando a história. É dentro da loja que a história é
  contada; **NPCs são parte extra**.
- **Interatividade 3D**: objetos que reagem (gavetas, telefone, máquina de escrever, fliperama,
  interruptores, monitores, inspeção girando o objeto).
- Vitrines com **colagem de várias imagens** do projeto. Projeto sem imagem ganha visual estilo
  GitHub/terminal com dados do README. Repositórios privados aparecem só com dados (sem código).
- **Integração com GitHub** (READMEs em telões, atividade, linguagens, estrelas) sem token no cliente.
- Foto do Gabriel do portfólio antigo num outdoor do "Sobre mim". Currículo e LinkedIn como base dos
  textos (sem telefone/endereço). Evidenciar habilidades: game dev, IA (Claude, agentes, IAs locais),
  integrações, arquitetura.
- Trilha própria: `game/assets/audio/music/bloodlines_ost.mp3` ("inaciodev — Bloodlines like 3"), em
  loop, abaixa nos diálogos, botão de som.
- **SEO excelente**: HTML semântico real, página por projeto, JSON-LD, sitemap, OG. Honestidade: topo
  pelo nome e termos específicos é alcançável; termos genéricos não têm garantia.

## Personagens
- Estilo definido pela referência `docs/referencias/personagem_referencia.png`: estilizado moderno,
  proporções normais/atléticas, maxilar marcado, olhos pequenos, cabelo em mechas esculpidas,
  sombreamento limpo. **Nada redondo/fofo, não clonar o RUMOR**, expressões sérias e adultas.
- Pipeline aprovado: arte conceito (gpt-image-2) → Meshy image-to-3D → Blender (decimar, ~12k tris,
  textura comprimida) → rig e animações Mixamo pelo Claude in Chrome (conta dele já logada) → Godot.
- Elenco: Vance (detetive), Lena (couro), Otto (bartender), Kai (hacker).
- Cenário e props devem seguir o mesmo padrão visual dos personagens para não destoar.

## Ferramentas liberadas
- **Meshy** (chave em `C:/Users/gabri/.meshy_key`, nunca imprimir/commitar; créditos exclusivos do
  projeto, usar à vontade). Os créditos acabaram em 2026-11-01 após 31 props; pedir recarga ao usuário.
- **OpenAI** gpt-image-2 (chave em `C:/Users/gabri/.openai_key`). O gpt-image-1 foi desativado na API.
- **Stable Diffusion local** (RTX 4070 Ti 16 GB): `C:/Project/tools-ai/sd/Scripts/python
  C:/Project/tools-ai/gen.py "prompt" saida.png [--modelo leve|xl] [--lado] [--n] [--seed] [--tile]`
  para tarefas menores (texturas, variações, fundos).
- **Mixamo** pelo Claude in Chrome (sem digitar senha nem aceitar termos novos).
- Pesquisa na web para referências visuais (sem baixar assets de terceiros).
- Blender headless com qualquer recurso.

## Hospedagem
- Repositório `GabrielInacior/portfolio-noir`, **público** desde 2026-11-01 (a pedido do usuário).
- Domínio `inaciodev.online` (versão antiga ainda no ar). Recomendação em `docs/HOSPEDAGEM.md`;
  mudar DNS/hospedagem só com aprovação explícita.

## Projetos relacionados
- README de perfil do GitHub (repo `GabrielInacior/GabrielInacior`, feito por outra sessão): usa o
  elenco (`docs/elenco_wip.png`) como card do portfólio; quando a cidade tiver um hero bonito, avisar
  para trocar.
- Prints reais do InacioCyber (só a interface, 6 temas): `data/captures/inaciocyber/`.
