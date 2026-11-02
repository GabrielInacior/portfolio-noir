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

## Animações dos personagens: o que deformava e como ficou (2026-11-01)
- **Causa dos braços torcidos:** as 15 animações foram baixadas no esqueleto do Vance e aplicadas
  como rotação local nos outros, que têm pose de repouso diferente (Otto/Kai até 43°, Lena até 53°).
  **Correção:** `game/tools_dev/char_bake_anims.gd` converte a biblioteca para cada esqueleto
  (`assets/characters/meshy/anims_<id>.res`): `qt = C(pai)^-1 * qs * C(osso)`, com
  `C = repouso_origem^-1 * repouso_destino` em espaço de mundo; quadril pelo comprimento da perna.
  `noir_character.gd` carrega a biblioteca do próprio personagem. Rodar de novo sempre que um
  personagem ou `anims.glb` mudar:
  `godot --headless --audio-driver Dummy --path game -s res://tools_dev/char_bake_anims.gd`.
- **Braços entrando no corpo (Vance de sobretudo, Otto largo):** na mesma conversão, "espaço dos
  braços" dependente da pose: em cada quadro braço e antebraço são empurrados para longe do tronco
  (forte quando colados/cruzando, zero quando já abertos). Graus por personagem em `ARM_OPEN` e
  `FORE_OPEN` (Vance 9/11, Otto 9/9, Kai 6/6, Lena 4/4).
- **Lena (Mixamo recusou o auto-rig):** `tools/blender/char_rig_fit.py` encaixa o esqueleto Mixamo
  na geometria dela (coluna e pernas pelo centro das fatias do corpo; braço do ombro, medido pela
  largura do tronco, até a ponta da mão), solda vértices duplicados, calcula pesos por calor dos
  ossos numa cópia fechada (voxel 5 mm) e transfere para a malha; dedos pesam na mão; região do braço
  separada do tronco/pernas por raio (`R_ARM/R_FORE/R_HAND`). Sai `.blend`, e
  `char_export.py` aceita `.blend` direto (sem FBX). Ela não usa só "pensativo" (antebraço cruzando a
  barriga ainda puxa a barra da jaqueta).
- **Riscos escuros no rosto:** malha da Meshy vinha partida nas emendas (frestas mostravam o lado de
  dentro) e as ilhas coladas da textura vazavam com mipmap. `char_export.py` solda vértices
  (0,8 mm) e o material do personagem usa filtro linear sem mipmap; os `.jpg.import` dos 4 estão no
  repositório (sem mipmap, qualidade 0,95).
- **Prova:** `game/tools_dev/char_anim_grid.tscn` (4 personagens x 6 animações, frente e lado, 2 momentos).
- A Meshy não será recarregada (decisão do usuário): os 4 modelos atuais são definitivos.

## Correção de raiz dos braços e grão PS1 nos personagens (2026-11-01, rodada 2)
- **Raiz:** a malha do Meshy chega em A-pose com braço e mão encostados no tronco/casaco/coxa e
  partida nas emendas; os pesos (Mixamo ou calor dos ossos) misturavam braço com tronco: manga do Otto
  rasgava no ombro, barra do sobretudo do Vance e da jaqueta da Lena seguiam o braço, pele esticava.
- **Pesos refeitos nos 4** com `tools/blender/char_rig_fit.py` (Vance/Otto/Kai com `FIT_BONES=0`,
  mantém o esqueleto da Mixamo; Lena com encaixe próprio): solda; calor dos ossos numa cópia fechada;
  raio de cada osso do braço medido na malha (manga grossa = raio maior, mão limitada a 8,5 cm);
  vértice só é do braço se estiver perto do osso **e** o calor concordar (a barra do casaco ao lado da
  mão fica com o quadril), ou colado na mão inteira e mais perto dela do que da perna; braço sem peso
  do tronco e vice-versa (exceto junto do ombro); pele que sobrou herda o peso dos vizinhos de malha.
  Teste de pose extrema no espaço do esqueleto (erguer, frente, cruzar) sai junto (`... debug.png`).
  Uso: `FIT_BONES=0 blender -b -P tools/blender/char_rig_fit.py -- mixamo.fbx mixamo.fbx saida.blend prova.png`
  e depois `char_export.py -- saida.blend personagem.glb`, e reconverter (`char_bake_anims.gd`).
- Torção: conferida com e sem o "espaço dos braços" da conversão; não há torção nos dois. O empurrão
  fica (tira o braço de dentro do sobretudo). Os 4 fazem todas as animações (`SAFE_ANIMS` vazio).
- **PS1:** `tools/blender/char_ps1_textures.py` quantiza as texturas dos 4 na mesma paleta dos props
  (`tools/props/ps1_textures.py`), 512 px (256 deixava pontos escuros nas emendas das ilhas); a pele
  só posteriza (a paleta tem poucos tons de pele e o rosto perdia nariz/olhos/boca). Material =
  `ps1.gd` (NEAREST, sem especular) + contorno neon, luz por pixel e rugosidade 0,8 (em 1,0 o contorno
  do Godot estoura). Originais em `tools/props/_orig/char_*` (fora do git).
- **Prova dentro do jogo:** `game/tools_dev/char_ingame_shot.tscn` (NPCs na rua em close, frente e 3/4,
  e tela de diálogo; a câmera entra na SubViewport retrô do `main.gd`).
- Branco nunca puro nas texturas dos personagens (cinza claro quente, máx. 214) e contorno neon
  pesado pelo inverso da claridade (`*_rim.png` gerado junto, usado como `rim_texture`): a manga do
  Otto parou de estourar.

## Rodada 5 (lojas lotadas, interação, GitHub, skills, carreira, i18n, retrô PS1)
- **Lojas**: salas de 7,2 x 9 m (carreira 7,2 x 13) com identidade por estilo em `game/scripts/museum_dress.gd`
  (`LOOKS`: detetive, cyber, arcade, bar, studio, study, startup, lab, career). Tudo sinaliza skills: estante com
  livros nomeados por tecnologia, pôsteres de stack, adesivos em racks/laptops, quadro branco de arquitetura,
  neons com nomes de tecnologias, telas procedurais (`shaders/matrix_rain`, `code_scroll`, `chart_screen`, `led_panel`).
- **Interação**: contorno pulsando no objeto mirado (`shaders/hover_outline.gdshader` via material_overlay),
  retícula central, verbo no aviso ("[E] atender", "toque para jogar"). Itens com `panel` abrem `scripts/panels.gd`
  (inspect, terminal, gallery, doc, skills, timeline, contact, arcade); itens com `action` fazem algo físico
  (telefone toca, gaveta abre, máquina datilografa, interruptor apaga a sala). Fliperamas jogáveis em `scripts/arcade/`.
- **GitHub**: `scripts/gh_screen.gd` (telão por loja, renderizado uma vez numa SubViewport e rolado por UV) e
  painel terminal; `GithubLive` é autoload; README ao vivo só no navegador (repo público), snapshot nos demais.
- **Carreira**: prédio CARREIRA na transversal (`special: career`), conteúdo em `tools/museum/build_career.py`.
  DÚVIDAS para o usuário confirmar: "imp" (projeto de análise de licitações) e "SysGuide" não aparecem no currículo
  nem no LinkedIn; foram colocados como projetos da Sys Evolution conforme a mensagem dele.
- **i18n**: `scripts/i18n.gd` (autoload `L`); texto-fonte é o português; `tools/i18n/build_i18n.py` extrai tudo e
  traduz com gpt-4.1 (cache em `tools/i18n/cache_en.json`), além de corrigir acentos que faltavam nos roteiros.
  UI.label/button traduzem sozinhos. Idioma: escolha salva (pf_lang), ?lang=, /en, navegador, sistema; fallback en.
  As páginas de SEO abrem na língua do navegador (sem redirecionar robôs).
- **Retrô PS1**: o 3D roda numa SubViewport em baixa resolução (forte 360p, suave 540p, HD) ampliada com NEAREST,
  com `shaders/retro_ps1.gdshader` (quantização + Bayer 4x4 + vinheta); a interface fica nítida por cima.
  Botão na barra de cima e escolha salva (pf_retro). Props: `scripts/ps1.gd` (material único, luz por vértice,
  sem PBR, nearest) e `tools/props/ps1_textures.py` (texturas da Meshy na paleta única; originais em tools/props/_orig).

## Braço x tronco "assado" nas animações (2026-11-01, rodada 3)
- `game/tools_dev/char_bake_anims.gd` mede o volume do tronco de cada personagem na malha (elipse em
  6 fatias da cintura ao pescoço: largura limitada pelo ombro, profundidade frente/trás) e, em cada
  chave, gira braço e antebraço o mínimo para tirar cotovelo, meio do antebraço, punho e ponta da mão
  de dentro dele (3 passadas, até 10 iterações). Só conta o que CRUZA o corpo (na frente/atrás);
  mão ao lado da coxa é postura normal. Lena com volume ×0,78 (jaqueta aberta inflava a medida).
  Depois mede a cada 0,1 s e imprime o que sobrar (`resto de penetração ... cm`).
- Fora da biblioteca (bizarras sem cenário): encostado (parede), sentado e digitando (cadeira).
  Trocas no jogo (`noir_character.gd`, SUBST): encostado→respirando, sentado→idle,
  digitando→olhando, perguntando→falando (só Lena), bartender→respirando (bartender só no Otto,
  ONLY_FOR). Lena não usa perguntando nem bartender (resto de 4 a 5 cm).
- Prova: `char_anim_grid.tscn` (4 personagens, 12 animações) e `char_ingame_shot.tscn` (rua e
  diálogo, pelo `play()` do personagem, com as trocas valendo como no jogo).

## Áudio (2026-11-01)
- Sons gerados localmente com Stable Audio Open + triagem CLAP (pipeline herdada do FortressChaos;
  skill `.claude/skills/portfolio-audio`, detalhes em `docs/AUDIO.md`). Venv `C:\Users\gabri\ai_audio\venv`,
  token HF em `C:\Users\gabri\.hf_token` (nunca imprimir). Proibido banco de sons pronto e AudioGen/MusicGen.
- Usuário pediu para não gastar muito tempo no som: conjunto essencial entregue (ambientes de rua e das lojas,
  passos, portas, painéis, mira, objetos, fliperama), 3,1 MB além da OST. Refazer som só se ele pedir.
- `Audio` (autoload) faz tudo sozinho observando a cena (zona rua/loja, passos, neon, vapor, carros, objetos
  pelo item mirado, interruptor, telefone); nada toca antes do ENTRAR; botão de som cala o Master.

## Personagens PS1 feitos no Blender (2026-11-01, substituem os Meshy)
Decisão do usuário: descartar o elenco Meshy e refazer no Blender. Pipeline atual (tudo por código):
- `tools/blender/char_ps1_faces.py`: rostos pixel art 64x64 por expressão, atlas 8x2 por personagem
  (`game/assets/characters/ps1/face_<id>.png`): sério, desconfiado, intrigado, pensativo, sorriso de canto,
  cansado, firme, neutro; linha de baixo = boca aberta (fala).
- `tools/blender/char_ps1_build.py -- <id|all|anims>`: malha low-poly (~850 a 980 tris) construída em volta
  do esqueleto Mixamo de `tools/mixamo_raw/vance_idle_serio.fbx`, na pose de repouso dele, com braços
  SEPARADOS do tronco e pesos por anel (1 a 2 ossos). Cor por vértice (sem textura) + decalque de rosto.
  Elenco: vance, lena, otto, kai, extra1 (boné), extra2 (sobretudo vinho). Saída `ps1/<id>.glb`.
- Animações (`ps1/anims.glb`, ~0,9 MB, 13 animações): CAUSA DOS BRAÇOS TORTOS ACHADA: os FBX "sem pele" da
  Mixamo vêm com repouso em T, e o personagem estava em A; copiar a rotação local torcia os braços para
  dentro. Agora cada FBX é transferido por COPY_TRANSFORMS em espaço do mundo, osso a osso, e assado
  (`bake_from`). Depois, `correct_arms` mede antebraço/mão contra o tronco do Otto (o mais largo) quadro a
  quadro e assa a menor abdução/flexão do ombro que tira de dentro (margem 1,2 cm).
  Novas por pose-chave (IK + bake): `bracos_cruzados` e `maos_bolsos`. Fora: sentado, digitando, encostado,
  apontando (precisam de cenário). Todos os personagens usam o MESMO esqueleto: uma biblioteca serve a todos.
- Medida: `tools/blender/char_ps1_check.py -- vance,lena,otto,kai,extra1,extra2` (penetração de antebraço e
  mão no tronco, por paridade de raio): máximo 0,4 cm (Kai, braços cruzados apoiados no moletom); 0 nas demais.
- Prova no Godot: `game/tools_dev/char_ps1_grid.tscn` (cada personagem em cada animação, frente e 3/4, e
  folha de expressões). Peso total dos personagens: ~1,6 MB.
- `game/scripts/scene3d/noir_character.gd` mantém a interface (setup/set_expression/set_talking/set_rim/play);
  `set_expression` troca a célula do atlas do rosto; a fala alterna boca aberta/fechada.
