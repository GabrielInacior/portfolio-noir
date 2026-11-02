"""Utilitários compartilhados da pipeline de SFX (auditoria, acabamento, piloto).

Fica separado porque auditoria e acabamento PRECISAM medir do mesmo jeito: se a
auditoria disser "-18 LUFS" e o acabamento normalizar com outra régua, o
relatório de antes/depois mente. Uma função de medida só, usada pelos dois.
"""
from __future__ import annotations

import re
from pathlib import Path

import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from scipy.signal import resample_poly

REPO = Path(__file__).resolve().parents[2]
SFX_DIR = REPO / "game" / "assets" / "audio" / "sfx"
LIB_GD = REPO / "game" / "scripts" / "sfx.gd"

# Grupos de leitura humana (o pedido do usuário). A categoria TÉCNICA do jogo
# (`category` da receita, que liga ao limitador de vozes) continua existindo;
# este agrupamento é só pra comparar sons que o ouvido compara entre si.
GROUP_RULES = [
    ("chefe", r"^(boss_|giant_step|quake_slam|reaper_swing)"),
    ("magia", r"^(spell_|beam_hum|sentinel_mark|crypt_summon)"),
    ("ui", r"^(ui_|reroll|select_)"),
    ("recompensa", r"^(card_|upgrade_chosen|unlock_chime|resource_gained|market_trade|"
                   r"core_level_up|structure_|synergy_|wave_cleared|phase_cleared|campaign_victory)"),
    ("construcao", r"^(build_|unit_recruited|mine_plant)"),
    ("combate_torre", r"^(shot_(archer|cannon|mage|core)|ballista_fire|mortar_fire)"),
    ("impacto", r"^(impact_|mine_blast)"),
    ("inimigo", r"^(enemy_|shot_(javelin|tar|witchfire)|acid_)"),
    ("alerta", r"^(wave_start|swarm_incoming|core_damaged|core_destroyed)"),
    ("ambiente", r"^(wind_gust)"),
]


def group_of(sid: str) -> str:
    for name, pat in GROUP_RULES:
        if re.match(pat, sid):
            return name
    return "outros"


def recipe_categories() -> dict[str, str]:
    """Lê `category` de cada receita direto do `sfx_library.gd`.

    Parse por texto (e não rodando o Godot) porque o Godot pode estar ocupado
    com um export; a estrutura das receitas é regular o bastante pra isso.
    """
    text = LIB_GD.read_text(encoding="utf-8")
    cats: dict[str, str] = {}
    for m in re.finditer(r'^\t"(\w+)": \{\s*\n?\s*"duration"[^\n]*?"category": "(\w+)"', text, re.M):
        cats[m.group(1)] = m.group(2)
    # Vozes de seleção herdam "select" da base, salvo sobrescrita (rara).
    for m in re.finditer(r'^\t"(\w+)": \{"material"', text, re.M):
        cats.setdefault("select_" + m.group(1), "select")
    return cats


def recipe_loudness_overrides() -> dict[str, float]:
    """Receitas que sobrescrevem o alvo da categoria (`"loudness": -26.0`)."""
    text = LIB_GD.read_text(encoding="utf-8")
    out: dict[str, float] = {}
    # O "loudness" aparece ora na linha da duração, ora na linha seguinte (com
    # comentário); procura no cabeçalho da receita, antes do bloco "params".
    for m in re.finditer(r'^\t"(\w+)": \{\s*\n?\s*"duration"(.*?)"params"', text, re.M | re.S):
        lm = re.search(r'"loudness": (-?[\d.]+)', m.group(2))
        if lm:
            out[m.group(1)] = float(lm.group(1))
    return out


def load_mono(path: Path) -> tuple[np.ndarray, int]:
    x, sr = sf.read(str(path), dtype="float32", always_2d=True)
    return x.mean(axis=1), sr


def db(v: float) -> float:
    return float(20.0 * np.log10(max(v, 1e-9)))


def true_peak_db(x: np.ndarray) -> float:
    # 4x de sobreamostragem é o que a BS.1770 pede pra estimar o pico entre amostras.
    return db(float(np.max(np.abs(resample_poly(x, 4, 1)))) if len(x) else 0.0)


def lufs(x: np.ndarray, sr: int) -> float:
    """LUFS integrado (BS.1770). Bloco menor que 400 ms em som curto.

    O padrão exige blocos de 400 ms; um clique de 0,14 s nem fecha um bloco, e
    completar com silêncio subestimaria o volume. Em som curto usamos blocos de
    100 ms (a mesma ponderação K e os mesmos portões) — vale como comparação
    entre sons do jogo, que é o que importa aqui.
    """
    dur = len(x) / sr
    block = 0.4 if dur >= 0.6 else 0.1
    if dur < block:
        x = np.pad(x, (0, int(block * sr) - len(x) + 1))
    meter = pyln.Meter(sr, block_size=block)
    v = meter.integrated_loudness(x.astype(np.float64))
    return float(v) if np.isfinite(v) else -70.0


def envelope(x: np.ndarray, sr: int, win_ms: float = 5.0) -> np.ndarray:
    n = max(1, int(sr * win_ms / 1000))
    return np.sqrt(np.convolve(x * x, np.ones(n) / n, mode="same"))


def silence_edges(x: np.ndarray, sr: int, thresh_db: float = -60.0) -> tuple[float, float]:
    env = envelope(x, sr, 2.0)
    above = np.where(env > 10 ** (thresh_db / 20))[0]
    if len(above) == 0:
        return len(x) / sr, 0.0
    return above[0] / sr, (len(x) - 1 - above[-1]) / sr


def attack_ms(x: np.ndarray, sr: int) -> float:
    """Do primeiro som audível até o pico do envelope (ms).

    Um tiro/impacto/clique sem ataque (rampa > ~25 ms) soa "mole" e atrasado em
    relação ao visual — é o defeito mais comum de síntese com envelope suave.
    """
    env = envelope(x, sr, 5.0)
    lead, _ = silence_edges(x, sr)
    i0 = int(lead * sr)
    ipk = int(np.argmax(env))
    return max(0.0, (ipk - i0) / sr * 1000.0)


def spectral(x: np.ndarray, sr: int) -> dict:
    """Centróide, rolloff e partilha de energia por banda (só nos quadros com som)."""
    n_fft = 2048
    hop = 512
    if len(x) < n_fft:
        x = np.pad(x, (0, n_fft - len(x)))
    frames = np.lib.stride_tricks.sliding_window_view(x, n_fft)[::hop] * np.hanning(n_fft)
    mag = np.abs(np.fft.rfft(frames, axis=1)) ** 2
    energy = mag.sum(axis=1)
    keep = energy > energy.max() * 1e-3 if energy.max() > 0 else np.ones_like(energy, bool)
    mag = mag[keep]
    freqs = np.fft.rfftfreq(n_fft, 1 / sr)
    spec = mag.sum(axis=0)
    tot = spec.sum() + 1e-12
    centroid = float((freqs * spec).sum() / tot)
    cum = np.cumsum(spec) / tot
    rolloff = float(freqs[np.searchsorted(cum, 0.85)])
    return {
        "centroid": centroid,
        "rolloff85": rolloff,
        "low_frac": float(spec[freqs < 150].sum() / tot),
        "mid_frac": float(spec[(freqs >= 150) & (freqs < 4000)].sum() / tot),
        "high_frac": float(spec[freqs >= 6000].sum() / tot),
        "sub40_frac": float(spec[freqs < 40].sum() / tot),
    }


def cleanliness(x: np.ndarray, sr: int) -> dict:
    """Métricas de "limpeza" — o que separa efeito profissional de ruído.

    - `floor_db`: nível do chão de ruído (percentil 10 do envelope nos trechos
      fora do corpo do som) relativo ao pico. Chiado/hum de fundo aparece aqui.
    - `snr_db`: pico do envelope menos esse chão. Efeito limpo passa de ~45 dB.
    - `flatness`: planura espectral mediana (0 = tonal/estruturado, 1 = ruído
      branco). Explosão é naturalmente mais plana; clique/moeda/sino não deveriam.
    - `presence_frac`: fração de energia em 2–5 kHz, a faixa onde o ouvido é
      mais sensível — demais ali é o que cansa em repetição.
    - `harsh_db`: quanto a banda 2–5 kHz sobressai em relação às vizinhas
      (1–2 kHz e 5–10 kHz), em dB. Positivo alto = pico áspero localizado.
    """
    env = envelope(x, sr, 10.0)
    pk = env.max() + 1e-12
    # Chão: o trecho mais quieto da segunda metade da cauda (onde só sobra ruído
    # de fundo, se houver) e o mais quieto antes do ataque.
    # Ignora silêncio DIGITAL (abaixo de -120 dB): o Stable Audio devolve zeros
    # exatos depois do fim pedido, e medir ali dava "SNR 180 dB" para qualquer
    # candidato — o chiado que importa é o que fica por baixo do som, dentro do
    # trecho com sinal (do primeiro ao último ponto acima de -120 dB).
    # Só as amostras vivas (não o intervalo inteiro): a geração às vezes tem
    # buracos de zero digital NO MEIO, que também davam o falso "180 dB".
    live = np.where(env > pk * 1e-6)[0]
    seg = env[live] if len(live) > 20 else env
    lo = np.percentile(seg[int(len(seg) * 0.5):], 10) if len(seg) > 20 else pk
    floor_db = db(lo / pk)
    n_fft = 2048
    hop = 512
    y = np.pad(x, (0, max(0, n_fft - len(x))))
    frames = np.lib.stride_tricks.sliding_window_view(y, n_fft)[::hop] * np.hanning(n_fft)
    mag = np.abs(np.fft.rfft(frames, axis=1)) + 1e-12
    e = (mag ** 2).sum(axis=1)
    keep = e > e.max() * 1e-2
    fl = np.exp(np.mean(np.log(mag[keep]), axis=1)) / np.mean(mag[keep], axis=1)
    freqs = np.fft.rfftfreq(n_fft, 1 / sr)
    spec = (mag[keep] ** 2).sum(axis=0)
    tot = spec.sum()

    def band(a, b):
        sel = (freqs >= a) & (freqs < b)
        return spec[sel].sum(), spec[sel].mean()

    p_sum, p_mean = band(2000, 5000)
    _, l_mean = band(1000, 2000)
    _, h_mean = band(5000, 10000)
    return {
        "floor_db": floor_db,
        "snr_db": -floor_db,
        "flatness": float(np.median(fl)),
        "presence_frac": float(p_sum / tot),
        "harsh_db": db(np.sqrt(p_mean / (np.sqrt(l_mean * h_mean) + 1e-20))),
    }


def measure(x: np.ndarray, sr: int) -> dict:
    lead, tail = silence_edges(x, sr)
    m = {
        "dur": len(x) / sr,
        "lufs": lufs(x, sr),
        "tp": true_peak_db(x),
        "attack_ms": attack_ms(x, sr),
        "lead_s": lead,
        "tail_s": tail,
        "clip": int(np.sum(np.abs(x) >= 0.999)),
    }
    m.update(spectral(x, sr))
    m.update(cleanliness(x, sr))
    return m
