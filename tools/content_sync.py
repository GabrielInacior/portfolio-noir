# -*- coding: utf-8 -*-
"""Copia os dados gerados (data/) para dentro do jogo (game/assets/data/), que e de onde o
cliente Godot le. Rode depois de content_museum / content_snapshot / content_images.
Uso: python tools/content_sync.py"""
import os
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "data")
DST = os.path.join(ROOT, "game", "assets", "data")

FILES = ["profile.json", "projects.json", "github_snapshot.json"]
DIRS = ["museum", "readmes", "collages"]


def main():
    os.makedirs(DST, exist_ok=True)
    n = 0
    for f in FILES:
        s = os.path.join(SRC, f)
        if os.path.exists(s):
            shutil.copy2(s, os.path.join(DST, f))
            n += 1
    for d in DIRS:
        s = os.path.join(SRC, d)
        if not os.path.isdir(s):
            continue
        dd = os.path.join(DST, d)
        os.makedirs(dd, exist_ok=True)
        for fn in os.listdir(s):
            shutil.copy2(os.path.join(s, fn), os.path.join(dd, fn))
            n += 1
    print("sincronizados", n, "arquivos para", os.path.relpath(DST, ROOT))


if __name__ == "__main__":
    main()
