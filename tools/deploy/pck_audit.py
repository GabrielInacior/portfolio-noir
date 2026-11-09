"""Lista o conteúdo de um .pck do Godot 4 por pasta e por arquivo, ordenado por tamanho.
Uso: python tools/deploy/pck_audit.py site/jogo/index.pck [N arquivos]"""
import collections
import struct
import sys

f = open(sys.argv[1], "rb")
top = int(sys.argv[2]) if len(sys.argv) > 2 else 40
assert f.read(4) == b"GDPC"
ver, ma, mi, pa, flags = struct.unpack("<IIIII", f.read(20))
base, = struct.unpack("<Q", f.read(8))
if ver >= 3:
    dir_off, = struct.unpack("<Q", f.read(8))
    f.seek(dir_off)
else:
    f.read(64)
n, = struct.unpack("<I", f.read(4))
ents = []
for _ in range(n):
    l, = struct.unpack("<I", f.read(4))
    p = f.read(l).rstrip(b"\0").decode("utf8")
    off, size = struct.unpack("<QQ", f.read(16))
    f.read(16)
    f.read(4)
    ents.append((p, size))
tot = sum(s for _, s in ents)
print("arquivos", n, "total MB", round(tot / 1e6, 2))
by = collections.Counter()
ext = collections.Counter()
for p, s in ents:
    q = p.replace("res://", "").split("/")
    by["/".join(q[:2]) if len(q) > 2 else q[0]] += s
    ext[p.rsplit(".", 1)[-1] if "." in p else "?"] += s
print("--- por pasta")
for k, v in by.most_common(25):
    print("%7.2f MB %s" % (v / 1e6, k))
print("--- por extensão")
for k, v in ext.most_common(12):
    print("%7.2f MB %s" % (v / 1e6, k))
print("--- maiores arquivos")
for p, s in sorted(ents, key=lambda e: -e[1])[:top]:
    print("%7.0f KB %s" % (s / 1e3, p))
