# Props 3D e arte das lojas-museu

Estado atual: os objetos das lojas e os móveis de ambiente são montados com primitivas bem
compostas (`game/scripts/museum_objects.gd`), no estilo pincelado da cidade. Funciona e é leve,
mas ainda não tem o acabamento "estilizado moderno limpo" dos personagens novos.

## Próximo passo: props de verdade (Meshy / Stable Diffusion)

Ferramentas liberadas nesta fase (ler a chave do arquivo, nunca imprimir nem commitar):
- **Meshy** (exclusiva deste projeto): chave em `C:/Users/gabri/.meshy_key`. text-to-3D ou
  image-to-3D. Polycount baixo por prop (300 a 3k tris conforme tamanho), textura 512 (1024 só em
  peças grandes), consolidar em atlas quando possível.
- **Stable Diffusion local** (RTX 4070 Ti, sem custo):
  `C:/Project/tools-ai/sd/Scripts/python C:/Project/tools-ai/gen.py "prompt" saida.png [--modelo leve|xl] [--lado 512] [--n 4] [--tile]`.
  Usar para texturas de fachada/asfalto/madeira (`--tile`), quadros e cartazes das lojas e
  conceitos de prop para o Meshy image-to-3D. Manter prompts no tema noir/neon do portfólio.
- **gpt-image-2**: reservar para hero art de mais qualidade.

### Props prioritários por loja (para gerar e substituir as primitivas)
- **RUMOR (escritório):** máquina de escrever, abajur de mesa, quadro de cortiça com polaroides e
  barbante, cadeira de madeira, luminária de teto.
- **Fortress (fliperama):** gabinete de fliperama completo, cartas/miniaturas, troféu.
- **InacioCyber (lab):** rack de servidor, monitor de terminal, cadeado/HSM, bancada.
- **BuscaVagas / Orbix / AirMessage / MBM (escritório):** monitor, mesa, cadeira de escritório,
  arquivo, telefone.
- **FormataAI / Lábia (estúdio/bar):** microfone de estúdio, mesa de som, balcão de bar, garrafas.
- **Rua:** poste, hidrante, lixeira, banco, placa, carro parado, caixa de correio.

### Pipeline sugerido
1. Conceito 2D no estilo dos personagens (SD `--modelo xl` ou gpt-image-2), fundo neutro.
2. Meshy image-to-3D → GLB low-poly, textura 512.
3. Importar em `game/assets/props/<nome>.glb`, carregado por loja/zona (não no .pck inicial).
4. Aplicar o shader toon do projeto para casar a luz suave do modelo com o neon/névoa da cena
   (rim light colorida, emissão nas telas, fog).
5. Trocar a chamada correspondente em `museum_objects.gd` por `load()` do GLB.

O manifesto dos itens de cada loja (título, texto, imagem, kind) está em
`game/assets/museum/_items/<projeto>.json` e `_lab.json`, gerado por `tools/museum/build_items.py`.
Trocar `kind: "prop"` + `model: "<nome>"` para apontar ao GLB novo é suficiente.
