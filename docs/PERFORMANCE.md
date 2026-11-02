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
