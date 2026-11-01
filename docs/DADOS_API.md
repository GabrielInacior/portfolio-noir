# Dados do portfólio: formato e API interna

Todo o conteúdo mora em `data/` e é copiado para `game/assets/data/` por `tools/content_sync.py`.
O jogo (cidade) lê de `res://assets/data/`.

## Arquivos

- `data/profile.json`: perfil (nome, cargo, bio, habilidades por grupo, experiência, formação, links).
- `data/projects.json`: lista de projetos (id, title, tagline, year, kind, neon, desc, stack, links,
  cover, private, highlight). É o índice que a cidade usa para os lugares.
- `data/museum/<id>.json`: o roteiro contado dentro da loja de cada projeto. Campos:
  `{ id, loja, ambiente, pieces: [ { titulo, texto, tipo, img? } ] }`.
  `tipo` sugere o objeto 3D que apresenta a peça: `quadro`, `telao`, `objeto`, `placa_stack`,
  `relatorio`, `linha_do_tempo`, `foto`. `img` (quando existe) é um nome em `assets/img` do RUMOR.
- `data/collages/<id>.png`: a textura da vitrine. Projeto com imagens vira colagem de polaroides;
  projeto sem imagens vira cartão estilo terminal/GitHub. Use como `albedo`/emissão nos telões.
- `data/readmes/<id>.md`: o README real do repositório (para o leitor em tela cheia).
- `data/github_snapshot.json`: fallback do GitHub gerado no build (ver abaixo).

## Snapshot do GitHub (`github_snapshot.json`)

```
{
  generated, login, name, bio, public_repos, followers, total_stars,
  languages: { "Python": bytes, ... },          # agregado, para a barra de linguagens
  activity: [ { repo, msg, at } ],              # para o ticker de LED
  repos: [ {
    id, repo, full, private, stars, lang,
    languages: { ... },                         # por repo, para a barra
    updated, pushed, desc, homepage, url,
    tree: [ "pasta/", "arquivo" ],              # nível 1, para o cartão terminal
    has_readme
  } ]
}
```

Repos privados entram só com estes dados (sem código). Nada de token no arquivo.

## Módulo ao vivo: `GithubLive` (`game/scripts/data/github_live.gd`)

Autoload sugerido (adicionar em `project.godot`): `GithubLive="*res://scripts/data/github_live.gd"`.
No navegador ele busca da API pública do GitHub (60 por hora por IP), guarda em cache no
`localStorage` e cai no snapshot quando falha ou estoura o limite. Nunca coloque token: roda no cliente.

```gdscript
GithubLive.ready_data.connect(_desenhar)   # snapshot/cache prontos para desenhar
GithubLive.updated.connect(_atualizar)     # chegou dado mais novo ao vivo
GithubLive.fetch()                          # tenta atualizar (ideal no web)

GithubLive.repo("rumor")      # Dictionary do repo
GithubLive.readme("rumor")    # markdown do README (do build)
GithubLive.activity()         # Array {repo,msg,at} para o ticker
GithubLive.languages()        # Dictionary linguagem->bytes
GithubLive.total_stars()      # int
```

O módulo não desenha nada: ele entrega os dados, e a cidade/telões decidem a aparência.
