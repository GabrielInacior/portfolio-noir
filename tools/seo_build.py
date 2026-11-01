# -*- coding: utf-8 -*-
"""Gera a camada de SEO em game/web/ (conteudo real indexavel; o jogo carrega por cima apos o
clique). Faz: index.html (pt-BR) e en/index.html, uma pagina estatica por projeto, JSON-LD
(Person, WebSite, ProfilePage, SoftwareApplication), sitemap.xml, robots.txt, 404.html, a imagem
Open Graph 1200x630 e o CSS do site. Uso: python tools/seo_build.py"""
import html
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEB = os.path.join(ROOT, "game", "web")
SITE = "https://inaciodev.online"

profile = json.load(open(os.path.join(ROOT, "data", "profile.json"), encoding="utf8"))
projects = json.load(open(os.path.join(ROOT, "data", "projects.json"), encoding="utf8"))
museum = {}
for p in projects:
    mp = os.path.join(ROOT, "data", "museum", p["id"] + ".json")
    if os.path.exists(mp):
        museum[p["id"]] = json.load(open(mp, encoding="utf8"))

os.makedirs(os.path.join(WEB, "projetos"), exist_ok=True)
os.makedirs(os.path.join(WEB, "assets"), exist_ok=True)
e = html.escape

KIND = {"game": "Jogo", "web": "Aplicacao web", "mobile": "Aplicativo", "security": "Ferramenta de seguranca"}
SCHEMA_KIND = {"game": "VideoGame", "web": "WebApplication", "mobile": "MobileApplication", "security": "SoftwareApplication"}


def _langjs(canonical):
    """Abre o site na língua do visitante (navigator.languages), respeitando a escolha salva
    (pf_lang) e sem redirecionar robôs de busca (cada língua continua indexável)."""
    if canonical == SITE + "/":
        cond = "s==='en'||(!s&&!/^pt/i.test(l))"
        dest = "/en/"
    elif canonical == SITE + "/en/":
        cond = "s==='pt'||(!s&&/^pt/i.test(l))"
        dest = "/"
    else:
        return ""
    return ("<script>(function(){try{var s=localStorage.getItem('pf_lang');var l=(navigator.languages&&navigator.languages[0])||navigator.language||'';"
            "if(/bot|crawl|spider|slurp|lighthouse|preview/i.test(navigator.userAgent))return;if(%s)location.replace('%s');}catch(e){}})();</script>" % (cond, dest))


def head(title, desc, canonical, og_img="/assets/og.png", extra_ld=None, alt_lang=None):
    ld = []
    person = {
        "@context": "https://schema.org", "@type": "Person",
        "name": profile["fullName"], "alternateName": "Gabriel Inacio",
        "jobTitle": profile["role"], "url": SITE, "image": SITE + "/assets/foto.jpg",
        "email": "mailto:" + profile["links"]["email"],
        "address": {"@type": "PostalAddress", "addressLocality": "Sao Paulo", "addressCountry": "BR"},
        "sameAs": [profile["links"]["github"], profile["links"]["linkedin"]],
        "knowsAbout": sum(list(profile["skills"].values()), []),
    }
    ld.append(person)
    if extra_ld:
        ld.append(extra_ld)
    ld_tags = "\n".join('<script type="application/ld+json">%s</script>' % json.dumps(x, ensure_ascii=False) for x in ld)
    alt = ""
    if alt_lang:
        alt = '\n  <link rel="alternate" hreflang="%s" href="%s">' % alt_lang
    return """<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <title>{title}</title>
  <meta name="description" content="{desc}">
  <link rel="canonical" href="{canonical}">{alt}
  <meta property="og:type" content="website">
  <meta property="og:title" content="{title}">
  <meta property="og:description" content="{desc}">
  <meta property="og:image" content="{site}{og}">
  <meta property="og:url" content="{canonical}">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="{title}">
  <meta name="twitter:description" content="{desc}">
  <meta name="twitter:image" content="{site}{og}">
  <meta name="theme-color" content="#060c1f">
  <link rel="icon" href="/assets/favicon.png">
  <link rel="stylesheet" href="/assets/site.css">
  {ld}
  {langjs}
</head>
<body>""".format(langjs=_langjs(canonical), title=e(title), desc=e(desc), canonical=e(canonical), alt=alt,
                 site=SITE, og=og_img, ld=ld_tags)


def nav():
    return """
  <header class="top"><a class="brand" href="/">INACIODEV</a>
    <nav><a href="/#projetos">Projetos</a><a href="/#sobre">Sobre</a><a href="/#contato">Contato</a>
    <a href="/en/" onclick="try{localStorage.setItem('pf_lang','en')}catch(e){}">EN</a>
    <a href="/" onclick="try{localStorage.setItem('pf_lang','pt')}catch(e){}">PT</a></nav></header>"""


def footer():
    L = profile["links"]
    return """
  <footer class="foot">
    <p>Gabriel Inacio Rodrigues Silva, Sao Paulo, Brasil.</p>
    <p><a href="{gh}">GitHub</a> · <a href="{li}">LinkedIn</a> · <a href="mailto:{em}">{em}</a></p>
  </footer>
  <script>
    // O jogo (cidade noir 3D) carrega por cima do conteudo apos o primeiro gesto, para nao atrasar
    // a leitura nem a indexacao. Sem JS, o site inteiro continua funcionando como portfolio.
    (function(){{
      var b=document.getElementById('jogar'); if(!b) return;
      b.addEventListener('click',function(){{ location.href='/jogo/'; }});
    }})();
  </script>
</body></html>""".format(gh=L["github"], li=L["linkedin"], em=L["email"])


def index_pt():
    L = profile["links"]
    cards = ""
    for p in projects:
        img = "/assets/collages/%s.webp" % p["id"]
        cards += """
      <a class="card" href="/projetos/{id}/" style="--neon:{neon}">
        <img loading="lazy" src="{img}" alt="{title}, {kind}" width="1280" height="800">
        <div class="card-body"><h3>{title}</h3><p>{tag}</p>
        <ul class="stack">{stack}</ul></div></a>""".format(
            id=p["id"], neon=p.get("neon", "#ffc83d"), img=img, title=e(p["title"]),
            kind=e(KIND.get(p["kind"], "Projeto")), tag=e(p["tagline"]),
            stack="".join("<li>%s</li>" % e(s) for s in p["stack"][:5]))
    skills = ""
    for group, items in profile["skills"].items():
        skills += "<div class='skillgroup'><h4>%s</h4><p>%s</p></div>" % (e(group), e(", ".join(items)))
    exp = ""
    for x in profile["experience"]:
        exp += "<li><strong>%s</strong>, %s <span>%s</span><ul>%s</ul></li>" % (
            e(x["role"]), e(x["company"]), e(x["period"]),
            "".join("<li>%s</li>" % e(h) for h in x["highlights"]))
    collection = {
        "@context": "https://schema.org", "@type": "CollectionPage",
        "name": "Projetos de Gabriel Inacio",
        "hasPart": [{"@type": SCHEMA_KIND.get(p["kind"], "SoftwareApplication"),
                     "name": p["title"], "url": "%s/projetos/%s/" % (SITE, p["id"]),
                     "description": p["desc"]} for p in projects]}
    s = head("Gabriel Inacio · Desenvolvedor Full-Stack, Game Dev e IA",
             profile["tagline"] + ". " + profile["bio"][0], SITE + "/",
             extra_ld=collection, alt_lang=("en", SITE + "/en/"))
    s += nav()
    s += """
  <main>
    <section class="hero">
      <p class="eyebrow">{role}</p>
      <h1>Gabriel Inacio</h1>
      <p class="lead">{tagline}</p>
      <div class="cta"><button id="jogar">Entrar na cidade</button>
        <a class="ghost" href="#projetos">Ver projetos</a></div>
      <p class="hint">Entre na cidade noir em 3D. Prefere ler? Está tudo aqui embaixo.</p>
    </section>
    <section id="projetos"><h2>Projetos</h2><div class="grid">{cards}</div></section>
    <section id="sobre"><h2>Sobre</h2>{bio}
      <div class="skills">{skills}</div>
      <h3>Experiencia</h3><ul class="exp">{exp}</ul>
      <h3>Formacao</h3><ul>{edu}</ul></section>
    <section id="contato"><h2>Contato</h2>
      <p>Aberto a conversas sobre projetos, vagas e parcerias.</p>
      <p class="links"><a href="mailto:{em}">{em}</a> · <a href="{gh}">GitHub</a> · <a href="{li}">LinkedIn</a></p>
    </section>
  </main>""".format(
        role=e(profile["role"]), tagline=e(profile["tagline"]), cards=cards,
        bio="".join("<p>%s</p>" % e(b) for b in profile["bio"]),
        skills=skills, exp=exp,
        edu="".join("<li><strong>%s</strong>, %s <span>%s</span>. %s</li>" % (
            e(x["course"]), e(x["school"]), e(x["period"]), e(x["note"])) for x in profile["education"]),
        em=L["email"], gh=L["github"], li=L["linkedin"])
    s += footer()
    return s


def _en(t):
    path = os.path.join(ROOT, "game", "assets", "data", "i18n", "en.json")
    d = json.load(open(path, encoding="utf8")) if os.path.exists(path) else {}
    return d.get(t, t)


def index_en():
    L = profile["links"]
    exp_html = ""
    for x in profile["experience"]:
        exp_html += "<article class='job'><h3>%s · %s</h3><p class='meta'>%s · %s</p><ul>%s</ul></article>" % (
            e(_en(x["role"])), e(x["company"]), e(_en(x["period"])), e(_en(x["place"])),
            "".join("<li>%s</li>" % e(_en(h)) for h in x.get("highlights", [])))
    cards = "".join(
        '<a class="card" href="/projetos/{id}/" style="--neon:{n}"><img loading="lazy" src="/assets/collages/{id}.webp" alt="{t}" width="1280" height="800"><div class="card-body"><h3>{t}</h3><p>{tag}</p></div></a>'.format(
            id=p["id"], n=p.get("neon", "#ffc83d"), t=e(p["title"]), tag=e(_en(p["tagline"]))) for p in projects)
    s = head("Gabriel Inacio · Full-Stack Software Engineer, Game Dev and AI",
             "Full-stack software engineer with 4+ years building web, mobile and backend systems, LLM integration and game development.",
             SITE + "/en/", alt_lang=("pt-BR", SITE + "/"))
    s += nav()
    s += """
  <main>
    <section class="hero"><p class="eyebrow">Full-Stack Software Engineer</p>
      <h1>Gabriel Inacio</h1>
      <p class="lead">4+ years turning ideas into products that reach production. Web, mobile, game dev and AI.</p>
      <div class="cta"><button id="jogar">Enter the city</button><a class="ghost" href="#projects">See projects</a></div></section>
    <section id="projects"><h2>Projects</h2><div class="grid">%s</div></section>
    <section id="about"><h2>About</h2>
      <p>Full-stack software engineer with 4+ years building web, mobile and backend systems. I lead technical teams, own architecture and ship to production. Core developer at a Brazilian public procurement SaaS, original developer of ACL (Public Bidding Assistant). I work extensively with AI and LLMs, both as development tools (Claude Code, agents) and inside production apps.</p>
      <p class="links"><a href="mailto:%s">%s</a> · <a href="%s">GitHub</a> · <a href="%s">LinkedIn</a></p></section>
    <section id="experience"><h2>Experience</h2>%s</section>
  </main>""" % (cards, L["email"], L["email"], L["github"], L["linkedin"], exp_html)
    s += footer()
    return s


def project_page(p):
    m = museum.get(p["id"], {})
    pieces = m.get("pieces", [])
    body = ""
    for pc in pieces:
        body += "<section class='piece'><h2>%s</h2><p>%s</p></section>" % (e(pc["titulo"]), e(pc["texto"]))
    links = ""
    for k, v in p.get("links", {}).items():
        label = {"site": "Acessar", "github": "Código no GitHub"}.get(k, k)
        links += '<a class="btn" href="%s" rel="noopener">%s</a>' % (e(v), e(label))
    if p.get("private") and "github" not in p.get("links", {}):
        links += '<span class="btn ghost">Repositório privado</span>'
    app = {"@context": "https://schema.org", "@type": SCHEMA_KIND.get(p["kind"], "SoftwareApplication"),
           "name": p["title"], "description": p["desc"], "applicationCategory": KIND.get(p["kind"], "Software"),
           "operatingSystem": "Web", "author": {"@type": "Person", "name": profile["fullName"]},
           "url": "%s/projetos/%s/" % (SITE, p["id"]),
           "image": "%s/assets/collages/%s.png" % (SITE, p["id"]),
           "keywords": ", ".join(p["stack"])}
    if p.get("links", {}).get("site"):
        app["installUrl"] = p["links"]["site"]
    bc = {"@context": "https://schema.org", "@type": "BreadcrumbList", "itemListElement": [
        {"@type": "ListItem", "position": 1, "name": "Projetos", "item": SITE + "/#projetos"},
        {"@type": "ListItem", "position": 2, "name": p["title"], "item": "%s/projetos/%s/" % (SITE, p["id"])}]}
    s = head("%s · %s | Gabriel Inacio" % (p["title"], p["tagline"]),
             p["desc"], "%s/projetos/%s/" % (SITE, p["id"]),
             extra_ld={"@graph": [app, bc]})
    s += nav()
    s += """
  <main class="project" style="--neon:{neon}">
    <nav class="crumb"><a href="/">Início</a> / <a href="/#projetos">Projetos</a> / <span>{title}</span></nav>
    <header class="phead"><p class="eyebrow">{kind} · {year}</p><h1>{title}</h1>
      <p class="lead">{tag}</p><div class="cta">{links}</div></header>
    <img class="shot" loading="lazy" src="/assets/collages/{id}.webp" alt="Imagens do projeto {title}" width="1280" height="800">
    <p class="desc">{desc}</p>
    <ul class="stack big">{stack}</ul>
    {body}
  </main>""".format(
        neon=p.get("neon", "#ffc83d"), title=e(p["title"]), kind=e(KIND.get(p["kind"], "Projeto")),
        year=p.get("year", ""), tag=e(p["tagline"]), links=links, id=p["id"], desc=e(p["desc"]),
        stack="".join("<li>%s</li>" % e(x) for x in p["stack"]), body=body)
    s += footer()
    return s


def css():
    return """:root{--bg:#060c1f;--ink:#05091a;--paper:#e8ecf7;--mist:#9fb0d8;--amber:#ffc83d;--pink:#ff4fa3;--cyan:#5aaadc;--neon:#ffc83d}
*{box-sizing:border-box}html{scroll-behavior:smooth}
body{margin:0;background:radial-gradient(120% 80% at 70% -10%,#122046 0%,var(--bg) 55%,var(--ink) 100%);color:var(--paper);font-family:'Nunito',system-ui,-apple-system,Segoe UI,Roboto,sans-serif;line-height:1.6}
a{color:var(--cyan);text-decoration:none}a:hover{color:var(--amber)}
.top{display:flex;justify-content:space-between;align-items:center;padding:18px 24px;position:sticky;top:0;background:rgba(6,12,31,.82);backdrop-filter:blur(8px);z-index:10;border-bottom:1px solid #1a2b50}
.top{border-bottom:1px solid #1a2b50}.brand{font-weight:900;letter-spacing:3px;color:var(--amber)}
.top nav a{margin-left:18px;color:var(--mist);font-weight:700}
main{max-width:1120px;margin:0 auto;padding:0 20px}
.hero{padding:72px 0 40px}.eyebrow{color:var(--pink);font-weight:800;letter-spacing:2px;text-transform:uppercase;margin:0 0 6px}
h1{font-size:clamp(48px,9vw,104px);margin:.1em 0;line-height:.95;background:linear-gradient(90deg,var(--cyan),var(--amber) 40%,var(--pink));-webkit-background-clip:text;background-clip:text;color:transparent}
.lead{font-size:clamp(18px,2.4vw,26px);color:var(--mist);max-width:40ch}
.cta{display:flex;gap:12px;flex-wrap:wrap;margin:22px 0}
button,.btn{font:inherit;font-weight:800;border:0;border-radius:12px;padding:14px 26px;background:var(--amber);color:#05091a;cursor:pointer}
.ghost{background:transparent;border:2px solid var(--neon);color:var(--paper)}
.hint{color:#6f82b4;font-size:14px}
h2{font-size:clamp(28px,5vw,44px);margin:56px 0 18px;border-left:5px solid var(--neon);padding-left:14px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:18px}
.card{display:block;background:#0c1430;border:1px solid #1a2b50;border-radius:16px;overflow:hidden;transition:.18s;border-top:3px solid var(--neon)}
.card:hover{transform:translateY(-4px);box-shadow:0 14px 40px rgba(0,0,0,.5),0 0 24px -6px var(--neon)}
.card img{width:100%;display:block;aspect-ratio:16/10;object-fit:cover}
.card-body{padding:14px 16px}.card-body h3{margin:.2em 0;color:var(--paper)}.card-body p{color:var(--mist);margin:.2em 0;font-size:15px}
.stack{list-style:none;display:flex;flex-wrap:wrap;gap:6px;padding:0;margin:10px 0 0}
.stack li{font-size:12px;color:var(--cyan);border:1px solid #23407a;border-radius:999px;padding:2px 10px}
.stack.big li{font-size:14px;padding:5px 14px}
.skills{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:14px;margin:12px 0}
.skillgroup{background:#0b1026;border:1px solid #1a2b50;border-radius:12px;padding:12px 16px}
.skillgroup h4{margin:.2em 0;color:var(--amber)}.skillgroup p{color:var(--mist);margin:.2em 0;font-size:15px}
.exp>li{margin:14px 0}.exp span{color:#6f82b4;font-size:14px;margin-left:8px}
.project .phead{padding:18px 0}.crumb{color:#6f82b4;font-size:14px;padding-top:18px}
.shot{width:100%;border-radius:16px;border:1px solid #1a2b50;margin:14px 0}
.desc{font-size:19px;color:var(--mist)}
.piece{border-left:3px solid var(--neon);padding:4px 0 4px 16px;margin:16px 0}.piece h2{border:0;padding:0;font-size:22px;margin:0 0 4px}
.foot{max-width:1120px;margin:60px auto 30px;padding:24px 20px;border-top:1px solid #1a2b50;color:#6f82b4}
@media(max-width:640px){.hero{padding:48px 0 24px}}
"""


def og_image():
    try:
        from PIL import Image, ImageDraw, ImageFont, ImageFilter
    except Exception:
        return
    fonts = os.path.join(ROOT, "game", "assets", "fonts")
    W, H = 1200, 630
    # fundo: render noir local (Stable Diffusion) quando existir, senao degrade pintado
    bg = os.path.join(ROOT, "game", "assets", "tex", "og_bg.png")
    if os.path.exists(bg):
        src = Image.open(bg).convert("RGB")
        r = max(W / src.width, H / src.height)
        src = src.resize((int(src.width * r), int(src.height * r)), Image.LANCZOS)
        img = src.crop((0, 0, W, H))
        # escurece a esquerda para o texto ler
        shade = Image.new("L", (W, H), 0)
        sd = shade.load()
        for x in range(W):
            v = int(220 * max(0, 1 - x / (W * 0.8)))
            for y in range(H):
                sd[x, y] = v
        img = Image.composite(Image.new("RGB", (W, H), (4, 7, 16)), img, shade)
    else:
        img = Image.new("RGB", (W, H))
        d0 = ImageDraw.Draw(img)
        for y in range(H):
            k = y / H
            d0.line([(0, y), (W, y)], fill=(int(9 + 10 * (1 - k)), int(14 + 16 * (1 - k)), int(30 + 40 * (1 - k))))
    d = ImageDraw.Draw(img)

    def F(n, s):
        return ImageFont.truetype(os.path.join(fonts, n), s)
    for off, c in [((-6, -4), (90, 170, 220)), ((6, 4), (255, 79, 163)), ((0, 0), (255, 200, 61))]:
        d.text((70 + off[0], 150 + off[1]), "GABRIEL INACIO", font=F("BebasNeue-Regular.ttf", 128), fill=c)
    d.text((74, 300), "Desenvolvedor Full-Stack · Game Dev · IA", font=F("SpecialElite-Regular.ttf", 40), fill=(232, 236, 248))
    d.text((74, 380), "Engenharia de software, games e IA", font=F("Nunito-Var.ttf", 32), fill=(159, 176, 216))
    d.text((74, 540), "inaciodev.online", font=F("BebasNeue-Regular.ttf", 52), fill=(255, 79, 163))
    img.save(os.path.join(WEB, "assets", "og.png"))


def main():
    open(os.path.join(WEB, "index.html"), "w", encoding="utf8").write(index_pt())
    os.makedirs(os.path.join(WEB, "en"), exist_ok=True)
    open(os.path.join(WEB, "en", "index.html"), "w", encoding="utf8").write(index_en())
    for p in projects:
        d = os.path.join(WEB, "projetos", p["id"])
        os.makedirs(d, exist_ok=True)
        open(os.path.join(d, "index.html"), "w", encoding="utf8").write(project_page(p))
    open(os.path.join(WEB, "assets", "site.css"), "w", encoding="utf8").write(css())
    # colagens acessiveis ao site
    col_dst = os.path.join(WEB, "assets", "collages")
    os.makedirs(col_dst, exist_ok=True)
    import shutil
    from PIL import Image as _Img
    for fn in os.listdir(os.path.join(ROOT, "data", "collages")):
        if not fn.endswith(".png"):
            continue
        shutil.copy2(os.path.join(ROOT, "data", "collages", fn), os.path.join(col_dst, fn))
        # webp leve para o site (LCP mais rapido; o PNG fica como fallback e para o JSON-LD)
        _Img.open(os.path.join(ROOT, "data", "collages", fn)).convert("RGB").save(
            os.path.join(col_dst, fn[:-4] + ".webp"), "WEBP", quality=82, method=6)
    foto = os.path.join(ROOT, "game", "assets", "foto_gabriel.png")
    if os.path.exists(foto):
        shutil.copy2(foto, os.path.join(WEB, "assets", "foto.jpg"))
        shutil.copy2(foto, os.path.join(WEB, "assets", "favicon.png"))
    og_image()
    # sitemap
    urls = [SITE + "/", SITE + "/en/"] + ["%s/projetos/%s/" % (SITE, p["id"]) for p in projects]
    sm = '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
    for u in urls:
        sm += "  <url><loc>%s</loc><changefreq>monthly</changefreq></url>\n" % u
    sm += "</urlset>\n"
    open(os.path.join(WEB, "sitemap.xml"), "w", encoding="utf8").write(sm)
    open(os.path.join(WEB, "robots.txt"), "w", encoding="utf8").write(
        "User-agent: *\nAllow: /\nSitemap: %s/sitemap.xml\n" % SITE)
    open(os.path.join(WEB, "404.html"), "w", encoding="utf8").write(
        head("Pagina nao encontrada | Gabriel Inacio", "Esta rua nao existe no mapa.", SITE + "/404") +
        nav() + '<main class="hero"><h1>404</h1><p class="lead">Esta rua nao existe no mapa. <a href="/">Voltar ao inicio</a>.</p></main>' + footer())
    print("seo: index pt/en,", len(projects), "paginas de projeto, sitemap, robots, 404, og.png, css")


if __name__ == "__main__":
    main()
