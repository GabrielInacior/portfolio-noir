"""Pipeline Meshy para gerar props 3D das lojas-museu (text-to-3D ou image-to-3D), baixar o GLB
e colocar em game/assets/props/. A chave é lida de C:/Users/gabri/.meshy_key e NUNCA impressa.

Uso:
  python tools/props/meshy.py text  "nome"  "prompt em ingles"  [--poly 2000]
  python tools/props/meshy.py image "nome"  caminho_da_imagem.png  [--poly 2000]
  python tools/props/meshy.py manifest   # gera todos os props do manifesto abaixo (longo)

Peso: polycount baixo (padrao 2000), textura 1024 que depois reduzimos para 512/atlas.
Carregar por loja/zona, nunca no .pck inicial.
"""
import json
import os
import sys
import time
import urllib.request

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "props")
API = "https://api.meshy.ai/openapi"
KEY_FILE = "C:/Users/gabri/.meshy_key"

STYLE = (", stylized low-poly game asset, clean shapes, smooth soft shading, flat colors with "
         "subtle gradient, modern stylized look like Synty POLYGON, neutral studio background, "
         "single object, noir detective theme")

# nome -> prompt (tema de cada loja). Conceito para image-to-3D pode vir do SD local.
MANIFEST = {
    "maquina_escrever": "a vintage typewriter on a desk",
    "abajur": "a small desk banker lamp with green glass shade",
    "quadro_cortica": "a cork board with pinned photos and red string, detective evidence board",
    "fliperama": "a retro arcade cabinet machine",
    "servidor": "a server rack tower with blinking lights",
    "monitor_terminal": "a computer monitor showing a terminal, on a desk",
    "cadeado": "a heavy brass padlock",
    "microfone": "a studio microphone on a stand",
    "trofeu": "a golden trophy cup",
    "poste": "a street lamp post, noir city",
    "hidrante": "a fire hydrant",
    "lixeira": "a metal street trash can",
    "banco_praca": "a wooden park bench",
}


def _key() -> str:
    with open(KEY_FILE) as f:
        return f.read().strip()


def _req(method: str, path: str, body=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(API + path, data=data, method=method,
                               headers={"Authorization": "Bearer " + _key(), "Content-Type": "application/json"})
    with urllib.request.urlopen(r, timeout=60) as resp:
        return json.load(resp)


def _poll(kind: str, tid: str) -> dict:
    for _ in range(120):
        t = _req("GET", "/v2/%s/%s" % (kind, tid))
        st = t.get("status")
        print("  %s... %s%%" % (st, t.get("progress", 0)))
        if st in ("SUCCEEDED", "FAILED"):
            return t
        time.sleep(10)
    return {"status": "TIMEOUT"}


def _download(url: str, name: str) -> None:
    os.makedirs(OUT, exist_ok=True)
    dst = os.path.join(OUT, name + ".glb")
    urllib.request.urlretrieve(url, dst)
    print("  salvo", dst, "%.1f KB" % (os.path.getsize(dst) / 1024))


def text_to_3d(name: str, prompt: str, poly: int = 2000) -> None:
    print("text->3d", name)
    pre = _req("POST", "/v2/text-to-3d", {"mode": "preview", "prompt": prompt + STYLE,
                                          "art_style": "realistic", "target_polycount": poly,
                                          "should_remesh": True, "topology": "triangle"})
    tid = pre.get("result")
    t = _poll("text-to-3d", tid)
    if t.get("status") != "SUCCEEDED":
        print("  falhou", t.get("status"))
        return
    ref = _req("POST", "/v2/text-to-3d", {"mode": "refine", "preview_task_id": tid, "enable_pbr": False})
    t = _poll("text-to-3d", ref.get("result"))
    url = (t.get("model_urls") or {}).get("glb")
    if url:
        _download(url, name)


def image_to_3d(name: str, image_path: str, poly: int = 2000) -> None:
    print("image->3d", name)
    import base64
    with open(image_path, "rb") as f:
        b64 = "data:image/png;base64," + base64.b64encode(f.read()).decode()
    pre = _req("POST", "/v1/image-to-3d", {"image_url": b64, "target_polycount": poly,
                                           "should_remesh": True, "enable_pbr": False})
    t = _poll("image-to-3d", pre.get("result"))
    url = (t.get("model_urls") or {}).get("glb")
    if url:
        _download(url, name)


def main() -> None:
    if len(sys.argv) < 2:
        print(__doc__)
        return
    cmd = sys.argv[1]
    poly = 2000
    if "--poly" in sys.argv:
        poly = int(sys.argv[sys.argv.index("--poly") + 1])
    if cmd == "text":
        text_to_3d(sys.argv[2], sys.argv[3], poly)
    elif cmd == "image":
        image_to_3d(sys.argv[2], sys.argv[3], poly)
    elif cmd == "manifest":
        for name, prompt in MANIFEST.items():
            if os.path.exists(os.path.join(OUT, name + ".glb")):
                print("pula", name)
                continue
            try:
                text_to_3d(name, prompt, poly)
            except Exception as e:
                print("  erro", name, e)


if __name__ == "__main__":
    main()
