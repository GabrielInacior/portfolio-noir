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
