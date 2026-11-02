---
name: portfolio-audio
description: OBRIGATÓRIA antes de gerar, refazer, trocar ou integrar sons do portfólio noir (ambientes, passos, efeitos de interação, trilha). Pipeline de IA local (Stable Audio Open + triagem CLAP) herdada do FortressChaos, régua de qualidade, mixagem espacial no Godot e armadilhas já pagas.
---
# Sons do portfólio noir

Leia antes: `docs/AUDIO.md` (o que existe, API do jogo, onde cada som toca) e o catálogo
`tools/audio/noir_catalog.py`. Pipeline-mãe documentada no FortressChaos:
`C:\Project\game\docs\audio\pipeline_sfx.md`.

## Régua (o som só entra se passar)
- Limpo: ataque nítido + corpo + cauda curta. Sem chiado, estalo, ruído de fundo, grave embolado nem agudo
  estridente (o `master` corta sub < 40 Hz, doma 2 a 5 kHz e agudo dominante).
- Frequentes (passos, tecla da máquina, mira, bip do fliperama): curtos, 3 a 4 variações, ±3 a 8% de tom no jogo.
- Ambientes: loop SEM emenda (cruzamento de 2 s no fim/começo), estáveis, sem evento alto isolado.
  Camas 2D estéreo; loops presos a objetos (neon, vapor) mono para o 3D.
- Hierarquia de volume (LUFS, `sfx_master.TARGETS`): interface (-28,5) < passos (-22,5) < interação (-23,5)
  ; ambientes -26 (rua) e -30 (internos e suaves). A OST manda; ambiente desce quando painel abre.
- CLAP com o texto-alvo vencendo os negativos (música, fala, chiado, distorção, baixa qualidade, silêncio);
  burburinho de bar e bleeps de fliperama liberam "fala"/"música" pelo campo `allow`.
- Decisão final é ouvindo a página de revisão (`noir_prod.py page`).

## Pipeline (sempre com o Python do venv de áudio)
`C:/Users/gabri/ai_audio/venv/Scripts/python tools/audio/noir_prod.py gen|score|install|page [--ids a,b] [--kind bed|spot|one]`
- Pesos em `C:\Users\gabri\ai_audio\hf_cache`; token HF em `C:\Users\gabri\.hf_token` (nunca imprimir/commitar).
- Brutos/notas fora do repo em `C:/Users/gabri/ai_audio/noir/`; instalados em `game/assets/audio/sfx/<id>_<n>.ogg`
  e `game/assets/audio/amb/<id>.ogg` (Vorbis). Total de áudio além da OST < 6 MB.
- Bruto SEMPRE em FLOAT (a saída do modelo passa de 1,0; PCM_16 clipava). Bloco latente curto (128/256/512)
  conforme a duração pedida. Cada lote dentro de `gpu_lock` (a GPU é dividida com render, SD e outros agentes).
- Prompt concreto (ação + material + distância), sem "no X" no positivo; o proibido mora no negativo.

## Godot
- Autoload `Audio` (`game/scripts/audio.gd`): barramentos Music/Amb/SFX criados por código, reverb por zona,
  camas por zona (rua: chuva + cidade; loja: chuva na janela + cama do estilo da loja), passos por piso,
  emissores 3D automáticos (neon nas fachadas, vapor nos bueiros, carros que passam), som dos objetos
  detectado pelo item mirado quando o painel abre, telefone tocando, interruptor, bip dos minijogos.
- Nada toca antes de `Audio.start()` (botão ENTRAR; política de autoplay do navegador).
- Teste sempre com `--audio-driver Dummy`.

## Proibido
- Bancos de sons prontos (Freesound etc.) e modelos sem uso comercial (AudioGen/MusicGen, CC-BY-NC).
- Stable Audio Open: uso comercial liberado abaixo de US$ 1 mi/ano de receita.
