"""Produção dos sons do portfólio noir com IA local (Stable Audio Open + triagem CLAP).

Sempre com o Python do venv de áudio:
    C:/Users/gabri/ai_audio/venv/Scripts/python tools/audio/noir_prod.py gen   [--ids a,b] [--kind bed|spot|one]
    C:/Users/gabri/ai_audio/venv/Scripts/python tools/audio/noir_prod.py score [--ids ...]
    C:/Users/gabri/ai_audio/venv/Scripts/python tools/audio/noir_prod.py install [--ids ...]
    C:/Users/gabri/ai_audio/venv/Scripts/python tools/audio/noir_prod.py page

Brutos e notas ficam FORA do repo em C:/Users/gabri/ai_audio/noir/ (raw/<id>/s<semente>.wav,
results.json). Instalados: game/assets/audio/sfx/<id>_<n>.ogg (mono) e game/assets/audio/amb/<id>.ogg.
Regras herdadas do FortressChaos (skill portfolio-audio): bruto em FLOAT (o modelo passa de 1,0),
trava de GPU por lote, bloco latente curto, nada de banco de som pronto nem modelo sem uso comercial.
"""
from __future__ import annotations

import argparse
import html
import json
import os
import shutil
import sys
import time
from pathlib import Path

AI = Path("C:/Users/gabri/ai_audio")
os.environ.setdefault("HF_HOME", str(AI / "hf_cache"))
os.environ.setdefault("HF_HUB_DISABLE_TELEMETRY", "1")

import numpy as np  # noqa: E402
import soundfile as sf  # noqa: E402
from scipy.signal import resample_poly  # noqa: E402

sys.path.insert(0, str(Path(__file__).parent))
from sfx_common import measure  # noqa: E402
from sfx_master import SR, TARGETS, highpass, limit, master, tame_air  # noqa: E402
import noir_catalog as CAT  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
WORK = AI / "noir"
SFX_OUT = REPO / "game" / "assets" / "audio" / "sfx"
AMB_OUT = REPO / "game" / "assets" / "audio" / "amb"
REVIEW = Path("C:/Users/gabri/Downloads/Portfolio_Noir_Sons")
CLAP_NEG = ["music", "a person speaking", "static noise hiss", "distorted harsh noise",
            "low quality recording", "silence"]


def hf_token() -> str | None:
    p = Path("C:/Users/gabri/.hf_token")
    return p.read_text(encoding="utf-8").strip() if p.exists() else os.environ.get("HF_TOKEN")


def select(args) -> list[dict]:
    items = CAT.ITEMS
    if getattr(args, "ids", None):
        items = [CAT.BY_ID[i] for i in args.ids.split(",")]
    if getattr(args, "kind", None):
        items = [it for it in items if it["kind"] == args.kind]
    return items


# ───────────────────────────────────────────────────────────────── geração ──
def cmd_gen(args) -> None:
    import torch
    from diffusers import StableAudioPipeline
    from gpu_lock import gpu_lock
    todo = []
    for it in select(args):
        d = WORK / "raw" / it["id"]
        d.mkdir(parents=True, exist_ok=True)
        seeds = [args.seed_base + 37 * i for i in range(it["n"])]
        miss = [s for s in seeds if not (d / f"s{s}.wav").exists()]
        if miss:
            todo.append((it, miss))
    if not todo:
        print("nada a gerar")
        return
    pipe = StableAudioPipeline.from_pretrained("stabilityai/stable-audio-open-1.0",
                                               torch_dtype=torch.float16, token=hf_token())
    pipe.set_progress_bar_config(disable=True)
    pipe.vae.enable_slicing()
    for it, seeds in todo:
        # bloco latente proporcional ao pedido (~21,5 quadros por segundo; mínimo 128)
        lat = 128 if it["gen_s"] <= 5 else (256 if it["gen_s"] <= 11 else 512)
        pipe.transformer.register_to_config(sample_size=lat)
        style = CAT.STYLE_AMB if it["kind"] in ("bed", "spot") else (CAT.STYLE_UI if it["cat"] == "ui" else CAT.STYLE_ONE)
        neg = CAT.NEG_AMB if it["kind"] in ("bed", "spot") else CAT.NEG_PROMPT
        prompt = f"{it['prompt']}, {style}"
        t0 = time.perf_counter()
        for b0 in range(0, len(seeds), args.batch):
            sb = seeds[b0:b0 + args.batch]
            gens = [torch.Generator("cuda").manual_seed(s) for s in sb]
            with gpu_lock(f"noir {it['id']}"):
                pipe.to("cuda")
                out = pipe(prompt, negative_prompt=neg, num_inference_steps=args.steps, guidance_scale=7.0,
                           audio_end_in_s=float(it["gen_s"]), num_waveforms_per_prompt=len(sb),
                           generator=gens).audios.float().cpu()
                pipe.to("cpu")
                torch.cuda.empty_cache()
            for s, w in zip(sb, out):
                sf.write(str(WORK / "raw" / it["id"] / f"s{s}.wav"), w.T.numpy(), pipe.vae.sampling_rate, subtype="FLOAT")
        print(f"[{it['id']}] {len(seeds)} gerados em {time.perf_counter() - t0:.0f} s", flush=True)


# ──────────────────────────────────────────────────────────── acabamento ────
def to44(x: np.ndarray, sr: int) -> np.ndarray:
    if sr == SR:
        return x.astype(np.float64)
    from math import gcd
    g = gcd(SR, sr)
    return resample_poly(x, SR // g, sr // g, axis=0).astype(np.float64)


def make_loop(x: np.ndarray, sr: int, it: dict) -> np.ndarray:
    """Loop sem emenda: corta o começo (a geração costuma entrar com um "ataque" artificial), cruza
    os últimos 2 s com os primeiros (potência constante) e normaliza o loudness. Ambiente 2D fica
    estéreo; loop 3D (spot) vira mono para o AudioStreamPlayer3D espacializar."""
    y = to44(x, sr)
    if it["kind"] == "spot" and y.ndim == 2:
        y = y.mean(axis=1)
    if y.ndim == 1:
        y = y[:, None]
    y = np.stack([highpass(y[:, c]) for c in range(y.shape[1])], axis=1)
    y = y[int(0.6 * SR):]
    # descarta o rabo silencioso que o modelo devolve depois do fim pedido
    env = np.abs(y).max(axis=1)
    live = np.where(env > env.max() * 1e-3)[0]
    y = y[: live[-1] + 1] if len(live) else y
    X = int(2.0 * SR)
    if len(y) < 3 * X:
        X = len(y) // 3
    body = y[:-X].copy()
    t = np.linspace(0, np.pi / 2, X)[:, None]
    body[:X] = y[:X] * np.sin(t) + y[-X:] * np.cos(t)
    import pyloudnorm as pyln
    tgt = it.get("lufs", TARGETS.get(it["cat"], -28.0))
    cur = pyln.Meter(SR).integrated_loudness(body)
    if np.isfinite(cur):
        body = body * 10 ** ((tgt - cur) / 20)
    pk = np.abs(body).max()
    if pk > 0.89:
        body *= 0.89 / pk
    return body.astype(np.float32) if body.shape[1] > 1 else body[:, 0].astype(np.float32)


def finish_one(x: np.ndarray, sr: int, it: dict) -> np.ndarray:
    y = tame_air(x, sr)
    return master(y, SR, it["cat"], it.get("max_dur"), it.get("lufs"))


def penalty(m: dict, it: dict, raw_clip: float) -> tuple[float, list[str]]:
    p, why = 0.0, []
    if it["kind"] == "one":
        if it["cat"] in ("ui", "footstep") and m["attack_ms"] > 30:
            p += min(0.15, (m["attack_ms"] - 30) / 300)
            why.append(f"ataque lento {m['attack_ms']:.0f} ms")
        if m["dur"] < 0.05:
            p += 0.3
            why.append("quase mudo")
        if not it.get("noisy") and m["flatness"] > 0.35:
            p += min(0.1, (m["flatness"] - 0.35) / 2)
            why.append("espectro ruidoso")
        if not it.get("noisy") and m["snr_db"] < 38:
            p += min(0.15, (38 - m["snr_db"]) / 100)
            why.append(f"chão de ruído (SNR {m['snr_db']:.0f})")
    if m["high_frac"] > 0.5:
        p += min(0.12, (m["high_frac"] - 0.5) / 2.5)
        why.append("agudo dominante")
    if m["low_frac"] > 0.75:
        p += min(0.12, (m["low_frac"] - 0.75) * 0.6)
        why.append("grave dominante")
    if raw_clip > 0.0005:
        p += min(0.12, raw_clip * 40)
        why.append("saturado na geração")
    return p, why


def flat_top(x: np.ndarray) -> float:
    a = np.abs(x)
    pk = float(a.max()) if len(a) else 0.0
    if pk <= 0:
        return 0.0
    return float(np.mean((a[1:] >= 0.98 * pk) & (np.abs(np.diff(x)) < 1e-6)))


def cmd_score(args) -> None:
    import torch
    sys.path.insert(0, str(Path(__file__).parent))
    from transformers import ClapModel, ClapProcessor
    dev = "cuda" if torch.cuda.is_available() else "cpu"
    model = ClapModel.from_pretrained("laion/larger_clap_general").to(dev).eval()
    proc = ClapProcessor.from_pretrained("laion/larger_clap_general")

    def emb(e):
        return e if isinstance(e, torch.Tensor) else e.pooler_output

    @torch.no_grad()
    def clap(x: np.ndarray, target: str, allow: list[str]) -> dict:
        negs = [n for n in CLAP_NEG if n not in allow]
        y = resample_poly(x, 48000, SR).astype(np.float32)
        a = proc(audio=[y], sampling_rate=48000, return_tensors="pt").to(dev)
        ae = torch.nn.functional.normalize(emb(model.get_audio_features(**a)), dim=-1)
        t = proc(text=[target] + negs, return_tensors="pt", padding=True).to(dev)
        te = torch.nn.functional.normalize(emb(model.get_text_features(**t)), dim=-1)
        s = (ae @ te.T)[0].cpu().numpy()
        tgt, neg = float(s[0]), float(s[1:].max())
        return {"clap": tgt, "neg": neg, "neg_label": negs[int(s[1:].argmax())], "score": tgt - max(0.0, neg - tgt)}

    rpath = WORK / "results.json"
    results = json.loads(rpath.read_text(encoding="utf-8")) if rpath.exists() else {}
    for it in select(args):
        cands = []
        fin_dir = WORK / "fin" / it["id"]
        fin_dir.mkdir(parents=True, exist_ok=True)
        for w in sorted((WORK / "raw" / it["id"]).glob("s*.wav")):
            x, sr = sf.read(str(w), dtype="float32", always_2d=True)
            mono_raw = x.mean(axis=1)
            y = make_loop(x, sr, it) if it["kind"] in ("bed", "spot") else finish_one(mono_raw, sr, it)
            ym = y.mean(axis=1) if y.ndim == 2 else y
            if len(ym) < 0.05 * SR:
                continue
            m = measure(ym.astype(np.float64), SR)
            c = clap(ym[: int(10 * SR)].astype(np.float64), it["clap"], it.get("allow", []))
            pen, why = penalty(m, it, flat_top(mono_raw))
            sf.write(str(fin_dir / f"{w.stem}.wav"), y, SR, subtype="PCM_16")
            cands.append({"seed": w.stem, "score": c["score"] - pen, **c, "pen": pen, "why": why,
                          "lufs": m["lufs"], "dur": m["dur"]})
        cands.sort(key=lambda r: -r["score"])
        results[it["id"]] = {"cands": cands, "escolhidos": [r["seed"] for r in cands[: it["keep"]]]}
        best = cands[0] if cands else None
        if best:
            print(f"[{it['id']}] melhor {best['seed']} nota {best['score']:.2f} (CLAP {best['clap']:.2f}, neg {best['neg_label']} {best['neg']:.2f}) {', '.join(best['why'])}", flush=True)
        rpath.write_text(json.dumps(results, ensure_ascii=False, indent=1), encoding="utf-8")


# ──────────────────────────────────────────────────────────────── instalar ──
def cmd_install(args) -> None:
    results = json.loads((WORK / "results.json").read_text(encoding="utf-8"))
    SFX_OUT.mkdir(parents=True, exist_ok=True)
    AMB_OUT.mkdir(parents=True, exist_ok=True)
    for it in select(args):
        r = results.get(it["id"])
        if not r or not r["escolhidos"]:
            print(f"[{it['id']}] sem escolhidos")
            continue
        for k, seed in enumerate(r["escolhidos"]):
            x, sr = sf.read(str(WORK / "fin" / it["id"] / f"{seed}.wav"), dtype="float32")
            if it["kind"] in ("bed", "spot"):
                out = AMB_OUT / f"{it['id']}.ogg"
            else:
                out = SFX_OUT / f"{it['id']}_{k}.ogg"
            # Vorbis via ffmpeg (o encoder do libsndfile trava em arquivo longo no Windows); qualidade 3
            # nos ambientes (longos, pequenos) e 4 nos efeitos curtos
            import subprocess
            src = WORK / "fin" / it["id"] / f"{seed}.wav"
            q = "3" if it["kind"] in ("bed", "spot") else "4"
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(src), "-c:a", "libvorbis", "-q:a", q, str(out)], check=True)
        print(f"[{it['id']}] instalado {len(r['escolhidos'])}")
    tot = sum(p.stat().st_size for p in list(SFX_OUT.glob("*.ogg")) + list(AMB_OUT.glob("*.ogg")))
    print(f"total de áudio (sem a OST): {tot / 1e6:.2f} MB")


# ───────────────────────────────────────────────────────── página de revisão ─
def cmd_page(args) -> None:
    results = json.loads((WORK / "results.json").read_text(encoding="utf-8"))
    REVIEW.mkdir(parents=True, exist_ok=True)
    (REVIEW / "audio").mkdir(exist_ok=True)
    rows = []
    groups = [("Ambientes (loop)", "bed"), ("Loops 3D", "spot"), ("Efeitos", "one")]
    for title, kind in groups:
        rows.append(f"<h2>{title}</h2>")
        for it in CAT.ITEMS:
            if it["kind"] != kind or it["id"] not in results:
                continue
            r = results[it["id"]]
            rows.append(f"<div class='item'><h3>{html.escape(it['label'])} <small>{it['id']}</small></h3>")
            for c in r["cands"][: max(3, it["keep"] + 1)]:
                src = WORK / "fin" / it["id"] / f"{c['seed']}.wav"
                dst = REVIEW / "audio" / f"{it['id']}_{c['seed']}.wav"
                shutil.copyfile(src, dst)
                star = "★ escolhido" if c["seed"] in r["escolhidos"] else ""
                loop = " loop" if kind != "one" else ""
                rows.append(f"<div class='c'><audio controls preload='none'{loop} src='audio/{dst.name}'></audio>"
                            f"<span>{star} nota {c['score']:.2f} · CLAP {c['clap']:.2f} · {c['lufs']:.1f} LUFS · {c['dur']:.1f} s"
                            f"{' · ' + html.escape(', '.join(c['why'])) if c['why'] else ''}</span></div>")
            rows.append("</div>")
    page = f"""<!doctype html><html lang="pt-BR"><meta charset="utf-8"><title>Sons do portfólio noir</title>
<style>body{{background:#0b0d18;color:#e8ecf8;font-family:system-ui;max-width:980px;margin:auto;padding:24px}}
h1{{color:#ffc83d}}h2{{color:#ff6fae;border-bottom:1px solid #333;margin-top:36px}}.item{{background:#141729;border:1px solid #262b45;border-radius:10px;padding:12px 16px;margin:12px 0}}
h3{{margin:0 0 8px}}small{{color:#7a83a8;font-weight:normal}}.c{{display:flex;gap:12px;align-items:center;margin:6px 0}}span{{font-size:13px;color:#a9b3d6}}audio{{width:360px}}</style>
<h1>Sons do portfólio noir</h1><p>Gerados localmente (Stable Audio Open) e triados por CLAP. ★ = o que entrou no jogo. Ambientes tocam em loop: ouça a emenda.</p>
{''.join(rows)}</html>"""
    (REVIEW / "index.html").write_text(page, encoding="utf-8")
    print(REVIEW / "index.html")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["gen", "score", "install", "page"])
    ap.add_argument("--ids")
    ap.add_argument("--kind")
    ap.add_argument("--batch", type=int, default=4)
    ap.add_argument("--steps", type=int, default=100)
    ap.add_argument("--seed-base", type=int, default=11)
    a = ap.parse_args()
    {"gen": cmd_gen, "score": cmd_score, "install": cmd_install, "page": cmd_page}[a.cmd](a)


if __name__ == "__main__":
    main()
