"""Cliques de interface sintetizados (mira e botão): o modelo entrega "tique" com agudo dominante e
nota CLAP baixa; aqui é um transiente curto e macio, controlado, que não cansa na centésima vez.
Uso: C:/Users/gabri/ai_audio/venv/Scripts/python tools/audio/synth_ui.py"""
from pathlib import Path
import sys
import numpy as np
import soundfile as sf
sys.path.insert(0, str(Path(__file__).parent))
from sfx_master import SR, master  # noqa: E402

OUT = Path(__file__).resolve().parents[2] / "game" / "assets" / "audio" / "sfx"


def tick(f0: float, dur: float, body: float, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    n = int(dur * SR)
    t = np.arange(n) / SR
    tone = np.sin(2 * np.pi * f0 * t) * np.exp(-t / body)
    click = rng.standard_normal(n) * np.exp(-t / 0.002) * 0.3
    from scipy.signal import butter, sosfilt
    click = sosfilt(butter(2, [800, 4000], btype="bandpass", fs=SR, output="sos"), click)
    return (tone + click).astype(np.float32)


specs = {"ui_mira": [(1650, 0.08, 0.012, 1)], "ui_botao": [(900, 0.12, 0.02, 2), (980, 0.12, 0.02, 3)]}
for sid, vs in specs.items():
    for k, (f0, d, b, s) in enumerate(vs):
        y = master(tick(f0, d, b, s), SR, "ui", 0.15)
        sf.write(str(OUT / f"{sid}_{k}.ogg"), y, SR, format="OGG", subtype="VORBIS")
        print(sid, k)
