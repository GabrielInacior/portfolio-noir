"""Servidor local que imita a Vercel para testar carregamento: brotli em wasm/js/pck/html, cleanUrls,
Cache-Control igual ao vercel.json. Opcional: limita a banda (KB/s) para simular rede lenta.
Uso: python tools/deploy/serve_local.py [porta] [--kbps 2000] [--root site]
O brotli (qualidade 9) é gerado uma vez e guardado em .cache_br (fora do git)."""
import argparse
import functools
import hashlib
import json
import mimetypes
import os
import re
import sys
import time
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

import brotli

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ap = argparse.ArgumentParser()
ap.add_argument("port", nargs="?", type=int, default=8090)
ap.add_argument("--kbps", type=int, default=0)
ap.add_argument("--root", default="site")
ap.add_argument("--rtt", type=int, default=0, help="atraso por requisição, ms")
ap.add_argument("--slow-re", default="", help="só os caminhos que casam com esta regex usam --slow-kbps (ex.: pacote das lojas)")
ap.add_argument("--slow-kbps", type=int, default=0)
ap.add_argument("--fail-re", default="", help="caminhos que respondem 503 na 1ª tentativa (teste de nova tentativa)")
A = ap.parse_args()
SITE = os.path.join(ROOT, A.root)
CACHE = os.path.join(ROOT, "tools", "deploy", ".cache_br")
os.makedirs(CACHE, exist_ok=True)
RULES = []
for h in json.load(open(os.path.join(ROOT, "vercel.json"), encoding="utf8")).get("headers", []):
    RULES.append((re.compile("^" + h["source"] + "$"), {x["key"]: x["value"] for x in h["headers"]}))
COMP = (".wasm", ".js", ".pck", ".html", ".json", ".css", ".svg")
mimetypes.add_type("application/wasm", ".wasm")


FAILED = set()


class H(SimpleHTTPRequestHandler):
    def translate_path(self, path):
        p = path.split("?")[0].split("#")[0]
        p = re.sub(r"(index\.[0-9a-f]{10})c[0-9]+", lambda m: m.group(1), p)  # alias de teste a frio (?cold=N no carregador)
        fs = os.path.join(SITE, p.lstrip("/").replace("/", os.sep))
        if os.path.isdir(fs):
            fs = os.path.join(fs, "index.html")
        return fs

    def log_message(self, *a):
        pass

    def do_GET(self):
        fs = self.translate_path(self.path)
        if not os.path.isfile(fs):
            self.send_error(404)
            return
        if A.rtt:
            time.sleep(A.rtt / 1000)
        if A.fail_re and re.search(A.fail_re, self.path) and self.path not in FAILED:
            FAILED.add(self.path)
            self.send_error(503)
            return
        url = self.path.split("?")[0]
        ext = os.path.splitext(fs)[1].lower()
        data = None
        enc = None
        pre = any(rx.match(url) and "Content-Encoding" in hs for rx, hs in RULES)  # já comprimido no build (vercel.json)
        if not pre and ext in COMP and "br" in self.headers.get("Accept-Encoding", ""):
            st = os.stat(fs)
            key = hashlib.md5(f"{fs}{st.st_mtime_ns}{st.st_size}".encode()).hexdigest()
            cf = os.path.join(CACHE, key + ".br")
            if not os.path.isfile(cf):
                open(cf, "wb").write(brotli.compress(open(fs, "rb").read(), quality=9))
            data = open(cf, "rb").read()
            enc = "br"
        if data is None:
            data = open(fs, "rb").read()
        self.send_response(200)
        ctype = mimetypes.guess_type(fs)[0] or "application/octet-stream"
        hdr = {"Content-Type": ctype}
        for rx, hs in RULES:
            if rx.match(url):
                hdr.update(hs)
        if "Cache-Control" not in hdr:
            hdr["Cache-Control"] = "public, max-age=0, must-revalidate"
        for k, v in hdr.items():
            self.send_header(k, v)
        if enc:
            self.send_header("Content-Encoding", enc)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        try:
            kb = A.slow_kbps if (A.slow_re and re.search(A.slow_re, self.path)) else A.kbps
            if kb:
                chunk = max(4096, kb * 1024 // 20)
                for i in range(0, len(data), chunk):
                    self.wfile.write(data[i:i + chunk])
                    time.sleep(0.05)
            else:
                self.wfile.write(data)
        except (BrokenPipeError, ConnectionResetError):
            pass


ThreadingHTTPServer(("127.0.0.1", A.port), H).serve_forever()
