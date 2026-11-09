"""Divide o .pck exportado do Godot 4 em pacotes: um principal por idioma (só o que a cidade precisa para
abrir, com os anúncios/outdoors do idioma escolhido) e pacotes em segundo plano (música, lojas).
Lê o formato PCK v4 (Godot 4.7) e grava pacotes novos no mesmo formato, sem reexportar nada.
O jogo carrega os extras com ProjectSettings.load_resource_pack (scripts/packs.gd); o carregador da página
(make_boot.py) baixa cada pacote em paralelo e o entrega ao motor com engine.copyToFS.
Uso: python tools/deploy/pck_split.py site/jogo/index.pck site/jogo   (gera main.pck lang_pt.pck lang_en.pck music.pck shops.pck)"""
import glob
import hashlib
import os
import re
import struct
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GAME = os.path.join(ROOT, "game")

# regras por caminho de ORIGEM (o arquivo importado .godot/imported/x-hash.ctex vira o caminho do original)
PACKS = [
    ("music", lambda s: s.startswith("assets/audio/music/")),
    ("shops", lambda s: s.startswith("assets/museum/") or re.match(
        r"assets/audio/amb/amb_(chuva_interior|escritorio|servidores|fliperama|bar|estudio|lab)\.", s) is not None),
    ("drop", lambda s: s.startswith("assets/tex/og_bg")),  # só serve à imagem de prévia do site (seo_build.py)
]
LANG = re.compile(r"(?:^|/)[^/]*_(pt|en)(?:[_.][^/]*)?$")


def read_pck(path):
    f = open(path, "rb")
    assert f.read(4) == b"GDPC"
    ver, ma, mi, pa, flags = struct.unpack("<IIIII", f.read(20))
    assert ver == 4 and flags & 2, "formato de pck não suportado: v%d flags %d" % (ver, flags)
    base, dir_off = struct.unpack("<QQ", f.read(16))
    f.seek(dir_off)
    n, = struct.unpack("<I", f.read(4))
    ents = []
    for _ in range(n):
        ln, = struct.unpack("<I", f.read(4))
        p = f.read(ln).rstrip(b"\0").decode("utf8")
        off, size = struct.unpack("<QQ", f.read(16))
        md5 = f.read(16)
        fl, = struct.unpack("<I", f.read(4))
        ents.append({"path": p, "off": base + off, "size": size, "md5": md5, "flags": fl})
    return f, (ver, ma, mi, pa), ents


def write_pck(out, f, ver, ents):
    HEAD = 112
    with open(out, "wb") as o:
        o.write(b"GDPC" + struct.pack("<IIIII", 4, ver[1], ver[2], ver[3], 2))
        o.write(struct.pack("<QQ", HEAD, 0))
        o.write(b"\0" * 64)
        o.write(b"\0" * (HEAD - o.tell()))
        table = []
        for e in ents:
            while (o.tell() - HEAD) % 16:
                o.write(b"\0")
            start = o.tell() - HEAD
            f.seek(e["off"])
            left = e["size"]
            while left:
                chunk = f.read(min(left, 1 << 22))
                o.write(chunk)
                left -= len(chunk)
            table.append((e, start))
        while o.tell() % 16:
            o.write(b"\0")
        dir_off = o.tell()
        o.write(struct.pack("<I", len(table)))
        for e, start in table:
            pb = e["path"].encode("utf8")
            pad = (4 - len(pb) % 4) % 4
            pb += b"\0" * pad
            o.write(struct.pack("<I", len(pb)) + pb + struct.pack("<QQ", start, e["size"]) + e["md5"] + struct.pack("<I", e["flags"]))
        o.seek(24 + 8)
        o.write(struct.pack("<Q", dir_off))


def main():
    src, outdir = sys.argv[1], sys.argv[2]
    f, ver, ents = read_pck(src)
    # nome importado -> caminho de origem
    imported = {}
    for imp in glob.glob(os.path.join(GAME, "**", "*.import"), recursive=True):
        t = open(imp, encoding="utf8").read()
        srcp = os.path.relpath(imp[:-7], GAME).replace(os.sep, "/")
        for x in re.findall(r'path[^=\n]*="res://\.godot/imported/([^"]+)"', t):
            imported[x] = srcp

    def origin(p):
        q = p[6:] if p.startswith("res://") else p
        if q.startswith(".godot/imported/"):
            return imported.get(q.split("/")[-1], q)
        if q.endswith(".import"):
            return q[:-7]
        return q

    groups = {"main": [], "lang_pt": [], "lang_en": [], "music": [], "shops": [], "drop": []}
    for e in ents:
        o = origin(e["path"])
        for name, rule in PACKS:
            if rule(o):
                groups[name].append(e)
                break
        else:
            m = LANG.search(o) if o.startswith("assets/") else None
            if m:
                groups["lang_" + m.group(1)].append(e)
            else:
                groups["main"].append(e)
    res = {}
    for name, es in groups.items():
        if name == "drop":
            print("%-8s %6.2f MB  descartado" % (name, sum(e["size"] for e in es) / 1e6))
            continue
        out = os.path.join(outdir, name + ".pck")
        write_pck(out, f, ver, es)
        res[name] = os.path.getsize(out)
        print("%-8s %6.2f MB  %4d arquivos" % (name, res[name] / 1e6, len(es)))
    return res


if __name__ == "__main__":
    main()
