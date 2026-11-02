"""Catálogo de sons do portfólio noir (dado puro; o motor é `noir_prod.py`).

Cada item:
  id      nome do arquivo no jogo (game/assets/audio/sfx/<id>_<n>.ogg ou amb/<id>.ogg)
  kind    "bed"  = ambiente 2D em loop (estéreo, sem emenda)
          "spot" = loop 3D mono (neon, vapor) com atenuação
          "one"  = efeito curto (mono)
  cat     categoria de loudness (tools/audio/sfx_master.TARGETS)
  gen_s   segundos pedidos ao modelo
  max_dur duração máxima depois do acabamento (one-shots)
  n       candidatos gerados
  keep    variações que vão pro jogo (sons frequentes ganham 3 a 4)
  prompt  texto de geração (inglês, concreto: ação + material + distância)
  clap    texto curto e literal para a triagem CLAP
  noisy   ruído é o próprio som (chuva, vapor): não penalizar planura
  allow   negativos do CLAP que NÃO valem aqui (ex.: burburinho de bar tem fala indistinta)
"""
from __future__ import annotations

STYLE_ONE = ("high quality professional game sound effect, clean, crisp, close-miked, "
             "isolated one-shot, silent background")
STYLE_UI = ("high quality professional game user interface sound, clean, short, soft, pleasant, "
            "isolated, silent background")
STYLE_AMB = ("high quality field recording, seamless ambience, steady, natural, stereo, "
             "professional game ambience loop")
NEG_PROMPT = ("music, melody, song, orchestra, singing, speech, talking, vocals, low quality, "
              "distorted, clipping, static, hiss, muffled, lo-fi")
NEG_AMB = ("music, melody, song, singing, low quality, distorted, clipping, sudden loud noise")

ITEMS: list[dict] = [
    # ── ambientes 2D em loop ────────────────────────────────────────────────
    {"id": "amb_chuva_rua", "kind": "bed", "cat": "amb", "gen_s": 20, "n": 4, "keep": 1, "noisy": True,
     "prompt": "steady rain falling on a city street at night, rain drops on pavement and puddles, water dripping from gutters",
     "clap": "rain falling on a city street", "label": "Chuva na rua"},
    {"id": "amb_chuva_forte", "kind": "bed", "cat": "amb", "gen_s": 20, "n": 4, "keep": 1, "noisy": True,
     "prompt": "heavy rain pouring on a city street at night, strong downpour, distant rolling thunder",
     "clap": "heavy rain with distant thunder", "label": "Chuva forte"},
    {"id": "amb_chuva_interior", "kind": "bed", "cat": "amb_soft", "gen_s": 20, "n": 4, "keep": 1, "noisy": True,
     "prompt": "rain heard from inside a quiet small room, rain drops tapping on a window glass, soft",
     "clap": "rain on a window heard from inside", "label": "Chuva na janela (interior)"},
    {"id": "amb_cidade_noite", "kind": "bed", "cat": "amb_soft", "gen_s": 20, "n": 4, "keep": 1, "noisy": True,
     "prompt": "night city ambience heard from a street, continuous distant traffic rumble, occasional far away siren",
     "clap": "distant city traffic ambience", "label": "Cidade à noite"},
    {"id": "amb_bar", "kind": "bed", "cat": "amb_soft", "gen_s": 20, "n": 4, "keep": 1, "noisy": True,
     "allow": ["a person speaking"],
     "prompt": "quiet bar ambience at night, low indistinct murmur of people, glasses clinking, bottles on wood",
     "clap": "bar ambience with murmur and glasses clinking", "label": "Bar (burburinho)"},
    {"id": "amb_servidores", "kind": "bed", "cat": "amb_soft", "gen_s": 20, "n": 4, "keep": 1, "noisy": True,
     "prompt": "server room ambience, computer cooling fans humming, steady air flow, occasional soft electronic beeps",
     "clap": "server room fans humming", "label": "Sala de servidores"},
    {"id": "amb_escritorio", "kind": "bed", "cat": "amb_soft", "gen_s": 20, "n": 4, "keep": 1,
     "prompt": "quiet office room at night, wall clock ticking, ceiling fan whirring softly",
     "clap": "clock ticking and ceiling fan in a quiet room", "label": "Escritório do detetive"},
    {"id": "amb_fliperama", "kind": "bed", "cat": "amb_soft", "gen_s": 20, "n": 4, "keep": 1,
     "allow": ["music"],
     "prompt": "retro video arcade room ambience, many arcade cabinets playing beeps and blips in the background, crowd-free, steady",
     "clap": "video game arcade ambience", "label": "Fliperama"},
    {"id": "amb_estudio", "kind": "bed", "cat": "amb_soft", "gen_s": 20, "n": 4, "keep": 1, "noisy": True,
     "prompt": "quiet recording studio room tone, soft air conditioning hum, faint electronic equipment hum",
     "clap": "quiet room tone with air conditioning hum", "label": "Estúdio"},
    {"id": "amb_lab", "kind": "bed", "cat": "amb_soft", "gen_s": 20, "n": 4, "keep": 1, "noisy": True,
     "prompt": "quiet technology laboratory ambience, soft computer hum, gentle electronic beeps, air vent",
     "clap": "computer lab hum with soft beeps", "label": "Laboratório"},
    # ── loops 3D (mono, presos a objetos) ──────────────────────────────────
    {"id": "loop_neon", "kind": "spot", "cat": "amb", "gen_s": 12, "n": 6, "keep": 1, "noisy": True,
     "prompt": "buzzing neon sign, electrical hum with light crackle, close",
     "clap": "electrical buzzing neon sign", "label": "Zumbido de neon"},
    {"id": "loop_vapor", "kind": "spot", "cat": "amb", "gen_s": 12, "n": 6, "keep": 1, "noisy": True,
     "prompt": "continuous low steam vent hiss with soft rumble, gentle airflow from a pipe",
     "clap": "steam hissing", "label": "Vapor do bueiro"},
    # ── rua ─────────────────────────────────────────────────────────────────
    {"id": "carro_passa", "kind": "one", "cat": "interact", "gen_s": 6, "max_dur": 5.0, "n": 8, "keep": 3, "noisy": True,
     "prompt": "a single car driving past on a wet street, tires on wet asphalt, passing by",
     "clap": "car passing by on a wet road", "label": "Carro passando"},
    {"id": "buzina", "kind": "one", "cat": "interact", "gen_s": 3, "max_dur": 1.6, "n": 8, "keep": 2,
     "prompt": "a car horn honking once in a city street, slightly distant",
     "clap": "car horn honk", "label": "Buzina"},
    # ── passos ──────────────────────────────────────────────────────────────
    {"id": "passo_asfalto", "kind": "one", "cat": "footstep", "gen_s": 2, "max_dur": 0.45, "n": 10, "keep": 4,
     "prompt": "one footstep of a leather shoe stepping on a wet concrete sidewalk, close-up foley",
     "clap": "footstep on wet concrete", "label": "Passo: asfalto molhado"},
    {"id": "passo_madeira", "kind": "one", "cat": "footstep", "gen_s": 2, "max_dur": 0.45, "n": 10, "keep": 4,
     "prompt": "a single footstep on a wooden floor, leather shoe, one step",
     "clap": "a single footstep on a wooden floor", "label": "Passo: madeira"},
    {"id": "passo_carpete", "kind": "one", "cat": "footstep", "gen_s": 2, "max_dur": 0.4, "n": 10, "keep": 4,
     "prompt": "one soft footstep on a thick carpet, muffled thud, close-up foley",
     "clap": "a soft footstep on carpet", "label": "Passo: carpete"},
    {"id": "passo_piso", "kind": "one", "cat": "footstep", "gen_s": 2, "max_dur": 0.45, "n": 10, "keep": 4,
     "prompt": "one footstep of a hard shoe heel on a ceramic tile floor, close-up foley",
     "clap": "a single footstep on a tile floor", "label": "Passo: piso de loja"},
    {"id": "passo_poca", "kind": "one", "cat": "footstep", "gen_s": 2, "max_dur": 0.6, "n": 8, "keep": 3, "noisy": True,
     "prompt": "one boot stepping into a shallow rain puddle, water splash, close-up foley",
     "clap": "a footstep splashing in a puddle", "label": "Passo: poça"},
    # ── interface ───────────────────────────────────────────────────────────
    {"id": "ui_mira", "kind": "one", "cat": "ui", "gen_s": 1, "max_dur": 0.15, "n": 8, "keep": 1,
     "prompt": "a tiny soft wooden tick, very short and quiet, user interface hover sound",
     "clap": "a soft short tick", "label": "Mirar em objeto"},
    {"id": "ui_abrir", "kind": "one", "cat": "ui", "gen_s": 2, "max_dur": 0.5, "n": 8, "keep": 1,
     "prompt": "a soft quick paper folder opening swoosh, user interface panel open",
     "clap": "soft paper swoosh", "label": "Abrir painel"},
    {"id": "ui_fechar", "kind": "one", "cat": "ui", "gen_s": 2, "max_dur": 0.4, "n": 8, "keep": 1,
     "prompt": "a short soft paper swish, quick and light, user interface close",
     "clap": "soft short swoosh", "label": "Fechar painel"},
    {"id": "ui_botao", "kind": "one", "cat": "ui", "gen_s": 1, "max_dur": 0.2, "n": 8, "keep": 2,
     "prompt": "a soft click of a plastic button, short",
     "clap": "a soft button click", "label": "Botão"},
    {"id": "ui_notificacao", "kind": "one", "cat": "ui", "gen_s": 2, "max_dur": 0.9, "n": 8, "keep": 1,
     "allow": ["music"],
     "prompt": "a soft pleasant two note notification chime, glassy",
     "clap": "a soft notification chime", "label": "Notificação"},
    {"id": "ui_contador", "kind": "one", "cat": "ui", "gen_s": 2, "max_dur": 0.6, "n": 8, "keep": 1,
     "allow": ["music"],
     "prompt": "a short soft bright sparkle, item discovered, rising",
     "clap": "a short bright sparkle", "label": "Item examinado (contador)"},
    # ── objetos interativos ─────────────────────────────────────────────────
    {"id": "porta_loja", "kind": "one", "cat": "interact", "gen_s": 3, "max_dur": 2.2, "n": 8, "keep": 1,
     "prompt": "a shop door opening with a small brass bell jingling above the door",
     "clap": "shop door opening with a bell jingle", "label": "Porta da loja com sininho"},
    {"id": "porta_fecha", "kind": "one", "cat": "interact", "gen_s": 2, "max_dur": 1.0, "n": 8, "keep": 1,
     "prompt": "a wooden door closing softly with a latch click",
     "clap": "a door closing with a latch click", "label": "Porta fechando"},
    {"id": "gaveta", "kind": "one", "cat": "interact", "gen_s": 2, "max_dur": 1.2, "n": 8, "keep": 1,
     "prompt": "opening a heavy steel filing cabinet drawer, metal sliding on ball bearing rails, close-up foley",
     "clap": "a metal drawer sliding open", "label": "Gaveta do arquivo"},
    {"id": "telefone_toca", "kind": "one", "cat": "interact", "gen_s": 4, "max_dur": 2.8, "n": 8, "keep": 1,
     "prompt": "an old rotary telephone bell ringing, one ring",
     "clap": "an old telephone ringing", "label": "Telefone tocando"},
    {"id": "telefone_atende", "kind": "one", "cat": "interact", "gen_s": 2, "max_dur": 0.8, "n": 8, "keep": 1,
     "prompt": "lifting an old bakelite telephone handset off its cradle, hook switch click and rattle, close-up foley",
     "clap": "telephone handset lifted with a click", "label": "Atender o telefone"},
    {"id": "maquina_tecla", "kind": "one", "cat": "interact", "gen_s": 1, "max_dur": 0.25, "n": 10, "keep": 4,
     "lufs": -27.0,
     "prompt": "a single typewriter key strike, mechanical metal click",
     "clap": "a typewriter key click", "label": "Tecla da máquina de escrever"},
    {"id": "maquina_sineta", "kind": "one", "cat": "interact", "gen_s": 3, "max_dur": 1.6, "n": 8, "keep": 1,
     "prompt": "typewriter carriage return bell ding followed by a mechanical slide",
     "clap": "typewriter bell ding", "label": "Sineta da máquina de escrever"},
    {"id": "interruptor", "kind": "one", "cat": "interact", "gen_s": 1, "max_dur": 0.3, "n": 8, "keep": 2,
     "prompt": "a wall light switch flicked, plastic click",
     "clap": "a light switch click", "label": "Interruptor"},
    {"id": "monitor_liga", "kind": "one", "cat": "interact", "gen_s": 3, "max_dur": 1.5, "n": 8, "keep": 1,
     "prompt": "an old CRT monitor turning on, electric click and rising high whine with static",
     "clap": "an old CRT monitor turning on", "label": "Monitor ligando"},
    {"id": "fliper_moeda", "kind": "one", "cat": "interact", "gen_s": 2, "max_dur": 0.9, "n": 8, "keep": 1,
     "prompt": "a coin inserted into an arcade machine coin slot, coin dropping inside metal",
     "clap": "a coin dropping into an arcade machine", "label": "Moeda no fliperama"},
    {"id": "fliper_bleep", "kind": "one", "cat": "ui", "gen_s": 1, "max_dur": 0.35, "n": 10, "keep": 3,
     "allow": ["music"],
     "prompt": "a retro 8-bit arcade video game bleep, chiptune blip",
     "clap": "a retro video game bleep", "label": "Bleep do fliperama"},
    {"id": "papel", "kind": "one", "cat": "interact", "gen_s": 2, "max_dur": 0.8, "n": 8, "keep": 2, "noisy": True,
     "prompt": "crisp paper sheet handled and rustled, close-up foley, dry paper crinkle",
     "clap": "paper crinkling and rustling", "label": "Papel"},
]

BY_ID = {it["id"]: it for it in ITEMS}
