"""Internacionalização: junta todos os textos em português do jogo (interface, falas dos NPCs, peças
de museu, perfil, projetos, carreira) e gera game/assets/data/i18n/en.json com traduções naturais
feitas por modelo da OpenAI (com cache: só traduz o que é novo). Também corrige acentos que faltam
nos roteiros (ex.: "codigo" -> "código") e regrava esses textos corrigidos nos JSON de origem.
Uso: python tools/i18n/build_i18n.py   (chave em C:/Users/gabri/.openai_key, nunca impressa)"""
import glob
import json
import os
import re
import sys
import urllib.request

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GAME = os.path.join(ROOT, "game")
OUT = os.path.join(GAME, "assets", "data", "i18n")
CACHE = os.path.join(ROOT, "tools", "i18n", "cache_en.json")
os.makedirs(OUT, exist_ok=True)

CTX = re.compile(r'(?:UI\.(?:label|title|button|ghost)|L\.t|L\.tf|neon\(m,|label3d\(m,|_choice_button\(|_tag\(|_chip\(|_rule\()\s*\(?\s*"((?:[^"\\]|\\.)+)"')
TERN = re.compile(r'"((?:[^"\\]|\\.)+)"\s+if\s+[^"]+\s+else\s+"((?:[^"\\]|\\.)+)"')
DICTV = re.compile(r'"(?:title|text|verb|q|a|doc_style_x)":\s*"((?:[^"\\]|\\.)+)"')
ASSIGN = re.compile(r'(?:greet|role|nm\.text|rl\.text|lb\.text)\s*=\s*"((?:[^"\\]|\\.)+)"')
SKIP = {"type", "title", "body", "bold", "marker", "frame", "screen", "monitor", "poster", "plaque", "prop", "arcade",
        "doc", "phone", "typewriter", "file", "switch", "drawer", "inspect", "terminal", "gallery", "skills", "timeline",
        "contact", "neutro", "feliz", "nervoso", "desconfiado", "?", "✕", "◀", "▶", "SNAKE"}
EXTRA = ["privado", "público", "atualizado", "Arquitetura", "Cliente", "Ideia", "Agentes", "Testes", "Como eu trabalho com IA",
         "Mais da história", "CARREIRA", "PRAÇA", "CONTATO", "SAIR", "EXAMINAR", "VER", "INSPECIONAR", "toque para", "[E] sair",
         "toque para sair", "toque para abrir", "[E] abrir  ·  toque no letreiro para ir até lá", "SAIR PARA A RUA",
         "Engenheiro de software full-stack · games · IA", "Formação", "Chamada recebida", "Arraste para girar",
         "Usada no trabalho profissional (veja a CARREIRA).", "Repositório privado", "Repositório privado: o código não é público, só a descrição.",
         "Toque numa tecnologia para ver os projetos em que ela foi usada.", "GAME DEV · IA · ARQUITETURA", "· %d/%d explorados", "· %d/%d examinados", "· 0/%d examinados"]


def ok(s):
    s2 = s.strip()
    if len(s2) < 2 or s2 in SKIP or s2.startswith("res://") or s2.startswith("#") or s2.startswith("http"):
        return False
    if re.fullmatch(r"[a-z_0-9]+", s2):
        return False
    if not re.search(r"[A-Za-zÀ-ú]", s2):
        return False
    return True


def collect():
    keys = []
    seen = set()

    def add(s, src):
        s = s.replace('\\n', '\n').replace('\\"', '"')
        if ok(s) and s not in seen:
            seen.add(s)
            keys.append((s, src))
    for f in glob.glob(os.path.join(GAME, "scripts", "**", "*.gd"), recursive=True):
        txt = open(f, encoding="utf8").read()
        for rx in (CTX, DICTV, ASSIGN):
            for m in rx.finditer(txt):
                add(m.group(1), "code")
        for m in TERN.finditer(txt):
            add(m.group(1), "code")
            add(m.group(2), "code")
    for s in EXTRA:
        add(s, "code")
    # dados
    prof = json.load(open(os.path.join(GAME, "assets", "data", "profile.json"), encoding="utf8"))
    for k in ["role", "tagline", "bio", "location"]:
        if isinstance(prof.get(k), str):
            add(prof[k], "data")
    for cat, items in prof.get("skills", {}).items():
        add(cat, "data")
        for t in items:
            if re.search(r"[a-zà-ú]{3,} [a-zà-ú]", t) or re.search(r"[ãçéíóúâêô]", t):
                add(t, "data")
    for e in prof.get("experience", []):
        for k in ["role", "period", "place"]:
            add(str(e.get(k, "")), "data")
        for h in e.get("highlights", []):
            add(h, "data")
    for e in prof.get("education", []):
        for v in e.values():
            if isinstance(v, str):
                add(v, "data")
    for e in prof.get("languages", []) if isinstance(prof.get("languages"), list) else []:
        if isinstance(e, str):
            add(e, "data")
        elif isinstance(e, dict):
            for v in e.values():
                if isinstance(v, str):
                    add(v, "data")
    for p in json.load(open(os.path.join(GAME, "assets", "data", "projects.json"), encoding="utf8")):
        for k in ["tagline", "desc", "highlight", "kind"]:
            v = p.get(k)
            if isinstance(v, str):
                add(v, "data")
            elif isinstance(v, list):
                for x in v:
                    add(str(x), "data")
    for f in glob.glob(os.path.join(GAME, "assets", "museum", "_items", "*.json")):
        d = json.load(open(f, encoding="utf8"))
        add(d.get("theme", {}).get("sub", ""), "museum")
        for it in d.get("items", []):
            for k in ["title", "text", "tag"]:
                add(str(it.get(k, "")), "museum")
    return keys


def openai(batch):
    key = open("C:/Users/gabri/.openai_key").read().strip()
    items = [{"i": i, "pt": s} for i, s in enumerate(batch)]
    prompt = ("You translate Brazilian Portuguese text from a noir 3D portfolio website (a first-person city where each shop "
              "shows a software project of Gabriel Inácio, a full-stack engineer, game developer and AI developer) into natural, "
              "fluent English, not literal. Keep proper nouns, product names and technology names. Keep placeholders like %d and %s "
              "and line breaks exactly. If the source is ALL CAPS, answer in ALL CAPS. Keep it concise like UI copy. Never use the em dash. "
              "Also, if the Portuguese is missing accents or cedillas (e.g. 'codigo', 'clinicas', 'integracao', 'nao'), return the "
              "corrected Portuguese in 'pt'; otherwise return the Portuguese unchanged in 'pt'. "
              "Answer only JSON: {\"items\": [{\"i\": 0, \"pt\": \"...\", \"en\": \"...\"}]}\n\n" + json.dumps(items, ensure_ascii=False))
    body = json.dumps({"model": "gpt-4.1", "temperature": 0.2, "response_format": {"type": "json_object"},
                       "messages": [{"role": "user", "content": prompt}]}).encode()
    req = urllib.request.Request("https://api.openai.com/v1/chat/completions", data=body,
                                 headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"})
    r = json.load(urllib.request.urlopen(req, timeout=180))
    out = json.loads(r["choices"][0]["message"]["content"])["items"]
    return {batch[o["i"]]: (o.get("pt", batch[o["i"]]), o.get("en", "")) for o in out if 0 <= o["i"] < len(batch)}


def main():
    cache = json.load(open(CACHE, encoding="utf8")) if os.path.exists(CACHE) else {}
    keys = collect()
    todo = [s for s, _ in keys if s not in cache]
    print("textos:", len(keys), "novos:", len(todo))
    for i in range(0, len(todo), 50):
        batch = todo[i:i + 50]
        try:
            res = openai(batch)
        except Exception as e:
            print("falhou lote", i, type(e).__name__)
            continue
        for s, (pt, en) in res.items():
            cache[s] = {"pt": pt, "en": en}
        json.dump(cache, open(CACHE, "w", encoding="utf8"), ensure_ascii=False, indent=0)
        print("lote", i // 50 + 1, "ok")
    en = {}
    fixes = {}
    for s, v in cache.items():
        if not v.get("en"):
            continue
        v["en"] = v["en"].replace(" — ", ", ").replace("—", "-")
        en[s] = v["en"]
        if v.get("pt") and v["pt"] != s:
            en[v["pt"]] = v["en"]
            fixes[s] = v["pt"]
    json.dump(en, open(os.path.join(OUT, "en.json"), "w", encoding="utf8"), ensure_ascii=False, indent=0)
    # corrige acentos nos JSON de origem (roteiros das lojas e manifestos)
    targets = glob.glob(os.path.join(ROOT, "data", "museum", "*.json")) + glob.glob(os.path.join(GAME, "assets", "museum", "_items", "*.json"))
    n = 0
    for f in targets:
        raw = open(f, encoding="utf8").read()
        d = json.loads(raw)

        def walk(x):
            nonlocal n
            if isinstance(x, dict):
                return {k: walk(v) for k, v in x.items()}
            if isinstance(x, list):
                return [walk(v) for v in x]
            if isinstance(x, str) and x in fixes:
                n += 1
                return fixes[x]
            return x
        json.dump(walk(d), open(f, "w", encoding="utf8"), ensure_ascii=False, indent=1)
    print("en.json:", len(en), "acentos corrigidos:", n)


if __name__ == "__main__":
    main()
