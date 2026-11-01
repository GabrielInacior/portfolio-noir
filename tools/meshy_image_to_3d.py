"""Meshy image-to-3D: manda uma arte conceito e baixa o GLB texturizado.

Uso: python tools/meshy_image_to_3d.py <imagem.png> <saida.glb> [polycount]
A chave fica FORA do repositório em ~/.meshy_key (nunca impressa nem gravada aqui).
"""
import base64
import json
import os
import sys
import time
import urllib.request

API = "https://api.meshy.ai/openapi/v1/image-to-3d"
KEY = open(os.path.expanduser("~/.meshy_key")).read().strip()


def call(url, data=None):
    req = urllib.request.Request(url, data=json.dumps(data).encode() if data is not None else None,
                                 headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read())


def main():
    img, out = sys.argv[1], sys.argv[2]
    poly = int(sys.argv[3]) if len(sys.argv) > 3 else 12000
    b64 = base64.b64encode(open(img, "rb").read()).decode()
    body = {
        "image_url": "data:image/png;base64," + b64,
        "ai_model": "latest",
        "topology": "triangle",
        "target_polycount": poly,
        "should_remesh": True,
        "should_texture": True,
        "enable_pbr": False,
        "symmetry_mode": "on",
    }
    try:
        tid = call(API, body)["result"]
    except urllib.error.HTTPError as e:
        print("HTTP", e.code, e.read().decode()[:600])
        raise SystemExit(1)
    print("task", tid, flush=True)
    t0 = time.time()
    while True:
        time.sleep(10)
        st = call(API + "/" + tid)
        s = st.get("status")
        print(f"  {int(time.time() - t0)}s {s} {st.get('progress')}", flush=True)
        if s == "SUCCEEDED":
            url = st["model_urls"]["glb"]
            urllib.request.urlretrieve(url, out)
            tex = st.get("texture_urls") or []
            print("OK", out, os.path.getsize(out), "bytes", "textures", len(tex))
            return
        if s in ("FAILED", "CANCELED", "EXPIRED"):
            print("falhou", json.dumps(st.get("task_error"))[:400])
            raise SystemExit(1)


if __name__ == "__main__":
    main()
