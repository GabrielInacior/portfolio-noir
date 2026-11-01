"""Props 3D das lojas e da rua no padrão dos personagens (estilizado moderno limpo).

Etapas (cada uma pula o que já existe):
  python tools/props/build_props.py concept [nomes...]   # arte conceito gpt-image-2 -> tools/props/concepts/<nome>.png
  python tools/props/build_props.py meshy   [nomes...]   # Meshy image-to-3D (paralelo) -> tools/props/raw/<nome>.glb
Chaves lidas de arquivo (C:/Users/gabri/.openai_key, C:/Users/gabri/.meshy_key), nunca impressas.
Lista em tools/props/props_list.json (prompt, poly, zone).
"""
import base64
import concurrent.futures as cf
import json
import os
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CON = os.path.join(HERE, "concepts")
RAW = os.path.join(HERE, "raw")
os.makedirs(CON, exist_ok=True)
os.makedirs(RAW, exist_ok=True)
PROPS = json.load(open(os.path.join(HERE, "props_list.json"), encoding="utf8"))

STYLE = ("Stylized 3D game prop render, modern polished stylized game asset (same look as a clean stylized "
         "modular character pack): simplified readable shapes, slightly chunky proportions, clean smooth soft shading, "
         "flat solid colors with subtle gradients, minimal texture detail, crisp edges, no outlines. "
         "Single object only, isolated, centered, three-quarter view from slightly above, the whole object visible "
         "with margin, neutral plain light gray background, even studio lighting, no cast shadow on the floor, "
         "no text, no logos, no people. Mood: noir detective city at night but the object itself has readable colors. "
         "Object: ")


def _key(p):
    return open(p).read().strip()


def concept(name):
    out = os.path.join(CON, name + ".png")
    if os.path.exists(out):
        return name, "pula"
    body = {"model": "gpt-image-2", "prompt": STYLE + PROPS[name]["prompt"], "size": "1024x1024", "quality": "medium", "n": 1}
    req = urllib.request.Request("https://api.openai.com/v1/images/generations", data=json.dumps(body).encode(),
                                 headers={"Authorization": "Bearer " + _key("C:/Users/gabri/.openai_key"),
                                          "Content-Type": "application/json"})
    for t in range(5):
        try:
            with urllib.request.urlopen(req, timeout=600) as r:
                d = json.load(r)
            open(out, "wb").write(base64.b64decode(d["data"][0]["b64_json"]))
            return name, "ok"
        except urllib.error.HTTPError as e:
            msg = e.read().decode()[:300]
            if e.code in (429, 500, 502, 503):
                time.sleep(10 * (t + 1))
                continue
            return name, "erro %d %s" % (e.code, msg)
        except Exception as e:
            time.sleep(5)
            err = str(e)
    return name, "falhou"


MAPI = "https://api.meshy.ai/openapi/v1/image-to-3d"


def _mcall(url, data=None):
    req = urllib.request.Request(url, data=json.dumps(data).encode() if data is not None else None,
                                 headers={"Authorization": "Bearer " + _key("C:/Users/gabri/.meshy_key"),
                                          "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read())


def meshy(name):
    out = os.path.join(RAW, name + ".glb")
    if os.path.exists(out):
        return name, "pula"
    img = os.path.join(CON, name + ".png")
    if not os.path.exists(img):
        return name, "sem conceito"
    b64 = base64.b64encode(open(img, "rb").read()).decode()
    body = {"image_url": "data:image/png;base64," + b64, "ai_model": "latest", "topology": "triangle",
            "target_polycount": int(PROPS[name].get("poly", 1500)), "should_remesh": True, "should_texture": True,
            "enable_pbr": False}
    try:
        tid = _mcall(MAPI, body)["result"]
    except urllib.error.HTTPError as e:
        return name, "HTTP %d %s" % (e.code, e.read().decode()[:200])
    t0 = time.time()
    while time.time() - t0 < 1800:
        time.sleep(12)
        try:
            st = _mcall(MAPI + "/" + tid)
        except Exception:
            continue
        s = st.get("status")
        if s == "SUCCEEDED":
            urllib.request.urlretrieve(st["model_urls"]["glb"], out)
            return name, "ok %d KB %ds" % (os.path.getsize(out) // 1024, time.time() - t0)
        if s in ("FAILED", "CANCELED", "EXPIRED"):
            return name, "falhou " + json.dumps(st.get("task_error"))[:200]
    return name, "timeout"


def main():
    stage = sys.argv[1]
    names = sys.argv[2:] or list(PROPS.keys())
    fn = concept if stage == "concept" else meshy
    workers = 6 if stage == "concept" else 10
    with cf.ThreadPoolExecutor(workers) as ex:
        for name, res in ex.map(fn, names):
            print(name, res, flush=True)


if __name__ == "__main__":
    main()
