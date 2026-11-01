# SEO do portfólio (inaciodev.online)

O jogo roda num canvas, e buscadores não leem canvas. Por isso o site entrega **conteúdo real em
HTML** antes do jogo carregar. O jogo (cidade noir 3D) sobe por cima, após o primeiro clique.

## O que já está feito (gerado por `python tools/seo_build.py`, sai em `game/web/`)

- **Página inicial** (`/index.html`, pt-BR) com `h1`, hero, grade de projetos, Sobre, habilidades,
  experiência e contato, tudo em texto indexável. Botão "Entrar na cidade" leva ao jogo em `/jogo/`.
- **Versão em inglês** (`/en/index.html`) com `hreflang`, feita a partir do currículo.
- **Uma página por projeto** (`/projetos/<id>/`) com `title` e `description` próprios, imagem da
  vitrine, descrição, stack, breadcrumb e o roteiro do projeto.
- **Dados estruturados (JSON-LD)**: `Person` (nome, cargo, habilidades, redes), `CollectionPage`
  na home, e em cada projeto `SoftwareApplication`/`VideoGame` mais `BreadcrumbList`.
- **Prévia social**: `og.png` 1200x630 noir (fundo gerado localmente) com Open Graph e Twitter Card.
- **Idiomas**: pt-BR e en com `hreflang`.
- **Infra**: `sitemap.xml`, `robots.txt`, `404.html` estilizada, favicon e CSS leve.
- **Imagens**: colagens em WebP (com PNG de reserva) e `loading="lazy"` com `width`/`height`.

### Notas do Lighthouse (rodado local, servidor simples sem compressão)

| Categoria | Nota |
|---|---|
| SEO | 100 |
| Boas práticas | 100 |
| Acessibilidade | 97 |
| Performance | 75 |

A performance sobe sozinha num host de verdade, porque ali entram compressão (Brotli/Gzip),
cache de longa duração e CDN, que o servidor de teste não tem. O jogo pesado só é baixado depois
do clique, então não atrapalha a primeira pintura nem a indexação.

## O que só você (Gabriel) pode fazer

Nenhuma técnica garante o primeiro lugar em termos genéricos muito disputados (por exemplo
"desenvolvedor full stack"), porque isso depende de tempo e de outros sites apontando para o seu.
O alcançável com folga: dominar as buscas pelo seu nome e por termos específicos (RUMOR, jogo de
detetive para sala de aula, os nomes dos seus projetos), e ficar competitivo nos genéricos.

1. **Google Search Console**: adicionar o site, verificar a posse (TXT no DNS ou arquivo), e enviar
   `https://inaciodev.online/sitemap.xml`.
2. **Bing Webmaster Tools**: mesma coisa, importando do Search Console.
3. **Backlinks**: colocar o link do site no seu GitHub (perfil e repositórios), no LinkedIn
   (seção Sobre e Destaques) e em qualquer lugar onde você já apareça. É o que mais pesa.
4. **Confirmar o endereço**: garantir que `inaciodev.online` serve esta pasta, com HTTPS e com
   `www` redirecionando para o domínio sem `www` (ou o contrário), um só, para não dividir força.
5. Opcional: um perfil no Google de quem você é, para a busca pelo seu nome mostrar um cartão.

## Regerar

```bash
python tools/content_museum.py      # textos do museu
python tools/content_snapshot.py    # dados do GitHub (precisa do gh logado)
python tools/content_images.py      # colagens e cartões terminal
python tools/content_sync.py        # leva os dados para dentro do jogo
python tools/seo_build.py           # gera game/web/ (o site + SEO)
```
