"""Acabamento padronizado de SFX ("master" de efeito de jogo).

Cadeia, na ordem, e por que cada passo existe:
  1. mono + 44,1 kHz      — o `AudioStreamPlayer3D` espacializa sozinho; estéreo
                            gravado brigaria com a posição 3D, e 44,1 kHz/16 bit
                            é o que os .wav do jogo já usam (o import não muda).
  2. passa-alta 40 Hz     — sub abaixo de 40 Hz não sai em caixa de notebook nem
                            em fone comum, mas ocupa headroom e soma em dezenas de
                            vozes; o modelo gerador costuma deixar esse "ronco".
                            Filtro CAUSAL (não fase zero) pra não criar pré-eco
                            antes do transiente.
  2b. presença 2–5 kHz   — corte proporcional ao excesso (anti-fadiga em repetição).
  2c. expansor de cauda  — some com o chiado de fundo da geração sem degrau.
  3. corte de silêncio   — som atrasado em relação ao clarão visual parece lag;
                            mantemos 2 ms antes do início pra não decepar o ataque.
  4. duração máxima       — som repetido longo embola com as outras vozes; o
                            corte vem com fade cosseno, nunca seco.
  5. fades curtos         — 2 ms na entrada (sem clique de DC), fade de cauda.
  6. loudness (LUFS)      — alvo por categoria técnica do jogo (ver TARGETS).
  7. limitador -1 dBTP    — pico verdadeiro (4x) com lookahead, pra a soma de
                            vozes e a conversão do Godot não estourarem.

Uso como biblioteca (`master(x, sr, category, max_dur)`) ou linha de comando:
    python sfx_master.py entrada.wav saida.wav --category shot [--max-dur 0.8]
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import butter, resample_poly, sosfilt

sys.path.insert(0, str(Path(__file__).parent))
from sfx_common import envelope, lufs, true_peak_db  # noqa: E402

SR = 44100
CEILING_DBTP = -1.0

# Alvo de LUFS por categoria TÉCNICA do jogo (`category` da receita em
# `sfx_library.gd`, a mesma que liga o som ao limitador de vozes do pool).
#
# Por que não os números "de livro" (UI -20, combate -16, impacto -14, chefe -12):
# o jogo já tem uma hierarquia por FREQUÊNCIA DE OCORRÊNCIA (o que empilha
# vozes fica embaixo; `LOUDNESS_TARGETS` em `sfx_library.gd`) e a mixagem dele —
# ganhos por id no `AudioDirector`, ducking, tetos de voz — foi afinada em cima
# dela. Trocar a régua junto com o timbre misturaria duas mudanças.
#
# Aquela tabela usa uma APROXIMAÇÃO de loudness (`AudioDSP.loudness`); medindo os
# 284 .wav atuais com BS.1770 de verdade (auditoria de 31/10), a mediana fica
# ~4,4 dB abaixo do alvo nominal. Então aqui vale: alvo do jogo − 4,4 dB,
# arredondado a 0,5. O nível ABSOLUTO segue ajustável no jogo
# (`LOUDNESS_OFFSET_DB`, ganhos por id); o que este acabamento trava é a
# HIERARQUIA: UI < tiro/impacto < morte/obra < magia/destruição/stinger < Núcleo.
HIERARCHY_OFFSET_DB = -4.4
_GAME_TARGETS = {
    "ui": -24.0, "select": -21.0, "resource": -21.0, "shot": -19.0, "impact": -19.0,
    "enemy_hurt": -20.0, "enemy_death": -18.0, "footstep": -18.0, "build": -17.0,
    "destruction": -14.0, "ui_world": -15.0, "core": -13.0, "stinger": -14.0, "default": -19.0,
    # portfólio noir: interação com objeto (porta, gaveta, telefone) e ambientes em loop
    "interact": -19.0, "amb": -26.0, "amb_soft": -30.0,
}
TARGETS = {k: round((v + HIERARCHY_OFFSET_DB) * 2) / 2 for k, v in _GAME_TARGETS.items()}


def to_mono_44k(x: np.ndarray, sr: int) -> np.ndarray:
    if x.ndim == 2:
        x = x.mean(axis=1)
    if sr != SR:
        from math import gcd
        g = gcd(SR, sr)
        x = resample_poly(x, SR // g, sr // g)
    return x.astype(np.float64)


def highpass(x: np.ndarray, hz: float = 40.0) -> np.ndarray:
    sos = butter(4, hz, btype="highpass", fs=SR, output="sos")
    return sosfilt(sos, x)


def peaking(x: np.ndarray, f0: float, gain_db: float, q: float = 1.0) -> np.ndarray:
    """Biquad de pico (RBJ). Usado com ganho negativo pra domar 2–5 kHz."""
    from scipy.signal import lfilter
    A = 10 ** (gain_db / 40)
    w = 2 * np.pi * f0 / SR
    al = np.sin(w) / (2 * q)
    b = np.array([1 + al * A, -2 * np.cos(w), 1 - al * A])
    a = np.array([1 + al / A, -2 * np.cos(w), 1 - al / A])
    return lfilter(b / a[0], a / a[0], x)


def tame_presence(x: np.ndarray, max_cut_db: float = 4.0) -> tuple[np.ndarray, float]:
    """Corte proporcional em ~3,2 kHz quando a faixa de presença sobressai.

    É a faixa onde o ouvido é mais sensível: um tiro que tem um pico ali soa
    "nítido" na primeira vez e irritante na centésima. Só corta o EXCESSO em
    relação às bandas vizinhas (harsh_db acima de 3 dB), até `max_cut_db` —
    som equilibrado passa intacto, e o brilho de cima (5–10 kHz) fica.
    """
    from sfx_common import cleanliness
    h = cleanliness(x, SR)["harsh_db"]
    cut = float(np.clip(h - 3.0, 0.0, max_cut_db))
    if cut <= 0.1:
        return x, 0.0
    return peaking(x, 3200.0, -cut, 0.9), cut


def high_shelf(x: np.ndarray, f0: float, gain_db: float, q: float = 0.7) -> np.ndarray:
    """Prateleira de agudos (RBJ). Ganho negativo = tira o "ar" demais."""
    from scipy.signal import lfilter
    A = 10 ** (gain_db / 40)
    w = 2 * np.pi * f0 / SR
    al = np.sin(w) / (2 * q)
    cw = np.cos(w)
    b = np.array([A * ((A + 1) + (A - 1) * cw + 2 * np.sqrt(A) * al),
                  -2 * A * ((A - 1) + (A + 1) * cw),
                  A * ((A + 1) + (A - 1) * cw - 2 * np.sqrt(A) * al)])
    a = np.array([(A + 1) - (A - 1) * cw + 2 * np.sqrt(A) * al,
                  2 * ((A - 1) - (A + 1) * cw),
                  (A + 1) - (A - 1) * cw - 2 * np.sqrt(A) * al])
    return lfilter(b / a[0], a / a[0], x)


def tame_air(x: np.ndarray, sr: int, max_cut_db: float = 8.0, ok_frac: float = 0.35) -> np.ndarray:
    """Doma agudo estridente: corta acima de ~7 kHz quando ele DOMINA o som.

    Função nova (não está dentro de `master()`, pra não mudar o som de quem já
    usa a biblioteca): chame ANTES do `master`. O gerador às vezes devolve moeda,
    brilho mágico e armadura com 80–97% da energia acima de 6 kHz — soa fino,
    chiado e cansa em repetição. Corte proporcional ao excesso sobre `ok_frac`
    (até `max_cut_db`); som equilibrado passa intacto. Devolve mono 44,1 kHz.
    """
    from sfx_common import spectral
    y = to_mono_44k(x, sr)
    hf = spectral(y, SR)["high_frac"]
    cut = float(np.clip((hf - ok_frac) * 20.0, 0.0, max_cut_db))
    return high_shelf(y, 7000.0, -cut) if cut > 0.3 else y


def expand_tail(x: np.ndarray, thresh_rel_db: float = -48.0, ratio: float = 3.0) -> np.ndarray:
    """Expansor descendente suave: abaixa o que fica perto do chão de ruído.

    Geração por difusão quase sempre deixa um chiado baixinho por baixo e
    depois do som. Gate seco cortaria a cauda natural com "degrau" audível;
    expansão (abaixo do limiar, cada dB vira `ratio` dB) faz o chiado sumir
    junto com a cauda, que é o que um editor de som faria à mão.
    """
    env = envelope(x, SR, 15.0)
    thr = env.max() * 10 ** (thresh_rel_db / 20)
    rel = np.maximum(env, 1e-12) / thr
    g = np.where(rel < 1.0, rel ** (ratio - 1.0), 1.0)
    # Suaviza o ganho (~10 ms) pra não modular o som com a própria envoltória.
    n = int(0.01 * SR)
    g = np.convolve(g, np.ones(n) / n, mode="same")
    return x * g


def trim(x: np.ndarray, rel_db: float = -50.0, pre_ms: float = 2.0) -> np.ndarray:
    """Corta silêncio relativo ao pico do envelope (não absoluto).

    Relativo porque a geração vem em nível arbitrário: um limiar absoluto
    cortaria a cauda de um som baixo e deixaria o chiado de um som alto.
    """
    env = envelope(x, SR, 3.0)
    thr = env.max() * 10 ** (rel_db / 20)
    idx = np.where(env > thr)[0]
    if len(idx) == 0:
        return x
    a = max(0, idx[0] - int(pre_ms / 1000 * SR))
    b = min(len(x), idx[-1] + int(0.01 * SR))
    return x[a:b]


def fades(x: np.ndarray, fade_in_ms: float = 2.0, fade_out_ms: float = 40.0) -> np.ndarray:
    x = x.copy()
    ni = min(len(x), int(fade_in_ms / 1000 * SR))
    no = min(len(x) // 3, int(fade_out_ms / 1000 * SR))
    if ni > 0:
        x[:ni] *= np.linspace(0, 1, ni)
    if no > 0:
        x[-no:] *= 0.5 * (1 + np.cos(np.linspace(0, np.pi, no)))
    return x


def cap_duration(x: np.ndarray, max_dur: float | None) -> np.ndarray:
    """Encurta com fade longo (15% da duração) — a cauda some, não é decepada."""
    if not max_dur or len(x) <= max_dur * SR:
        return x
    n = int(max_dur * SR)
    x = x[:n].copy()
    nf = int(n * 0.15)
    x[-nf:] *= 0.5 * (1 + np.cos(np.linspace(0, np.pi, nf)))
    return x


def limit(x: np.ndarray, ceiling_db: float = CEILING_DBTP, look_ms: float = 1.5,
          release_ms: float = 60.0) -> np.ndarray:
    """Limitador de pico verdadeiro com lookahead.

    Detecta no sinal sobreamostrado 4x (o pico entre amostras é o que estoura
    no conversor), calcula o ganho necessário, antecipa pelo lookahead (mínimo
    deslizante) e solta com release exponencial — ataque instantâneo, sem
    distorcer o transiente em onda quadrada como um clip faria.
    """
    ceil = 10 ** (ceiling_db / 20)
    up = np.abs(resample_poly(x, 4, 1))
    peak = up.reshape(-1, 4).max(axis=1)[: len(x)] if len(up) >= 4 * len(x) else np.abs(x)
    if len(peak) < len(x):
        peak = np.pad(peak, (0, len(x) - len(peak)))
    need = np.minimum(1.0, ceil / np.maximum(peak, 1e-9))
    la = max(1, int(look_ms / 1000 * SR))
    # Mínimo deslizante pra frente: o ganho começa a cair ANTES do pico chegar.
    padded = np.pad(need, (0, la), constant_values=1.0)
    win = np.lib.stride_tricks.sliding_window_view(padded, la + 1).min(axis=1)[: len(x)]
    rel = np.exp(-1.0 / (release_ms / 1000 * SR))
    g = np.empty_like(win)
    cur = 1.0
    for i, w in enumerate(win):
        cur = w if w < cur else w + (cur - w) * rel
        g[i] = cur
    y = x * g
    # Rede de segurança: o release suave pode deixar escapar uma fração de dB.
    tp = 10 ** (true_peak_db(y) / 20)
    if tp > ceil:
        y *= ceil / tp
    return y


# Quanto de "sala" cada categoria recebe (dB do retorno em relação ao seco).
# UI fica seca: é interface, não mundo. Sons do mundo ganham a MESMA sala curta,
# pra que flecha, canhão e magia pareçam gravados no mesmo pátio — gerações
# diferentes chegam com ambiências diferentes, e essa cola é o que um mixador
# faria com um reverb de envio comum. Baixo de propósito: o modelo já traz
# alguma ambiência; aqui é só unificar, não afogar.
ROOM_WET_DB = {
    "ui": None, "select": None, "resource": -24.0, "shot": -22.0, "impact": -21.0,
    "enemy_hurt": -22.0, "enemy_death": -21.0, "footstep": -24.0, "build": -21.0,
    "destruction": -19.0, "ui_world": -20.0, "core": -19.0, "stinger": -19.0, "default": -22.0,
    "interact": -24.0, "amb": None, "amb_soft": None,
}


def _room_ir(rt60: float = 0.32, seed: int = 7) -> np.ndarray:
    """Resposta de sala sintética (pátio de pedra pequeno), sempre a mesma.

    Ruído com decaimento exponencial (RT60 ~0,32 s), pré-atraso de 12 ms e
    banda 300 Hz–7 kHz: sem o grave a sala não embola o corpo dos sons (o
    defeito nº 1 da auditoria) e sem o agudo extremo ela não vira chiado.
    Semente fixa = mesmo "lugar" pra todos os sons, em todas as rodadas.
    """
    rng = np.random.default_rng(seed)
    n = int(rt60 * 1.2 * SR)
    t = np.arange(n) / SR
    ir = rng.standard_normal(n) * np.exp(-6.91 * t / rt60)
    sos = butter(2, [300.0, 7000.0], btype="bandpass", fs=SR, output="sos")
    ir = sosfilt(sos, ir)
    ir = np.concatenate([np.zeros(int(0.012 * SR)), ir])
    return ir / np.sqrt(np.sum(ir ** 2))


def room(x: np.ndarray, wet_db: float | None) -> np.ndarray:
    if wet_db is None:
        return x
    from scipy.signal import fftconvolve
    wet = fftconvolve(x, _room_ir())[: len(x) + int(0.25 * SR)]
    y = np.pad(x, (0, len(wet) - len(x)))
    # Normaliza o retorno pela energia do seco: o mesmo wet_db soa igual em som
    # alto e baixo (a geração chega em nível arbitrário).
    k = np.sqrt(np.sum(x ** 2) / (np.sum(wet ** 2) + 1e-20)) * 10 ** (wet_db / 20)
    return y + k * wet


def master(x: np.ndarray, sr: int, category: str = "default", max_dur: float | None = None,
           target: float | None = None) -> np.ndarray:
    tgt = TARGETS.get(category, TARGETS["default"]) if target is None else target
    y = to_mono_44k(x, sr)
    y = highpass(y)
    y, _cut = tame_presence(y)
    y = expand_tail(y)
    y = trim(y)
    y = cap_duration(y, max_dur)
    # Sala depois do corte de duração: a cauda da sala (até +0,25 s) é curta e
    # coerente, e o fade final abaixo a encerra sem degrau.
    y = room(y, ROOM_WET_DB.get(category, ROOM_WET_DB["default"]))
    y = trim(y, -55.0)
    y = fades(y, 2.0, min(60.0, 1000 * len(y) / SR * 0.12))
    # Ganho → limita → corrige: o limitador come um pouco de loudness em som
    # muito transiente, então duas passadas aproximam o alvo sem estourar.
    for _ in range(3):
        cur = lufs(y, SR)
        y = y * 10 ** ((tgt - cur) / 20)
        y = limit(y)
        if abs(lufs(y, SR) - tgt) < 0.5:
            break
    return y.astype(np.float32)


def pitch_variant(x: np.ndarray, ratio: float) -> np.ndarray:
    """Variação de tom por reamostragem (muda tom E duração, como o pool do jogo)."""
    from fractions import Fraction
    f = Fraction(ratio).limit_denominator(200)
    return resample_poly(x, f.denominator, f.numerator).astype(np.float32)


def write_wav(path: Path, x: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    sf.write(str(path), x, SR, subtype="PCM_16")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("inp")
    ap.add_argument("out")
    ap.add_argument("--category", default="default")
    ap.add_argument("--max-dur", type=float, default=None)
    ap.add_argument("--target", type=float, default=None)
    a = ap.parse_args()
    x, sr = sf.read(a.inp, dtype="float32")
    y = master(x, sr, a.category, a.max_dur, a.target)
    write_wav(Path(a.out), y)
    print(f"{a.out}: {lufs(y.astype(np.float64), SR):.1f} LUFS, {true_peak_db(y):.1f} dBTP, {len(y) / SR:.2f} s")


if __name__ == "__main__":
    main()
