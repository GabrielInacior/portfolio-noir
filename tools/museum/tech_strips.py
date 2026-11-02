"""Fila de ícones das tecnologias de cada projeto (stack de data/projects.json mapeada para o atlas
game/assets/tech_icons por nome/alias). Uma imagem por projeto, usada na fachada da loja (verga sob o
letreiro), nos panfletos e onde mais a stack aparecer.
Saída: game/assets/tech_strips/<id>.png  (+ relatório de nomes sem ícone)
Uso: python tools/museum/tech_strips.py
"""
import json
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ICONS = os.path.join(ROOT, "game", "assets", "tech_icons")
OUT = os.path.join(ROOT, "game", "assets", "tech_strips")
os.makedirs(OUT, exist_ok=True)
EXTRA_ALIAS = {"node": ["node.js", "nodejs", "express.js"], "postgres": ["postgresql", "postgres rls", "rls"],
               "next": ["next.js", "nextjs"], "nuxt": ["nuxt 3", "nuxt.js"], "vue": ["vue 3", "vue.js"],
               "socketio": ["socket.io", "websocket", "websockets"], "openai": ["gpt-4o-mini", "gpt", "whisper"],
               "ollama": ["ia local", "llm local"], "flutter": ["flutter web"], "godot": ["gdscript", "godot 4"],
               "nest": ["nestjs", "nest.js"], "aws": ["aws s3", "s3", "amazon web services"], "tauri": ["rust + tauri"],
               "gemini": ["gemini api"], "fastapi": ["fast api"], "docker": ["docker compose", "containers"],
               "materialdesign": ["material 3", "material design"], "tailwind": ["tailwindcss", "tailwind css"]}


def index():
    idx = json.load(open(os.path.join(ROOT, "data", "tech_icons.json"), encoding="utf8"))
    m = {}
    for it in idx:
        names = [it["id"], it["name"]] + list(it.get("alias", [])) + EXTRA_ALIAS.get(it["id"], [])
        for n in names:
            m[n.lower().strip()] = it["id"]
    return m


def strip(ids, h=128, gap=18, pad=14):
    ims = [Image.open(os.path.join(ICONS, i + "_128.png")).convert("RGBA").resize((h, h), Image.LANCZOS) for i in ids]
    w = pad * 2 + len(ims) * h + (len(ims) - 1) * gap
    base = Image.new("RGBA", (w, h + pad * 2), (8, 10, 22, 235))
    d = ImageDraw.Draw(base)
    d.rounded_rectangle([1, 1, w - 2, h + pad * 2 - 2], radius=18, outline=(255, 255, 255, 60), width=3)
    x = pad
    for im in ims:
        base.alpha_composite(im, (x, pad))
        x += h + gap
    return base


def main():
    m = index()
    projs = json.load(open(os.path.join(ROOT, "data", "projects.json"), encoding="utf8"))
    projs = projs if isinstance(projs, list) else projs.get("projects", [])
    missing = {}
    for p in projs:
        ids = []
        for s in p.get("stack", []):
            k = s.lower().strip()
            i = m.get(k)
            if i is None:
                for part in k.replace("+", "/").replace(",", "/").split("/"):
                    i = m.get(part.strip())
                    if i:
                        break
            if i and i not in ids:
                ids.append(i)
            elif not i:
                missing.setdefault(p["id"], []).append(s)
        if ids:
            strip(ids[:7]).save(os.path.join(OUT, p["id"] + ".png"), optimize=True)
        p["tech_ids"] = ids
    print("faixas:", len(os.listdir(OUT)), "| sem ícone:", missing)
    json.dump({p["id"]: p.get("tech_ids", []) for p in projs}, open(os.path.join(OUT, "index.json"), "w", encoding="utf8"), indent=1)


if __name__ == "__main__":
    main()
