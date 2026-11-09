# Performance

Medido em desktop (RTX 4070 Ti, 1280x720, Godot 4.7.1 GL Compatibility) com `tools_dev/perf.tscn`:

| Cena | Draw calls | Objetos | Primitivas | VRAM | FPS |
|---|---|---|---|---|---|
| Rua (cidade) | 669 | 758 | 96 693 | 82,8 MB | 151 |
| Loja-museu (RUMOR) | 8* | 8 | 88 | 102,4 MB | 180 |

\* a sonda não movimenta a câmera dentro da loja; com a sala toda em quadro gira em torno de
60 a 120 objetos. A loja é fechada (sem céu, sem a rua renderizada), por isso é barata.

## Já aplicado
- GL Compatibility, materiais unshaded/emissivos para neon, poucas luzes reais por cena.
- Skyline distante e janelas por **MultiMesh** (um draw call), sem sombra.
- Sombra direcional só no desktop; nenhuma no mobile.
- Chuva com menos partículas no celular.
- Lojas carregadas só ao entrar pela porta; a rua não é renderizada dentro da loja (occlusion por zona).
- Sem física além de colisão de cápsula do jogador e caixas das paredes.

## A fazer (reduzir draw calls da rua, hoje ~669)
- **Merge de malhas estáticas por quarteirão:** juntar paredes, janelas e detalhes de cada prédio
  numa malha só por material (SurfaceTool), alvo abaixo de 200 draw calls.
- **MultiMesh** para postes, meios-fios, faixas da rua e props repetidos.
- **Impostores/billboards** para os prédios de fundo (já são caixas; trocar por cards).
- **Atlas único** de textura por zona (hoje: asfalto, parede, tijolo, e as novas de interior).
- **Compressão VRAM** no import das texturas grandes (ETC2/S3TC) para o web.
- **Resolução adaptativa por FPS** (como no RUMOR) e um **modo leve** automático em celular fraco
  (menos partículas, sem feixes de luz, menos janelas acesas).
- Medir de novo no navegador do celular, não só no desktop.


## Rodada 4A (bairro com esquinas, vida, lojas novas)
Medido com `tools_dev/district_shot.tscn` (PERF=1, ponto z=-30 olhando o cruzamento), RTX 4070 Ti:

| Resolução | FPS | Draw calls | Objetos | Primitivas | VRAM |
|---|---|---|---|---|---|
| 1920x1080 (PC, glow + sombra) | 164 | 422 | 501 | 897 mil | 197 MB |
| 405x720 (em pé) | 176 | 266 | 345 | 880 mil | 172 MB |
| rua reta antiga (referência) | 151 | 669 | 758 | 97 mil | 83 MB |

- Draw calls caíram mesmo com o bairro ~4x maior: geometria estática fundida por pedaço de 16 m, MultiMesh
  para props, skyline e janelas em lote.
- Primitivas subiram muito: investigar personagens (12k tris, sombra) e o skyline com recuos; meta < 300 mil.
- Peso: props 5,6 MB (44 GLB), texturas 6,4 MB. No celular real (`UI.is_mobile()`): sem glow, sem sombra,
  menos chuva/vapor/carros/pedestres, metade dos postes sem luz real.

## Rodada final de performance (PC, sonda `tools_dev/perf_r6.tscn`, 4 pontos da cidade)
Antes = sem fusão de malhas e com panfletos/anúncios em arquivos soltos e texturas sem compressão.
Draw calls do mundo (`dc_mundo`), pior ponto (avenida) / ponto típico (cruzamento).

| Perfil | Resolução | Draw calls (cruz./avenida) | Primitivas (cruz.) | VRAM | Quadro médio / pior |
|---|---|---|---|---|---|
| Antes (NOMERGE, sem compressão) | 1280x720 | 830 / 1993 | 64 mil | 523 MB | 10,6 / 24 ms |
| Alto/padrão agora | 1280x720 | 405 / 701 | 107 mil | ~390 MB | 6,2 / 14 ms |
| Padrão | 405x720 | 209 / 351 | 72 mil | 294 MB | 5,7 / 12 ms |
| Batata | 405x720 | 151 / 243 | 51 mil | 290 MB | 5,5 / 6 ms |

Feito: fusão de malhas estáticas por célula e material (`render/merge.gd`: 2294 para 483 malhas),
atlas de anúncios por língua (3 páginas), imagens grandes em WebP com perda
(`tools/deploy/compress_imports.py`, reaplicado no build porque `.import` não é versionado; VRAM comprimida S3TC+ETC2 baixava a VRAM para ~229 MB, mas o .pck ia a 225 MB, então ficou de fora),
panfletos da rua em miniaturas de 384 px (`assets/flyers`, antes carregava os prints cheios: -100 MB),
perfil `UI.quality()` alto/padrão/batata (celular e GPU fraca detectados, queda automática por FPS,
`?q=batata` ou `localStorage pf_q` forçam), distância de câmera/névoa menores, resolução interna menor.
Limite conhecido: a fusão tira o culling por objeto (primitivas sobem no PC); falta OccluderInstance3D e
`visibility_range` por quarteirão, e pausar telões/tráfego fora da vista. `.pck` 26,6 MB (meta 15 MB; antes 24 MB: 6 atlas novos). VRAM de ~290 MB passa da meta (250 padrão, 120 batata):
vem das texturas sem compressão em GPU e de ~130 MB de buffers de viewport/pós (investigar com a sonda de memória
`tools_dev/mem_probe.tscn`).


## Rodada de carregamento e travadas (nov 2026)
Medido no Chrome real, servidor local que imita a Vercel (`tools/deploy/serve_local.py`: brotli, cache e cabeçalhos do
`vercel.json`), PC com RTX 4070 Ti SUPER, perfil de navegador novo (partida a frio, sem cache de shader do driver) e perfil
reaproveitado (visita repetida). Sonda: `node tools/deploy/cdp_perf.js <url> [--soft] [--shops a,b] [--logs]`; no jogo
`?perf=1` expõe `pfFrameStats()` (CPU por quadro) e `pfAB(nome, ligado)` (interruptores A/B por sistema).

### Antes x depois
| Item | Antes | Depois |
|---|---|---|
| Carga transferida antes do ENTRAR (brotli) | 32,9 MB (wasm 9,5 + pck 23,3) | ~20 MB (wasm 9,5 + principal 8,5 + idioma 2,0) |
| Em segundo plano, depois | nada | música 3,8 MB + lojas 5,7 MB |
| .pck inicial (principal) | 26,6 MB | 9,6 MB (+ 2,1 do idioma) |
| Cache | `max-age=3600, must-revalidate` | arquivos com hash: `max-age=31536000, immutable` |
| 1ª pintura do loader | 232 a 776 ms, sem texto de etapa | 45 a 330 ms, com etapas e % reais |
| Maior tarefa longa na carga (a frio) | 44,6 s (uma só) | 8,2 s |
| Maior tarefa longa na carga (visita repetida) | 7,7 s | 2,8 s |
| Pronto para ENTRAR, a frio | 46,2 s | 39,5 a 47,6 s (varia; ver abaixo) |
| Pronto para ENTRAR, visita repetida | 9,6 s | 9,7 s |
| favicon / foto do JSON-LD | 1,6 MB cada | 6 KB / 50 KB |
| SwiftShader (sem placa), cidade 1280x720 | 146 ms/quadro (7 fps) | 64 ms (15,5 fps); 405x720: 63 ms |
| SwiftShader, dentro das lojas | não medido | 33 ms (30 fps, limite) |
| Draw calls da avenida (GPU) / passada nítida | 522 / 337 | igual (não foi atacado) |

### O que foi feito
- **Loader** (`tools/deploy/make_boot.py`, embutido em todas as páginas com `<link rel=preload>` do wasm, do pck de idioma e do JS
  do motor): barra por bytes com MB e velocidade, etapas Baixando, Ligando o motor, Cidade (% real vindo do jogo por
  `window.pfProgress`), Aquecendo shaders; animações só com transform/opacity (seguem com a thread ocupada); dica de rede lenta
  depois de 10 s; erro visível com botão de tentar de novo; marcas de tempo em `window.__pf.t` e no console (`[pf] ...`).
- **Cidade em fatias** (`city.gd`, `merge.gd`, `lowpoly.gd`): 12 ms por quadro e o 3D não é desenhado durante a montagem (cada
  quadro com a cidade pela metade custava dezenas de ms e quadruplicava o tempo). `sharp_pass.gd` não marca nada durante a
  montagem (os gêmeos oclusores entravam na fusão de malhas). Fusão idêntica à versão síncrona (2294 para 483 malhas).
- **Aquecimento de shaders** (`city.gd::_warm_up`): cada material único vira um quadradinho diante da câmera, em lotes
  adaptativos, com luzes de teste (variante com luz) e sem luz. Na visita repetida é dispensado (o navegador guarda os
  programas; chave em `localStorage pf_warm` por versão do jogo e placa).
- **Pacotes** (`tools/deploy/pck_split.py` lê o PCK v4 e grava principal, `lang_pt`, `lang_en`, `music`, `shops`;
  `scripts/packs.gd` monta com `load_resource_pack`; o carregador baixa e entrega por `engine.copyToFS`). A loja espera o pacote
  se ele ainda não chegou ("Carregando a loja..."). Descartado do pacote: `og_bg.png` (só serve ao `seo_build`).
- **Nomes com hash** e `Cache-Control: immutable` só para `index.<hash>.*`; `boot.js` com cache curto. O build apaga `site/` inteiro
  antes de gerar (nada de build antigo acumulado) e falha se algum script tiver erro de parse.
- **Entrada nas lojas**: véu preto de 0,16 s com "ENTRANDO..." esconde a montagem da sala (antes a tela congelava 90 a 500 ms
  com os shaders em cache e até 2,9 s sem cache). Dentro das lojas: 12 a 29 draw calls, 3 a 5 ms de CPU por quadro.
- **Perfil sem placa** (`UI.software()`; o loader detecta SwiftShader, llvmpipe, Basic Render Driver ou
  `failIfMajorPerformanceCaveat` e passa `sw=1`; `?q=sw` força): 30 fps, 3D em 240 px de altura, canvas em meia resolução (CSS amplia),
  sem passada nítida, sem luz real, 45% das janelas e do skyline, câmera 38 m, névoa 34 m, alcance de peças pequenas 9/16 m.

### Onde estava o custo (interruptores A/B)
Desligar a cidade inteira derruba o quadro de 19 para 4,6 ms de CPU; a lógica GDScript (tráfego, pedestres, anúncios, efeitos)
soma 1 a 2 ms; luzes, rótulos 3D, chuva, glow, HUD e passada nítida, um a um, não mudaram a CPU. Na GPU o custo é submissão de
draw calls (522 + 337 da passada nítida) pelo WebGL do wasm. No SwiftShader o custo é outro: luzes -45 ms, MultiMesh
(janelas/skyline) -58 ms, malha fundida -68 ms por quadro.

### Partida a frio: o que sobra
- Boa parte do tempo a frio é compilação de shader no Windows (Direct3D 11 via ANGLE): ~2,5 s por programa com luz por pixel,
  ~0,25 s por programa sem luz, ~455 materiais únicos. Só na 1ª visita (o navegador guarda os programas). Testado e descartado:
  `force_vertex_shading` (compila 2x mais rápido, mas as fachadas grandes ficam pretas), `max_lights_per_object=3` (sem efeito
  no tempo), uniformizar textura/emissão/cor de vértice dos materiais (ganho de 3 s, custo fixo de fragmento). Próximo passo
  real: reduzir variantes de material nos helpers `_mat`/`_painted` ou template do Godot com compilação assíncrona; sem
  emsdk/scons instalados, o template customizado não foi tentado.
- wasm: `wasm-opt -Oz` (binaryen) levou ~9 min e economizou só 3,4% (39,5 para 38,2 MB); não adotado. Brotli nível 11 deixaria
  o wasm em 6,9 MB (contra 9,5 MB da Vercel), mas depende de servir `.br` pré-comprimido com `Content-Encoding` pela Vercel;
  não testado em produção.
- Meta de 12 MB antes do ENTRAR não atingida: o wasm sozinho tem 8 a 9,5 MB comprimido.
- SwiftShader ficou em 15,5 fps na cidade (meta 20): o custo restante é draw call e vértice por software.

### Validação no site no ar (inaciodev.online, Chrome próprio, perfil novo e reaproveitado)
- Cabeçalhos: arquivos `index.<hash>.*` com `Cache-Control: public, max-age=31536000, immutable` e `Content-Encoding: br`; `boot.js` com 3600 s.
  Tamanhos transferidos: wasm 9,55 MB, principal 8,70 MB, idioma 2,04 MB, música 3,79 MB, lojas 5,80 MB.
- 1ª pintura do loader: 500 ms (3,4 s antes de os preloads passarem a `fetchpriority=low`).
- Cold: pronto para ENTRAR em 44,7 s (download do wasm e do principal concluído em 5,8 s; compilação de shader sem cache de driver
  responde por ~30 s); maior tarefa longa 7,4 s (antes uma de 44,6 s). Visita repetida: 9,6 s, maior tarefa 3,1 s.
- Capturas: `docs/perf/loader_live.png` (loader com progresso) e `docs/perf/cidade_live.png` (cidade).


## Rodada 2 (nov 2026): mundo noir, oclusores fundidos, template próprio, wasm brotli 11
Mesma sonda (`tools/deploy/cdp_perf.js`, Chrome headless, RTX 4070 Ti SUPER, D3D11/ANGLE), medido no site no ar
(inaciodev.online) depois de cada publicação. "Antes" = rodada 1 no ar.

| Item | Antes (no ar) | Depois (no ar) |
|---|---|---|
| Pronto para ENTRAR, 1ª visita (perfil novo) | 44,7 s | 28,3 s (local: 26,6 s; sem aquecer as lojas: 19,6 s) |
| Pronto para ENTRAR, visita repetida | 9,6 s | 6,9 s |
| Maior tarefa longa na carga (a frio) | 7,4 s | 6,8 s |
| wasm transferido | 9,55 MB (brotli da Vercel) | 5,83 MB (template próprio + brotli 11 pré-comprimido) |
| CPU por quadro na cidade | ~19 ms (17 a 22 conforme a máquina) | 14 a 15 ms |
| Draw calls passada nítida (avenida) | 335 | 226 |
| Draw calls mundo (avenida) | 519 | 491 |
| 1ª entrada numa loja (a frio) | 2,6 a 2,9 s congelado | 0,28 a 1,5 s |
| Programas de shader na cidade (censo) | 41 (17 com luz, ~75 variantes) | 17 (1 com luz, ~19 variantes) |
| SwiftShader, cidade | 64 ms (15,5 fps) | 65 ms (sem mudança: o noir fica desligado sem placa) |

### O que entrou
- **Censo** (`scripts/render/census.gd`, `?perf=1` ou `CENSUS=1`; `pfAB("census",true,"rotulo")`): programas distintos
  (StandardMaterial3D por flags, ShaderMaterial por código, variantes de luz e de instância) e superfícies por categoria.
  Antes: 41 programas, 472 materiais, fundidos 483, nítida 333 oclusores, textos 153, multimesh 46, carros 56, pessoas 26.
- **Mundo noir** (`shaders/noir/`, `scripts/render/noir.gd`): todos os StandardMaterial3D da cidade viram 5 ShaderMaterial
  `unshaded` (opaco, opaco dupla face, recorte, mistura, aditivo) com a luz calculada no shader, replicando a do Godot 4.7
  (Burley + Schlick-GGX, atenuação omni/spot, energia x PI, a mesma cúbica de sRGB do motor; conferido pixel a pixel em
  `tools_dev/noir_test.tscn`: diferença de 1 a 2 níveis). Luzes viram dados: textura RGBAF 4 x 121 atualizada 1 vez por
  quadro (0,7 ms). As OmniLight/SpotLight seguem na árvore (o jogo mexe nelas) com `editor_only`, o motor não as desenha.
  **Luz por objeto como no Compatibility**: cada objeto fixo leva no material as até 8 omni + 8 spot que o motor daria
  (menor distância centro a centro / alcance x energia); sem isso as fachadas ficavam claras demais (o visual aprovado
  depende desse limite). Faróis dos carros entram nas vagas livres. Neon pulsa no shader (sem CPU por quadro).
  A fusão (`merge.gd`) grava cor, emissão, rugosidade, metal e "sem luz" no vértice (COLOR, CUSTOM0, CUSTOM1).
  `?noir=0` / `NOIR=0` voltam ao caminho antigo para comparar.
- **Passada nítida**: os oclusores da geometria fundida viram 13 malhas por célula de 32 m (antes um gêmeo por malha
  fundida, ~200). Bug achado: `SurfaceTool.append_from` com malhas com e sem índice perde as sem índice; tudo é indexado.
- **Template web próprio** (`tools/deploy/godot_template/`, receita em `custom.py`): Godot 4.7.1-stable, emsdk 4.0.11,
  `optimize=size lto=full production=yes`, sem mono/csg/gridmap/navegação/xr/rede/theora/gltf/ruído/compressores de
  textura/visual_shader. 33,9 MB cru (oficial 38,6). `deprecated=no` quebrou o jogo (`Image.create`), ficou ligado.
- **wasm brotli 11** gravado no build (`build_site.sh`) e `Content-Encoding: br` no `vercel.json` só para
  `index.<hash>.wasm`. Conferido no ar: a Vercel entrega os bytes como estão (5.827.090 bytes, idênticos ao arquivo),
  sem recomprimir, e o Chrome decodifica. `serve_local.py` respeita arquivo pré-comprimido.
- **Lojas**: continuam no caminho de luz do motor (ver "não funcionou"); as variantes com luz delas (toon, liso, textura,
  vidro, luz por vértice, rosto) são aquecidas no carregador com luzes de teste reais.

### O que não funcionou / ficou de fora
- **Lojas no shader próprio**: a luz em faixas do `toon.gdshader` (light() com retícula) convertida para dados de luz
  ficou escura e em manchas na comparação lado a lado com o motor; não achei a causa no tempo. As lojas usam o motor.
- **Passada nítida exclusiva** (nítido só nela, até o fim da câmera): sem o retrô por baixo, letreiros distantes
  apareciam por vidros e frestas e a CPU subiu (33 ms). Ficou desligada (`exclusive` em `sharp_pass.gd`).
- **Eliminar a 2ª viewport**: o retrô é de baixa resolução e o nítido é de resolução cheia; num passe só, ou o texto
  pixela (regra do usuário) ou o mundo perde o pixel do retrô. Não feito.
- **Meta de draws (<= 150) e 60 fps estáveis**: não atingida. O custo restante é número de draws (491 + 226): textos 3D
  (153 Label3D, ~130 visíveis), fundidos por célula/textura (~170 visíveis) e MultiMesh. Ver próximos passos.
- **Aquecer as lojas custa ~7 s na 1ª visita**; sem isso a 1ª porta congela ~6 s. Escolhi o carregador (com barra).
- **SwiftShader**: o fragmento próprio custa mais por pixel (76 ms contra 64); sem placa o noir fica desligado.
- **Música por Web Audio**: não feito nesta rodada.

Capturas: `docs/perf/loader_r2.png`, `docs/perf/avenida_antes_depois_noir.png` e `docs/perf/cidade_antes_depois_noir.png`
(esquerda motor, direita noir, mesmo ponto), `docs/perf/loja_rumor_r2.png`.


## Rodada 3 (nov 2026): marcador de entrada, música pelo navegador, entrada das lojas, perfil de celular
Medido no ar (inaciodev.online) com `cdp_perf.js`; perfil de celular = `--mobile` (390x844, toque, UA Android, CPU 4x).

| Item | Antes (rodada 2 no ar) | Depois (no ar) |
|---|---|---|
| Música no celular (4x a 6x CPU) | mixer do Godot sem threads: lenta/distorcida | navegador: 3,04 s de trilha em 3,04 s de relógio, 48 kHz |
| Celular: download até ENTRAR (1ª visita) | 39,9 s | 32,9 s |
| Celular: aquecimento de shaders | 17,1 s (425 materiais) | ~8 s (31 programas; lojas não aquecem no celular) |
| PC: ENTRAR, visita repetida | 6,9 s | 7,7 s (variação de rede; mesmo motor) |
| PC: CPU por quadro na cidade | 14 a 15 ms | 14 ms |
| Draws cidade / passada nítida | 491 / 226 | 476 / 219 (+1 do marcador) |
| Lojas: câmera ao entrar | olhando a porta (vão sem porta) | de costas para a porta, olhando o centro; porta de madeira por dentro |

Etapas no perfil de celular (local, 4x): motor (wasm + início) 6,5 s; montar a cidade 14,3 s (otimizar geometria 6,8 s,
lojas 2,6 s, anúncios 2,3 s); aquecer shaders 8,0 s; interface até o ENTRAR ~3 s.

### Por loja (PC, draws mundo + nítida, CPU média dentro, 1ª entrada a frio)
| Loja | Draws antes | Com fusão (`?shopmerge=1`) | CPU |
|---|---|---|---|
| rumor | 306 + 236 | 166 + 155 | 6,7 / 5,0 ms |
| fortress | 269 + 208 | 178 + 156 | 5,7 / 4,6 ms |
| formataai | 314 + 240 | 170 + 154 | 6,5 / 4,7 ms |
| ankiana | 326 + 236 | 178 + 159 | 6,7 / 4,7 ms |
| labia | 133 + 67 | 59 + 56 | 4,0 / 3,6 ms |
| carreira | 229 + 167 | 156 + 132 | 5,4 / 4,5 ms |
Censo das lojas (`--shopcensus`): 15 a 18 programas (6 a 8 com luz), 150 a 250 materiais únicos, 160 a 260 malhas soltas
(causa dos draws), 17 a 81 Label3D. A fusão (mesmo visual: diferença média 0,1/255) fica DESLIGADA por padrão: a 1ª
entrada a frio subiu para 4 a 6 s. Com a câmera olhando para dentro, a 1ª entrada compila tudo de uma vez atrás do véu
(rumor 4,8 s a frio); antes isso acontecia aos poucos ao virar a câmera (as travadas ao olhar em volta).

### Não feito nesta rodada
- Troca de idioma ao vivo (hoje recarrega): o jogo monta os textos uma vez com `L.t()` em centenas de lugares e os anúncios
  são atlas por língua; precisa de um sinal `L.changed` reaplicado por HUD/painéis e troca de atlas/letreiros na cidade.
- Textos 3D em atlas (corte de 300 a 400 draws), loja pré-montada antes da porta (< 50 ms), lojas no shader próprio.
  Achado: o "toon escuro" da rodada 2 era a referência errada (a captura de comparação tinha a textura de luz vazia,
  que vira branca); o visual escuro das lojas é o de produção. Vale retestar a migração.
- Meta do celular (8 s após o download): exige cidade pré-montada no build (.scn) e streaming por distância.

Capturas: `docs/perf/marcador_entrada_r3.png`, `docs/perf/lojas_entrada_r3.png`.
