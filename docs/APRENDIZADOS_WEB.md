# Aprendizados de web e performance (herdados do RUMOR)

Lições concretas pagas no RUMOR, aplicadas aqui para rodar liso no celular e no desktop.

## Nitidez 3D
- `SubViewportContainer` com o tamanho em pixels reais e reduzido na mesma proporção (`UI.render_scale`)
  deixa a imagem 3D chegar 1:1 na tela (sem esticar = sem borrão). Ver `case_scene.gd` do RUMOR.
- **Resolução adaptativa por FPS**: mede a fluidez a cada 1,5 s; se cair de ~40 fps, baixa um degrau;
  se sobrar, sobe até o máximo da tela. **Desligar em modo gravação** (`Engine.get_write_movie_path()`),
  senão o vídeo sai borrado.

## Performance
- Renderizador **GL Compatibility**, export web **sem threads** (`thread_support=false`).
- **Sem sombras no mobile**; sombra direcional só no desktop. Emissão (unshaded) no lugar de luz
  sempre que possível: neon, janelas, letreiros são materiais emissivos, não luzes.
- **MultiMesh** para repetição barata (janelas do skyline = um só draw call).
- Poucas `OmniLight3D` dinâmicas; o resto é emissão + halos aditivos (quad `BLEND_MODE_ADD`), que
  no Compatibility substituem o glow/bloom (limitado).
- Névoa por profundidade colorida dá clima sem custo.

## Web e áudio
- Shell HTML com carregamento noir e botão **ENTRAR**: a web só toca áudio e captura o mouse
  depois de um gesto do usuário. O ENTRAR destrava a OST e o pointer lock.
- `beforeunload` para confirmar saída acidental (no RUMOR).
- `.gz` pré-comprimido dos arquivos grandes (`index.wasm`, `index.pck`) no build.
- `content_scale` troca retrato/paisagem; UI feita para celular em pé primeiro.

## Texto e UI
- **Guarda de texto vertical**: um vigia confere o tamanho real dos rótulos e desliga a quebra de
  linha quando o texto fica espremido a ponto de virar coluna de letras. No portfólio, os rótulos
  de nome/tag usam `AUTOWRAP_OFF` explícito.
- Rolagem por toque na web: `TouchScroll` próprio lido no `_input` (o drag nativo do
  `ScrollContainer` falha na web). Importar do RUMOR quando houver leitor de README rolável.

## Captura e gravação
- Testes e capturas sempre mudos (`--audio-driver Dummy`).
- Gravação de vídeo vertical: `override.cfg` com janela sem borda (`borderless=true`,
  `initial_position=(0,0)`) pode passar do tamanho do monitor e gravar 1080x1920 nítido.
- Mojibake "Ã©" ao ler stdout do node no Windows: redecodificar byte a byte (latin1 -> utf8).
