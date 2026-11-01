# Portfólio Noir — Gabriel Inácio

Portfólio web como **jogo 3D em primeira pessoa**: uma cidade noir noturna por onde o visitante
anda, conhece os projetos em vitrines de neon, conversa com NPCs guia e abre dossiês. Feito em
Godot 4.7.1 (renderizador Compatibility), exportado para web, leve, bom no celular e no desktop.

Estética noir adulta (referência Vampire: The Masquerade Bloodlines) com acabamento pincelado do
RUMOR: azul da noite, neon quente, chuva, asfalto molhado refletindo as luzes.

## O que já funciona
- **Rua noir em primeira pessoa**: desktop com WASD + mouse (pointer lock); celular com alavanca
  virtual, olhar por arrasto e toque no letreiro para caminhar sozinho até ele.
- **Neon**: tubos finos emissivos com halo aditivo, letreiros com flicker, reflexo alongado nas
  poças, janelas acesas no skyline, feixes de poste. Fachadas texturizadas pinceladas.
- **Projetos**: cada um é uma vitrine com a capa atrás do vidro e um NPC guia. Aproxime-se e um
  anel acende; interagir abre a **conversa** e depois o **dossiê**.
- **Tela de diálogo** no nível do RUMOR: close 3D do personagem riggado (animação Mixamo), nome e
  função, fala datilografada, árvore de perguntas e botão para abrir o projeto; a expressão muda a
  cada fala.
- **Dossiês custom**: capa, descrição, stack, botões de site/GitHub (abre com `window.open` na web),
  mais Sobre mim e Contato. **Modo lista** para quem tem pressa.
- **Jogo de verdade**: entrada cinematográfica (ENTRAR destrava áudio e mouse), trilha própria com
  ducking e liga/desliga, minimapa e contador de projetos explorados.
- **Dados**: `data/projects.json`, `data/profile.json` e `data/github_snapshot.json` (gerado no
  build via `gh`, sem token no cliente).

## Rodar
```bash
# validar e importar (sem abrir o editor)
godot --headless --audio-driver Dummy --path game --import
# rodar
godot --path game
# capturas mudas
RUMOR_SHOT=/pasta godot --audio-driver Dummy --path game --resolution 1920x1080 res://tools_dev/shot.tscn
# snapshot do GitHub (usa gh logado localmente)
node tools/dev/github_snapshot.js
```

## Estrutura
```
game/            projeto Godot
  scripts/       cidade, jogador, HUD, dossiê, diálogo, minimapa, áudio, dados
  scripts/scene3d/character.gd   personagem riggado (atlas de expressão + Mixamo)
  assets/        fontes, céu e texturas pinceladas, capas, personagem, áudio
  tools_dev/     sonda de captura (fora da exportação)
data/            projects.json, profile.json, github_snapshot.json
tools/           art (céu/texturas por PIL), blender, ai_art, dev (snapshot)
docs/            APRENDIZADOS_WEB, HOSPEDAGEM, PROXIMOS_PASSOS
```

## Próximos passos
Ver [`docs/PROXIMOS_PASSOS.md`](docs/PROXIMOS_PASSOS.md): personagens bespoke mais sérios, bairro
com esquinas e interiores entráveis, GitHub ao vivo com READMEs em telas 3D, vitrines em colagem,
cartão GitHub/terminal para projetos sem imagem, e conteúdo do currículo/LinkedIn.

Feito por [Gabriel Inácio](https://github.com/GabrielInacior). Trilha "Bloodlines" original. Nenhum
asset pronto de terceiros.
