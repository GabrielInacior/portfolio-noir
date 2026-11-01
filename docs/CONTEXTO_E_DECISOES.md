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

## Personagens: pipeline final (rodada 3C)
Resultado aprovado na régua: 4 personagens no estilo da referência (`docs/referencias/personagem_referencia.png`),
comparação em `docs/referencias/personagens/comparacao_elenco.jpg`. Vance (detetive), Otto (bartender), Kai
(hacker) e Lena (couro). GLBs em `game/assets/characters/meshy/`, script `game/scripts/scene3d/noir_character.gd`.

1. **Arte conceito**: `tools/ai_art/gen_image.ps1 -Model gpt-image-2 -Quality medium -Size 1024x1536`
   (gpt-image-1 foi desativado na API). Prompts em `tools/meshy_prompt_<nome>.txt`: frente, A-pose,
   braços a 45 graus, fundo cinza, estilo "modular character". Conceitos em `docs/referencias/personagens/`.
2. **Meshy image-to-3D**: `python tools/meshy_image_to_3d.py arte.png saida.glb 12000` (chave em
   `~/.meshy_key`, nunca no repo). Parâmetros: `ai_model=latest, topology=triangle, target_polycount=12000,
   should_remesh=true, should_texture=true, enable_pbr=false, symmetry_mode=on`. ~2 min por modelo.
   ATENÇÃO: os créditos da conta acabaram em 01/11 (HTTP 402) depois dos 4 personagens + 31 props.
3. **Blender (prep)**: `blender -b -P tools/blender/char_prep.py -- in.glb out_base 12000 1024 [clean]`
   (altura 1,80, pés no chão, decima, textura 1024, FBX para a Mixamo). Render de prova:
   `tools/blender/char_render.py`.
4. **Mixamo (Claude in Chrome, conta do usuário já logada)**: UPLOAD CHARACTER, enviar o FBX pelo input de
   arquivo, NEXT, arrastar marcadores (queixo embaixo do queixo, pulsos, cotovelos, joelhos, virilha ENTRE as
   pernas), Standard Skeleton, NEXT, revisar, NEXT, "proceed". Animações pela API interna da página
   (`window.MX` no console: `characters/primary`, `products/{id}?character_id=`, `animations/export` com
   `preferences {format:'fbx7_2019', skin:'false', fps:'30'}`, `characters/{id}/monitor`); o download cai em
   `~/Downloads`. Brutos da Mixamo NÃO vão para o repo (`tools/mixamo_raw/*.fbx` ignorado).
   A Lena foi recusada pelo auto-rig ("Unknown error while generating motion", 4 tentativas, inclusive malha
   limpa e esqueleto sem dedos): rigada por transferência em `tools/blender/char_rig_transfer.py -- kai.fbx
   lena.glb lena_rig.fbx arms` (esqueleto do Kai, pesos copiados por proximidade, braços pelo osso mais
   próximo). Ainda estica a mão em gestos amplos: o jogo só toca nela animações seguras (`SAFE_ANIMS`).
   Para resolver de vez: regerar a Lena no Meshy (cabelo preso, `lena2.png` já existe no scratchpad) quando
   houver créditos, e rigar na Mixamo.
5. **Exportação para o jogo**: `blender -b -P tools/blender/char_export.py -- personagem_mixamo.fbx saida.glb 1024`:
   cabeça separada numa malha própria com 5 shape keys feitas por código na região do rosto (brow_down,
   brow_up, smile_r, squint, jaw), textura JPEG. Biblioteca de animações comum:
   `tools/blender/char_anims.py -- pasta_fbx anims.glb base_skin.fbx` (15: idle, respirando, falando,
   perguntando, pensativo, sim, nao, olhando, apontando, encostado, digitando, bartender, fumando, sentado,
   andando). No Godot só entram trilhas de rotação (e posição do quadril), então a mesma animação serve
   aos quatro sem deformar proporções.
6. **Peso**: 12k tris por personagem; importado no Godot = 4,7 MB no total (4 personagens + animações),
   texturas em modo com perda (WebP 0,8), sem tangentes, LOD gerado na importação, animação pausa fora da
   tela, sombra só no PC.
7. **Provas**: `tools_dev/char_sheet.tscn` (elenco, bustos, expressões, poses) e
   `tools_dev/char_dialogue_shot.tscn` (tela de diálogo com 3 expressões), sempre mudas.

## Rodada 4A (lojas, bairro, interface): o que foi decidido e feito
- **Bairro com esquinas** (`game/scripts/city.gd`, reescrito): avenida (x ±7, z 8 a -72), transversal em
  z -42 (de x -48 a 48), beco à direita em z -20 (fundo = loja do InacioCyber), praça à esquerda
  (x -66..-48, z -56..-28) com fonte, árvores, bancos, cabine de CONTATO e outdoor com a foto; prédio do LAB
  no fim da avenida. Andar = união de retângulos (`player.walk_rects`), a museu troca para a sala.
- **Lojas por projeto** em pontos fixos (`_place_shops`): fachada com porta, vitrine com a colagem
  (`assets/data/collages/<id>.png`, UV em "cover"), letreiro de neon com halo, toldo, placa de bandeira
  balançando, luz colorida real com corte por distância e luz falsa no chão.
- **Vida**: carros com faróis/lanternas, pedestres andando e duplas conversando (personagens do agente de
  personagens via `noir_character.gd`), vapor de bueiro, respingos, neons com falha, janelas vivas, ventiladores,
  pombos, névoa em cartões, varal de lâmpadas no beco, letreiros no topo dos prédios distantes.
- **Janelas** com interior falso: atlas 4x4 gerado no SD local (`assets/tex/janelas_atlas.png`,
  `tools/art/window_atlas.py`).
- **Geometria estática fundida** por pedaço de 16 m (`_sbox`), frente = sentido horário (bug dos prédios
  quebrados era a ordem invertida). Props repetidos em MultiMesh (`_prop`).
- **Props**: 31 da Meshy (interiores) + 13 da rua feitos em Blender por código
  (`tools/props/street_props_blender.py`). A Meshy ficou sem créditos e o usuário decidiu NÃO recarregar:
  tudo novo sai de Blender por código, SD local ou gpt-image-2 (com moderação).
- **Interiores** (`museum.gd`): sala composta por tema com props Meshy, lambri/rodapé, tapete, luminárias,
  janela; itens de parede no máximo 3 por parede a 3 m; objetos 3D em pedestal girando; InacioCyber com
  parede de 6 monitores com os temas reais (`assets/museum/inaciocyber/tema_*.jpg`, faixa "backend offline"
  recortada).
- **Imagens em molduras**: sempre plano com UV 0..1; "cover" para quadros/fotos/colagens, "contain" para
  prints com texto (`museum_objects.gd: img()`, `city.gd: _cover()`). Nunca BoxMesh com textura.
- **Interface responsiva**: escala lógica por orientação (720x1280 em pé, 960x540 celular deitado,
  1280x720 PC) em `main.gd`, vigia de texto vertical, `TouchScroll` (do RUMOR) em `scripts/touch_scroll.gd`;
  diálogo com personagem em cima no celular e ao lado no PC; modal com fechar fixo; alvos de 88 px.
  Minimapa = radar centrado no jogador + mapa grande (toque ou M).
- **Nome**: título "Gabriel Inácio" (sem "Portfólio"), subtítulo "engenharia de software · games · IA".
