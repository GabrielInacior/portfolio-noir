# Áudio do portfólio noir

Tudo gerado localmente (Stable Audio Open + triagem CLAP), sem banco de sons pronto. Skill:
`.claude/skills/portfolio-audio`. Catálogo: `tools/audio/noir_catalog.py`. Motor: `tools/audio/noir_prod.py`.
Página de revisão (ouvir candidatos e escolhidos): `C:\Users\gabri\Downloads\Portfolio_Noir_Sons\index.html`
(gerar de novo com `noir_prod.py page`).

## O que existe
- **Trilha**: `assets/audio/music/bloodlines_ost.mp3` ("Portfolio Music Noir", trilha original de Gabriel Inácio, 213 s, 128 kbps), única música.
- **Ambientes 2D em loop** (`assets/audio/amb/`): chuva na rua, chuva forte, chuva na janela (interiores),
  cidade à noite, bar, sala de servidores, escritório do detetive, fliperama, estúdio, laboratório.
- **Loops 3D**: zumbido de neon (em cada fachada de loja), vapor (em cada bueiro).
- **Efeitos** (`assets/audio/sfx/<id>_<n>.ogg`, variações sorteadas com leve mudança de tom): carro passando,
  buzina, passos (asfalto molhado, madeira, carpete, piso de loja, poça), interface (mirar, abrir/fechar painel,
  botão, notificação, contador), porta da loja com sininho, porta fechando, gaveta, telefone tocando e
  atendendo, tecla e sineta da máquina de escrever, interruptor, monitor ligando, moeda e bip do fliperama, papel.

## Mixagem
- Barramentos criados por código em `Audio`: **Music**, **Amb** (camas), **SFX** (efeitos e 3D, com reverb).
- Zona **rua**: chuva + cidade; reverb aberto. Zona **loja** (detectada quando o jogador entra no museu):
  chuva na janela + cama do estilo da loja (detetive, cyber, arcade, bar, studio, study, startup, lab, career),
  reverb de sala pequena, passos no piso da loja; porta com sininho ao entrar e porta fechando ao sair.
- Painel/diálogo aberto (`Audio.duck(true)`, que os painéis já chamam): som de abrir/fechar, música e
  ambientes descem.
- Limite de 14 vozes 2D simultâneas; 3D com atenuação inversa por distância.
- Nada toca antes de `Audio.start()` (ENTRAR). O botão de som cala o Master; preferências salvas em
  `user://audio.cfg` (no navegador, armazenamento local).

## API (para quem cria cena ou objeto novo)
```gdscript
Audio.play("porta_loja")                       # efeito 2D
Audio.play_at("buzina", global_pos)             # efeito 3D numa posição
Audio.loop_at(no3d, "loop_neon", -12.0, 2.2)    # loop 3D preso a um nó
Audio.on_action("drawer", item)                 # som de objeto da loja (switch, phone, drawer,
                                                #   typewriter, monitor/github/terminal, arcade, doc)
Audio.arcade_bleep()                            # minijogos (já chamado em breakout, snake, fortress_td)
Audio.set_music_volume(0.0..1.0)
Audio.set_sfx_volume(0.0..1.0)
```
Automático (não precisa chamar): zona e camas, passos, neon/vapor da cidade, carros que passam perto,
tique ao mirar objeto examinável, som do objeto quando o painel dele abre (pelo item mirado), interruptor,
telefone tocando enquanto o item tem `ring.on`, contador de examinados (`museum.examined`).

## Como gerar/trocar um som
1. Editar/adicionar o item em `tools/audio/noir_catalog.py` (prompt concreto em inglês, `clap` literal).
2. `C:/Users/gabri/ai_audio/venv/Scripts/python tools/audio/noir_prod.py gen --ids <id>`
3. `... score --ids <id>` (nota CLAP − penalidades; escolhe os melhores) e `... page` para ouvir.
4. `... install --ids <id>` grava os `.ogg` no jogo.
