# LÁBIA

Jogo cooperativo de comédia (1 a 4 jogadores) em que vocês são vigaristas e aplicam golpes **falando de verdade,
pelo microfone**, com NPCs movidos por uma IA local. Os NPCs entendem o que você diz, se irritam, riem, lembram do que
ouviram e chamam a segurança. A IA interpreta; o código decide.

> *A co-op comedy heist game (1–4 players): you talk to AI-driven NPCs with your real voice. Portuguese, English and Spanish.*

## As fases
1. **Balada Neon** — pegue o celular do DJ Tatu na área VIP.
2. **Festa na Mansão do Marcão** — o uísque de 18 anos está no cofre.
3. **Domingão do Zeca** — o Troféu Microfone de Ouro, ao vivo na TV.
4. **Casamento na Chácara** — os noivinhos de ouro do topo do bolo.
5. **Noite VIP no Museu da Bola** — a Taça Dourada, protegida por lasers.

Cada fase tem 5–6 NPCs com voz e personalidade próprias, vários caminhos (lábia, itens, suborno, disfarce ou o atalho
arriscado de convencer o chefão), guardas de ronda, eventos do caos (blecaute, karaokê, hora da dança...), missões
secretas por jogador, disfarces absurdos para improvisar e prêmios no fim (Lábia de Ouro, Pé-Frio, Palhaço da Noite).

## Controles
| Tecla | Ação |
|---|---|
| WASD / mouse | andar / olhar (primeira pessoa) |
| **V** (segurar) | falar com o NPC na mira — e os amigos perto ouvem |
| **B** (segurar) | falar só com o time (o NPC não entende) |
| T | digitar em vez de falar |
| E | pegar item / abrir porta com o item certo |
| 1–6 / G | escolher item / mostrar o item ao NPC |
| Z X C F | dançar, acenar, rir, apontar |
| Esc | menu (Configurações, sair) · F3 desempenho · F11 tela cheia |

## Jogar com amigos
Um jogador **hospeda** (a IA roda no PC dele) e os outros **entram** pelo IP. A sala de espera mostra o IP da rede local
e tenta abrir a porta no roteador sozinha (UPnP); se não conseguir, libere a porta **UDP 7777**. O host escolhe a fase e,
no fim de cada golpe, o próximo — o placar da noite soma tudo.

## Requisitos (quem hospeda)
- Windows 10/11, **placa NVIDIA** com CUDA. 16 GB de vídeo para o cérebro completo (Gemma 12B) + voz com emoção; com
  menos, o jogo escolhe sozinho o cérebro **Leve** (E4B) — dá para mudar em Configurações › IA.
- Quem só entra na partida precisa bem menos (Whisper para o próprio microfone + a voz dos NPCs; a voz com emoção pode
  ser desligada nas Configurações).

## Instalação (a partir do código)
1. [Godot 4.7](https://godotengine.org) e Python 3.12.
2. Plugins e modelos (não vão para o git):
   ```
   python tools/install_plugins.py           # NobodyWho (IA/voz) e whisper.cpp
   python tools/download_model.py e4b        # cérebro leve; o 12B: huggingface.co/google/gemma-4-12B-it-qat-q4_0-gguf -> models_llm/
   python tools/download_model.py stt        # reconhecimento de voz (Whisper)
   powershell tools/tts_server/setup.ps1     # voz com emoção (Chatterbox)
   ```
3. Abra o projeto no Godot e rode `scenes/main.tscn` (é a cena principal).

## Para desenvolvedores
- Testes: `godot_console --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json`
- Partidas automáticas, gravação de telas e todas as receitas (personagens, cenários, vozes, UI, idiomas, fases) estão
  nas skills em `.claude/skills/labia-*` e em `docs/` (decisões em `docs/DECISIONS.md`).
