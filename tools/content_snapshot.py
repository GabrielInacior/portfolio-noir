# -*- coding: utf-8 -*-
"""Snapshot do GitHub gerado no build com `gh` (login do dono), para fallback offline e para os
repos privados (so dados, sem codigo). Gera data/github_snapshot.json e data/readmes/<repo>.md.
Uso: python tools/content_snapshot.py"""
import base64
import json
import os
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data")
RD = os.path.join(OUT, "readmes")
os.makedirs(RD, exist_ok=True)

# repos que o portfolio mostra (id do projeto -> repo real no github)
REPO = {
    "rumor": "rumor", "fortress": "fortress-chaos", "buscavagas": "BuscaVagas",
    "orbix": "Orbix", "formataai": "FormataAI", "labia": "JoogoLabia",
    "airmessage": "AirMessage", "inaciocyber": "InacioCyber", "ankiana": "AnkiAna",
    "sitembm": "SiteMbm",
}


def gh(path, **kw):
    try:
        r = subprocess.run(["gh", "api", path], capture_output=True, text=True, encoding="utf8")
        if r.returncode != 0:
            return kw.get("default")
        return json.loads(r.stdout)
    except Exception:
        return kw.get("default")


def main():
    user = gh("user", default={}) or {}
    repos = gh("user/repos?per_page=100&sort=updated", default=[]) or []
    by_name = {r["name"].lower(): r for r in repos}
    total_stars = sum(r.get("stargazers_count", 0) for r in repos)

    # linguagens agregadas do perfil
    lang_agg = {}
    out_repos = []
    for pid, name in REPO.items():
        full = "GabrielInacior/" + name
        meta = by_name.get(name.lower())
        langs = gh("repos/%s/languages" % full, default={}) or {}
        for k, v in langs.items():
            lang_agg[k] = lang_agg.get(k, 0) + v
        # readme (base64) -> salva markdown bruto para o cartao terminal e o leitor
        rd = gh("repos/%s/readme" % full, default=None)
        readme_md = ""
        if rd and rd.get("content"):
            try:
                readme_md = base64.b64decode(rd["content"]).decode("utf8", "replace")
            except Exception:
                readme_md = ""
        if readme_md:
            with open(os.path.join(RD, pid + ".md"), "w", encoding="utf8") as f:
                f.write(readme_md)
        # arvore de pastas (nivel 1) para o cartao
        tree = []
        br = (meta or {}).get("default_branch", "main")
        t = gh("repos/%s/git/trees/%s" % (full, br), default=None)
        if t and t.get("tree"):
            tree = sorted({n["path"].split("/")[0] + ("/" if n["type"] == "tree" else "")
                           for n in t["tree"]})[:14]
        out_repos.append({
            "id": pid, "repo": name, "full": full,
            "private": bool((meta or {}).get("private", True)),
            "stars": (meta or {}).get("stargazers_count", 0),
            "lang": ((meta or {}).get("language")) or (max(langs, key=langs.get) if langs else None),
            "languages": langs,
            "updated": ((meta or {}).get("updated_at") or "")[:10],
            "pushed": ((meta or {}).get("pushed_at") or "")[:10],
            "desc": (meta or {}).get("description") or "",
            "homepage": (meta or {}).get("homepage") or None,
            "url": "https://github.com/" + full if meta else None,
            "tree": tree,
            "has_readme": bool(readme_md),
        })

    # atividade recente (eventos push publicos) para o ticker de LED
    events = gh("users/GabrielInacior/events/public?per_page=30", default=[]) or []
    activity = []
    for e in events:
        if e.get("type") == "PushEvent":
            repo = e.get("repo", {}).get("name", "").split("/")[-1]
            commits = e.get("payload", {}).get("commits", [])
            msg = commits[-1]["message"].split("\n")[0] if commits else "push"
            activity.append({"repo": repo, "msg": msg[:80], "at": e.get("created_at", "")[:10]})
        if len(activity) >= 12:
            break

    snap = {
        "generated": __import__("datetime").date.today().isoformat(),
        "login": user.get("login", "GabrielInacior"),
        "name": user.get("name", "Gabriel Inacio"),
        "bio": user.get("bio", ""),
        "public_repos": user.get("public_repos", 0),
        "followers": user.get("followers", 0),
        "total_stars": total_stars,
        "languages": dict(sorted(lang_agg.items(), key=lambda x: -x[1])),
        "activity": activity,
        "repos": out_repos,
    }
    with open(os.path.join(OUT, "github_snapshot.json"), "w", encoding="utf8") as f:
        json.dump(snap, f, ensure_ascii=False, indent=2)
    print("snapshot:", len(out_repos), "repos,", len(activity), "eventos,",
          sum(1 for r in out_repos if r["has_readme"]), "readmes")


if __name__ == "__main__":
    main()
